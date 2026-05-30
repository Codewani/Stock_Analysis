import uuid

from pydantic import BaseModel


class UserCreate(BaseModel):
	first_name: str
	last_name: str
	email: str
	phone_number: str
	password: str


class UserResponse(BaseModel):
	user_id: uuid.UUID
	message: str


class UserProfileResponse(BaseModel):
	user_id: uuid.UUID
	first_name: str
	last_name: str
	email: str
	phone_number: str