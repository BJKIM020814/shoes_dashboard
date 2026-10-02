from __future__ import annotations

from typing import Optional, Literal
from fastapi import APIRouter, Depends, Query, HTTPException
from pydantic import Field
from pydantic import field_validator
from . import firebase
from . import database as db
from .common import Body, encode_id, decode_id, require
from .login import current_admin

router = APIRouter(prefix='/inquiries', tags=['6. 문의관리'], dependencies=[Depends(current_admin)])
_COLS = 'customer_customer_id, head_office_id, c_seq, contact_post, c_date, c_answer, c_answerdate, c_status'


def decorate(row):
    row['id'] = encode_id('inquiry', row['customer_customer_id'], row['head_office_id'], row['c_seq'])
    row['status'] = 'answered' if row['c_status'] == 1 else 'pending'
    # 기존 테이블에 제목 컬럼이 없어 본문의 첫 줄을 제목으로 사용한다.
    row['title'] = (row['contact_post'] or '').split('\n')[0][:100]
    return row


@router.get('')
def inquiries(status: Optional[Literal['pending', 'answered']] = None,
              keyword: Optional[str] = Query(None, max_length=100),
              page: int = Query(1, ge=1), page_size: int = Query(20, ge=1, le=100)):
    clauses, args = ['1=1'], []
    if status:
        clauses.append('c_status=%s')
        args.append(1 if status == 'answered' else 0)
    if keyword:
        clauses.append('(contact_post LIKE %s OR customer_customer_id LIKE %s OR CAST(c_seq AS CHAR) LIKE %s)')
        args.extend(['%' + keyword + '%'] * 3)
    suffix = ' FROM contact WHERE ' + ' AND '.join(clauses)
    result = db.paginate('SELECT ' + _COLS + suffix + ' ORDER BY c_date DESC, customer_customer_id, head_office_id, c_seq', args,
                         'SELECT COUNT(*) n' + suffix, args, page, page_size)
    result['items'] = [decorate(r) for r in result['items']]
    firebase.enrich(result['items'], 'customer_customer_id')
    return result


@router.get('/{inquiry_id}')
def inquiry(inquiry_id: str):
    row = require(db.one('SELECT ' + _COLS + ' FROM contact WHERE customer_customer_id=%s '
                         'AND head_office_id=%s AND c_seq=%s', decode_id(inquiry_id, 'inquiry')))
    firebase.enrich([row], 'customer_customer_id')
    return decorate(row)


class AnswerBody(Body):
    answer: str = Field(min_length=1, max_length=10000)
    # 상세 조회 시 받은 값을 넣어 다른 관리자의 답변을 덮어쓰는 것을 막는다.
    expected_answer: Optional[str] = Field(None, max_length=10000)
    model_config = {'extra': 'forbid', 'str_strip_whitespace': False}

    @field_validator('answer')
    @classmethod
    def nonblank_answer(cls, value):
        value = value.strip()
        if not value:
            raise ValueError('답변 내용을 입력하세요.')
        return value


@router.put('/{inquiry_id}/answer')
def answer(inquiry_id: str, body: AnswerBody, admin=Depends(current_admin)):
    values = decode_id(inquiry_id, 'inquiry')
    with db.connection() as conn, conn.cursor() as cur:
        cur.execute('SELECT c_answer FROM contact WHERE customer_customer_id=%s AND head_office_id=%s AND c_seq=%s FOR UPDATE', values)
        row = require(cur.fetchone())
        if (row['c_answer'] or None) != (body.expected_answer or None):
            raise HTTPException(409, '답변이 변경되었습니다. 상세를 다시 조회한 후 저장하세요.')
        cur.execute('SELECT CHARACTER_MAXIMUM_LENGTH max_length FROM information_schema.COLUMNS '
                    'WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=%s AND COLUMN_NAME=%s', ('contact', 'c_answer'))
        column = cur.fetchone()
        if column and column['max_length'] and len(body.answer) > column['max_length']:
            raise HTTPException(422, f"현재 DB 답변 컬럼은 최대 {column['max_length']}자입니다.")
        cur.execute('UPDATE contact SET c_answer=%s,c_answerdate=NOW(),c_status=1 '
                    'WHERE customer_customer_id=%s AND head_office_id=%s AND c_seq=%s', (body.answer, *values))
        db.audit(cur, admin, 'inquiry.answer', inquiry_id)
        cur.execute('SELECT ' + _COLS + ' FROM contact WHERE customer_customer_id=%s AND head_office_id=%s AND c_seq=%s', values)
        result = decorate(cur.fetchone())
        conn.commit()
    return result
