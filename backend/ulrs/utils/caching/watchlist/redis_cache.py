import os
import logging

import redis


logger = logging.getLogger(__name__)

REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")

redis_client = redis.Redis.from_url(REDIS_URL, decode_responses=True)

def get_watchlist_cache_key(user_id: str) -> str:
    return f"snaptrade:accounts:{user_id}"


def _handle_cache_error(action: str, user_id: str, exc: redis.RedisError) -> None:
    logger.warning("Redis unavailable during %s for user %s: %s", action, user_id, exc)


def cache_watchlist(user_id: str, symbols: list[str]):
    key = get_watchlist_cache_key(user_id)
    try:
        redis_client.delete(key)
        if symbols:
            redis_client.rpush(key, *symbols)
    except redis.RedisError as exc:
        _handle_cache_error("cache write", user_id, exc)

def get_cached_watchlist(user_id: str) -> list[str]:
    key = get_watchlist_cache_key(user_id)
    try:
        return redis_client.lrange(key, 0, -1)
    except redis.RedisError as exc:
        _handle_cache_error("cache read", user_id, exc)
        return []

def delete_cached_watchlist(user_id: str):
    key = get_watchlist_cache_key(user_id)
    try:
        redis_client.delete(key)
    except redis.RedisError as exc:
        _handle_cache_error("cache delete", user_id, exc)
