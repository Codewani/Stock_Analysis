from fastapi import APIRouter, Depends, FastAPI, HTTPException, status
from sqlalchemy.orm import Session
from passlib.context import CryptContext
from pydantic import BaseModel
from models.auth.user import *
from models.auth.token import *
from database import SessionLocal
from utils.snap_trade import snaptrade
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from datetime import datetime, timedelta, timezone
from typing import Annotated
import jwt
from jwt.exceptions import InvalidTokenError

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

router = APIRouter()

pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")
# to get a string like this run:
# openssl rand -hex 32
SECRET_KEY = "09d25e094faa6ca2556c818166b7a9563b93f7099f6f0f4caa6cf63b88e8d3e7"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

class UserCreate(BaseModel):
    user_id: str
    first_name: str
    last_name: str
    email: str
    phone_number: str
    password: str

class UserResponse(BaseModel):
    user_id: str
    message: str

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.post("/register", response_model=UserResponse)
def register_user(user: UserCreate, db: Session = Depends(get_db)):
    # Check if email already exists
    db_user = db.query(User).filter(User.email == user.email).first()

    snap_trade_response = snaptrade.authentication.register_snap_trade_user(
        user_id=user.user_id
    )
    
    if snap_trade_response.status != 200:
        raise HTTPException(status_code=400, detail="Failed to register with SnapTrade")
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    user_secret = snap_trade_response.body['userSecret']

    # Create new user
    new_user = User(
        user_id=user.user_id,
        first_name=user.first_name,
        last_name=user.last_name,
        email=user.email,
        phone_number=user.phone_number
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    # Hash password and create credential
    hashed_password = pwd_context.hash(user.password)
    new_credential = Credential(
        user_id=new_user.user_id,
        password_hash=hashed_password
    )
    db.add(new_credential)
    db.commit()

    new_user_secret = UserSecret(
        user_id=new_user.user_id,
        snap_trade_secret=user_secret
    )

    db.add(new_user_secret)
    db.commit()

    return UserResponse(user_id=new_user.user_id, message="User registered successfully")


password_hash = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")


def verify_password(plain_password, hashed_password):
    return password_hash.verify(plain_password, hashed_password)


def get_password_hash(password):
    return password_hash.hash(password)


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


async def get_current_user(token: Annotated[str, Depends(oauth2_scheme)], db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username = payload.get("sub")
        if username is None:
            raise credentials_exception
        token_data = TokenData(username=username)
    except InvalidTokenError:
        raise credentials_exception
    user = get_user(db, token_data.username)
    if user is None:
        raise credentials_exception
    return user


async def get_current_active_user(
    current_user: Annotated[UserInDB, Depends(get_current_user)],
):
    return current_user


@router.get("/users/me")
async def read_current_user(current_user: Annotated[UserInDB, Depends(get_current_user)]):
    return {
        "user_id": current_user.user_id,
        "first_name": current_user.first_name,
        "last_name": current_user.last_name,
        "email": current_user.email,
        "phone_number": current_user.phone_number,
    }


@router.get("/users/{user_id}")
def get_user_endpoint(user_id: str, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.user_id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return {
        "user_id": user.user_id,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "email": user.email,
        "phone_number": user.phone_number
    }


@router.post("/login")
async def login_for_access_token(
    form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
db: Session = Depends(get_db)) -> Token:
    user = authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.user_id}, expires_delta=access_token_expires
    )
    return Token(access_token=access_token, token_type="bearer")


