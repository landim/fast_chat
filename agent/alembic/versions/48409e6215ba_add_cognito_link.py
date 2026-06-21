"""add cognito link to users

Revision ID: 48409e6215ba
Revises: a1f414912117
Create Date: 2026-06-21 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '48409e6215ba'
down_revision: Union[str, Sequence[str], None] = 'a1f414912117'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("cognito_sub", sa.String(), nullable=True))
    op.add_column("users", sa.Column("email", sa.String(), nullable=True))
    op.create_unique_constraint("uq_users_cognito_sub", "users", ["cognito_sub"])


def downgrade() -> None:
    op.drop_constraint("uq_users_cognito_sub", "users", type_="unique")
    op.drop_column("users", "email")
    op.drop_column("users", "cognito_sub")
