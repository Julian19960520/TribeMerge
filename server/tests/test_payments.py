"""Paid content: order → pay → grant → apply/upload → ack, plus duplicates, lost replies and the amber ledger."""
import uuid

import pytest
from sqlalchemy import select
from sqlalchemy.orm import Session

from app import catalog, clock, payments
from app.config import get_settings
from app.db import engine
from app.models import Account, AuditLog, Grant, PaymentOrder
from conftest import snapshot


def order(player, product, detail=None, key=None):
    return player.c.post('/v1/payments/orders', json={'product': product, 'detail': detail or {}},
                         headers={**player.h(), 'Idempotency-Key': key or uuid.uuid4().hex})


def buy(player, product, detail=None):
    created = order(player, product, detail)
    assert created.status_code == 200, created.text
    paid = player.post('/v1/payments/mock/pay', {'order_id': created.json()['order']['id']})
    assert paid.status_code == 200, paid.text
    return paid.json()


def grants(player):
    return player.get('/v1/payments/grants').json()['grants']


def applied(*grant_ids, **fields):
    """A client snapshot after the `grant` command recorded these ids in replay_meta."""
    return snapshot(replay_meta={'seq': 1, 'grants': {gid: 1 for gid in grant_ids}}, **fields)


def rows(model, **where):
    with Session(engine()) as db:
        return list(db.execute(select(model).filter_by(**where)).scalars())


def account(player):
    with Session(engine()) as db:
        return db.get(Account, player.id)


def test_order_pay_grant_ack(player):
    created = order(player, 'amber:0').json()['order']
    assert created['status'] == 'created' and created['price_fen'] == 600 and created['grant_id'] == ''
    assert grants(player) == []
    paid = player.post('/v1/payments/mock/pay', {'order_id': created['id']}).json()
    grant = paid['grant']
    assert paid['order']['status'] == 'paid' and paid['order']['grant_id'] == grant['id']
    assert grant['content'] == {'product': 'amber:0', 'amber': 80}
    assert [g['id'] for g in grants(player)] == [grant['id']]
    assert account(player).paid_amber == 80
    # Acknowledging before the snapshot that applied it is uploaded does not deliver it.
    early = player.post('/v1/payments/grants/ack', {'ids': [grant['id']]}).json()
    assert early['delivered'] == [] and early['pending'] == [grant['id']]
    assert len(grants(player)) == 1
    assert player.upload(applied(grant['id'], amber=80), 0).json()['version'] == 1
    ack = player.post('/v1/payments/grants/ack', {'ids': [grant['id']]}).json()
    assert ack['delivered'] == [grant['id']] and ack['pending'] == []
    assert grants(player) == []
    assert rows(Grant, account_id=player.id)[0].delivered_version == 1


def test_create_order_is_idempotent(player):
    key = uuid.uuid4().hex
    first = order(player, 'amber:1', key=key).json()
    again = order(player, 'amber:1', key=key).json()
    assert first['order']['id'] == again['order']['id']
    assert len(rows(PaymentOrder, account_id=player.id)) == 1
    reused = order(player, 'amber:2', key=key)
    assert reused.status_code == 409 and reused.json()['error'] == 'idempotency_key_reused'
    missing = player.post('/v1/payments/orders', {'product': 'amber:1'})
    assert missing.status_code == 400 and missing.json()['error'] == 'idempotency_key_required'


def test_lost_pay_reply_never_grants_twice(player):
    created = order(player, 'amber:3').json()['order']
    first = player.post('/v1/payments/mock/pay', {'order_id': created['id']}).json()
    # The reply was lost; the client pays again with the same order.
    second = player.post('/v1/payments/mock/pay', {'order_id': created['id']}).json()
    assert first['grant']['id'] == second['grant']['id']
    assert len(rows(Grant, account_id=player.id)) == 1 and account(player).paid_amber == 2500
    assert len(grants(player)) == 1


