import os
import jwt
from sqlalchemy.orm import Session
from passlib.context import CryptContext
from backend.models.auth.user import Credential, User, UserInDB
from datetime import datetime, timedelta, timezone

pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")
SECRET_KEY = os.getenv("SECRET_KEY", "development-secret-change-me")

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password):
    return pwd_context.hash(password)


def get_user(db: Session, user_identifier: str):
    """Get user by user_id or email, joined with credentials."""
    user = db.query(User).filter(
        (User.user_id == user_identifier) | (User.email == user_identifier)
    ).first()
    
    if user:
        credential = db.query(Credential).filter(Credential.user_id == user.user_id).first()
        if credential:
            user_in_db = UserInDB(
                user_id=user.user_id,
                first_name=user.first_name,
                last_name=user.last_name,
                email=user.email,
                phone_number=user.phone_number,
                hashed_password=credential.password_hash
            )
            return user_in_db
    return None


def authenticate_user(db: Session, username: str, password: str):
    """Authenticate user by username/email and password."""
    user = get_user(db, username)
    if not user:
        return False
    if not verify_password(password, user.hashed_password):
        return False
    return user


def create_access_token(data: dict, expires_delta: timedelta | None = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt