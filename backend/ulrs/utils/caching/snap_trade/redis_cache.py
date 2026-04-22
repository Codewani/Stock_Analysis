import logging

import redis

from backend.ulrs.utils.caching.load_redis import redis_client


logger = logging.getLogger(__name__)

def get_account_ids_cache_key(user_id: str) -> str:
    return f"snaptrade:accounts:{user_id}"


def _handle_cache_error(action: str, user_id: str, exc: redis.RedisError) -> None:
    logger.warning("Redis unavailable during %s for user %s: %s", action, user_id, exc)


def cache_account_ids(user_id: str, account_ids: list[str]):
    key = get_account_ids_cache_key(user_id)
    try:
        redis_client.delete(key)
        if account_ids:
            redis_client.rpush(key, *account_ids)
    except redis.RedisError as exc:
        _handle_cache_error("cache write", user_id, exc)

def get_cached_account_ids(user_id: str) -> list[str]:
    key = get_account_ids_cache_key(user_id)
    try:
        return redis_client.lrange(key, 0, -1)
    except redis.RedisError as exc:
        _handle_cache_error("cache read", user_id, exc)
        return []

def delete_cached_account_ids(user_id: str):
    key = get_account_ids_cache_key(user_id)
    try:
        redis_client.delete(key)
    except redis.RedisError as exc:
        _handle_cache_error("cache delete", user_id, exc)
