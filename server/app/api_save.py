"""Cloud save API: read the current snapshot, upload a newer one."""

from fastapi import APIRouter, Depends
from pydantic import Field
from sqlalchemy.orm import Session

from . import save_service
from .db import get_db
from .schemas import Req
from .security import Auth, current

router = APIRouter(prefix="/v2", tags=["云存档"])


class SaveReq(Req):
    base: int = Field(ge=0)
    hash: str = Field(pattern=r"^[0-9a-f]{64}$")
    data: str = Field(min_length=1, max_length=1_000_000)


@router.post("/session")
def session(auth: Auth = Depends(current), db: Session = Depends(get_db)):
    return save_service.session(auth, db)


@router.post("/save")
def save(request: SaveReq, auth: Auth = Depends(current), db: Session = Depends(get_db)):
    return save_service.upload(request, auth, db)
