from __future__ import annotations

import json
import sys
from fastapi import HTTPException
from . import database as db
from .config import get_settings

# 첨부 ERD와 기존 python/dashboard_data.py에서 확인한 실행 계약.
REQUIRED = {
    'customer': {'customer_id', 'age', 'totalprice'},
    'purchase': {'customer_customer_id', 'p_code', 'p_price', 'p_date'},
    'product': {'p_code', 'p_name', 'b_name'},
    'review': {'customer_customer_id', 'product_p_code', 'review_seq', 'r_date', 'context', 'r_fit', 'rating', 'likecount'},
    'contact': {'customer_customer_id', 'head_office_id', 'c_seq', 'contact_post', 'c_date', 'c_answer', 'c_answerdate', 'c_status'},
    'authorized_dealer': {'seq'},
    'notice': {'head_office_id', 'authorized_dealer_seq', 'seq', 'category', 'title', 'content', 'savedate'},
    'hq_member_metadata': {'customer_id', 'grade', 'updated_by', 'updated_at'},
    'hq_review_moderation': {'resource_key', 'customer_id', 'product_code', 'review_seq', 'status', 'reason', 'updated_by', 'updated_at'},
    'hq_audit_log': {'id', 'employee_id', 'action', 'entity_id', 'created_at'},
}


def check_mysql():
    rows = db.query('SELECT TABLE_NAME table_name, COLUMN_NAME column_name FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=%s',
                    (get_settings().db_name,))
    found = {}
    for row in rows:
        found.setdefault(row['table_name'], set()).add(row['column_name'])
    missing = {table: sorted(cols - found.get(table, set())) for table, cols in REQUIRED.items() if cols - found.get(table, set())}
    return {'ready': not missing, 'missing_columns': missing, 'checked_tables': sorted(REQUIRED)}


if __name__ == '__main__':
    try:
        result = check_mysql()
        print(json.dumps(result, ensure_ascii=False, indent=2))
        sys.exit(0 if result['ready'] else 1)
    except HTTPException as exc:
        print(json.dumps({'ready': False, 'error': exc.detail}, ensure_ascii=False))
        sys.exit(1)
