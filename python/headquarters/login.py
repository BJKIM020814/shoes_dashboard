from __future__ import annotations

from collections import OrderedDict, deque
from threading import Lock
from time import monotonic
import httpx
from firebase_admin.exceptions import FirebaseError
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import Field
from .common import Body
from .config import get_settings
from . import firebase

router = APIRouter(prefix='/auth', tags=['1. 로그인'])
bearer = HTTPBearer(auto_error=False)
_attempts = OrderedDict()
_lock = Lock()


def current_admin(credentials: HTTPAuthorizationCredentials = Depends(bearer)):
    if not credentials or credentials.scheme.lower() != 'bearer':
        raise HTTPException(401, '로그인이 필요합니다.', headers={'WWW-Authenticate': 'Bearer'})
    claims = firebase.verify_token(credentials.credentials)
    staff = firebase.employee(claims['uid'])
    # 화면에서 고른 역할이나 요청 body로 권한을 부여하지 않는다.
    if not staff or staff.get('role') != 'headquarters' or staff.get('active') is not True:
        raise HTTPException(403, '활성 본사 직원 계정만 사용할 수 있습니다.')
    staff_id = staff.get('employeeId')
    office_id = staff.get('headOfficeId')
    if not isinstance(staff_id, (str, int)) or not str(staff_id).strip() or type(office_id) is not int:
        raise HTTPException(403, '직원 ID와 MySQL 본사 ID 매핑을 확인하세요.')
    return {'uid': claims['uid'], 'email': claims.get('email'), 'employee_id': str(staff_id),
            'head_office_id': office_id, 'name': staff.get('name'),
            'position': staff.get('position'), 'department': staff.get('department'), 'role': 'headquarters'}


class LoginBody(Body):
    email: str = Field(min_length=3, max_length=254, pattern=r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
    password: str = Field(min_length=1, max_length=256)
    # 비밀번호의 앞뒤 공백은 유효한 문자이므로 제거하지 않는다.
    model_config = {'extra': 'forbid', 'str_strip_whitespace': False}


def throttle(request):
    ip = request.client.host if request.client else 'unknown'
    now = monotonic()
    with _lock:
        queue = _attempts.setdefault(ip, deque())
        _attempts.move_to_end(ip)
        while queue and queue[0] <= now - 60:
            queue.popleft()
        if len(queue) >= 10:
            raise HTTPException(429, '잠시 후 다시 로그인하세요.', headers={'Retry-After': '60'})
        queue.append(now)
        while len(_attempts) > 10000:
            _attempts.popitem(last=False)


@router.post('/login')
def login(body: LoginBody, request: Request):
    throttle(request)
    s = get_settings()
    if not s.api_key:
        raise HTTPException(503, 'Firebase Web API Key 설정이 필요합니다.')
    try:
        with httpx.Client(timeout=10) as session:
            response = session.post('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword',
                                    params={'key': s.api_key}, json={'email': body.email,
                                    'password': body.password, 'returnSecureToken': True})
    except httpx.HTTPError as exc:
        raise HTTPException(503, 'Firebase 로그인 서버에 연결할 수 없습니다.') from exc
    if response.status_code >= 500:
        raise HTTPException(503, 'Firebase 로그인 서버를 사용할 수 없습니다.')
    if response.status_code != 200:
        raise HTTPException(401, '이메일 또는 비밀번호를 확인하세요.')
    payload = response.json()
    admin = current_admin(HTTPAuthorizationCredentials(scheme='Bearer', credentials=payload['idToken']))
    return {'access_token': payload['idToken'], 'refresh_token': payload['refreshToken'],
            'token_type': 'bearer', 'expires_in': int(payload['expiresIn']), 'admin': admin}


@router.get('/me')
def me(admin=Depends(current_admin)):
    return admin


class RefreshBody(Body):
    refresh_token: str = Field(min_length=1, max_length=4096)


@router.post('/refresh')
def refresh(body: RefreshBody, request: Request):
    throttle(request)
    if not get_settings().api_key:
        raise HTTPException(503, 'Firebase Web API Key 설정이 필요합니다.')
    try:
        response = httpx.post('https://securetoken.googleapis.com/v1/token',
                              params={'key': get_settings().api_key}, timeout=10,
                              data={'grant_type': 'refresh_token', 'refresh_token': body.refresh_token})
    except httpx.HTTPError as exc:
        raise HTTPException(503, 'Firebase 인증 서버에 연결할 수 없습니다.') from exc
    if response.status_code >= 500:
        raise HTTPException(503, 'Firebase 인증 서버를 사용할 수 없습니다.')
    if response.status_code != 200:
        raise HTTPException(401, '로그인을 다시 진행하세요.')
    p = response.json()
    admin = current_admin(HTTPAuthorizationCredentials(scheme='Bearer', credentials=p['id_token']))
    return {'access_token': p['id_token'], 'refresh_token': p['refresh_token'],
            'expires_in': int(p['expires_in']), 'token_type': 'bearer', 'admin': admin}


@router.post('/logout')
def logout(admin=Depends(current_admin)):
    # Firebase UID 전체 세션을 취소한다. 각 요청에서 check_revoked=True로 확인한다.
    from firebase_admin import auth
    from google.api_core.exceptions import GoogleAPICallError
    try:
        auth.revoke_refresh_tokens(admin['uid'], app=firebase.firebase_app())
    except (GoogleAPICallError, FirebaseError) as exc:
        raise HTTPException(503, 'Firebase 세션을 종료할 수 없습니다.') from exc
    return {'logged_out': True, 'scope': 'all_sessions_for_user'}
