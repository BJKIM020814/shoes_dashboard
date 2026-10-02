from __future__ import annotations

import argparse
from pathlib import Path
from .database import connection


def main():
    parser = argparse.ArgumentParser(description='검토한 본사 관리 보조 테이블을 생성합니다. 기존 데이터는 수정하지 않습니다.')
    parser.add_argument('--apply', action='store_true', help='MySQL DDL 실행. MySQL DDL은 자동 커밋되므로 롤백할 수 없습니다.')
    args = parser.parse_args()
    sql = (Path(__file__).parent / 'migrations' / '001_admin_metadata.sql').read_text()
    if not args.apply:
        print(sql)
        return
    with connection() as conn, conn.cursor() as cur:
        for statement in sql.split(';'):
            if statement.strip():
                cur.execute(statement)
        conn.commit()
    print('본사 관리 보조 테이블 생성 완료. python -m python.headquarters.check_database로 확인하세요.')


if __name__ == '__main__':
    main()
