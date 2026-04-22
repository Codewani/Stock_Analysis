from pydantic import BaseModel

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


class UserProfileResponse(BaseModel):
    user_id: str
    first_name: str
    last_name: str
    email: str
    phone_number: str