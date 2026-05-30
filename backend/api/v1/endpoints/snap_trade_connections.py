from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from backend.core.security import get_current_user
from backend.db.session import get_db
from backend.models.auth.user import UserInDB
from backend.schemas.snap_trade import ConnectionRequest
from backend.services.snap_trade import get_snap_trade_secret, snaptrade


router = APIRouter(prefix="/snap_trade/connections", tags=["snap_trade"])


@router.post("/establish_connection")
def create_connection(
	connection: ConnectionRequest,
	current_user: Annotated[UserInDB, Depends(get_current_user)],
	db: Session = Depends(get_db),
):
	user_secret = get_snap_trade_secret(db, current_user.user_id)
	response = snaptrade.authentication.login_snap_trade_user(
		user_id=current_user.snaptrade_user_id,
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