"""Server-owned paid content: payment orders, grants and the paid-amber ledger."""
from alembic import op
import sqlalchemy as sa

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("accounts") as batch:
        batch.add_column(sa.Column("paid_amber", sa.Integer(), nullable=False, server_default="0"))
    op.create_table(
        "payment_orders",
        sa.Column("id", sa.String(length=32), nullable=False),
        sa.Column("account_id", sa.String(length=32), sa.ForeignKey("accounts.id", ondelete="CASCADE"), nullable=False),
        sa.Column("product", sa.String(length=64), nullable=False),
        sa.Column("price_fen", sa.Integer(), nullable=False),
        sa.Column("once_key", sa.String(length=96), nullable=False, server_default=""),
        sa.Column("content", sa.JSON(), nullable=False),
        sa.Column("status", sa.String(length=12), nullable=False),
        sa.Column("provider", sa.String(length=16), nullable=False, server_default=""),
        sa.Column("provider_ref", sa.String(length=128), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("paid_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("grant_id", sa.String(length=32), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_payment_orders_account_id", "payment_orders", ["account_id"])
    op.create_index("ux_payment_orders_ref", "payment_orders", ["provider", "provider_ref"], unique=True)
    op.create_index("ix_payment_orders_product", "payment_orders", ["account_id", "product", "status"])
    op.create_table(
        "grants",
        sa.Column("id", sa.String(length=32), nullable=False),
        sa.Column("account_id", sa.String(length=32), sa.ForeignKey("accounts.id", ondelete="CASCADE"), nullable=False),
        sa.Column("order_id", sa.String(length=32), nullable=False),
        sa.Column("content", sa.JSON(), nullable=False),
        sa.Column("amber", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("delivered_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("delivered_version", sa.Integer(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("order_id"),
    )
    op.create_index("ix_grants_account_id", "grants", ["account_id"])


def downgrade() -> None:
    op.drop_index("ix_grants_account_id", "grants")
    op.drop_table("grants")
    op.drop_index("ix_payment_orders_product", "payment_orders")
    op.drop_index("ux_payment_orders_ref", "payment_orders")
    op.drop_index("ix_payment_orders_account_id", "payment_orders")
    op.drop_table("payment_orders")
    with op.batch_alter_table("accounts") as batch:
        batch.drop_column("paid_amber")
