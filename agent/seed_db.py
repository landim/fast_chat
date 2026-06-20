import os
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from database import User

load_dotenv()

_conn = os.getenv("DATABASE_URL", "postgresql://langdb:langdb@localhost:5432/langdb")
engine = create_engine(_conn.replace("postgresql://", "postgresql+psycopg://", 1))

with Session(engine) as session:
    session.add_all(
        [
            User(id=1, name="Alice"),
            User(id=2, name="Bob"),
            User(id=3, name="Carol"),
        ]
    )
    session.commit()
    print("Database seeded with 3 users.")
