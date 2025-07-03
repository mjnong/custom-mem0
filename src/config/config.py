import sys
import functools
from dotenv import load_dotenv
from enum import StrEnum
from pydantic_settings import BaseSettings
from pydantic import ValidationError, field_validator, model_validator
from typing_extensions import Self

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
    backend: str = "neo4j"  # Options: "neo4j",
    # "qdrant"
    qdrant_host: str = "localhost"
    qdrant_port: int = 6333
    qdrant_api_key: str = ""
    
    # Neo4j configuration
    neo4j_ip: str = "localhost"
    neo4j_username: str = "neo4j"
    neo4j_password: str = "password"
    neo4j_database: str = "memory"
    
    # FastAPI configuration
    fastapi_host: str = "localhost"  # e.g., "localhost" or "0.0.0"
    fastapi_port: int = 8000  # Default
    memory_log_level: LogLevel = LogLevel.INFO  # Default log level for FastAPI

    # OpenAI configuration
    openai_api_key: str = "your_openai_api_key"
    openai_model: str = "gpt-4o-mini"
    openai_embedding_model: str = "text-embedding-3-small"

    @field_validator('memory_log_level', mode='before')
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
            raise ValueError(f"memory_log_level must be one of {valid_levels}, got '{v}'")
        raise ValueError(f"memory_log_level must be a string or LogLevel enum, got {type(v)}")

    @field_validator('backend')
    @classmethod
    def validate_backend(cls, v: str) -> str:
        allowed_backends = {"neo4j", "qdrant"}
        if v not in allowed_backends:
            raise ValueError(f"backend must be one of {allowed_backends}, got '{v}'")
        return v

    @model_validator(mode='after')
    def validate_backend_dependencies(self) -> Self:
        # Skip validation if using default/development values
        skip_validation = (
            (self.neo4j_password == "password" or self.neo4j_password == "") and 
            (self.openai_api_key == "your_openai_api_key" or self.openai_api_key == "")
        )
        
        if skip_validation:
            return self
            
        if self.backend == "neo4j":
            # Validate Neo4j required fields
            if not self.neo4j_ip or self.neo4j_ip == "localhost":
                pass  # localhost is acceptable for development
            if not self.neo4j_username:
                raise ValueError("neo4j_username is required when backend is 'neo4j'")
            if not self.neo4j_password: # TODO: Include this `or self.neo4j_password == "password":`
                raise ValueError("neo4j_password must be set to a secure value when backend is 'neo4j'")
            if not self.neo4j_database:
                raise ValueError("neo4j_database is required when backend is 'neo4j'")
                
        elif self.backend == "qdrant":
            # Validate Qdrant required fields
            if not self.qdrant_host or self.qdrant_host == "localhost":
                pass  # localhost is acceptable for development
            if self.qdrant_port <= 0 or self.qdrant_port > 65535:
                raise ValueError("qdrant_port must be a valid port number (1-65535)")
            # qdrant_api_key is optional for local development but recommended for production
            
        # Validate OpenAI configuration (required for both backends)
        if not self.openai_api_key or self.openai_api_key == "your_openai_api_key":
            raise ValueError("openai_api_key must be set to a valid OpenAI API key")
            
        return self

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
        "case_sensitive": False,
        "extra": "ignore"
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