def test_receipts_are_verified_and_single_use(player):
    a = order(player, 'amber:0').json()['order']
    paid = player.post('/v1/payments/mock/pay', {'order_id': a['id']}).json()
    receipt = paid['receipt']
    # A lost confirm reply: the same receipt confirms the same grant again.
    again = player.post(f"/v1/payments/orders/{a['id']}/confirm", {'provider': 'mock', 'receipt': receipt}).json()
    assert again['grant']['id'] == paid['grant']['id']
    b = order(player, 'amber:0').json()['order']
    stolen = player.post(f"/v1/payments/orders/{b['id']}/confirm", {'provider': 'mock', 'receipt': receipt})
    assert stolen.status_code == 422 and stolen.json()['error'] == 'invalid_receipt'
    forged = receipt.rsplit('.', 1)[0].replace(a['id'], b['id']) + '.' + '0' * 64
    assert player.post(f"/v1/payments/orders/{b['id']}/confirm", {'provider': 'mock', 'receipt': forged}).json()['error'] == 'invalid_receipt'
    unknown = player.post(f"/v1/payments/orders/{b['id']}/confirm", {'provider': 'appstore', 'receipt': 'x'})
    assert unknown.status_code == 400 and unknown.json()['error'] == 'provider_unavailable'
    with Session(engine()) as db:
        valid = payments.mock_receipt(db.get(PaymentOrder, b['id']))
        other = payments.mock_receipt(db.get(PaymentOrder, b['id']))
    assert player.post(f"/v1/payments/orders/{b['id']}/confirm", {'provider': 'mock', 'receipt': valid}).json()['order']['status'] == 'paid'
    twice = player.post(f"/v1/payments/orders/{b['id']}/confirm", {'provider': 'mock', 'receipt': other})
    assert twice.status_code == 409 and twice.json()['error'] == 'order_already_paid'
    assert len(rows(Grant, account_id=player.id)) == 2 and account(player).paid_amber == 160


def test_orders_belong_to_their_account(client, player):
    from conftest import Player
    created = order(player, 'amber:0').json()['order']
    other = Player(client, 'device-other')
    response = other.post('/v1/payments/mock/pay', {'order_id': created['id']})
    assert response.status_code == 404 and response.json()['error'] == 'unknown_order'
    assert other.get('/v1/payments/grants').json()['grants'] == []


def test_lost_ack_is_settled_by_the_upload(player):
    grant = buy(player, 'amber:0')['grant']
    player.upload(applied(grant['id'], amber=80), 0)
    # The client never sent (or never heard back from) the ack: the upload already delivered it.
    assert grants(player) == []
    assert player.post('/v1/payments/grants/ack', {'ids': [grant['id']]}).json()['delivered'] == [grant['id']]


def test_progress_without_the_grant_gets_it_again(player):
    grant = buy(player, 'amber:0')['grant']
    player.upload(applied(grant['id'], amber=80), 0)
    assert grants(player) == []
    # The newest save lacks the grant (e.g. local progress lost before upload): it is pending again.
    player.upload(snapshot(level=2), 1)
    assert [g['id'] for g in grants(player)] == [grant['id']]
    assert [row.kind for row in rows(AuditLog, account_id=player.id)] == ['grant_redeliver']
    player.upload(applied(grant['id'], level=2, amber=80), 2)
    assert grants(player) == []


def test_paid_amber_is_not_flagged_but_free_amber_is(player):
    player.upload(snapshot(amber=10), 0)
    grant = buy(player, 'amber:4')['grant']
    assert grant['content']['amber'] == 6500
    assert player.upload(applied(grant['id'], amber=6510), 1).json()['version'] == 2
    assert not account(player).flagged
    # The ledger allowance is consumed by that upload; the same jump again is flagged.
    player.upload(applied(grant['id'], amber=13010), 2)
    assert account(player).flagged and 'amber' in account(player).flag_reason


def test_bundle_amber_counts_toward_the_ledger(player):
    paid = buy(player, 'gift:1')['grant']['content']
    assert paid['gift']['step'] == 1 and ['amber_4', 200] in paid['rewards']
    assert account(player).paid_amber == 200
    ufo = buy(player, 'ufo', {'offer_id': '42', 'items': ['fruit_3', 'fruit_3', 'veg_2']})['grant']['content']
    # bonus amber_5 is one physical item worth 40 amber when collected
    assert ['amber_5', 1, 'physical'] in ufo['rewards'] and account(player).paid_amber == 240


