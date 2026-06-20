from database import engine, User
from sqlalchemy.orm import Session

with Session(engine) as session:
    session.add_all([
        User(id=1, name="Alice"),
        User(id=2, name="Bob"),
        User(id=3, name="Carol"),
    ])
    session.commit()
    print("Database seeded with 3 users.")
