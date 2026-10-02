from __future__ import annotations

from functools import lru_cache
import firebase_admin
from firebase_admin import auth, firestore
from firebase_admin.exceptions import FirebaseError
from google.auth.exceptions import DefaultCredentialsError
from google.api_core.exceptions import GoogleAPICallError
from google.cloud.firestore_v1.base_query import FieldFilter
from fastapi import HTTPException
from .config import get_settings


@lru_cache
def firebase_app():
    try:
        return firebase_admin.initialize_app(options={'projectId': get_settings().project_id}, name='headquarters')
    except (DefaultCredentialsError, ValueError) as exc:
        raise HTTPException(503, 'Firebase Admin 인증 설정을 확인하세요.') from exc


@lru_cache
def client():
    try:
        return firestore.client(app=firebase_app(), database_id=get_settings().database_id)
    except (DefaultCredentialsError, ValueError) as exc:
        raise HTTPException(503, 'Firebase Admin 인증 설정을 확인하세요.') from exc


def verify_token(token):
    try:
        return auth.verify_id_token(token, app=firebase_app(), check_revoked=True)
    except (auth.InvalidIdTokenError, auth.ExpiredIdTokenError, auth.RevokedIdTokenError,
            auth.UserDisabledError, ValueError) as exc:
        raise HTTPException(401, '유효한 Firebase ID 토큰이 필요합니다.', headers={'WWW-Authenticate': 'Bearer'}) from exc
    except (DefaultCredentialsError, GoogleAPICallError, FirebaseError) as exc:
        raise HTTPException(503, 'Firebase 인증 서버 연결을 확인하세요.') from exc


def employee(uid):
    try:
        snap = client().collection(get_settings().employee_collection).document(uid).get(timeout=10)
        return snap.to_dict() if snap.exists else None
    except GoogleAPICallError as exc:
        raise HTTPException(503, 'Firebase 직원 정보를 조회할 수 없습니다.') from exc


PROFILE_FIELDS = ('email', 'name', 'phone', 'gender', 'address', 'joinPath', 'joinedAt')


def profiles(emails):
    emails = list(dict.fromkeys(emails))
    if not emails:
        return {}
    if any('/' in email for email in emails):
        raise HTTPException(503, 'account 문서 ID와 customer_id 매핑을 확인하세요.')
    try:
        refs = [client().collection(get_settings().account_collection).document(email) for email in emails]
        return {snap.id: {k: snap.to_dict().get(k) for k in PROFILE_FIELDS}
                for snap in client().get_all(refs, timeout=10) if snap.exists}
    except GoogleAPICallError as exc:
        raise HTTPException(503, 'Firebase 회원 정보를 조회할 수 없습니다.') from exc


def find_emails(prefix):
    """회원명 접두어 검색. 결과를 제한하고 초과 시 검색어를 구체화하도록 안내."""
    if not prefix:
        return []
    try:
        q = client().collection(get_settings().account_collection).where(
            filter=FieldFilter('name', '>=', prefix)).where(
            filter=FieldFilter('name', '<=', prefix + '\uf8ff')).order_by('name').limit(501)
        docs = list(q.stream(timeout=10))
        if len(docs) > 500:
            raise HTTPException(422, '회원명 검색 결과가 많습니다. 검색어를 구체화하세요.')
        return [d.id for d in docs]
    except GoogleAPICallError as exc:
        raise HTTPException(503, 'Firebase 회원명 검색을 수행할 수 없습니다.') from exc


def enrich(rows, email_field):
    data = profiles(row[email_field] for row in rows)
    for row in rows:
        row['profile'] = data.get(row[email_field])
        row['profile_found'] = row['profile'] is not None
    return rows
