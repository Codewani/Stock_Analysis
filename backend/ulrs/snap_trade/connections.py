from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import Annotated, Any, Callable
from pydantic import BaseModel

from backend.models.auth.user import UserSecret
from backend.models.snap_trade.user_holdings import *
from backend.ulrs.auth.user import get_db, get_current_user, UserInDB
from backend.utils.snap_trade import snaptrade
from backend.utils.redis_cache import *
from backend.ulrs.utils.snap_trade.snap_trade_db import *
import datetime


router = APIRouter(prefix="/snap_trade/connections", tags=["snap_trade"])

 
class ConnectionRequest(BaseModel):
    broker: str
    custom_redirect: str | None = "https://snaptrade.com"
    immediate_redirect: bool = True
    reconnect: str = ""
    show_close_button: bool = True
    dark_mode: bool = True
    connection_portal_version: str = "v4"


@router.post("/establish_connection")
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
    # After successful connection, update the accounts cache
    return response.body