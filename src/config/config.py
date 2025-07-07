import functools
import sys
from enum import StrEnum
from typing import Self

from dotenv import load_dotenv
from pydantic import ValidationError, field_validator, model_validator
from pydantic_settings import BaseSettings

load_dotenv(
    override=True,  # Override existing environment variables
)


class LogLevel(StrEnum):
    DEBUG = "debug"
    INFO = "info"
    WARNING = "warning"
    ERROR = "error"
    CRITICAL = "critical"
    TRACE = "trace"


class Config(BaseSettings):
    # General configuration
    backend: str = "pgvector"  # Options: "pgvector", "qdrant"
    history_db_path: str = "memory.db"  # Default path for the history database

    # Qdrant configuration
    qdrant_host: str = "localhost"
    qdrant_port: int = 6333

    # Neo4j configuration
    neo4j_ip: str = "localhost"
    neo4j_username: str = "neo4j"
    neo4j_password: str = "password"

    # Vector store configuration pgvector
    postgres_host: str = "postgres"
    postgres_port: int = 5432
    postgres_user: str = "postgres"
    postgres_password: str = "postgres"
    postgres_database: str = "postgres"
    postgres_collection_name: str = "memories"  # Default collection name for memories

    # FastAPI configuration
    fastapi_host: str = "localhost"  # e.g., "localhost" or "0.0.0"
    fastapi_port: int = 8000  # Default
    memory_log_level: LogLevel = LogLevel.INFO  # Default log level for FastAPI

    # OpenAI configuration
    openai_api_key: str = "your_openai_api_key"
    openai_model: str = "gpt-4o-mini"
    openai_embedding_model: str = "text-embedding-3-small"

    @field_validator("memory_log_level", mode="before")
    @classmethod
    def validate_memory_log_level(cls, v) -> LogLevel:
        if isinstance(v, LogLevel):
            return v
        if isinstance(v, str):
            # Try to find the enum by value (case-insensitive)
            v_lower = v.lower()
            for level in LogLevel:
                if level.value.lower() == v_lower:
                    return level
            # If not found, raise an error with helpful message
            valid_levels = [level.value for level in LogLevel]
            raise ValueError(
                f"memory_log_level must be one of {valid_levels}, got '{v}'"
            )
        raise ValueError(
            f"memory_log_level must be a string or LogLevel enum, got {type(v)}"
        )

    @field_validator("backend")
    @classmethod
    def validate_backend(cls, v: str) -> str:
        allowed_backends = {"pgvector", "qdrant"}
        if v not in allowed_backends:
            raise ValueError(f"backend must be one of {allowed_backends}, got '{v}'")
        return v

    @model_validator(mode="after")
    def validate_backend_dependencies(self) -> Self:
        # In production, we should validate all required fields
        # Skip validation only in development/testing scenarios
        is_development = self.neo4j_password in [
            "password",
            "mem0graph",
        ] and self.openai_api_key in ["your_openai_api_key", "sk-proj-"]

        if is_development:
            # Allow development defaults but warn
            print(
                "Warning: Using development defaults. Set secure values for production."
            )
            return self

        if self.backend == "pgvector":
            # Validate PostgreSQL required fields
            if not self.postgres_host:
                raise ValueError("postgres_host is required when backend is 'pgvector'")
            if not self.postgres_user:
                raise ValueError("postgres_user is required when backend is 'pgvector'")
            if not self.postgres_password or self.postgres_password == "postgres":
                pass  # Allow default password for development
            if self.postgres_port <= 0 or self.postgres_port > 65535:
                raise ValueError("postgres_port must be a valid port number (1-65535)")

        elif self.backend == "qdrant":
            # Validate Qdrant required fields
            if not self.qdrant_host:
                raise ValueError("qdrant_host is required when backend is 'qdrant'")
            if self.qdrant_port <= 0 or self.qdrant_port > 65535:
                raise ValueError("qdrant_port must be a valid port number (1-65535)")

        # Validate OpenAI configuration (required for both backends)
        if not self.openai_api_key or self.openai_api_key == "your_openai_api_key":
            raise ValueError("openai_api_key must be set to a valid OpenAI API key")

        return self

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
        "case_sensitive": False,
        "extra": "ignore",
    }


@functools.lru_cache(maxsize=1)
def get_config() -> Config:
    try:
        return Config()
    except ValidationError as e:
        print(f"Configuration error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error while loading configuration: {e}", file=sys.stderr)
        sys.exit(1)
