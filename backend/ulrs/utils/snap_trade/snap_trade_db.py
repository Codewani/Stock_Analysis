'''
TODO: add all snap_trade database helper functions
'''
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from backend.models.auth.user import UserSecret


router = APIRouter(prefix="/snap_trade", tags=["snap_trade"])


def get_snap_trade_secret(db: Session, user_id: str) -> str:
    secret_row = db.query(UserSecret).filter(UserSecret.user_id == user_id).first()
    if not secret_row:
        raise HTTPException(status_code=404, detail="SnapTrade secret not found for user")
    return secret_row.snap_trade_secret