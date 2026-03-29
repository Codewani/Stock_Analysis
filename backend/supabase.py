connection_url = 'postgresql://postgres.fenicqqghwvgzcfbllij:fQzPdNNBttIQRI42@aws-1-us-east-2.pooler.supabase.com:5432/postgres'


from sqlmodel import SQLModel, Field, create_engine, Session, select
from typing import Optional, List
from fastapi import FastAPI
from contextlib import asynccontextmanager

engine = create_engine(connection_url)
def create_db_and_tables():
    SQLModel.metadata.create_all(engine)

class User(SQLModel, table=True):
    __tablename__ = "users"

    user_id: str =  Field(default=None, primary_key=True)
    first_name: str
    last_name: str
    email: str
    phone_number: str

@asynccontextmanager
async def lifespan(app: FastAPI):
    create_db_and_tables()
    yield

app = FastAPI(lifespan=lifespan)
@app.post("/register")
def register_user(user: User):
    with Session(engine) as session:
        session.add(user)
        session.commit()
        session.refresh(user)
        return {"user_id": user.user_id, "message": "User registered successfully"}

@app.get('/users/', response_model=List[User])
def get_users():
    with Session(engine) as session:
        users = session.exec(select(User)).all()
        return users