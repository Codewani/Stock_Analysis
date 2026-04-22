from fastapi import HTTPException
from sqlalchemy.orm import Session
from typing import Any, Callable

from backend.models.auth.user import UserSecret
from backend.models.snap_trade.user_holdings import *
from backend.ulrs.auth.user import UserInDB
from backend.utils.snap_trade import snaptrade
from backend.ulrs.utils.caching.snap_trade.redis_cache import *
from backend.ulrs.utils.snap_trade.snap_trade import *


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
        user_id=current_user.user_id,
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
    account_ids = get_account_ids(current_user, db)
    results = {}
    for account_id in account_ids:
        results[account_id] = operation_fn(account_id)
    return results
