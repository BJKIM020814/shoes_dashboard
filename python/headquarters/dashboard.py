from __future__ import annotations

from datetime import timedelta
from fastapi import APIRouter, Depends
from . import database as db
from .common import today
from .login import current_admin
from .sales import report

router = APIRouter(prefix='/dashboard', tags=['2. 대시보드'], dependencies=[Depends(current_admin)])


@router.get('')
def dashboard():
    day = today()
    current = db.one('SELECT COALESCE(SUM(p_price),0) sales, COUNT(*) orders FROM purchase '
                     'WHERE p_date >= %s AND p_date < %s', (day, day + timedelta(days=1)))
    previous = db.one('SELECT COALESCE(SUM(p_price),0) sales, COUNT(*) orders FROM purchase '
                      'WHERE p_date >= %s AND p_date < %s', (day - timedelta(days=1), day))
    totals = db.one('SELECT COALESCE(SUM(p_price),0) sales, COUNT(*) orders FROM purchase')
    pending = db.one('SELECT COUNT(*) n FROM contact WHERE c_status=0')['n']
    members = db.one('SELECT COUNT(*) n FROM customer')['n']
    branches = db.one('SELECT COUNT(*) n FROM authorized_dealer')['n']
    notices = db.query('SELECT head_office_id, authorized_dealer_seq, seq, category, title, content, savedate '
                       'FROM notice ORDER BY savedate DESC, seq DESC LIMIT 5')
    return {'date': day, 'timezone': 'Asia/Seoul', 'currency': 'KRW',
            'summary': {'today_sales': current['sales'], 'today_orders': current['orders'],
                        'sales_growth_percent': round((current['sales'] - previous['sales']) * 100 / previous['sales'], 2) if previous['sales'] else None,
                        'total_sales': totals['sales'], 'total_orders': totals['orders'],
                        'member_count': members, 'dealer_count': branches,
                        'pending_inquiries': pending, 'attention_count': pending,
                        'available_inventory': None, 'ongoing_orders': None},
            'notices': notices,
            'alerts': [{'type': 'pending_inquiries', 'count': pending, 'route': '/inquiries?status=pending'}] if pending else [],
            'sales_chart': report(day - timedelta(days=6), day, 'day', 5)['chart'],
            'limitations': ['재고·진행 주문·재고 부족·결재 요청 수는 기존 DB 코드에서 정확한 매핑을 확인하지 못했습니다.',
                            'attention_count는 미답변 문의 수만 포함합니다. 매출은 환불 차감 전 purchase.p_price 합계입니다.']}
