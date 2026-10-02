"""MySQL 연결 공통 모듈 (pymysql) - shoes_dashboard 용

접속 정보는 .env 에서 읽는다. (코드에 직접 작성 금지, .env 는 .gitignore 대상)
찾는 순서: shoes_dashboard/.env -> ../Bootcamp_TeamProject_1/.env (같은 DB 를 쓰는 팀 프로젝트 설정)
모든 쿼리는 %s 파라미터 바인딩으로 실행해 SQL Injection을 막는다.
"""
import os
from contextlib import contextmanager

import pymysql
from dotenv import load_dotenv
from pymysql.cursors import DictCursor

_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
for _env in (
    os.path.join(_ROOT, ".env"),
    os.path.join(os.path.dirname(_ROOT), "Bootcamp_TeamProject_1", ".env"),
):
    if os.path.exists(_env):
        load_dotenv(_env)
        break


class DBError(Exception):
    """DB 연결/쿼리 실패 시 던지는 공통 예외"""


def get_connection():
    """새 MySQL 연결을 열어 반환한다. 사용 후 close() 필요."""
    try:
        return pymysql.connect(
            host=os.getenv("DB_HOST"),
            port=int(os.getenv("DB_PORT", "3306")),
            user=os.getenv("DB_USER"),
            password=os.getenv("DB_PASSWORD"),
            database=os.getenv("DB_NAME"),
            charset="utf8mb4",
            cursorclass=DictCursor,
            connect_timeout=5,
        )
    except (pymysql.MySQLError, ValueError) as e:
        raise DBError(f"DB 연결 실패: {e}") from e


@contextmanager
def connection():
    """with 문으로 연결을 쓰면 자동으로 닫힌다."""
    conn = get_connection()
    try:
        yield conn
    finally:
        conn.close()


def query(sql, params=None):
    """조회용(SELECT). 결과 전체를 list[dict]로 반환."""
    with connection() as conn:
        try:
            with conn.cursor() as cur:
                cur.execute(sql, params)
                return cur.fetchall()
        except pymysql.MySQLError as e:
            raise DBError(f"쿼리 실패: {e}") from e


def query_one(sql, params=None):
    """조회용(SELECT). 첫 행만 dict로 반환, 없으면 None."""
    rows = query(sql, params)
    return rows[0] if rows else None


def execute(sql, params=None):
    """변경용(INSERT/UPDATE/DELETE). 성공 시 커밋, 실패 시 롤백. 영향받은 행 수 반환."""
    with connection() as conn:
        try:
            with conn.cursor() as cur:
                affected = cur.execute(sql, params)
            conn.commit()
            return affected
        except pymysql.MySQLError as e:
            conn.rollback()
            raise DBError(f"쿼리 실패: {e}") from e
