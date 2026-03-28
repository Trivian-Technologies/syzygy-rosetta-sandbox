"""
Syzygy Rosetta Sandbox — Configuration Management

Handles environment variables and settings for GCP deployment.
"""

import os
from pathlib import Path
from typing import Optional
from pydantic_settings import BaseSettings
from pydantic import Field, field_validator

# Load .env file if it exists
from dotenv import load_dotenv

# Ensure .env is loaded from repository root regardless of current working directory.
_REPO_ROOT = Path(__file__).resolve().parent.parent
_ENV_PATH = _REPO_ROOT / ".env"
load_dotenv(_ENV_PATH)


class Settings(BaseSettings):
    """Application settings loaded from environment variables"""
    
    # LLM Configuration
    llm_provider: str = Field(default="gemini", description="LLM provider: gemini, mock")
    gemini_api_key: Optional[str] = Field(default=None, alias="GEMINI_API_KEY")
    gemini_model: str = Field(default="mock", alias="GEMINI_MODEL")
    gemini_project_id: Optional[str] = Field(default=None, alias="GCP_PROJECT_ID")
    gemini_location: str = Field(default="us-central1", alias="GCP_LOCATION")
    
    # Rosetta Configuration
    rosetta_url: str = Field(default="http://localhost:8000", alias="ROSETTA_URL")
    
    # Application Settings
    environment: str = Field(default="development", alias="ENVIRONMENT")
    log_level: str = Field(default="INFO", alias="LOG_LEVEL")
    
    # Paths
    logs_dir: Path = Field(default=Path(__file__).parent.parent / "logs")
    results_dir: Path = Field(default=Path(__file__).parent / "results")
    
    class Config:
        env_file = str(_ENV_PATH)
        env_file_encoding = "utf-8"
        extra = "ignore"

    @field_validator("gemini_api_key", mode="before")
    @classmethod
    def strip_gemini_api_key(cls, v: Optional[str]) -> Optional[str]:
        """Secret Manager / shell often adds trailing newlines; gRPC then fails with Illegal metadata."""
        if v is None:
            return None
        if isinstance(v, str):
            s = v.strip()
            return s if s else None
        return v

    def is_production(self) -> bool:
        return self.environment == "production"
    
    def use_real_llm(self) -> bool:
        return self.llm_provider != "mock" and self.gemini_api_key is not None


# Global settings instance
settings = Settings()
