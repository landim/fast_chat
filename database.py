from sqlalchemy import create_engine, Column, Integer, String
from sqlalchemy.orm import DeclarativeBase, Session
from langchain_core.tools import tool
from langchain_core.runnables import RunnableConfig

DATABASE_URL = "sqlite:///users.db"
engine = create_engine(DATABASE_URL)


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True)
    name = Column(String, nullable=False)


Base.metadata.create_all(engine)


@tool
def get_name(user_id: int, config: RunnableConfig) -> str:
    """Look up a user's name by their ID in the database."""
    session: Session = config["configurable"]["db_session"]
    user = session.get(User, user_id)
    if user is None:
        return f"No user found with id {user_id}"
    return user.name
