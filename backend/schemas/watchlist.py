from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class WatchlistItem(BaseModel):
	symbol: str


class WatchlistResponse(BaseModel):
	user_id: UUID
	message: str


class WatchlistEntry(BaseModel):
	watchlist_item_id: UUID
	user_id: UUID
	symbol: str
	created_at: datetime | None = None

	model_config = ConfigDict(from_attributes=True)