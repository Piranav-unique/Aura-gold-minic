"""create_workflow_module

Revision ID: m8h9i0j1k2l3
Revises: l7g8h9i0j1k2
Create Date: 2026-06-08 22:00:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "m8h9i0j1k2l3"
down_revision: Union[str, None] = "l7g8h9i0j1k2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "workflow_requests",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("request_number", sa.String(length=40), nullable=False),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column(
            "request_type",
            sa.String(length=50),
            server_default="general",
            nullable=False,
        ),
        sa.Column(
            "state",
            sa.String(length=20),
            server_default="draft",
            nullable=False,
        ),
        sa.Column("requester_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("assignee_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("entity_type", sa.String(length=50), nullable=True),
        sa.Column("entity_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("payload", postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column("escalation_level", sa.Integer(), server_default="0", nullable=False),
        sa.Column("pending_since", sa.DateTime(timezone=True), nullable=True),
        sa.Column("submitted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "state IN ('draft', 'pending', 'approved', 'rejected')",
            name="ck_workflow_requests_state",
        ),
        sa.CheckConstraint(
            "request_type IN ('general', 'transaction', 'inventory', 'customer')",
            name="ck_workflow_requests_type",
        ),
        sa.ForeignKeyConstraint(["assignee_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["requester_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("request_number"),
    )
    op.create_index("ix_workflow_requests_state", "workflow_requests", ["state"])
    op.create_index(
        "ix_workflow_requests_request_type", "workflow_requests", ["request_type"]
    )
    op.create_index(
        "ix_workflow_requests_requester_id", "workflow_requests", ["requester_id"]
    )
    op.create_index(
        "ix_workflow_requests_assignee_id", "workflow_requests", ["assignee_id"]
    )
    op.create_index(
        "ix_workflow_requests_pending_since", "workflow_requests", ["pending_since"]
    )
    op.create_index(
        "ix_workflow_requests_created_at", "workflow_requests", ["created_at"]
    )

    op.create_table(
        "workflow_approval_history",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("request_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("actor_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("action", sa.String(length=30), nullable=False),
        sa.Column("comment", sa.Text(), nullable=True),
        sa.Column("from_state", sa.String(length=20), nullable=True),
        sa.Column("to_state", sa.String(length=20), nullable=True),
        sa.Column("assignee_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("escalation_level", sa.Integer(), server_default="0", nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "action IN ('created', 'submitted', 'assigned', 'approved', 'rejected', 'escalated')",
            name="ck_workflow_approval_history_action",
        ),
        sa.ForeignKeyConstraint(["actor_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["assignee_id"], ["users.id"]),
        sa.ForeignKeyConstraint(
            ["request_id"], ["workflow_requests.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_workflow_approval_history_request_id",
        "workflow_approval_history",
        ["request_id"],
    )
    op.create_index(
        "ix_workflow_approval_history_created_at",
        "workflow_approval_history",
        ["created_at"],
    )

    op.create_table(
        "workflow_comments",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("request_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("author_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["author_id"], ["users.id"]),
        sa.ForeignKeyConstraint(
            ["request_id"], ["workflow_requests.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_workflow_comments_request_id", "workflow_comments", ["request_id"]
    )
    op.create_index(
        "ix_workflow_comments_created_at", "workflow_comments", ["created_at"]
    )

    op.create_table(
        "workflow_escalation_rules",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            server_default=sa.text("gen_random_uuid()"),
            nullable=False,
        ),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column(
            "request_type",
            sa.String(length=50),
            server_default="*",
            nullable=False,
        ),
        sa.Column("hours_until_escalation", sa.Integer(), nullable=False),
        sa.Column("target_permission", sa.String(length=100), nullable=False),
        sa.Column("escalation_level", sa.Integer(), server_default="0", nullable=False),
        sa.Column("is_active", sa.Boolean(), server_default="true", nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "hours_until_escalation > 0",
            name="ck_workflow_escalation_rules_hours_pos",
        ),
        sa.CheckConstraint(
            "escalation_level >= 0",
            name="ck_workflow_escalation_rules_level_nonneg",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_workflow_escalation_rules_request_type",
        "workflow_escalation_rules",
        ["request_type"],
    )
    op.create_index(
        "ix_workflow_escalation_rules_is_active",
        "workflow_escalation_rules",
        ["is_active"],
    )


def downgrade() -> None:
    op.drop_table("workflow_escalation_rules")
    op.drop_table("workflow_comments")
    op.drop_table("workflow_approval_history")
    op.drop_table("workflow_requests")
