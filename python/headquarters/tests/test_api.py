from __future__ import annotations

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from python.headquarters.main import app
from python.headquarters import login
from python.headquarters.common import encode_id
from python.headquarters import database as db, firebase

BASE = '/api/v1/headquarters'


def test_routes_require_authentication():
    with TestClient(app) as c:
        for path in ['/dashboard', '/sales', '/members', '/reviews', '/inquiries', '/ready', '/auth/me']:
            assert c.get(BASE + path).status_code == 401
        assert c.get('/health').json() == {'status': 'ok'}


def test_staff_role_checked_from_verified_uid(monkeypatch):
    monkeypatch.setattr(firebase, 'verify_token', lambda t: {'uid': 'real-uid', 'email': 'admin@example.com'})
    seen = []
    def employee(uid):
        seen.append(uid)
        return {'role': 'store', 'active': True, 'employeeId': 1, 'headOfficeId': 1}
    monkeypatch.setattr(firebase, 'employee', employee)
    with TestClient(app) as c:
        assert c.get(BASE + '/auth/me', headers={'Authorization': 'Bearer token'}).status_code == 403
    assert seen == ['real-uid']


def test_inactive_and_missing_staff_mapping_rejected(monkeypatch):
    monkeypatch.setattr(firebase, 'verify_token', lambda t: {'uid': 'uid'})
    with TestClient(app) as c:
        for staff in [None, {'role': 'headquarters', 'active': False}, {'role': 'headquarters', 'active': True}]:
            monkeypatch.setattr(firebase, 'employee', lambda uid, s=staff: s)
            assert c.get(BASE + '/auth/me', headers={'Authorization': 'Bearer token'}).status_code == 403


@pytest.mark.parametrize('period', ['day', 'week', 'month'])
def test_sales_date_bounds_and_real_mysql_grouping(client, period):
    r = client.get(BASE + '/sales', params={'start_date': '2026-09-30', 'end_date': '2026-10-01', 'period': period})
    assert r.status_code == 200, r.text
    data = r.json()
    assert data['summary']['sales'] == 300
    assert data['summary']['orders'] == 2
    assert sum(item['sales'] for item in data['chart']) == 300
    assert data['top_products'][0]['sales'] == 300
    assert data['branch_sales'] is None


def test_sales_zero_fills_and_validates_period(client):
    r = client.get(BASE + '/sales?start_date=2026-09-29&end_date=2026-10-01')
    assert r.json()['chart'][0]['sales'] == 0
    assert r.json()['summary']['growth_percent'] is None
    assert client.get(BASE + '/sales?start_date=2026-10-02&end_date=2026-10-01').status_code == 422
    assert client.get(BASE + '/sales?period=invalid').status_code == 422


def test_members_search_pagination_grade_and_profile(client):
    r = client.get(BASE + '/members?keyword=김&page_size=1').json()
    assert r['total'] == 1 and r['items'][0]['profile']['name'] == '김민수'
    assert r['items'][0]['purchase_count'] == 3
    r = client.patch(BASE + '/members/grade?customer_id=member@example.com', json={'grade': 'vip'})
    assert r.status_code == 200, r.text
    r = client.get(BASE + '/members?grade=vip').json()
    assert r['total'] == 1 and r['items'][0]['grade'] == 'vip'
    assert client.get(BASE + '/members?page_size=0').status_code == 422
    assert client.get(BASE + '/members/detail?customer_id=missing@example.com').status_code == 404
    assert db.one('SELECT COUNT(*) n FROM hq_audit_log')['n'] == 1


def test_review_moderation_targets_exact_composite_key(client):
    rid = encode_id('review', 'member@example.com', 1, 1)
    r = client.patch(BASE + '/reviews/' + rid + '/status', json={'status': 'hidden', 'reason': '검토'})
    assert r.status_code == 200, r.text
    data = client.get(BASE + '/reviews?status=public').json()
    assert data['total'] == 1 and data['items'][0]['review_seq'] == 2
    assert db.one('SELECT COUNT(*) n FROM review')['n'] == 2
    assert client.get(BASE + '/reviews/invalid').status_code == 422
    missing = encode_id('review', 'member@example.com', 1, 999)
    assert client.patch(BASE + '/reviews/' + missing + '/status', json={'status': 'public'}).status_code == 404


def test_inquiry_exact_key_answer_conflict_and_column_limit(client):
    iid = encode_id('inquiry', 'member@example.com', 1, 1)
    route = BASE + '/inquiries/' + iid + '/answer'
    assert client.put(route, json={'answer': '   '}).status_code == 422
    assert client.put(route, json={'answer': '가' * 46}).status_code == 422
    r = client.put(route, json={'answer': '배송 완료 예정입니다.'})
    assert r.status_code == 200, r.text
    assert r.json()['status'] == 'answered'
    assert client.put(route, json={'answer': '새 답변'}).status_code == 409
    assert client.put(route, json={'answer': '수정 답변', 'expected_answer': '배송 완료 예정입니다.'}).status_code == 200
    other = db.one('SELECT c_status FROM contact WHERE head_office_id=2')
    assert other['c_status'] == 0
    assert db.one('SELECT COUNT(*) n FROM hq_audit_log')['n'] == 2


