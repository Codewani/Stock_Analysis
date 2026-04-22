import logging

import redis
from pydantic import TypeAdapter

from backend.ulrs.utils.caching.load_redis import redis_client
from backend.ulrs.utils.watchlist.req_res_models import WatchlistEntry


logger = logging.getLogger(__name__)
watchlist_adapter = TypeAdapter(list[WatchlistEntry])

def get_watchlist_cache_key(user_id: str) -> str:
    return f"watchlist:{user_id}"


def _handle_cache_error(action: str, user_id: str, exc: redis.RedisError) -> None:
    logger.warning("Redis unavailable during %s for user %s: %s", action, user_id, exc)


def cache_watchlist(user_id: str, watchlist: list[WatchlistEntry]) -> None:
    key = get_watchlist_cache_key(user_id)
    try:
        payload = watchlist_adapter.dump_json(watchlist).decode("utf-8")
        redis_client.set(key, payload)
    except redis.RedisError as exc:
        _handle_cache_error("cache write", user_id, exc)

def get_cached_watchlist(user_id: str) -> list[WatchlistEntry] | None:
    key = get_watchlist_cache_key(user_id)
    try:
        payload = redis_client.get(key)
        if payload is None:
            return None
        return watchlist_adapter.validate_json(payload)
    except redis.RedisError as exc:
        _handle_cache_error("cache read", user_id, exc)
        return None

def delete_cached_watchlist(user_id: str):
    key = get_watchlist_cache_key(user_id)
    try:
        redis_client.delete(key)
    except redis.RedisError as exc:
        _handle_cache_error("cache delete", user_id, exc)
