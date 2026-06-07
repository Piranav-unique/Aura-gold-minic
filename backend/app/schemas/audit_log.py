import uuid
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


class AuditLogResponse(BaseModel):
    """Pydantic schema representing audit log retrieval query results."""

    id: uuid.UUID
    user_id: Optional[uuid.UUID] = None
    action: str
    entity_type: Optional[str] = None
    entity_id: Optional[str] = None
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None
    timestamp: datetime
    # Map from SQLAlchemy 'meta_data' attribute to 'metadata' JSON key
    metadata: Optional[dict] = Field(None, validation_alias="meta_data")

    model_config = {
        "from_attributes": True,
        "populate_by_name": True,
    }
