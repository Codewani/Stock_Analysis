from sqlalchemy.orm import Session
from backend.models.watchlist.watchlist import WatchList
from backend.ulrs.utils.caching.watchlist.redis_cache import cache_watchlist, get_cached_watchlist
from backend.ulrs.utils.watchlist.req_res_models import WatchlistEntry


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