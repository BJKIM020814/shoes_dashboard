"""공통 의존성: 매장 식별, 선택적 API 키 검사, Firestore 클라이언트."""
import os
import sys
from functools import lru_cache

from fastapi import Header, HTTPException

# python/ 폴더의 db.py, dashboard_data.py 를 import 하기 위함 (uvicorn 을 다른 위치에서 실행해도 동작)
_PY_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _PY_DIR not in sys.path:
    sys.path.insert(0, _PY_DIR)

import db  # noqa: E402
import dashboard_data as dd  # noqa: E402


def require_api_key(x_api_key: str | None = Header(default=None)):
    """STORE_API_KEY 환경변수가 설정된 경우에만 X-API-Key 헤더를 검사한다."""
    expected = os.getenv("STORE_API_KEY")
    if expected and x_api_key != expected:
        raise HTTPException(401, "API 키가 올바르지 않습니다.")


def get_dealer_or_404(dealer_seq: int):
    dealer = dd.get_dealer(dealer_seq)
    if not dealer:
        raise HTTPException(404, "존재하지 않는 매장입니다.")
    return dealer


@lru_cache
def firestore_client():
    """Firestore 클라이언트. GOOGLE_APPLICATION_CREDENTIALS(서비스 계정 JSON) 필요."""
    from google.cloud import firestore

    return firestore.Client(
        project=os.getenv("FIREBASE_PROJECT_ID", "shoe-20260930"),
        database=os.getenv("FIREBASE_DATABASE_ID", "(default)"),
    )
