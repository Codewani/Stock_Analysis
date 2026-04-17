from datetime import datetime
import uuid

from pydantic import BaseModel, ConfigDict
from sqlalchemy import Column, String, DECIMAL, TIMESTAMP, func, ForeignKey, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from models.auth.user import Base

class AccountBalanceSnapshot(Base):
    __tablename__ = "account_balance_snapshots"

    snapshot_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(String(255), ForeignKey("users.user_id"), nullable=False)
    total_balance = Column(DECIMAL(18, 2), nullable=False)
    snapshot_timestamp = Column(TIMESTAMP, nullable=False)
    created_at = Column(TIMESTAMP, server_default=func.current_timestamp())

    user = relationship("User", back_populates="account_balance_snapshots")

    __table_args__ = (
        UniqueConstraint('user_id', 'snapshot_timestamp', name='uq_user_snapshot_time'),
    )

class AccountBalanceSnapshotInDB(BaseModel):
    snapshot_id: uuid.UUID
    user_id: str
    total_balance: float
    snapshot_timestamp: datetime
    created_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)
