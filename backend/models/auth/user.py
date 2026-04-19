from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy.orm import relationship, declarative_base
from pydantic import BaseModel

Base = declarative_base()

class User(Base):
    __tablename__ = "users"
    user_id = Column(String, primary_key=True)
    first_name = Column(String, nullable=False)
    last_name = Column(String, nullable=False)
    email = Column(String, unique=True, nullable=False)
    phone_number = Column(String, nullable=False)

    credentials = relationship("Credential", back_populates="user", uselist=False)
    user_secrets = relationship("UserSecret", back_populates="user", uselist=False)
    account_balance_snapshots = relationship("AccountBalanceSnapshot", back_populates="user")
    user_holdings = relationship("UserHolding", back_populates="user")

class Credential(Base):
    __tablename__ = "credentials"
    user_id = Column(String, ForeignKey("users.user_id"), primary_key=True)
    password_hash = Column(String, nullable=False)

    user = relationship("User", back_populates="credentials")

class UserSecret(Base):
    __tablename__ = "user_secrets"
    user_id = Column(String, ForeignKey("users.user_id"), primary_key=True)
    snap_trade_secret = Column(String, nullable=False)

    user = relationship("User", back_populates="user_secrets")

class UserInDB(BaseModel):
    user_id: str
    first_name: str
    last_name: str
    email: str
    phone_number: str
    hashed_password: str
