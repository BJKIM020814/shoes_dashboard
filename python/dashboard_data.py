"""shoes_dashboard(본사/대리점 관리자 UI) 용 MySQL 데이터 접근 함수

이 폴더(shoes_dashboard/python)만으로 동작한다. 기존 Flutter/Python 코드는 수정하지 않았다.
Firebase 는 연결하지 않는다. 아래는 Firebase 와 데이터가 겹치지 않도록 정한 역할 분담이다.

[MySQL 에서 가져오는 것 - 이 파일이 다룸]
  customer(id/나이/누적결제)  purchase  review  contact(문의)  product
  authorized_dealer  pickup  p_return  `return`  notice
  model  contract  contraction  termination

[Firebase 가 관리하는 것 - 여기서 읽지도 쓰지도 않음]
  account            회원 이메일/비밀번호/이름/전화/성별/주소/가입경로
  employee           직원 정보(직급/부서/사업자번호). MySQL head_office 는 FK 용 id 로만 쓰고 직급/부서는 읽지 않음
  manufactor         제조사
  quotation / order / recieve    견적서 / 발주 / 수주  (결재 관리, 발주 관리 화면)
  office_inventory / distributor_inventory / registration / send   재고 수량 (재고 관리 화면)
  connect / change / resister    접속/변경/등록 이력

[두 저장소를 잇는 키]
  customer.customer_id = Firebase account.email
  product.p_code       = Firebase 재고 문서의 productId  (재고 목록에 상품명/가격을 붙일 때 get_products_by_codes 사용)
  authorized_dealer.name = Firebase 재고/발송 문서의 branchName (get_dealers_by_branches 사용)
  pickup/p_return/return.staff_id = Firebase employee.employeeId

[화면 -> 함수]
  본사 대시보드   get_hq_summary, get_recent_notices
  매출 현황       get_sales_by_day, get_sales_by_product
  회원 관리       get_members            (이름/연락처는 Firebase account 에서 이메일로 조회)
  리뷰 관리       get_reviews_all, delete_review
  문의 관리       get_inquiries, answer_inquiry
  주문 관리       get_orders
  대리점 관리     get_dealers, get_dealer, get_dealers_by_branches
  계약 관리       get_contracts, get_terminations, get_models
  대리점 주문/수령/반품/공지/정보   get_store_pickups, get_store_returns, get_store_notices, get_dealer
  재고/결재/발주  Firebase 전용 (MySQL 에는 해당 테이블 없음. 상품명은 get_products_by_codes 로 보강)

[MySQL 에 없어서 비워 둔 것]
  - 주문 상태 중 '배송완료': 해당 컬럼/테이블이 없음. (배송중/수령완료/반납완료만 판단)
  - 매장별 매출: purchase 에 대리점 컬럼이 없음.
  - 회원 등급: grade 컬럼이 없음. totalprice 만 제공.
모든 쿼리는 db.py 의 파라미터 바인딩(%s)을 사용한다. `return` 은 MySQL 예약어라 백틱으로 감싼다.
"""
import db

# 주문 상태: 같은 회원의 반품(p_return)이 있으면 반납완료, 수령(pickup)이 있으면 수령완료, 아니면 배송중.
# pickup 은 회원별 최신 1건만 한 번 조인해서 수령 대리점명과 상태 판단에 같이 쓴다. (MySQL 8 윈도우 함수)
_ORDER_STATUS_SQL = """
CASE
  WHEN EXISTS (SELECT 1 FROM p_return r
               WHERE r.customer_customer_id = pu.customer_customer_id AND r.p_id = pu.p_code) THEN '반납완료'
  WHEN lp.customer_id IS NOT NULL THEN '수령완료'
  ELSE '배송중'
END
"""
_LATEST_PICKUP_SQL = """
LEFT JOIN (
  SELECT x.customer_id, d.name AS dealer_name FROM (
    SELECT k.customer_customer_id AS customer_id, k.authorized_dealer_seq,
           ROW_NUMBER() OVER (PARTITION BY k.customer_customer_id ORDER BY k.pickup_date DESC) AS rn
    FROM pickup k
  ) x JOIN authorized_dealer d ON d.seq = x.authorized_dealer_seq WHERE x.rn = 1
) lp ON lp.customer_id = pu.customer_customer_id
"""


# ---------- 대리점(지점) / 상품 조회 ----------
_DEALER_COLS = "seq, name, dealer_number, manager, address, lat, lng"


def get_dealers():
    """대리점 전체 목록 (대리점 관리, 매장 정보)."""
    return db.query(f"SELECT {_DEALER_COLS} FROM authorized_dealer ORDER BY seq")


def get_dealer(seq):
    """대리점 1곳 조회 (없으면 None)."""
    return db.query_one(f"SELECT {_DEALER_COLS} FROM authorized_dealer WHERE seq = %s", (seq,))


