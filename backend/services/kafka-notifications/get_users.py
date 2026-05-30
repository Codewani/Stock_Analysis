from collections.abc import Iterable

from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from backend.models.auth.user import User
from backend.models.snap_trade.user_holdings import UserHolding
from backend.models.watchlist.watchlist import WatchList


def get_users_by_symbols(symbols: Iterable[str], db: Session) -> list[User]:
	normalized_symbols = [symbol.strip().upper() for symbol in symbols if symbol.strip()]
	if not normalized_symbols:
		return []

	return (
		db.query(User)
		.outerjoin(UserHolding, UserHolding.user_id == User.user_id)
		.outerjoin(WatchList, WatchList.user_id == User.user_id)
		.filter(
			or_(
				func.upper(UserHolding.symbol).in_(normalized_symbols),
				func.upper(WatchList.symbol).in_(normalized_symbols),
			)
		)
		.distinct()
		.all()
	)
