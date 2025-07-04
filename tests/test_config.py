#!/usr/bin/env python3
"""
Pytest test suite for Config validation.
"""

import os
import sys
from unittest.mock import patch

import pytest

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "src"))

from pydantic import ValidationError

from src.config.config import Config


class TestConfigValidation:
    """Test suite for Config validation functionality."""

    def test_invalid_backend_validation(self):
        """Test that invalid backend values are rejected."""
        with pytest.raises(ValidationError) as exc_info:
            Config(backend="invalid_backend")

        assert "backend must be one of" in str(exc_info.value)
        assert "invalid_backend" in str(exc_info.value)

    def test_valid_backends(self):
        """Test that valid backend values are accepted."""
        # Test neo4j backend with minimal config
        config_neo4j = Config(backend="neo4j")
        assert config_neo4j.backend == "neo4j"

        # Test qdrant backend with minimal config
        config_qdrant = Config(backend="qdrant")
        assert config_qdrant.backend == "qdrant"

    @patch.dict(
        os.environ,
        {
            "BACKEND": "qdrant",
            "QDRANT_HOST": "my-qdrant-server",
            "QDRANT_PORT": "6333",
            "OPENAI_API_KEY": "sk-real-key",
        },
    )
    def test_environment_variable_override(self):
        """Test that environment variables override default values."""
        config = Config()
        assert config.backend == "qdrant"
        assert config.qdrant_host == "my-qdrant-server"
        assert config.openai_api_key == "sk-real-key"

    def test_config_field_types(self):
        """Test that config fields have correct types."""
        config = Config()
        assert isinstance(config.backend, str)
        assert isinstance(config.qdrant_port, int)
        assert isinstance(config.neo4j_username, str)
        assert isinstance(config.openai_model, str)