def get_dealers_by_branches(branch_names):
    """Firebase 지점명(branchName) 여러 개로 한 번에 조회. {지점명: 대리점정보}. 같은 이름이면 seq 작은 쪽."""
    branch_names = list(dict.fromkeys(branch_names))
    if not branch_names:
        return {}
    marks = ", ".join(["%s"] * len(branch_names))
    rows = db.query(
        f"SELECT {_DEALER_COLS} FROM authorized_dealer WHERE name IN ({marks}) ORDER BY seq",
        branch_names,
    )
    result = {}
    for row in rows:
        result.setdefault(row["name"], row)
    return result


def get_products_by_codes(p_codes):
    """Firebase 재고의 productId(=p_code) 목록으로 상품 정보 조회. {p_code: 상품정보}. 이미지(blob) 제외."""
    p_codes = list(dict.fromkeys(p_codes))
    if not p_codes:
        return {}
    marks = ", ".join(["%s"] * len(p_codes))
    rows = db.query(
        "SELECT p_code, p_name, b_name, p_price, p_sku, p_gender, p_size, p_color "
        f"FROM product WHERE p_code IN ({marks})",
        p_codes,
    )
    return {row["p_code"]: row for row in rows}


# ---------- 본사: 대시보드 / 매출 ----------
def get_hq_summary():
    """대시보드 카드용 요약. 오늘 매출/오늘 주문/누적 매출/미답변 문의/대리점 수."""
    today = db.query_one(
        "SELECT COALESCE(SUM(p_price), 0) AS sales, COUNT(*) AS orders "
        "FROM purchase WHERE DATE(p_date) = CURDATE()"
    )
    total = db.query_one("SELECT COALESCE(SUM(p_price), 0) AS sales, COUNT(*) AS orders FROM purchase")
    pending = db.query_one("SELECT COUNT(*) AS n FROM contact WHERE c_status = 0")
    dealers = db.query_one("SELECT COUNT(*) AS n FROM authorized_dealer")
    return {
        "today_sales": int(today["sales"]),
        "today_orders": today["orders"],
        "total_sales": int(total["sales"]),
        "total_orders": total["orders"],
        "pending_inquiries": pending["n"],
        "dealer_count": dealers["n"],
    }


def get_recent_notices(limit=5):
    """본사/대리점 공지 최신순 (대시보드 '운영 현황')."""
    return db.query(
        "SELECT head_office_id, authorized_dealer_seq, seq, category, title, content, savedate "
        "FROM notice ORDER BY savedate DESC LIMIT %s",
        (limit,),
    )


def get_sales_by_day(days=30):
    """최근 N일 일별 매출/주문 수 (매출 현황 차트)."""
    return db.query(
        "SELECT DATE(p_date) AS day, SUM(p_price) AS sales, COUNT(*) AS orders "
        "FROM purchase WHERE p_date >= DATE_SUB(CURDATE(), INTERVAL %s DAY) "
        "GROUP BY DATE(p_date) ORDER BY day",
        (days,),
    )


def get_sales_by_product(limit=10):
    """상품별 매출 상위 N개."""
    return db.query(
        "SELECT pu.p_code, p.p_name, p.b_name, SUM(pu.p_price) AS sales, COUNT(*) AS orders "
        "FROM purchase pu LEFT JOIN product p ON p.p_code = pu.p_code "
        "GROUP BY pu.p_code, p.p_name, p.b_name ORDER BY sales DESC LIMIT %s",
        (limit,),
    )


# ---------- 본사: 회원 / 리뷰 / 문의 ----------
def get_members(keyword=None, limit=50, offset=0):
    """회원 목록(MySQL 쪽 정보만: id/나이/누적결제/구매 수). 이름·연락처는 Firebase account 에서 이메일로 조회."""
    sql = (
        "SELECT c.customer_id, c.age, c.totalprice, COUNT(pu.p_code) AS purchase_count "
        "FROM customer c LEFT JOIN purchase pu ON pu.customer_customer_id = c.customer_id WHERE 1=1"
    )
    params = []
    if keyword:
        sql += " AND c.customer_id LIKE %s"
        params.append(f"%{keyword}%")
    sql += " GROUP BY c.customer_id, c.age, c.totalprice ORDER BY c.customer_id LIMIT %s OFFSET %s"
    params += [limit, offset]
    return db.query(sql, params)


def get_reviews_all(limit=50, offset=0):
    """전체 리뷰 (최신순) + 상품명. 이미지(blob)는 제외."""
    return db.query(
        "SELECT r.customer_customer_id, r.product_p_code, r.review_seq, r.r_date, r.context, "
        "r.r_fit, r.rating, r.likecount, p.p_name, p.b_name "
        "FROM review r LEFT JOIN product p ON p.p_code = r.product_p_code "
        "ORDER BY r.r_date DESC LIMIT %s OFFSET %s",
        (limit, offset),
    )


def delete_review(customer_id, p_code):
    """부적절한 리뷰 삭제 (관리자)."""
    return db.execute(
        "DELETE FROM review WHERE customer_customer_id = %s AND product_p_code = %s",
        (customer_id, p_code),
    )


