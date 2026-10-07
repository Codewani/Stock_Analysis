from sqlalchemy.orm import Session

from backend.models.snap_trade.user_holdings import UserHolding, UserHoldingInDB
from backend.services.holdings_cache import cache_holdings, get_cached_holdings, delete_cached_holdings


def get_user_holdings(user_id: str, db: Session) -> list[UserHoldingInDB]:
	cached_holdings = get_cached_holdings(user_id)
	if cached_holdings is not None:
		return cached_holdings

	holdings = (
		db.query(UserHolding)
		.filter(UserHolding.user_id == user_id)
		.order_by(UserHolding.symbol.asc(), UserHolding.created_at.desc())
		.all()
	)
	serialized_holdings = [UserHoldingInDB.model_validate(holding) for holding in holdings]
	cache_holdings(user_id, serialized_holdings)
	return serialized_holdings
