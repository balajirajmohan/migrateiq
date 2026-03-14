import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv

env_path = Path(__file__).resolve().parent.parent / ".env"
load_dotenv(dotenv_path=env_path)


def _require(key: str) -> str:
    value = os.getenv(key)
    if not value:
        raise EnvironmentError(f"Missing required environment variable: {key}")
    return value


@dataclass(frozen=True)
class AWSConfig:
    profile: str = os.getenv("AWS_PROFILE", "presidio-devops")
    region: str = os.getenv("AWS_REGION", "us-east-1")


@dataclass(frozen=True)
class DatabaseConfig:
    host: str
    port: int
    name: str
    user: str
    password: str


@dataclass(frozen=True)
class Settings:
    aws: AWSConfig
    source_db: DatabaseConfig
    target_db: DatabaseConfig
    s3_bucket: str
    dynamodb_state_table: str
    dynamodb_kb_table: str
    sns_topic_arn: str
    bedrock_model_id: str
    bedrock_region: str


def load_settings() -> Settings:
    return Settings(
        aws=AWSConfig(),
        source_db=DatabaseConfig(
            host=_require("SOURCE_DB_HOST"),
            port=int(os.getenv("SOURCE_DB_PORT", "3306")),
            name=_require("SOURCE_DB_NAME"),
            user=_require("SOURCE_DB_USER"),
            password=_require("SOURCE_DB_PASSWORD"),
        ),
        target_db=DatabaseConfig(
            host=_require("TARGET_DB_HOST"),
            port=int(os.getenv("TARGET_DB_PORT", "5432")),
            name=_require("TARGET_DB_NAME"),
            user=_require("TARGET_DB_USER"),
            password=_require("TARGET_DB_PASSWORD"),
        ),
        s3_bucket=_require("S3_BUCKET_NAME"),
        dynamodb_state_table=_require("DYNAMODB_STATE_TABLE"),
        dynamodb_kb_table=_require("DYNAMODB_KB_TABLE"),
        sns_topic_arn=_require("SNS_TOPIC_ARN"),
        bedrock_model_id=os.getenv(
            "BEDROCK_MODEL_ID", "anthropic.claude-sonnet-4-20250514-v1:0"
        ),
        bedrock_region=os.getenv("BEDROCK_REGION", "us-east-1"),
    )
