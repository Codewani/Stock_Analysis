from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import Annotated, Any

from backend.models.snap_trade.user_holdings import *
from backend.ulrs.auth.user import get_db, get_current_user, UserInDB
from backend.utils.snap_trade import snaptrade
from backend.ulrs.utils.caching.snap_trade.redis_cache import *
from backend.models.snap_trade.account_balance_snapshot import AccountBalanceSnapshot, AccountBalanceSnapshotInDB
from backend.ulrs.utils.snap_trade.snap_trade import *
import datetime


router = APIRouter(prefix="/snap_trade/data", tags=["snap_trade"])

@router.get("/accounts", response_model=list[dict[str, Any]])
def list_user_accounts(
    current_user: Annotated[UserInDB, Depends(get_current_user)],
    db: Session = Depends(get_db),
) -> list[dict[str, Any]]:
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


@router.get("/accounts/activities", response_model=dict[str, Any])
def read_all_account_activities(
    current_user: Annotated[UserInDB, Depends(get_current_user)],
    db: Session = Depends(get_db),
) -> dict[str, Any]:
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



@router.get("/accounts/balances", response_model=dict[str, Any])
def read_all_account_balances(
    current_user: Annotated[UserInDB, Depends(get_current_user)],
    db: Session = Depends(get_db),
) -> dict[str, Any]:
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


@router.post("/accounts/update", response_model=AccountBalanceSnapshotInDB)
def update_holdings(
    current_user: Annotated[UserInDB, Depends(get_current_user)],
    db: Session = Depends(get_db),
) -> AccountBalanceSnapshotInDB:
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



@router.get("/accounts/orders", response_model=dict[str, Any])
def read_all_account_orders(
    current_user: Annotated[UserInDB, Depends(get_current_user)],
    db: Session = Depends(get_db),
    days: int = 365,
) -> dict[str, Any]:
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

@router.get("/accounts/balances/history", response_model=list[AccountBalanceSnapshotInDB])
def get_account_balance_history(
    current_user: Annotated[UserInDB, Depends(get_current_user)],
    db: Session = Depends(get_db),
) -> list[AccountBalanceSnapshotInDB]:
    snapshots = db.query(AccountBalanceSnapshot).filter(
        AccountBalanceSnapshot.user_id == current_user.user_id
    ).order_by(AccountBalanceSnapshot.snapshot_timestamp.desc()).all()
    return [AccountBalanceSnapshotInDB.model_validate(snapshot) for snapshot in snapshots]