from datetime import datetime
from uuid import UUID

from fastapi import APIRouter
from pydantic import BaseModel, ConfigDict

router = APIRouter()



class WatchlistItem(BaseModel):
    symbol: str

class WatchlistResponse(BaseModel):
    user_id: str
    message: str


class WatchlistEntry(BaseModel):
    watchlist_item_id: UUID
    user_id: str
    symbol: str
    created_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)



