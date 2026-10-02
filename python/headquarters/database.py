from __future__ import annotations

import logging
from contextlib import contextmanager
import pymysql
from pymysql.cursors import DictCursor
from fastapi import HTTPException
from .config import get_settings

logger = logging.getLogger(__name__)


@contextmanager
def connection():
    s = get_settings()
    if not all((s.db_host or s.db_socket, s.db_user, s.db_name)):
        raise HTTPException(503, 'MySQL 연결 설정이 필요합니다. python/headquarters/.env.example을 확인하세요.')
    conn = None
    try:
        conn = pymysql.connect(host=s.db_host, port=s.db_port, user=s.db_user,
                               password=s.db_password, database=s.db_name,
                               charset='utf8mb4', cursorclass=DictCursor,
                               connect_timeout=5, read_timeout=15, write_timeout=15,
                               unix_socket=s.db_socket or None)
        # 기존 DATETIME은 한국 시각이라는 계약. UTC 저장 DB라면 명시적 변환이 필요하다.
        with conn.cursor() as cur:
            cur.execute("SET time_zone = '+09:00'")
        yield conn
    except pymysql.MySQLError as exc:
        if conn:
            conn.rollback()
        logger.error('MySQL operation failed (code=%s)', exc.args[0])
        raise HTTPException(503, 'MySQL 연결 또는 스키마를 확인하세요. 내부 오류는 응답에 노출하지 않습니다.') from exc
    finally:
        if conn:
            conn.close()


def query(sql, params=()):
    with connection() as conn, conn.cursor() as cur:
        cur.execute(sql, params)
        return list(cur.fetchall())


def one(sql, params=()):
    rows = query(sql, params)
    return rows[0] if rows else None


def paginate(sql, params, count_sql, count_params, page, page_size):
    # SQL의 정렬은 각 호출자가 고정한다. 사용자 입력은 항상 바인딩한다.
    return {'items': query(sql + ' LIMIT %s OFFSET %s', (*params, page_size, (page - 1) * page_size)),
            'total': one(count_sql, count_params)['n'], 'page': page, 'page_size': page_size}


def audit(cur, actor, action, entity_id):
    cur.execute('INSERT INTO hq_audit_log (employee_id, action, entity_id) VALUES (%s,%s,%s)',
                (actor['employee_id'], action, entity_id))
