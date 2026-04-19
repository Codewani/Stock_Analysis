import os

from fastapi import Depends, HTTPException, status
from sqlalchemy.orm import Session
from backend.models.auth.token import Token
from backend.models.auth.user import Credential, User, UserInDB, UserSecret
from backend.utils.snap_trade import snaptrade
from fastapi.security import OAuth2PasswordRequestForm
from datetime import timedelta
from typing import Annotated
from backend.ulrs.utils.db.db_utils import get_db
from backend.ulrs.utils.auth.user import *

@router.post("/register", response_model=UserResponse)
def register_user(user: UserCreate, db: Session = Depends(get_db)):
    existing_user = db.query(User).filter(
        (User.email == user.email) | (User.user_id == user.user_id)
    ).first()
    if existing_user:
        if existing_user.email == user.email:
            raise HTTPException(status_code=400, detail="Email already registered")
        raise HTTPException(status_code=400, detail="User ID already registered")

    snap_trade_response = snaptrade.authentication.register_snap_trade_user(
        user_id=user.user_id
    )
    
    if snap_trade_response.status != 200:
        raise HTTPException(status_code=400, detail="Failed to register with SnapTrade")
    
    user_secret = snap_trade_response.body['userSecret']

    # Create new user
    new_user = User(
        user_id=user.user_id,
        first_name=user.first_name,
        last_name=user.last_name,
        email=user.email,
        phone_number=user.phone_number
    )
    hashed_password = get_password_hash(user.password)
    new_credential = Credential(
        user_id=new_user.user_id,
        password_hash=hashed_password
    )

    new_user_secret = UserSecret(
        user_id=new_user.user_id,
        snap_trade_secret=user_secret
    )

    db.add_all([new_user, new_credential, new_user_secret])
    try:
        db.commit()
    except Exception:
        db.rollback()
        raise HTTPException(status_code=500, detail="Failed to create user")

    db.refresh(new_user)

    return UserResponse(user_id=new_user.user_id, message="User registered successfully")


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


