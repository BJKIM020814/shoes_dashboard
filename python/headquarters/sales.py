from __future__ import annotations

from datetime import date, timedelta
from typing import Optional, Literal
from fastapi import APIRouter, Depends, Query
from . import database as db
from .common import dates
from .login import current_admin

router = APIRouter(prefix='/sales', tags=['3. 매출현황'], dependencies=[Depends(current_admin)])


def report(start, end, period, limit):
    start, end, stop = dates(start, end)
    span = (stop - start).days
    summary = db.one('SELECT COALESCE(SUM(p_price),0) sales, COUNT(*) orders FROM purchase '
                     'WHERE p_date >= %s AND p_date < %s', (start, stop))
    previous = db.one('SELECT COALESCE(SUM(p_price),0) sales, COUNT(*) orders FROM purchase '
                      'WHERE p_date >= %s AND p_date < %s', (start - timedelta(days=span), start))
    # SQL 식은 검증된 enum으로만 선택한다. ISO 주는 월요일 시작.
    expressions = {'day': 'DATE(p_date)', 'week': 'DATE_SUB(DATE(p_date), INTERVAL WEEKDAY(p_date) DAY)',
                   'month': "CAST(DATE_FORMAT(p_date, '%%Y-%%m-01') AS DATE)"}
    expr = expressions[period]
    rows = db.query(f'SELECT {expr} bucket, COALESCE(SUM(p_price),0) sales, COUNT(*) orders '
                    'FROM purchase WHERE p_date >= %s AND p_date < %s GROUP BY bucket ORDER BY bucket', (start, stop))
    values = {r['bucket']: r for r in rows}
    cursor = bucket_date(start, period)
    chart = []
    while cursor <= end:
        chart.append(values.get(cursor, {'bucket': cursor, 'sales': 0, 'orders': 0}))
        if period == 'month':
            cursor = date(cursor.year + (cursor.month == 12), cursor.month % 12 + 1, 1)
        else:
            cursor += timedelta(days=7 if period == 'week' else 1)
    products = db.query('SELECT pu.p_code, p.p_name, p.b_name, SUM(pu.p_price) sales, COUNT(*) orders '
                        'FROM purchase pu LEFT JOIN product p ON p.p_code=pu.p_code '
                        'WHERE pu.p_date >= %s AND pu.p_date < %s '
                        'GROUP BY pu.p_code,p.p_name,p.b_name ORDER BY sales DESC, pu.p_code LIMIT %s', (start, stop, limit))
    previous_sales = previous['sales']
    return {'start_date': start, 'end_date': end, 'period': period, 'currency': 'KRW',
            'sales_basis': 'gross_purchase_p_price_no_refund_deduction',
            'summary': {**summary, 'average_order_value': round(summary['sales'] / summary['orders'], 2) if summary['orders'] else 0,
                        'previous_sales': previous_sales,
                        'growth_percent': round((summary['sales'] - previous_sales) * 100 / previous_sales, 2) if previous_sales else None},
            'chart': chart, 'top_products': products,
            'branch_sales': None, 'limitations': ['purchase에 대리점 FK가 없어 매장별 매출을 계산할 수 없습니다.',
                                                'p_price는 행별 결제금액으로 집계합니다. 환불 차감과 결제번호별 주문 수는 별도 스키마가 필요합니다.']}


def bucket_date(value, period):
    if period == 'week':
        return value - timedelta(days=value.weekday())
    if period == 'month':
        return value.replace(day=1)
    return value


@router.get('')
def sales(start_date: Optional[date] = None, end_date: Optional[date] = None,
          period: Literal['day', 'week', 'month'] = 'day', top_limit: int = Query(10, ge=1, le=100)):
    return report(start_date, end_date, period, top_limit)
