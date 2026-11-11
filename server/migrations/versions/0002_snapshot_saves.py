"""Whole-snapshot cloud saves: save writer device, account plausibility flags.

Existing replay-confirmed saves are kept. Their hash becomes the SHA-256 of the
stored JSON text, which is what clients verify when they adopt a cloud save.
"""
import gzip
import hashlib

from alembic import op
import sqlalchemy as sa

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("accounts") as batch:
        batch.add_column(sa.Column("flagged", sa.Boolean(), nullable=False, server_default=sa.false()))
        batch.add_column(sa.Column("flag_reason", sa.String(length=200), nullable=False, server_default=""))
    with op.batch_alter_table("saves") as batch:
        batch.add_column(sa.Column("writer", sa.String(length=64), nullable=False, server_default=""))
    connection = op.get_bind()
    rows = connection.execute(sa.text("SELECT account_id, data FROM saves WHERE data IS NOT NULL")).fetchall()
    for account_id, data in rows:
        digest = hashlib.sha256(gzip.decompress(data)).hexdigest()
        connection.execute(sa.text("UPDATE saves SET hash = :hash WHERE account_id = :id"), {"hash": digest, "id": account_id})


def downgrade() -> None:
    with op.batch_alter_table("saves") as batch:
        batch.drop_column("writer")
    with op.batch_alter_table("accounts") as batch:
        batch.drop_column("flag_reason")
        batch.drop_column("flagged")
