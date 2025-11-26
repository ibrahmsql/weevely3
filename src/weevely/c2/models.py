from datetime import datetime
from typing import Optional

from sqlmodel import Field
from sqlmodel import SQLModel


class Agent(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    url: str = Field(index=True)
    password: str
    alias: Optional[str] = None
    tags: Optional[str] = None  # Comma separated tags
    last_seen: Optional[datetime] = None
    status: str = Field(default="Unknown")  # Active, Unreachable, Unknown
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    # Configuration for the agent (e.g. channel type if known)
    config: Optional[str] = None


class CommandLog(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    agent_id: int = Field(foreign_key="agent.id")
    command: str
    output: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)
