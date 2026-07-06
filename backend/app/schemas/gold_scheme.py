from datetime import datetime
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, Field

GoldSchemeTier = Literal[1, 5, 10]


class GoldSchemeResponse(BaseModel):
    status: Literal["not_selected", "active", "completed"] = "not_selected"
    target_grams: Decimal | None = None
    saved_grams: Decimal = Decimal("0")
    progress_percent: Decimal = Decimal("0")
    can_sell: bool = False
    can_sell_inquiry: bool = False
    sell_locked_reason: str | None = None
    started_at: datetime | None = None


class SelectGoldSchemeRequest(BaseModel):
    target_grams: GoldSchemeTier = Field(
        ...,
        description="Gold savings scheme target: 1, 5, or 10 grams",
    )


class UpgradeGoldSchemeRequest(BaseModel):
    target_grams: GoldSchemeTier = Field(
        ...,
        description="Higher gold savings scheme target after completing the current plan",
    )
