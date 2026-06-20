import os
from sqlalchemy import create_engine, Column, Integer, String, DateTime
from sqlalchemy.orm import DeclarativeBase, Session
from langchain_core.tools import tool

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg://langdb:langdb@localhost:5432/langdb"
)
engine = create_engine(DATABASE_URL)


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    name = Column(String, nullable=False)


class Thread(Base):
    __tablename__ = "threads"
    id = Column(String, primary_key=True)           # UUID string
    title = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), nullable=False)
    updated_at = Column(DateTime(timezone=True), nullable=False)


@tool
def get_name(user_id: int) -> str:
    """Look up a user's name by their ID in the database."""
    with Session(engine) as session:
        user = session.get(User, user_id)
        if user is None:
            return f"No user found with id {user_id}"
        return user.name
