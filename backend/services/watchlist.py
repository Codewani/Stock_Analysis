from sqlalchemy.orm import Session

from backend.models.watchlist.watchlist import WatchList
from backend.schemas.watchlist import WatchlistEntry
from backend.services.watchlist_cache import cache_watchlist, get_cached_watchlist, delete_cached_watchlist


def get_user_watchlist(user_id: str, db: Session) -> list[WatchlistEntry]:
	cached_watchlist = get_cached_watchlist(user_id)
	if cached_watchlist is not None:
		return cached_watchlist

	watchlist = (
		db.query(WatchList)
		.filter(WatchList.user_id == user_id)
		.order_by(WatchList.created_at.desc())
		.all()
	)
	serialized_watchlist = [WatchlistEntry.model_validate(item) for item in watchlist]
	cache_watchlist(user_id, serialized_watchlist)
	return serialized_watchlist
