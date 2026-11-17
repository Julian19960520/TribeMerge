"""逃离剑齿虎异步联机接口。"""

from fastapi import APIRouter, Depends, Query
from pydantic import Field
from sqlalchemy.orm import Session

from . import clock, tiger
from .db import get_db
from .errors import ApiError
from .schemas import Req
from .security import Auth, current
from .services import stamp

router = APIRouter(prefix="/v1/tiger", tags=["逃离剑齿虎"])


class TigerSyncReq(Req):
    cohort_id: str = Field(min_length=1, max_length=36)
    stage: int = Field(ge=0, le=20)
    points: int = Field(ge=0, le=10000)
    stage_times: list[float] = Field(default_factory=list, max_length=20)


@router.post("/join")
def tiger_join(auth: Auth = Depends(current), db: Session = Depends(get_db)):
    data = tiger.join_cohort(db, auth.account, clock.now())
    return stamp({"ok": True, "cohort": data})


@router.post("/sync")
def tiger_sync(request: TigerSyncReq, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    data = tiger.sync_progress(
        db, auth.account, request.cohort_id, request.stage, request.points, request.stage_times, clock.now()
    )
    if data is None:
        raise ApiError(404, "cohort_not_found", "Cohort not found")
    return stamp({"ok": True, "cohort": data})


@router.get("/state")
def tiger_state(cohort_id: str = Query(..., min_length=1, max_length=36), auth: Auth = Depends(current), db: Session = Depends(get_db)):
    data = tiger.get_state(db, auth.account, cohort_id, clock.now())
    if data is None:
        raise ApiError(404, "cohort_not_found", "Cohort not found")
    return stamp({"ok": True, "cohort": data})
