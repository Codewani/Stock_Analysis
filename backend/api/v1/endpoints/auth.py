import hashlib
import uuid
from datetime import timedelta
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from backend.core.security import (
	ACCESS_TOKEN_EXPIRE_MINUTES,
	authenticate_user,
	create_access_token,
	get_current_user,
	get_password_hash,
)
from backend.db.session import get_db
from backend.models.auth.user import Credential, User, UserInDB, UserSecret
from backend.schemas.auth import UserCreate, UserProfileResponse, UserResponse
from backend.schemas.token import Token
from backend.services.snap_trade import snaptrade


router = APIRouter(tags=["auth"])


def generate_snaptrade_user_id(email: str) -> str:
	normalized_email = email.strip().lower()
	return hashlib.sha256(normalized_email.encode("utf-8")).hexdigest()


def generate_user_id() -> uuid.UUID:
	return uuid.uuid4()


@router.post("/register", response_model=UserResponse)
def register_user(user: UserCreate, db: Session = Depends(get_db)) -> UserResponse:
	existing_user = db.query(User).filter(
		((User.email == user.email) | (User.phone_number == user.phone_number))
	).first()
	if existing_user:
		if existing_user.email == user.email:
			raise HTTPException(status_code=400, detail="Email already registered")
		raise HTTPException(status_code=400, detail="Phone number already registered")

	user_id = generate_user_id()
	snaptrade_user_id = generate_snaptrade_user_id(user.email)

	snap_trade_response = snaptrade.authentication.register_snap_trade_user(user_id=snaptrade_user_id)
	if snap_trade_response.status != 200:
		raise HTTPException(status_code=400, detail="Failed to register with SnapTrade")

	user_secret = snap_trade_response.body["userSecret"]
	new_user = User(
		user_id=user_id,
		snaptrade_user_id=snaptrade_user_id,
		first_name=user.first_name,
		last_name=user.last_name,
		email=user.email,
		phone_number=user.phone_number,
	)
	new_credential = Credential(
		user_id=new_user.user_id,
		password_hash=get_password_hash(user.password),
	)
	new_user_secret = UserSecret(
		user_id=new_user.user_id,
		snap_trade_secret=user_secret,
	)

	db.add_all([new_user, new_credential, new_user_secret])
	try:
		db.commit()
	except Exception:
		db.rollback()
		raise HTTPException(status_code=500, detail="Failed to create user")

	db.refresh(new_user)
	return UserResponse(user_id=new_user.user_id, message="User registered successfully")


@router.get("/users/me", response_model=UserProfileResponse)
async def read_current_user(
	current_user: Annotated[UserInDB, Depends(get_current_user)],
) -> UserProfileResponse:
	return UserProfileResponse(
		user_id=current_user.user_id,
		first_name=current_user.first_name,
		last_name=current_user.last_name,
		email=current_user.email,
		phone_number=current_user.phone_number,
	)


@router.get("/users/{user_id}", response_model=UserProfileResponse)
def get_user_endpoint(user_id: str, db: Session = Depends(get_db)) -> UserProfileResponse:
	try:
		parsed_user_id = uuid.UUID(user_id)
	except ValueError:
		raise HTTPException(status_code=404, detail="User not found")

	user = db.query(User).filter(User.user_id == parsed_user_id).first()
	if not user:
		raise HTTPException(status_code=404, detail="User not found")
	return UserProfileResponse(
		user_id=user.user_id,
		first_name=user.first_name,
		last_name=user.last_name,
		email=user.email,
		phone_number=user.phone_number,
	)


@router.post("/login", response_model=Token)
async def login_for_access_token(
	form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
	db: Session = Depends(get_db),
) -> Token:
	user = authenticate_user(db, form_data.username, form_data.password)
	if not user:
		raise HTTPException(
			status_code=status.HTTP_401_UNAUTHORIZED,
			detail="Incorrect username or password",
			headers={"WWW-Authenticate": "Bearer"},
		)
	access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
	access_token = create_access_token(
		data={"sub": str(user.user_id)}, expires_delta=access_token_expires
	)
	return Token(access_token=access_token, token_type="bearer")