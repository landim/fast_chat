import os
from sqlalchemy import create_engine, Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.orm import DeclarativeBase, Session, relationship
from langchain_core.tools import tool

_url = os.getenv("DATABASE_URL", "postgresql://langdb:langdb@localhost:5442/langdb")
DATABASE_URL = _url.replace("postgresql://", "postgresql+psycopg://", 1)
engine = create_engine(DATABASE_URL)


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    name = Column(String, nullable=False)
    threads = relationship("Thread", back_populates="user")


class Thread(Base):
    __tablename__ = "threads"
    id = Column(String, primary_key=True)  # UUID string
    title = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), nullable=False)
    updated_at = Column(DateTime(timezone=True), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    user = relationship("User", back_populates="threads")


@tool
def get_name(user_id: int) -> str:
    """Look up a user's name by their ID in the database."""
    with Session(engine) as session:
        user = session.get(User, user_id)
        if user is None:
            return f"No user found with id {user_id}"
        return user.name
