import logging
import random

import redis

from backend.services.redis import redis_client


logger = logging.getLogger(__name__)

# Set when a symbol's set is loaded from the DB and never extended by adds/removes, so if a
# rare race (e.g. a watchlist change landing mid-load) leaves a set slightly off, it self-heals
# within a day. Jitter keeps sets loaded together from all expiring and reloading at once.
CONCERNED_USERS_TTL_SECONDS = 24 * 60 * 60
CONCERNED_USERS_TTL_JITTER_SECONDS = 60 * 60

# Every loaded set contains this member. Redis deletes a set when its last member is removed,
# which would make "nobody is concerned" look like a cache miss; the marker keeps it alive.
LOADED_MARKER = "__loaded__"

# Adding to a set that isn't loaded would create one containing only this user, which readers
# would trust as the full list. The script runs atomically in Redis, so the key can't expire
# between the check and the add.
_add_if_loaded = redis_client.register_script(
    """
    if redis.call('EXISTS', KEYS[1]) == 1 then
        return redis.call('SADD', KEYS[1], ARGV[1])
    end
    return 0
    """
)


def normalize_symbol(symbol: str) -> str:
    return symbol.strip().upper()


def get_concerned_users_cache_key(symbol: str) -> str:
    return f"concerned_users:{normalize_symbol(symbol)}"


def _handle_cache_error(action: str, symbol: str, exc: redis.RedisError) -> None:
    logger.warning("Redis unavailable during %s for symbol %s: %s", action, symbol, exc)


def cache_concerned_users(symbol: str, user_ids: set[str]) -> None:
    key = get_concerned_users_cache_key(symbol)
    ttl = CONCERNED_USERS_TTL_SECONDS + random.randint(0, CONCERNED_USERS_TTL_JITTER_SECONDS)
    try:
        pipe = redis_client.pipeline()
        pipe.sadd(key, LOADED_MARKER, *user_ids)
        pipe.expire(key, ttl)
        pipe.execute()
    except redis.RedisError as exc:
        _handle_cache_error("cache write", symbol, exc)


def get_cached_concerned_users(symbol: str) -> set[str] | None:
    key = get_concerned_users_cache_key(symbol)
    try:
        members = redis_client.smembers(key)
    except redis.RedisError as exc:
        _handle_cache_error("cache read", symbol, exc)
        return None
    if not members:
        return None
    return members - {LOADED_MARKER}


def add_cached_concerned_user(symbol: str, user_id: str) -> None:
    key = get_concerned_users_cache_key(symbol)
    try:
        _add_if_loaded(keys=[key], args=[str(user_id)])
    except redis.RedisError as exc:
        _handle_cache_error("cache add", symbol, exc)


def remove_cached_concerned_user(symbol: str, user_id: str) -> None:
    key = get_concerned_users_cache_key(symbol)
    try:
        redis_client.srem(key, str(user_id))
    except redis.RedisError as exc:
        _handle_cache_error("cache remove", symbol, exc)