def get_inquiries(answered=None, limit=50, offset=0):
    """문의 목록. answered: True=답변완료, False=미답변, None=전체. (c_status 1 = 답변완료)"""
    sql = (
        "SELECT customer_customer_id, head_office_id, c_seq, contact_post, c_date, "
        "c_answer, c_answerdate, c_status FROM contact WHERE 1=1"
    )
    params = []
    if answered is not None:
        sql += " AND c_status = %s"
        params.append(1 if answered else 0)
    sql += " ORDER BY c_date DESC LIMIT %s OFFSET %s"
    params += [limit, offset]
    return db.query(sql, params)


def answer_inquiry(customer_id, head_office_id, c_seq, answer):
    """문의 답변 등록 (답변 내용/시각 저장 + 답변완료 처리)."""
    return db.execute(
        "UPDATE contact SET c_answer = %s, c_answerdate = NOW(), c_status = 1 "
        "WHERE customer_customer_id = %s AND head_office_id = %s AND c_seq = %s",
        (answer, customer_id, head_office_id, c_seq),
    )


# ---------- 본사/대리점: 주문 ----------
def get_orders(status=None, limit=50, offset=0):
    """주문 목록 (최신순). status: '배송중' | '수령완료' | '반납완료' | None(전체).

    purchase 에는 주문번호/대리점 컬럼이 없어 (회원, 본사id) 가 키이고, 수령 대리점은 같은 회원의 pickup 에서 찾는다.
    """
    sql = (
        "SELECT * FROM ("
        "SELECT pu.customer_customer_id AS customer_id, pu.head_office_id, pu.p_code, "
        "p.p_name, p.b_name, pu.p_date, pu.p_price, "
        "lp.dealer_name, "
        f"{_ORDER_STATUS_SQL} AS status "
        "FROM purchase pu LEFT JOIN product p ON p.p_code = pu.p_code "
        f"{_LATEST_PICKUP_SQL}"
        ") t WHERE 1=1"
    )
    params = []
    if status:
        sql += " AND status = %s"
        params.append(status)
    sql += " ORDER BY p_date DESC LIMIT %s OFFSET %s"
    params += [limit, offset]
    return db.query(sql, params)


# ---------- 본사: 계약 ----------
def get_models(limit=50, offset=0):
    """모델(광고 모델) 목록. 이미지(blob) 제외."""
    return db.query(
        "SELECT id, name, management, phone FROM model ORDER BY id LIMIT %s OFFSET %s",
        (limit, offset),
    )


def get_contracts(limit=50, offset=0):
    """모델 계약 목록 (계약기간/금액/옵션 포함)."""
    return db.query(
        "SELECT ct.head_office_id, ct.model_id, m.name AS model_name, ct.contraction_c_seq, "
        "ct.c_date, c.start_date, c.end_date, c.contraction_fee, c.c_option "
        "FROM contract ct "
        "JOIN contraction c ON c.c_seq = ct.contraction_c_seq "
        "LEFT JOIN model m ON m.id = ct.model_id "
        "ORDER BY ct.c_date DESC LIMIT %s OFFSET %s",
        (limit, offset),
    )


def get_terminations(limit=50, offset=0):
    """계약 해지 내역."""
    return db.query(
        "SELECT t.head_office_id, t.model_id, m.name AS model_name, t.t_seq, t.t_date, t.termination_fee "
        "FROM termination t LEFT JOIN model m ON m.id = t.model_id "
        "ORDER BY t.t_date DESC LIMIT %s OFFSET %s",
        (limit, offset),
    )


# ---------- 대리점(매장) 화면 ----------
def get_store_pickups(dealer_seq, limit=50, offset=0):
    """대리점 수령 확인 목록."""
    return db.query(
        "SELECT customer_customer_id AS customer_id, authorized_dealer_seq, staff_id, pickup_id, pickup_date "
        "FROM pickup WHERE authorized_dealer_seq = %s ORDER BY pickup_date DESC LIMIT %s OFFSET %s",
        (dealer_seq, limit, offset),
    )


def get_store_returns(dealer_seq, limit=50, offset=0):
    """대리점 반품 처리 목록 (고객 반품 p_return + 상품명). 이미지(blob) 제외."""
    return db.query(
        "SELECT r.customer_customer_id AS customer_id, r.authorized_dealer_seq, r.p_id, p.p_name, "
        "r.reason, r.p_date, r.refund, r.staff_id "
        "FROM p_return r LEFT JOIN product p ON p.p_code = r.p_id "
        "WHERE r.authorized_dealer_seq = %s ORDER BY r.p_date DESC LIMIT %s OFFSET %s",
        (dealer_seq, limit, offset),
    )


def process_refund(customer_id, dealer_seq, staff_id):
    """반품 환불 처리 완료 표시 (refund=1). staff_id 는 Firebase employeeId."""
    return db.execute(
        "UPDATE p_return SET refund = 1, staff_id = %s "
        "WHERE customer_customer_id = %s AND authorized_dealer_seq = %s",
        (staff_id, customer_id, dealer_seq),
    )


def get_store_notices(dealer_seq, limit=20):
    """대리점 공지사항 (해당 대리점 대상, 최신순)."""
    return db.query(
        "SELECT head_office_id, seq, category, title, content, savedate FROM notice "
        "WHERE authorized_dealer_seq = %s ORDER BY savedate DESC LIMIT %s",
        (dealer_seq, limit),
    )
