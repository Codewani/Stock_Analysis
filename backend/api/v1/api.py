from fastapi import APIRouter

from backend.api.v1.endpoints.auth import router as auth_router
from backend.api.v1.endpoints.snap_trade_connections import router as snap_trade_connections_router
from backend.api.v1.endpoints.snap_trade_data import router as snap_trade_data_router
from backend.api.v1.endpoints.watchlist import router as watchlist_router

api_router = APIRouter()
api_router.include_router(auth_router)
api_router.include_router(snap_trade_data_router)
api_router.include_router(snap_trade_connections_router)
api_router.include_router(watchlist_router)
