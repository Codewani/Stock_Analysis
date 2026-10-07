import logging

import redis
from pydantic import TypeAdapter

from backend.models.snap_trade.user_holdings import UserHoldingInDB
from backend.services.redis import redis_client


logger = logging.getLogger(__name__)
holdings_adapter = TypeAdapter(list[UserHoldingInDB])

HOLDINGS_CACHE_TTL_SECONDS = 24 * 60 * 60


def get_holdings_cache_key(user_id: str) -> str:
    return f"holdings:{user_id}"


def _handle_cache_error(action: str, user_id: str, exc: redis.RedisError) -> None:
    logger.warning("Redis unavailable during %s for user %s: %s", action, user_id, exc)


def cache_holdings(user_id: str, holdings: list[UserHoldingInDB]) -> None:
    key = get_holdings_cache_key(user_id)
    try:
        payload = holdings_adapter.dump_json(holdings).decode("utf-8")
        redis_client.set(key, payload, ex=HOLDINGS_CACHE_TTL_SECONDS)
    except redis.RedisError as exc:
        _handle_cache_error("cache write", user_id, exc)


def get_cached_holdings(user_id: str) -> list[UserHoldingInDB] | None:
    key = get_holdings_cache_key(user_id)
    try:
        payload = redis_client.get(key)
        if payload is None:
            return None
        return holdings_adapter.validate_json(payload)
    except redis.RedisError as exc:
        _handle_cache_error("cache read", user_id, exc)
        return None


def delete_cached_holdings(user_id: str):
    key = get_holdings_cache_key(user_id)
    try:
        redis_client.delete(key)
    except redis.RedisError as exc:
        _handle_cache_error("cache delete", user_id, exc)
