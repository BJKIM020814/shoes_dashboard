from __future__ import annotations

from typing import Optional, Literal
from fastapi import APIRouter, Depends, Query
from . import firebase
from . import database as db
from .common import Body, require
from .login import current_admin

router = APIRouter(prefix='/members', tags=['4. 회원관리'], dependencies=[Depends(current_admin)])
_BASE = (' FROM customer c LEFT JOIN hq_member_metadata m ON BINARY m.customer_id=BINARY c.customer_id '
         'LEFT JOIN (SELECT customer_customer_id, COUNT(*) purchase_count, MAX(p_date) last_purchase_at '
         'FROM purchase GROUP BY customer_customer_id) pu ON pu.customer_customer_id=c.customer_id ')
_COLS = ("c.customer_id, c.age, c.totalprice, COALESCE(m.grade,'general') grade, "
         'COALESCE(pu.purchase_count,0) purchase_count, pu.last_purchase_at')


@router.get('')
def members(keyword: Optional[str] = Query(None, max_length=100), grade: Optional[Literal['general', 'vip']] = None,
            page: int = Query(1, ge=1), page_size: int = Query(20, ge=1, le=100)):
    where, args = ['1=1'], []
    if keyword:
        emails = firebase.find_emails(keyword)
        clause = 'c.customer_id LIKE %s'
        args.append('%' + keyword + '%')
        if emails:
            clause += ' OR c.customer_id IN (' + ','.join(['%s'] * len(emails)) + ')'
            args.extend(emails)
        where.append('(' + clause + ')')
    if grade:
        where.append("COALESCE(m.grade,'general')=%s")
        args.append(grade)
    suffix = _BASE + ' WHERE ' + ' AND '.join(where)
    result = db.paginate('SELECT ' + _COLS + suffix + ' ORDER BY c.customer_id', args,
                         'SELECT COUNT(*) n' + suffix, args, page, page_size)
    firebase.enrich(result['items'], 'customer_id')
    return result


@router.get('/detail')
def member(customer_id: str = Query(min_length=1, max_length=254)):
    row = require(db.one('SELECT ' + _COLS + _BASE + ' WHERE c.customer_id=%s', (customer_id,)))
    firebase.enrich([row], 'customer_id')
    row['recent_purchases'] = db.query('SELECT pu.p_code, p.p_name, pu.p_price, pu.p_date FROM purchase pu '
                                      'LEFT JOIN product p ON p.p_code=pu.p_code WHERE pu.customer_customer_id=%s '
                                      'ORDER BY pu.p_date DESC LIMIT 10', (customer_id,))
    return row


class GradeBody(Body):
    grade: Literal['general', 'vip']


@router.patch('/grade')
def update_grade(body: GradeBody, customer_id: str = Query(min_length=1, max_length=254), admin=Depends(current_admin)):
    with db.connection() as conn, conn.cursor() as cur:
        cur.execute('SELECT customer_id FROM customer WHERE customer_id=%s FOR UPDATE', (customer_id,))
        require(cur.fetchone())
        cur.execute('INSERT INTO hq_member_metadata (customer_id,grade,updated_by) VALUES (%s,%s,%s) '
                    'ON DUPLICATE KEY UPDATE grade=VALUES(grade),updated_by=VALUES(updated_by),updated_at=CURRENT_TIMESTAMP',
                    (customer_id, body.grade, admin['employee_id']))
        db.audit(cur, admin, 'member.grade.' + body.grade, customer_id)
        conn.commit()
    return {'customer_id': customer_id, 'grade': body.grade}
