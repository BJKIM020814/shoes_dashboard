from __future__ import annotations

import os
from pathlib import Path
from functools import lru_cache
from dataclasses import dataclass
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[2]
load_dotenv(ROOT / '.env')
load_dotenv(ROOT / 'python' / '.env')
load_dotenv(ROOT / 'python' / 'headquarters' / '.env')


@dataclass(frozen=True)
class Settings:
    db_host: str = os.getenv('DB_HOST', '')
    db_port: int = int(os.getenv('DB_PORT', '3306'))
    db_user: str = os.getenv('DB_USER', '')
    db_password: str = os.getenv('DB_PASSWORD', '')
    db_name: str = os.getenv('DB_NAME', '')
    db_socket: str = os.getenv('DB_UNIX_SOCKET', '')
    project_id: str = os.getenv('FIREBASE_PROJECT_ID', 'shoe-20260930')
    database_id: str = os.getenv('FIRESTORE_DATABASE_ID', '(default)')
    api_key: str = os.getenv('FIREBASE_WEB_API_KEY', '')
    account_collection: str = os.getenv('FIREBASE_ACCOUNT_COLLECTION', 'account')
    employee_collection: str = os.getenv('FIREBASE_EMPLOYEE_COLLECTION', 'employee')
    origins: tuple = tuple(x.strip() for x in os.getenv('CORS_ORIGINS', '').split(',') if x.strip())


@lru_cache
def get_settings():
    return Settings()
