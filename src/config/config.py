import sys
import functools
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import ValidationError


class Config(BaseSettings):
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        
        # prefer environment variables over .env file
        env_prefix = "MEM0_"
        case_sensitive = False
        
        extra = "ignore"


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
