# 合合部落服务器

服务器使用 FastAPI 和 SQLAlchemy，不依赖 Godot。合成、订单、建造这类单机玩法完全在客户端运行，服务器只负责账号、云存档（整份快照）、备份、排行榜，以及对上传存档做合理性检查。

## 运行

```sh
pip install -r server/requirements.txt
python server/run.py
```

默认监听 `127.0.0.1:8765`，使用 SQLite；部署时可配置 PostgreSQL。环境变量示例见 `.env.example`。Docker 的构建上下文为工程根目录：

```sh
docker compose -f server/docker-compose.yml up --build
```

## 接口

| 接口 | 用途 |
| --- | --- |
| `/v1/auth/*`、`/v1/account*` | 游客账号、登录续期、转移码和身份绑定 |
| `/v1/health`、`/v1/time` | 健康检查、服务器时钟 |
| `/v1/rank/top`、`/v1/rank/name` | 按上传存档里建筑进度排名的排行榜，以及昵称 |
| `POST /v2/session` | 取得云端存档：`version`、`hash`、`data`（gzip+Base64），`mine` 表示是否为本设备写入 |
| `POST /v2/save` | 上传整份存档：`{base, hash, data}` |
| `POST /v1/payments/orders` | 下单（需 `Idempotency-Key`）：`{product, detail}` → 服务器定价的订单 |
| `POST /v1/payments/orders/{id}/confirm` | 提交支付凭证 `{provider, receipt}`，校验通过后标记已付并发放权益 |
| `POST /v1/payments/mock/pay` | 开发用模拟支付 `{order_id}`（`TRIBE_ENV=prod` 时关闭，返回 404） |
| `GET /v1/payments/grants` | 未送达的权益 |
| `POST /v1/payments/grants/ack` | `{ids}`：确认已入账并上传的权益 |

## 云存档

客户端在本地执行全部玩法命令，写本地检查点和操作日志（防崩溃），每 60 秒、切后台和退出时把整份存档上传。`hash` 是存档 JSON 文本的 SHA-256，`data` 是这段文本 gzip 后再 Base64。服务器校验哈希、大小（解压后默认上限 1 MiB）和基本字段，然后保存。

冲突规则：同一账号同一时间只有一个有效会话。

- 云端版本等于 `base`，或者云端存档也是本设备写的（例如上次的回复丢了）：覆盖，版本号加 1。
- 云端存档由别的设备在 `base` 之后写入：不覆盖，返回 `conflict: true` 和云端存档，客户端载入云端进度。
- 启动时：云端为空则上传本机进度；云端由别的设备更新过，或者是登录另一个账号，则载入云端。

每次覆盖前保留最近 `TRIBE_BACKUPS_RECENT` 份和每天一份备份。

## 合理性检查

上传时把等级、琥珀、贝壳的增量和距上次上传的时长比较（允许量 = burst + 每小时速率 × 小时数，见 `TRIBE_PLAUS_*`）。负数或超出允许量时**不拒绝存档**，只把账号标记为 `flagged`、写审计日志 `save_flagged`，并移出排行榜。首次上传没有基准，只检查负数。

付费发放的琥珀不算异常：服务器记着每个账号累计发放的付费琥珀（`accounts.paid_amber`），每次上传把上次上传以来新发的付费琥珀加进允许量。多人竞争玩法目前没有服务器接口。

## 付费内容

单机进度归客户端，涉及真钱的东西归服务器：价格、订单、支付凭证、发放记录和付费琥珀账本都只在服务器上。

