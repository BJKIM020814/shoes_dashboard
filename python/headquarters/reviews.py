from __future__ import annotations

from typing import Optional, Literal
from fastapi import APIRouter, Depends, Query
from pydantic import Field
from . import firebase
from . import database as db
from .common import Body, encode_id, decode_id, key, require
from .login import current_admin

router = APIRouter(prefix='/reviews', tags=['5. 리뷰관리'], dependencies=[Depends(current_admin)])
_BASE = (' FROM review r LEFT JOIN product p ON p.p_code=r.product_p_code '
         'LEFT JOIN hq_review_moderation m ON BINARY m.customer_id=BINARY r.customer_customer_id '
         'AND BINARY m.product_code=BINARY CAST(r.product_p_code AS CHAR) AND m.review_seq=r.review_seq ')
_COLS = ("r.customer_customer_id, r.product_p_code, r.review_seq, r.r_date, r.context, r.r_fit, "
         "r.rating, r.likecount, p.p_name, p.b_name, COALESCE(m.status,'public') status, m.reason")


def decorate(row):
    row['id'] = encode_id('review', row['customer_customer_id'], row['product_p_code'], row['review_seq'])
    return row


@router.get('')
def reviews(status: Optional[Literal['public', 'reported', 'hidden']] = None,
            keyword: Optional[str] = Query(None, max_length=100),
            page: int = Query(1, ge=1), page_size: int = Query(20, ge=1, le=100)):
    clauses, args = ['1=1'], []
    if status:
        clauses.append("COALESCE(m.status,'public')=%s")
        args.append(status)
    if keyword:
        emails = firebase.find_emails(keyword)
        clause = '(r.customer_customer_id LIKE %s OR p.p_name LIKE %s OR r.context LIKE %s'
        args.extend(['%' + keyword + '%'] * 3)
        if emails:
            clause += ' OR r.customer_customer_id IN (' + ','.join(['%s'] * len(emails)) + ')'
            args.extend(emails)
        clauses.append(clause + ')')
    suffix = _BASE + ' WHERE ' + ' AND '.join(clauses)
    result = db.paginate('SELECT ' + _COLS + suffix + ' ORDER BY r.r_date DESC, r.customer_customer_id, r.product_p_code, r.review_seq', args,
                         'SELECT COUNT(*) n' + suffix, args, page, page_size)
    result['items'] = [decorate(r) for r in result['items']]
    firebase.enrich(result['items'], 'customer_customer_id')
    return result


@router.get('/{review_id}')
def review(review_id: str):
    values = decode_id(review_id, 'review')
    row = require(db.one('SELECT ' + _COLS + _BASE + ' WHERE r.customer_customer_id=%s '
                         'AND r.product_p_code=%s AND r.review_seq=%s', values))
    firebase.enrich([row], 'customer_customer_id')
    return decorate(row)


class ModerationBody(Body):
    status: Literal['public', 'reported', 'hidden']
    reason: Optional[str] = Field(None, max_length=1000)


@router.patch('/{review_id}/status')
def moderate(review_id: str, body: ModerationBody, admin=Depends(current_admin)):
    values = decode_id(review_id, 'review')
    with db.connection() as conn, conn.cursor() as cur:
        cur.execute('SELECT review_seq FROM review WHERE customer_customer_id=%s '
                    'AND product_p_code=%s AND review_seq=%s FOR UPDATE', values)
        require(cur.fetchone())
        cur.execute('INSERT INTO hq_review_moderation (resource_key,customer_id,product_code,review_seq,status,reason,updated_by) '
                    'VALUES (%s,%s,%s,%s,%s,%s,%s) ON DUPLICATE KEY UPDATE status=VALUES(status),reason=VALUES(reason),'
                    'updated_by=VALUES(updated_by),updated_at=CURRENT_TIMESTAMP',
                    (key(review_id), values[0], str(values[1]), values[2], body.status, body.reason, admin['employee_id']))
        db.audit(cur, admin, 'review.' + body.status, review_id)
        conn.commit()
    return {'id': review_id, 'status': body.status, 'reason': body.reason}