def test_pass_tiers_and_upgrade_price(player):
    vip = order(player, 'pass:vip').json()['order']
    assert vip['price_fen'] == 3000
    content = player.post('/v1/payments/mock/pay', {'order_id': vip['id']}).json()['grant']['content']
    assert content['pass'] == {'tier': 1, 'season': catalog.pass_season(clock.now())} and content['rewards'] == [['fire_2', 150]]
    again = order(player, 'pass:vip')
    assert again.status_code == 409 and again.json()['error'] == 'already_owned'
    upgrade = order(player, 'pass:super').json()['order']
    assert upgrade['price_fen'] == 3800
    content = player.post('/v1/payments/mock/pay', {'order_id': upgrade['id']}).json()['grant']['content']
    assert content['pass']['tier'] == 2 and content['rewards'] == [['token_1', 10]]
    assert order(player, 'pass:super').json()['error'] == 'already_owned'
    # Next season the pass is for sale again at full price (checked in-process: the login token expires sooner).
    season = catalog.pass_season(clock.now())
    while catalog.pass_season(clock.now()) == season:
        clock.offset += 86400
    with Session(engine()) as db:
        assert catalog.owned_pass_tier(db, player.id, catalog.pass_season(clock.now())) == 0
        assert catalog.quote(db, player.id, 'pass:super', {})['price_fen'] == 6800


def test_once_only_products_and_purchase_limits(player):
    free = order(player, 'gift:0')
    assert free.status_code == 404 and free.json()['error'] == 'unknown_product'
    buy(player, 'gift:1')
    assert order(player, 'gift:1').json()['error'] == 'already_owned'
    buy(player, 'offer:energy:0')
    assert order(player, 'offer:energy:0').json()['error'] == 'limit_reached'
    for _ in range(5):
        buy(player, 'offer:spree:0')
    assert order(player, 'offer:spree:0').json()['error'] == 'limit_reached'
    clock.offset = 3600 + 1
    buy(player, 'offer:spree:0')
    for bad in ({'offer_id': '7', 'items': ['amber_4']}, {'offer_id': 'x', 'items': ['fruit_1']},
                {'offer_id': '7', 'items': ['fruit_1'] * 9}, {'offer_id': '7', 'items': ['fruit_99']}):
        assert order(player, 'ufo', bad).json()['error'] == 'invalid_product'
    for bad in ('amber:99', 'offer:nope:0', 'gift:999', 'pass:gold', 'coins'):
        assert order(player, bad).status_code == 404


def test_racing_orders_for_a_once_only_product_refund_the_second(player):
    first = order(player, 'gift:1').json()['order']
    second = order(player, 'gift:1').json()['order']
    player.post('/v1/payments/mock/pay', {'order_id': first['id']})
    late = player.post('/v1/payments/mock/pay', {'order_id': second['id']})
    assert late.status_code == 409 and late.json()['error'] == 'already_owned'
    assert [o.status for o in rows(PaymentOrder, id=second['id'])] == ['refund']
    assert len(rows(Grant, account_id=player.id)) == 1
    assert [row.kind for row in rows(AuditLog, account_id=player.id)] == ['payment_refund']


def test_mock_provider_is_off_when_disabled(player, monkeypatch):
    created = order(player, 'amber:0').json()['order']
    monkeypatch.setattr(get_settings(), 'enable_mock_payments', False)
    assert player.post('/v1/payments/mock/pay', {'order_id': created['id']}).status_code == 404
    confirm = player.post(f"/v1/payments/orders/{created['id']}/confirm", {'provider': 'mock', 'receipt': 'a.b.c'})
    assert confirm.json()['error'] == 'provider_unavailable'


def test_prod_settings_disable_mock_payments(monkeypatch):
    from app import config
    monkeypatch.setenv('TRIBE_ENV', 'prod')
    monkeypatch.setenv('TRIBE_TOKEN_PEPPER', 'real-secret')
    config.get_settings.cache_clear()
    try:
        assert config.get_settings().enable_mock_payments is False
    finally:
        config.get_settings.cache_clear()
