from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import Annotated, Any, Callable
from pydantic import BaseModel

from models.auth.user import UserSecret
from models.snap_trade.user_holdings import *
from ulrs.auth.user import get_db, get_current_user, UserInDB
from utils.snap_trade import snaptrade
from utils.redis_cache import *
from models.snap_trade.account_balance_snapshot import AccountBalanceSnapshot, AccountBalanceSnapshotInDB
import datetime

router = APIRouter(prefix="/snap_trade", tags=["snap_trade"])

'''
'positions': [{'average_purchase_price': 258.33,
                'cash_equivalent': False,
                'currency': {'code': 'USD',
                             'id': '57f81c53-bdda-45a7-a51f-032afd1ae41b',
                             'name': 'US Dollar'},
                'fractional_units': 15.48437,
                'open_pnl': 7.1228,
                'price': 258.79,
                'symbol': {'description': '',
                           'id': '7b8bafd2-36e1-4e2a-834e-f11543354708',
                           'is_quotable': True,
                           'is_tradable': True,
                           'listing_exchange': {},
                           'local_id': '',
                           'security_type': {},
                           'symbol': {'currencies': [],
                                      'currency': {'code': 'USD',
                                                   'id': '57f81c53-bdda-45a7-a51f-032afd1ae41b',
                                                   'name': 'US Dollar'},
                                      'description': 'Invesco Exchange-Traded '
                                                     'Fund Trust II - Invesco '
                                                     'NASDAQ 100 ETF',
                                      'exchange': {'close_time': '16:00:00',
                                                   'code': 'NASDAQ',
                                                   'id': 'ff4b2ffc-5a0e-4471-9cf5-95c0c30cdedd',
                                                   'mic_code': 'XNAS',
                                                   'name': 'NASDAQ',
                                                   'start_time': '09:30:00',
                                                   'suffix': None,
                                                   'timezone': 'America/New_York'},
                                      'figi_code': 'BBG00XS6PB74',
                                      'figi_instrument': {'figi_code': 'BBG00XS6PB74',
                                                          'figi_share_class': 'BBG00XS6PBW6'},
                                      'id': 'e5415fef-4a92-444f-b3da-b3ddaa8598da',
                                      'logo_url': '',
                                      'raw_symbol': 'QQQM',
                                      'symbol': 'QQQM',
                                      'type': {'code': 'et',
                                               'description': 'ETF',
                                               'id': '8057ceb7-e073-4c77-8635-a1c9bc6442cb',
                                               'is_supported': True}}},
                'tax_lots': [],
                'units': 15.48437},
               {'average_purchase_price': 365.54,
                'cash_equivalent': False,
                'currency': {'code': 'USD',
                             'id': '57f81c53-bdda-45a7-a51f-032afd1ae41b',
                             'name': 'US Dollar'},
                'fractional_units': 4.103485,
                'open_pnl': -5.6628,
                'price': 364.16,
                'symbol': {'description': '',
                           'id': '0cb5fba1-433e-42f7-ba3a-5e409c2b34f0',
                           'is_quotable': True,
                           'is_tradable': True,
                           'listing_exchange': {},
                           'local_id': '',
                           'security_type': {},
                           'symbol': {'currencies': [],
                                      'currency': {'code': 'USD',
                                                   'id': '57f81c53-bdda-45a7-a51f-032afd1ae41b',
                                                   'name': 'US Dollar'},
                                      'description': 'Tesla Inc',
                                      'exchange': {'close_time': '16:00:00',
                                                   'code': 'NASDAQ',
                                                   'id': 'ff4b2ffc-5a0e-4471-9cf5-95c0c30cdedd',
                                                   'mic_code': 'XNAS',
                                                   'name': 'NASDAQ',
                                                   'start_time': '09:30:00',
                                                   'suffix': None,
                                                   'timezone': 'America/New_York'},
                                      'figi_code': 'BBG000N9P426',
                                      'figi_instrument': {'figi_code': 'BBG000N9P426',
                                                          'figi_share_class': 'BBG001SQKGD7'},
                                      'id': 'a7ceb2ae-2b3f-4246-b153-8c15292330e5',
                                      'logo_url': 'https://api.twelvedata.com/logo/tesla.com',
                                      'raw_symbol': 'TSLA',
                                      'symbol': 'TSLA',
                                      'type': {'code': 'cs',
                                               'description': 'Common Stock',
                                               'id': '515c27d1-8471-4dec-a234-af12184c51d4',
                                               'is_supported': True}}},
                'tax_lots': [],
                'units': 4.103485},
               {'average_purchase_price': 250.75,
                'cash_equivalent': False,
                'currency': {'code': 'USD',
                             'id': '57f81c53-bdda-45a7-a51f-032afd1ae41b',
                             'name': 'US Dollar'},
                'fractional_units': 11.016012,
                'open_pnl': -18.9475,
                'price': 249.03,
                'symbol': {'description': '',
                           'id': 'afd270e7-1cc3-4278-84ed-f9d8ac15a48f',
                           'is_quotable': True,
                           'is_tradable': True,
                           'listing_exchange': {},
                           'local_id': '',
                           'security_type': {},
                           'symbol': {'currencies': [],
                                      'currency': {'code': 'USD',
                                                   'id': '57f81c53-bdda-45a7-a51f-032afd1ae41b',
                                                   'name': 'US Dollar'},
                                      'description': 'Amazon.com Inc.',
                                      'exchange': {'close_time': '16:00:00',
                                                   'code': 'NASDAQ',
                                                   'id': 'ff4b2ffc-5a0e-4471-9cf5-95c0c30cdedd',
                                                   'mic_code': 'XNAS',
                                                   'name': 'NASDAQ',
                                                   'start_time': '09:30:00',
                                                   'suffix': None,
                                                   'timezone': 'America/New_York'},
                                      'figi_code': 'BBG000BVQ4Z3',
                                      'figi_instrument': {'figi_code': 'BBG000BVQ4Z3',
                                                          'figi_share_class': 'BBG001S5PQL7'},
                                      'id': '3474fd1d-7e32-4f92-8515-46e2412754e3',
                                      'logo_url': 'https://api.twelvedata.com/logo/amazon.com',
                                      'raw_symbol': 'AMZN',
                                      'symbol': 'AMZN',
                                      'type': {'code': 'cs',
                                               'description': 'Common Stock',
                                               'id': '515c27d1-8471-4dec-a234-af12184c51d4',
                                               'is_supported': True}}},
                'tax_lots': [],
                'units': 11.016012}],
 'total_value': {'currency': 'USD', 'value': 8245.04267826}}
'''


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
    delete_cached_account_ids(current_user.user_id)
    # After successful connection, update the accounts cache
    accounts_response = snaptrade.account_information.list_user_accounts(
        user_id=current_user.user_id,
        user_secret=user_secret,
    )
    if accounts_response.status == 200:
        accounts = accounts_response.body or []
        account_ids = [acc["id"] for acc in accounts if "id" in acc]
        cache_account_ids(current_user.user_id, account_ids)
    return response.body


def get_snap_trade_secret(db: Session, user_id: str) -> str:
    secret_row = db.query(UserSecret).filter(UserSecret.user_id == user_id).first()
    if not secret_row:
        raise HTTPException(status_code=404, detail="SnapTrade secret not found for user")
    return secret_row.snap_trade_secret

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


def get_or_cache_account_ids(current_user: UserInDB, db: Session) -> list[str]:
    account_ids = get_cached_account_ids(current_user.user_id)
    if account_ids:
        return account_ids

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
    account_ids = get_or_cache_account_ids(current_user, db)
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
    account_ids = get_or_cache_account_ids(current_user, db)

    holdings = []
    total_balance = 0
    def op(account_id):
        nonlocal total_balance
        response = snaptrade.account_information.get_user_holdings(
            account_id=account_id,
            user_id=current_user.user_id,
            user_secret=user_secret
        )

        positions = response["positions"]
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
            total_balance += pos["total_value"]
    
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