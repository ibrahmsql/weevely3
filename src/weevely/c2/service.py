import io
import logging
from contextlib import redirect_stdout
from typing import Optional

from weevely.core import modules
from weevely.core.sessions import SessionURL
from weevely.core.terminal import Terminal

# Capture logs to return to API
log_capture_string = io.StringIO()
ch = logging.StreamHandler(log_capture_string)
ch.setLevel(logging.INFO)
logging.getLogger("weevely").addHandler(ch)


from sqlmodel import Session as DbSession
from .models import CommandLog
from .models import Agent
from datetime import datetime

# Global session cache to maintain state (e.g. CWD) across requests
_session_cache = {}


def get_cached_session(url: str, password: str) -> SessionURL:
    """
    Retrieve a session from cache or create a new one.
    """
    session_key = f"{url}|{password}"
    
    if session_key not in _session_cache:
        # Initialize session
        # We use volatile=True because we are managing persistence via the C2 database/cache
        # rather than Weevely's flat file system.
        session = SessionURL(url=url, password=password, volatile=True)
        modules.load_modules(session)
        _session_cache[session_key] = session
        
    return _session_cache[session_key]


def check_agent_health(agent: Agent, db: DbSession):
    """
    Check if an agent is reachable and update its status.
    """
    try:
        session = get_cached_session(agent.url, agent.password)
        # Use a simple echo command to check connectivity
        # We use the system_info module or just a raw command if possible
        # But to be generic, let's try to run a simple echo via the loaded shell
        
        # We need to find a loaded shell module
        shell_module = None
        if session.get("default_shell"):
             shell_module = modules.loaded.get(session.get("default_shell"))
        
        if not shell_module:
             # Try to setup if not set
             # This might be expensive, but necessary
             pass

        # For simplicity, let's just try to execute "echo 1" via the terminal emulation
        # or directly via the channel if we can access it.
        # Accessing channel directly is better for a health check.
        
        # Actually, let's reuse execute_command logic but keep it simple
        # We can't easily access the channel without module setup.
        # So let's run "echo 1"
        
        # Create terminal instance to execute command
        term = Terminal(session)
        
        # Capture stdout
        f = io.StringIO()
        with redirect_stdout(f):
            term.onecmd("echo 1")
            
        output = f.getvalue().strip()
        
        if "1" in output:
            agent.status = "Active"
            agent.last_seen = datetime.utcnow()
        else:
            agent.status = "Unreachable"
            
    except Exception:
        agent.status = "Unreachable"
    
    db.add(agent)
    db.commit()


def execute_command(agent_id: int, url: str, password: str, cmd: str, db: DbSession) -> str:
    """
    Execute a single command on a Weevely agent and log it.
    """
    # Clear previous logs
    log_capture_string.truncate(0)
    log_capture_string.seek(0)
    
    output_combined = ""
    
    try:
        session = get_cached_session(url, password)
        
        # Create terminal instance to execute command
        term = Terminal(session)
        
        # Capture stdout as well, although Weevely mostly uses loggers
        f = io.StringIO()
        with redirect_stdout(f):
            # Pre-process command (e.g. handle aliases)
            term.precmd(cmd)
            # Execute
            term.onecmd(cmd)
            
        output = f.getvalue()
        logs = log_capture_string.getvalue()
        
        output_combined = output + "\n" + logs

    except Exception as e:
        output_combined = f"Error: {str(e)}"
        
    # Log to DB
    log_entry = CommandLog(agent_id=agent_id, command=cmd, output=output_combined)
    db.add(log_entry)
    db.commit()
    
    return output_combined
