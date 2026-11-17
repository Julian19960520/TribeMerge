"""Async multiplayer cohorts and entries for Tiger Escape."""
from alembic import op
import sqlalchemy as sa

revision = "0004"
down_revision = "0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "tiger_cohorts",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("account_id", sa.String(length=32), sa.ForeignKey("accounts.id", ondelete="CASCADE"), nullable=False),
        sa.Column("start_at", sa.Float(), nullable=False, server_default="0"),
        sa.Column("player_count", sa.Integer(), nullable=False, server_default="100"),
        sa.Column("quotas", sa.JSON(), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False, server_default="running"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_tiger_cohorts_account_id", "tiger_cohorts", ["account_id"])
    op.create_table(
        "tiger_entries",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("cohort_id", sa.String(length=36), sa.ForeignKey("tiger_cohorts.id", ondelete="CASCADE"), nullable=False),
        sa.Column("slot", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("account_id", sa.String(length=32), nullable=True),
        sa.Column("source_entry_id", sa.Integer(), nullable=True),
        sa.Column("is_bot", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("name", sa.String(length=64), nullable=False, server_default=""),
        sa.Column("avatar", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("stage", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("points", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("stage_times", sa.JSON(), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False, server_default="running"),
        sa.Column("eliminated_stage", sa.Integer(), nullable=False, server_default="-1"),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_tiger_entries_cohort_id", "tiger_entries", ["cohort_id"])
    op.create_index("ix_tiger_entries_account_id", "tiger_entries", ["account_id"])
    op.create_index("ix_tiger_entries_cohort_slot", "tiger_entries", ["cohort_id", "slot"], unique=True)


def downgrade() -> None:
    op.drop_index("ix_tiger_entries_cohort_slot", table_name="tiger_entries")
    op.drop_index("ix_tiger_entries_account_id", table_name="tiger_entries")
    op.drop_index("ix_tiger_entries_cohort_id", table_name="tiger_entries")
    op.drop_table("tiger_entries")
    op.drop_index("ix_tiger_cohorts_account_id", table_name="tiger_cohorts")
    op.drop_table("tiger_cohorts")
