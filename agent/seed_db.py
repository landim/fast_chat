from database import Base, engine, User
from sqlalchemy.orm import Session

# Create tables if they don't exist
Base.metadata.create_all(engine)

with Session(engine) as session:
    session.add_all([
        User(id=1, name="Alice"),
        User(id=2, name="Bob"),
        User(id=3, name="Carol"),
    ])
    session.commit()
    print("Database seeded with 3 users.")