def test_dashboard_and_readiness(client):
    assert client.get(BASE + '/ready').status_code == 200
    r = client.get(BASE + '/dashboard')
    assert r.status_code == 200, r.text
    assert r.json()['summary']['pending_inquiries'] == 2
    assert r.json()['summary']['available_inventory'] is None


def test_sql_injection_is_bound_as_data(client):
    attack = "' OR 1=1 --"
    assert client.get(BASE + '/members', params={'keyword': attack}).json()['total'] == 0
    assert client.get(BASE + '/inquiries', params={'keyword': attack}).json()['total'] == 0


def test_audit_failure_rolls_back_answer(client, monkeypatch):
    iid = encode_id('inquiry', 'member@example.com', 1, 1)
    def fail(*args):
        raise HTTPException(503, 'audit unavailable')
    monkeypatch.setattr(db, 'audit', fail)
    assert client.put(BASE + '/inquiries/' + iid + '/answer', json={'answer': '답변'}).status_code == 503
    assert db.one('SELECT c_answer FROM contact WHERE head_office_id=1')['c_answer'] is None


def test_login_password_preserved_and_role_checked(monkeypatch):
    from dataclasses import replace
    from python.headquarters.config import get_settings
    from fastapi.security import HTTPAuthorizationCredentials
    monkeypatch.setattr(login, 'get_settings', lambda: replace(get_settings(), api_key='test-key'))
    monkeypatch.setattr(login, 'throttle', lambda request: None)
    captured = {}
    class Response:
        status_code = 200
        def json(self):
            return {'idToken': 'trusted-token', 'refreshToken': 'refresh', 'expiresIn': '3600'}
    class Session:
        def __init__(self, **kw):
            pass
        def __enter__(self):
            return self
        def __exit__(self, *args):
            pass
        def post(self, url, **kw):
            captured.update(kw)
            return Response()
    monkeypatch.setattr(login.httpx, 'Client', Session)
    monkeypatch.setattr(firebase, 'verify_token', lambda token: {'uid': 'admin-uid'})
    monkeypatch.setattr(firebase, 'employee', lambda uid: {'role': 'headquarters', 'active': True,
                                                         'employeeId': 'HQ01', 'headOfficeId': 1})
    with TestClient(app) as c:
        r = c.post(BASE + '/auth/login', json={'email': 'admin@example.com', 'password': ' password '})
        assert r.status_code == 200, r.text
        assert r.json()['expires_in'] == 3600
        assert captured['json']['password'] == ' password '
        monkeypatch.setattr(firebase, 'employee', lambda uid: {'role': 'store', 'active': True})
        assert c.post(BASE + '/auth/login', json={'email': 'admin@example.com', 'password': 'x'}).status_code == 403


def test_refresh_rechecks_staff_and_logout_revokes(monkeypatch):
    from dataclasses import replace
    from python.headquarters.config import get_settings
    from firebase_admin import auth
    monkeypatch.setattr(login, 'get_settings', lambda: replace(get_settings(), api_key='test-key'))
    monkeypatch.setattr(login, 'throttle', lambda request: None)
    monkeypatch.setattr(firebase, 'verify_token', lambda token: {'uid': 'admin-uid'})
    monkeypatch.setattr(firebase, 'employee', lambda uid: {'role': 'headquarters', 'active': True,
                                                         'employeeId': 'HQ01', 'headOfficeId': 1})
    class Response:
        status_code = 200
        def json(self):
            return {'id_token': 'new-token', 'refresh_token': 'new-refresh', 'expires_in': '3600'}
    monkeypatch.setattr(login.httpx, 'post', lambda *args, **kw: Response())
    with TestClient(app) as c:
        assert c.post(BASE + '/auth/refresh', json={'refresh_token': 'old'}).json()['access_token'] == 'new-token'
        revoked = []
        monkeypatch.setattr(firebase, 'firebase_app', lambda: None)
        monkeypatch.setattr(auth, 'revoke_refresh_tokens', lambda uid, **kw: revoked.append(uid))
        assert c.post(BASE + '/auth/logout', headers={'Authorization': 'Bearer token'}).status_code == 200
        assert revoked == ['admin-uid']
        monkeypatch.setattr(firebase, 'employee', lambda uid: None)
        assert c.post(BASE + '/auth/refresh', json={'refresh_token': 'old'}).status_code == 403
