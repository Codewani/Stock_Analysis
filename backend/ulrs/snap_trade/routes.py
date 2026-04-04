from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import Annotated
from pydantic import BaseModel

from models.auth.user import UserSecret
from ulrs.auth.user import get_db, get_current_user, UserInDB
from utils.snap_trade import snaptrade

router = APIRouter(prefix="/snap_trade", tags=["snap_trade"])


class ConnectionRequest(BaseModel):
    broker: str
    custom_redirect: str | None = "https://snaptrade.com"
    immediate_redirect: bool = True
    reconnect: str = ""
    show_close_button: bool = True
    dark_mode: bool = True
    connection_portal_version: str = "v4"


@router.post("/connections")
def create_connection(
    connection: ConnectionRequest,
    current_user: Annotated[UserInDB, Depends(get_current_user)],
    db: Session = Depends(get_db),
):
    user_secret = get_snap_trade_secret(db, current_user.user_id)
    response = snaptrade.authentication.login_snap_trade_user(
        user_id=current_user.user_id,
        user_secret=user_secret,
        broker=connection.broker,
        immediate_redirect=connection.immediate_redirect,
        custom_redirect=connection.custom_redirect,
        reconnect=connection.reconnect,
        show_close_button=connection.show_close_button,
        dark_mode=connection.dark_mode,
        connection_portal_version=connection.connection_portal_version,
    )
    if response.status != 200:
        raise HTTPException(status_code=response.status, detail=response.body)
    return response.body


def get_snap_trade_secret(db: Session, user_id: str) -> str:
    secret_row = db.query(UserSecret).filter(UserSecret.user_id == user_id).first()
    if not secret_row:
        raise HTTPException(status_code=404, detail="SnapTrade secret not found for user")
    return secret_row.snap_trade_secret


@router.get("/accounts/{account_id}/activities")
def read_account_activities(
    account_id: str,
    current_user: Annotated[UserInDB, Depends(get_current_user)],
    db: Session = Depends(get_db),
):
    user_secret = get_snap_trade_secret(db, current_user.user_id)
    response = snaptrade.account_information.get_account_activities(
        account_id=account_id,
        user_id=current_user.user_id,
        user_secret=user_secret,
    )
    if response.status != 200:
        raise HTTPException(status_code=response.status, detail=response.body)
    return response.body


@router.get("/accounts/{account_id}/balance")
def read_account_balance(
    account_id: str,
    current_user: Annotated[UserInDB, Depends(get_current_user)],
    db: Session = Depends(get_db),
):
    user_secret = get_snap_trade_secret(db, current_user.user_id)
    response = snaptrade.account_information.get_user_account_balance(
        account_id=account_id,
        user_id=current_user.user_id,
        user_secret=user_secret,
    )
    if response.status != 200:
        raise HTTPException(status_code=response.status, detail=response.body)
    return response.body


@router.get("/accounts/{account_id}/orders")
def read_account_orders(
    account_id: str,
    current_user: Annotated[UserInDB, Depends(get_current_user)],
    db: Session = Depends(get_db),
    days: int = 365,
):
    user_secret = get_snap_trade_secret(db, current_user.user_id)
    response = snaptrade.account_information.get_user_account_orders(
        account_id=account_id,
        user_id=current_user.user_id,
        user_secret=user_secret,
        days=days,
    )
    if response.status != 200:
        raise HTTPException(status_code=response.status, detail=response.body)
    return response.body
