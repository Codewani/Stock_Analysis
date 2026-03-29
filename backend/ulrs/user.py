from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from passlib.context import CryptContext
from pydantic import BaseModel
from models.users import User, Credential
from database import SessionLocal
from tests.snap_trade import snaptrade

router = APIRouter()

pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")

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
        user_id="kondwani-234"
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

    return UserResponse(user_id=new_user.user_id, message="User registered successfully")
