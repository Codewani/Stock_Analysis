from datetime import datetime
import uuid

from pydantic import BaseModel, ConfigDict
from sqlalchemy import Column, String, DECIMAL, TIMESTAMP, func, ForeignKey, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from models.auth.user import Base

class UserHolding(Base):
    __tablename__ = "user_holdings"

    holding_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(String(255), ForeignKey("users.user_id"), nullable=False)
    account_id = Column(String(255), nullable=False)
    symbol = Column(String(255), nullable=False)
    units = Column(DECIMAL(18, 4), nullable=False)
    open_pnl = Column(DECIMAL(18, 4), nullable=False)
    price = Column(DECIMAL(18, 4), nullable=False)
    created_at = Column(TIMESTAMP, server_default=func.current_timestamp())

    user = relationship("User", back_populates="user_holdings")

    __table_args__ = (
        UniqueConstraint('user_id', 'account_id', 'symbol', name='uq_user_holding'),
    )
