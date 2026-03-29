from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy.orm import relationship, declarative_base

Base = declarative_base()

class User(Base):
    __tablename__ = "users"

    user_id = Column(String, primary_key=True)
    first_name = Column(String, nullable=False)
    last_name = Column(String, nullable=False)
    email = Column(String, unique=True, nullable=False)
    phone_number = Column(String, nullable=False)

    credentials = relationship("Credential", back_populates="user", uselist=False)

class Credential(Base):
    __tablename__ = "credentials"
    user_id = Column(String, ForeignKey("users.user_id"), primary_key=True)
    password_hash = Column(String, nullable=False)

    user = relationship("User", back_populates="credentials")
