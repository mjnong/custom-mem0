"""Configuration management for mem0."""

from .config import Config, get_config

# Provide a convenient singleton instance
config = get_config()

__all__ = ["Config", "get_config", "config"]