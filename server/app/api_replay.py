"""The sole gameplay write API: current rule sessions and compact command batches."""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from . import replay_service
from .db import get_db
from .replay_models import SyncReq, parse_sync
from .security import Auth, current

router = APIRouter(prefix="/v2", tags=["操作重放"])


@router.post("/session")
def session(auth: Auth = Depends(current), db: Session = Depends(get_db)):
    return replay_service.session(auth, db)


@router.post("/sync")
def sync(request: SyncReq = Depends(parse_sync), auth: Auth = Depends(current), db: Session = Depends(get_db)):
    return replay_service.sync(request, auth, db)
