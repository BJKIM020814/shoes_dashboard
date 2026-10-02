from __future__ import annotations

from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from . import dashboard, inquiries, login, members, reviews
from .config import get_settings
from . import sales

app = FastAPI(title='FITPICK 본사 관리자 API', version='1.0.0',
              description='Firebase 직원 인증 + MySQL 운영 데이터. SQLite는 Flutter 단말의 로컬 데이터 전용입니다.')
app.add_middleware(CORSMiddleware, allow_origins=list(get_settings().origins),
                   allow_credentials=False, allow_methods=['GET', 'POST', 'PUT', 'PATCH'],
                   allow_headers=['Authorization', 'Content-Type'])

for module in (login, dashboard, sales, members, reviews, inquiries):
    app.include_router(module.router, prefix='/api/v1/headquarters')


@app.get('/health', tags=['운영'])
def health():
    """프로세스 생존 확인. DB 준비 상태는 인증된 /ready에서 검사."""
    return {'status': 'ok'}


@app.get('/api/v1/headquarters/ready', tags=['운영'])
def ready(admin=Depends(login.current_admin)):
    from .check_database import check_mysql
    from fastapi import HTTPException
    report = check_mysql()
    if not report['ready']:
        raise HTTPException(503, detail=report)
    return {'status': 'ready', 'mysql': report, 'firebase': 'employee_lookup_succeeded'}