1. **下单** `POST /v1/payments/orders`，请求头带 `Idempotency-Key`（回复丢了用同一个键重试，拿到同一张订单）。客户端只给商品编号，价格和要发的东西由服务器按 `data/*.json` 算好写进订单（`app/catalog.py`）：

   | 商品 | 配置 | 规则 |
   | --- | --- | --- |
   | `amber:<k>` | `amber_packs.json` 第 k 档 | 发 `n` 琥珀 |
   | `pass:vip`、`pass:super` | `pass.json` 的 `purchase` | 本赛季已拥有则 409；已是贵宾再买超级只付差价、只送多出的奖励 |
   | `offer:<kind>:<tier>` | `offers.json` | 任意 `duration_sec` 时长内最多买 `limit` 次 |
   | `ufo` | `ufo_offer.json` | `detail = {offer_id, items}`，物品必须是普通物品、件数在 `min_items..max_items`；每个 `offer_id` 只能买一次 |
   | `gift:<step>` | `gift_chain.json` 的付费步 | 当前这一期的这一步只能买一次 |

2. **支付**。正式渠道（App Store / Google Play / 微信）在客户端拿到凭证后调 `confirm`，服务器在 `payments.verify_receipt` 里向渠道校验；目前只实现了模拟渠道 `mock`（凭证 = 订单号 + 交易号 + HMAC 签名）。开发环境用 `POST /v1/payments/mock/pay` 直接完成一次模拟支付（`TRIBE_ENABLE_MOCK_PAYMENTS`，prod 下强制关闭）。同一凭证重复提交返回同一份权益；凭证不能用于别的订单；一张订单付过后换凭证再付返回 409。两张订单抢买同一件只能买一次的商品时，后付的那张记为 `refund`（不发货，写审计 `payment_refund`，待人工退款）。
3. **发放**。订单付款后服务器生成一条权益（`grants` 表，编号 `gr_…`，一张订单只对应一条），内容是琥珀数、通行证档位、礼包物品等，同时把其中的琥珀记进 `paid_amber`。
4. **入账**。客户端 `scripts/net/Payments.gd` 拉取 `GET /v1/payments/grants`，对每条执行 `grant` 命令（`Reducer.apply_grant`）。命令把权益编号记进存档的 `replay_meta.grants`，同一份存档里同一编号只入账一次，重启、重复拉取、回复丢失都不会重复发放。每次登录（`Replay.connect_session`）都会拉一次，所以付款后崩溃或断网的权益会在下次联网时到账。
5. **确认送达**。入账后客户端立刻上传存档，再调 `ack`。服务器只认存档：上传的存档里列出的权益标记为已送达；`ack` 也只对已存储存档里有的编号生效，所以 `ack` 丢了也没关系。反过来，如果最新上传的存档里缺了某条已送达的权益（例如本机进度丢失），它会重新变成待发放（审计 `grant_redeliver`）。

没联网、没登录或被顶下线时，购买按钮提示原因，不会发生任何扣款或发放。

## 验证

```sh
pip install -r server/requirements-dev.txt
TRIBE_GODOT=/path/to/godot python -m pytest -q server/tests
godot --headless --path . --script res://tools/check_cloud_save.gd -- --replay-test --cloud-off --save=user://cloud_save_check/boot.json --cloud-state=user://cloud_save_check/boot-cloud.json
godot --headless --path . --script res://tools/check_payments.gd -- --replay-test --cloud-off --save=user://payments_check/boot.json --cloud-state=user://payments_check/boot-cloud.json
```

`test_save.py` 覆盖上传、冲突、丢失回复、旧设备被顶下线、完整性错误、备份和合理性标记。`test_rules_replay.py`、`test_reducer_domains.py` 等直接调用 `scripts/replay/worker.gd` 检查共享玩法规则，需要设置 `TRIBE_GODOT`，未设置时跳过。`check_cloud_save.gd` 用真实客户端连临时服务器做端到端检查。`test_payments.py` 覆盖下单 → 支付 → 发放 → 确认、幂等下单、支付回复丢失、凭证校验和复用、`ack` 丢失、进度丢失后重发、限购和付费琥珀账本；`check_payments.gd` 用真实客户端买琥珀，确认支付回复丢失、重启和重复下发时都只到账一次。
