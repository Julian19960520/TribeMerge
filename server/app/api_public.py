"""Health, server clock and ranking from uploaded snapshots (flagged accounts excluded)."""

from fastapi import APIRouter, Depends, Query, Request
from fastapi.responses import JSONResponse
from sqlalchemy import func, or_, select, text
from sqlalchemy.orm import Session

from . import clock
from .config import get_settings
from .db import get_db
from .models import Account
from .schemas import NameReq, Resp
from .security import Auth, current
from .services import stamp

router = APIRouter(prefix="/v1", tags=["服务"])


@router.get("/health")
def health(db: Session = Depends(get_db)):
    try:
        db.execute(text("SELECT 1"))
        ok = True
    except Exception:
        ok = False
    return JSONResponse(stamp({"ok": ok, "db": ok, "env": get_settings().env}), status_code=200 if ok else 503)


@router.get("/time", response_model=Resp)
def server_time():
    return stamp({"ok": True, "secs_to_midnight": clock.secs_to_midnight(get_settings().day_utc_offset_hours)})


def rank_of(db, account) -> dict:
    ahead = db.scalar(select(func.count()).select_from(Account).where(Account.disabled.is_(False), Account.flagged.is_(False), or_(
        Account.rank_progress > account.rank_progress,
        (Account.rank_progress == account.rank_progress) & (Account.rank_reached_at < account.rank_reached_at),
        (Account.rank_progress == account.rank_progress) & (Account.rank_reached_at == account.rank_reached_at) & (Account.id < account.id))))
    return {"rank": ahead + 1, "id": account.id, "name": account.nick or ("原始人" + account.id[-4:]),
            "progress": account.rank_progress, "reached_at": account.rank_reached_at}


@router.get("/rank/top")
def rank_top(request: Request, n: int = Query(50, ge=1, le=200), db: Session = Depends(get_db)):
    rows = db.scalars(select(Account).where(Account.rank_progress > 0, Account.disabled.is_(False), Account.flagged.is_(False)).order_by(
        Account.rank_progress.desc(), Account.rank_reached_at.asc(), Account.id.asc()).limit(n)).all()
    total = db.scalar(select(func.count()).select_from(Account).where(Account.rank_progress > 0, Account.disabled.is_(False), Account.flagged.is_(False)))
    me = None
    if request.headers.get("authorization"):
        auth = current(request, db)
        if auth.account.rank_progress > 0 and not auth.account.flagged:
            me = rank_of(db, auth.account)
    top = [{"rank": index + 1, "id": account.id, "name": account.nick or ("原始人" + account.id[-4:]),
            "progress": account.rank_progress, "reached_at": account.rank_reached_at}
           for index, account in enumerate(rows)]
    return stamp({"ok": True, "total": total, "top": top, "me": me})


@router.post("/rank/name")
def rank_name(request: NameReq, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    auth.account.nick = request.name.strip().replace("\n", " ")
    if not auth.account.nick:
        from .errors import ApiError
        raise ApiError(422, "invalid_name", "名字不能为空")
    db.commit()
    return stamp({"ok": True, "me": rank_of(db, auth.account) if auth.account.rank_progress > 0 and not auth.account.flagged else None})
