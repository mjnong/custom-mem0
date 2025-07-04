import asyncio
import logging
import signal
import sys
from contextlib import AsyncExitStack, asynccontextmanager

import uvicorn
from fastapi import FastAPI
from fastapi.responses import JSONResponse

from src.app.memory.memory import get_memory_service
from src.config.config import get_config

logger = logging.getLogger(__name__)


@asynccontextmanager
async def app_lifespan(app: FastAPI):
    """Manage application lifecycle with type-safe context"""
    # Initialize on startup
    try:
        async with AsyncExitStack() as stack:
            # Add more context managers as needed
            await stack.enter_async_context(
                get_memory_service().mcp.session_manager.run()
            )
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
app = FastAPI(
    title="Custom Mem0 MCP Server",
    description="A custom Mem0 implementation with MCP (Model Context Protocol) support",
    version="0.1.0",
    lifespan=app_lifespan,
)


# Health check endpoint
@app.get("/health", response_class=JSONResponse)
async def health_check():
    """Health check endpoint for container orchestration"""
    return {"status": "healthy", "service": "custom-mem0-mcp"}


# Root endpoint
@app.get("/", response_class=JSONResponse)
async def root():
    """Root endpoint with service information"""
    return {
        "service": "Custom Mem0 MCP Server",
        "version": "0.1.0",
        "backend": get_config().backend,
        "status": "running",
    }


app.mount("/memory", get_memory_service().mcp.streamable_http_app())


async def main():
    # Register signal handlers for graceful shutdown
    signal.signal(signal.SIGINT, handle_shutdown_signal)
    signal.signal(signal.SIGTERM, handle_shutdown_signal)

    # Add additional signal handling for development reloads
    if hasattr(signal, "SIGHUP"):
        signal.signal(signal.SIGHUP, handle_shutdown_signal)

    config = uvicorn.Config(
        app,
        host=get_config().fastapi_host,
        port=get_config().fastapi_port,
        ws_ping_interval=10,
        ws_ping_timeout=20,
        log_level=get_config().memory_log_level,
        use_colors=True,
        access_log=True,
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
