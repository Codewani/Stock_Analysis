from collections.abc import Iterable

from sqlalchemy import func
from sqlalchemy.orm import Session

from backend.models.snap_trade.user_holdings import UserHolding
from backend.models.watchlist.watchlist import WatchList
from backend.services.concerned_users_cache import (
	add_cached_concerned_user,
	cache_concerned_users,
	get_cached_concerned_users,
	normalize_symbol,
	remove_cached_concerned_user,
)
from backend.services.holdings import get_user_holdings
from backend.services.watchlist import get_user_watchlist


def get_concerned_user_ids(symbols: Iterable[str], db: Session) -> set[str]:
	user_ids = set()
	for symbol in {normalize_symbol(symbol) for symbol in symbols if symbol.strip()}:
		symbol_user_ids = get_cached_concerned_users(symbol)
		if symbol_user_ids is None:
			symbol_user_ids = _load_concerned_user_ids(symbol, db)
			cache_concerned_users(symbol, symbol_user_ids)
		user_ids |= symbol_user_ids
	return user_ids


def get_held_symbols(user_id: str, db: Session) -> set[str]:
	return {normalize_symbol(holding.symbol) for holding in get_user_holdings(user_id, db)}


def is_user_concerned(user_id: str, symbol: str, db: Session) -> bool:
	symbol = normalize_symbol(symbol)
	watched_symbols = {normalize_symbol(item.symbol) for item in get_user_watchlist(user_id, db)}
	return symbol in watched_symbols or symbol in get_held_symbols(user_id, db)


def handle_symbol_added(user_id: str, symbol: str) -> None:
	add_cached_concerned_user(symbol, user_id)


def handle_symbol_removed(user_id: str, symbol: str, db: Session) -> None:
	# Call after the DB commit and cache invalidation, so the check sees the removal. The user
	# stays if they still hold or watch the symbol (e.g. another account, or a duplicate row).
	if not is_user_concerned(user_id, symbol, db):
		remove_cached_concerned_user(symbol, user_id)


def handle_holdings_changed(user_id: str, previous_symbols: set[str], db: Session) -> None:
	current_symbols = get_held_symbols(user_id, db)
	# Re-adding symbols the user already held is a no-op, and repairs a set that missed an add.
	for symbol in current_symbols:
		handle_symbol_added(user_id, symbol)
	for symbol in previous_symbols - current_symbols:
		handle_symbol_removed(user_id, symbol, db)


def _load_concerned_user_ids(symbol: str, db: Session) -> set[str]:
	holders = db.query(UserHolding.user_id).filter(func.upper(UserHolding.symbol) == symbol)
	watchers = db.query(WatchList.user_id).filter(func.upper(WatchList.symbol) == symbol)
	return {str(user_id) for (user_id,) in holders.union(watchers).all()}
