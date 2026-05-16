from typing import Any, Callable
import os

from dotenv import load_dotenv
from fastapi import HTTPException
from snaptrade_client import SnapTrade
from sqlalchemy.orm import Session

from backend.models.auth.user import UserSecret, UserInDB
from backend.services.snap_trade_cache import cache_account_ids, get_cached_account_ids, delete_cached_account_ids

load_dotenv()

snaptrade = SnapTrade(
	client_id=os.getenv("Client_Id"),
	consumer_key=os.getenv("Secret"),
)


def get_snap_trade_secret(db: Session, user_id: str) -> str:
	secret_row = db.query(UserSecret).filter(UserSecret.user_id == user_id).first()
	if not secret_row:
		raise HTTPException(status_code=404, detail="SnapTrade secret not found for user")
	return secret_row.snap_trade_secret


def get_account_ids(current_user: UserInDB, db: Session) -> list[str]:
	user_secret = get_snap_trade_secret(db, current_user.user_id)
	cached_account_ids = get_cached_account_ids(current_user.user_id)
	if cached_account_ids:
		return cached_account_ids
	response = snaptrade.account_information.list_user_accounts(
		user_id=current_user.snaptrade_user_id,
		user_secret=user_secret,
	)
	if response.status != 200:
		raise HTTPException(status_code=response.status, detail=response.body)

	accounts = response.body or []
	account_ids = [acc["id"] for acc in accounts if "id" in acc]
	cache_account_ids(current_user.user_id, account_ids)
	return account_ids


def for_each_account(
	current_user: UserInDB,
	db: Session,
	operation_fn: Callable[[str], Any],
) -> dict[str, Any]:
	results = {}
	for account_id in get_account_ids(current_user, db):
		results[account_id] = operation_fn(account_id)
	return results
