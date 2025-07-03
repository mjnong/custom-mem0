from contextlib import asynccontextmanager, AsyncExitStack
import logging
import signal
import sys
import asyncio

import uvicorn
from fastapi import FastAPI

from app.memory.memory import get_memory_service
from config import get_config


logger = logging.getLogger(__name__)


@asynccontextmanager
async def app_lifespan(app: FastAPI):
    """Manage application lifecycle with type-safe context"""
    # Initialize on startup
    try:
        async with AsyncExitStack() as stack:
            # Add more context managers as needed
            await stack.enter_async_context(get_memory_service().mcp.session_manager.run())
            yield
    finally:
        # Cleanup on shutdown
        pass

def handle_shutdown_signal(signum, frame):
    """Handle shutdown signals"""
    logger.info(f"Received signal {signum}, initiating graceful shutdown...")

    # Exit gracefully
    sys.exit(0)

# Initialize FastAPI app
app = FastAPI(lifespan=app_lifespan)
app.mount("/memory", get_memory_service().mcp.streamable_http_app())


async def main():
    # Register signal handlers for graceful shutdown
    signal.signal(signal.SIGINT, handle_shutdown_signal)
    signal.signal(signal.SIGTERM, handle_shutdown_signal)

    # Add additional signal handling for development reloads
    if hasattr(signal, 'SIGHUP'):
        signal.signal(signal.SIGHUP, handle_shutdown_signal)

    config = uvicorn.Config(
        app,
        host=get_config().fastapi_host,
        port=get_config().fastapi_port,
        ws_ping_interval=10,
        ws_ping_timeout=20,
        #reload=True,
        log_level=get_config().memory_log_level,
        # Add reload dirs to better control when reloading happens
        reload_dirs=["src/"],
        use_colors= True,
        # Exclude certain patterns that might cause unnecessary reloads
        reload_excludes=["**/.git/**", "**/__pycache__/**", "**/logs/**", "**/scripts/**"],
    )
    server = uvicorn.Server(config)

    try:
        await server.serve()
    except KeyboardInterrupt:
        logger.info("Received keyboard interrupt, shutting down...")
    except Exception as e:
        logger.error(f"Server error: {str(e)}")
        raise


if __name__ == "__main__":
    asyncio.run(main())