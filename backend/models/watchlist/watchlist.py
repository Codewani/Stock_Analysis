import uuid

from sqlalchemy import Column, String, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy import Column, String, TIMESTAMP, func, ForeignKey
from sqlalchemy.orm import relationship

from backend.models.auth.user import Base

class WatchList(Base):
    __tablename__ = "watchlist"

    watchlist_item_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(String(255), ForeignKey("users.user_id"), nullable=False)
    symbol = Column(String(255), nullable=False)
    created_at = Column(TIMESTAMP, server_default=func.current_timestamp())
    user = relationship("User", back_populates="watchlist")