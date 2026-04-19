from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import Annotated, Any, Callable
from pydantic import BaseModel

from backend.models.auth.user import UserSecret
from backend.models.snap_trade.user_holdings import *
from backend.ulrs.auth.user import get_db, get_current_user, UserInDB
from backend.utils.snap_trade import snaptrade
from backend.utils.redis_cache import *
from backend.models.snap_trade.account_balance_snapshot import AccountBalanceSnapshot, AccountBalanceSnapshotInDB
from backend.ulrs.utils.snap_trade.snap_trade_db import *
import datetime


router = APIRouter(prefix="/snap_trade/data", tags=["snap_trade"])

@router.get("/accounts")
def list_user_accounts(
    current_user: Annotated[UserInDB, Depends(get_current_user)],
    db: Session = Depends(get_db),
):
    """
    List all user accounts for the authenticated user using SnapTrade.
    """
    user_secret = get_snap_trade_secret(db, current_user.user_id)
    response = snaptrade.account_information.list_user_accounts(
        user_id=current_user.user_id,
        user_secret=user_secret,
    )
    if response.status != 200:
        raise HTTPException(status_code=response.status, detail=response.body)
    # Cache account IDs
    accounts = response.body or []
    account_ids = [acc["id"] for acc in accounts if "id" in acc]
    cache_account_ids(current_user.user_id, account_ids)
    return accounts


def get_account_ids(current_user: UserInDB, db: Session) -> list[str]:
    user_secret = get_snap_trade_secret(db, current_user.user_id)
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


def calculate_total_balance(accounts: list[dict[str, Any]]) -> float:
    total_balance = 0.0
    for account in accounts:
        if not isinstance(account, dict):
            continue
        balance = account.get("balance")
        if not isinstance(balance, dict):
            continue
        total = balance.get("total")
        if not isinstance(total, dict):
            continue
        amount = total.get("amount")
        try:
            total_balance += float(amount)
        except (TypeError, ValueError):
            continue
    return total_balance



# Helper to run operation for all accounts
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

@router.get("/accounts/activities")
def read_all_account_activities(
    current_user: Annotated[UserInDB, Depends(get_current_user)],
    db: Session = Depends(get_db),
):
    user_secret = get_snap_trade_secret(db, current_user.user_id)
    def op(account_id):
        response = snaptrade.account_information.get_account_activities(
            account_id=account_id,
            user_id=current_user.user_id,
            user_secret=user_secret,
        )
        if response.status != 200:
            return {"error": response.body}
        return response.body
    return for_each_account(current_user, db, op)



@router.get("/accounts/balances")
def read_all_account_balances(
    current_user: Annotated[UserInDB, Depends(get_current_user)],
    db: Session = Depends(get_db),
):
    user_secret = get_snap_trade_secret(db, current_user.user_id)
    def op(account_id):
        response = snaptrade.account_information.get_user_account_balance(
            account_id=account_id,
            user_id=current_user.user_id,
            user_secret=user_secret,
        )
        if response.status != 200:
            return {"error": response.body}
        return response.body

    balances = for_each_account(current_user, db, op)
    return balances


@router.post("/accounts/update")
def update_holdings(
    current_user: Annotated[UserInDB, Depends(get_current_user)],
    db: Session = Depends(get_db),
):
    user_secret = get_snap_trade_secret(db, current_user.user_id)
    account_ids = get_account_ids(current_user, db)

    holdings = []
    total_balance = 0
    def op(account_id):
        nonlocal total_balance
        response = snaptrade.account_information.get_user_holdings(
            account_id=account_id,
            user_id=current_user.user_id,
            user_secret=user_secret
        )

        positions = response.body["positions"]
        for pos in positions:
            symbol = pos.get("symbol", {})
            symbol_info = symbol.get("symbol", {})
            symbol_name = symbol_info.get("symbol")
            if not symbol_name:
                '''
                report
                '''
                continue

            db.query(UserHolding).filter(
                UserHolding.user_id == current_user.user_id,
                UserHolding.account_id == account_id
            ).delete()
            new_holding = UserHolding(
                user_id=current_user.user_id,
                account_id=account_id,
                symbol=symbol_name,
                units=pos.get("units", 0),
                average_purchase_price=pos.get("average_purchase_price", 0.0),
                open_pnl=pos.get("open_pnl", 0.0),
                price=pos.get("price", 0.0)
            )
            holdings.append(new_holding)
        total_balance += response.body["total_value"]["value"]
    
    for acct_id in account_ids:
        op(acct_id)

    snapshot = AccountBalanceSnapshot(
        user_id=current_user.user_id,
        total_balance=total_balance,
        snapshot_timestamp=datetime.datetime.utcnow(),
    )
    holdings.append(snapshot)
    db.add_all(holdings)
    db.commit()
    return AccountBalanceSnapshotInDB.model_validate(snapshot)



@router.get("/accounts/orders")
def read_all_account_orders(
    current_user: Annotated[UserInDB, Depends(get_current_user)],
    db: Session = Depends(get_db),
    days: int = 365,
):
    user_secret = get_snap_trade_secret(db, current_user.user_id)
    def op(account_id):
        response = snaptrade.account_information.get_user_account_orders(
            account_id=account_id,
            user_id=current_user.user_id,
            user_secret=user_secret,
            days=days,
        )
        if response.status != 200:
            return {"error": response.body}
        return response.body
    return for_each_account(current_user, db, op)

@router.get("/accounts/balances/history")
def get_account_balance_history(
    current_user: Annotated[UserInDB, Depends(get_current_user)],
    db: Session = Depends(get_db),
):
    snapshots = db.query(AccountBalanceSnapshot).filter(
        AccountBalanceSnapshot.user_id == current_user.user_id
    ).order_by(AccountBalanceSnapshot.snapshot_timestamp.desc()).all()
    return [AccountBalanceSnapshotInDB.model_validate(snapshot) for snapshot in snapshots]