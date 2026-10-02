"""가맹점 7개 화면의 API. 모든 경로는 /api/store/{dealer_seq}/... 로 매장을 지정한다."""
import hashlib
import hmac
import json
import os
import re
import urllib.parse
import urllib.request
import uuid
from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query

from . import schemas
from .deps import db, dd, firestore_client, get_dealer_or_404, require_api_key

router = APIRouter(prefix="/api/store/{dealer_seq}", dependencies=[Depends(require_api_key)])

LOW_STOCK = int(os.getenv("STORE_LOW_STOCK", "5"))

# 매장 주문 = 매장에서 수령한 적이 있거나, 선호 매장(customer_setting.favorite_dealer_seq)으로 지정한 회원의 구매.
# purchase 테이블에 매장 컬럼이 없어 이 기준을 쓴다. 상태는 dashboard_data 와 같은 규칙(반납완료/수령완료/배송중).
_STORE_ORDERS_SQL = """
FROM purchase pu
JOIN customer c ON c.customer_id = pu.customer_customer_id
LEFT JOIN product p ON p.p_code = pu.p_code
LEFT JOIN pickup k ON k.customer_customer_id = pu.customer_customer_id AND k.authorized_dealer_seq = %(d)s
LEFT JOIN customer_setting cs ON cs.customer_id = pu.customer_customer_id
WHERE (k.customer_customer_id IS NOT NULL OR cs.favorite_dealer_seq = %(d)s)
"""
_STATUS_SQL = """CASE
  WHEN EXISTS (SELECT 1 FROM p_return r WHERE r.customer_customer_id = pu.customer_customer_id
               AND r.authorized_dealer_seq = %(d)s AND r.p_id = pu.p_code) THEN '반납완료'
  WHEN k.customer_customer_id IS NOT NULL THEN '수령완료'
  ELSE '배송중' END"""


def _fs():
    try:
        return firestore_client()
    except Exception as e:  # 자격 증명/설정 오류는 상세 경로를 노출하지 않는다
        raise HTTPException(503, "Firebase 연결 설정을 확인해 주세요.") from e


def _stock_docs(dealer, product_id=None):
    from google.cloud.firestore_v1.base_query import FieldFilter

    q = _fs().collection("distributor_inventory").where(filter=FieldFilter("branchName", "==", dealer["name"]))
    if product_id:
        q = q.where(filter=FieldFilter("productId", "==", product_id))
    return list(q.stream())


def _add_stock(dealer, product_id, delta):
    """매장 재고에 delta 를 더한다(원자적 Increment). 재고 문서가 없으면 delta>0 일 때만 새로 만든다. 반영 여부 반환."""
    from google.cloud import firestore

    try:
        docs = _stock_docs(dealer, product_id)
        if docs:
            if delta < 0 and (docs[0].to_dict().get("quantity") or 0) < -delta:
                return False
            docs[0].reference.update({"quantity": firestore.Increment(delta)})
            return True
        if delta > 0:
            _fs().collection("distributor_inventory").add(
                {"branchName": dealer["name"], "productId": product_id, "quantity": delta})
            return True
    except HTTPException:
        raise
    except Exception:
        pass  # MySQL 처리는 이미 끝났으므로 재고 반영 실패는 stock_updated=false 로만 알린다
    return False


def pickup_code(customer_id, p_code):
    """고객 앱이 보여 주는 6자리 난수. 서버 비밀키(PICKUP_CODE_SECRET)로 (고객, 상품)에서 결정적으로 만든다.
    QR 이 안 읽힐 때 매장이 이 숫자를 입력해 인증한다. 고객 앱은 /pickup-code 로 같은 값을 받는다."""
    secret = os.getenv("PICKUP_CODE_SECRET")
    if not secret:
        raise HTTPException(503, "PICKUP_CODE_SECRET 이 설정되지 않았습니다.")
    digest = hmac.new(secret.encode(), f"{customer_id}|{p_code}".encode(), hashlib.sha256).digest()
    return f"{int.from_bytes(digest[:4], 'big') % 1_000_000:06d}"


def _parse_qr(raw):
    """QR 형식: 'FITPICK:PICKUP:<customer_id>:<p_code>' 또는 JSON {"customer_id":..,"p_code":..}."""
    raw = raw.strip()
    try:
        data = json.loads(raw)
        if isinstance(data, dict) and data.get("customer_id") and data.get("p_code"):
            return str(data["customer_id"]), str(data["p_code"])
    except ValueError:
        pass
    m = re.fullmatch(r"FITPICK:PICKUP:([^:]+):([^:]+)", raw)
    if not m:
        raise HTTPException(422, "인식할 수 없는 QR 코드입니다.")
    return m.group(1), m.group(2)


# ---------- 1. 대시보드 ----------
@router.get("/dashboard")
def dashboard(dealer_seq: int):
    dealer = get_dealer_or_404(dealer_seq)
    p = {"d": dealer_seq}
    one = (dealer_seq,)
    today_pickups = db.query_one(
        "SELECT COUNT(*) n FROM pickup WHERE authorized_dealer_seq=%s AND DATE(pickup_date)=CURDATE()", one)
    pending_refunds = db.query_one(
        "SELECT COUNT(*) n FROM p_return WHERE authorized_dealer_seq=%s AND refund=0", one)
    today_returns = db.query_one(
        "SELECT COUNT(*) n FROM p_return WHERE authorized_dealer_seq=%s AND DATE(p_date)=CURDATE()", one)
    orders = db.query_one("SELECT COUNT(*) n, COALESCE(SUM(pu.p_price),0) s " + _STORE_ORDERS_SQL, p)
    shipping = db.query_one(f"SELECT COUNT(*) n {_STORE_ORDERS_SQL} AND ({_STATUS_SQL}) = '배송중'", p)
    today = db.query_one(
        "SELECT COALESCE(SUM(pu.p_price),0) s, COUNT(*) n " + _STORE_ORDERS_SQL + " AND DATE(pu.p_date)=CURDATE()", p)
    try:
        stocks = [d.to_dict() for d in _stock_docs(dealer)]
        pending_shipments = sum(1 for d in _fs().collection("send").where(
            "branchName", "==", dealer["name"]).stream() if not d.to_dict().get("isReceived"))
        inventory = {"total_quantity": sum(s.get("quantity", 0) for s in stocks),
                     "low_stock_count": sum(1 for s in stocks if s.get("quantity", 0) <= LOW_STOCK),
                     "pending_shipments": pending_shipments}
    except Exception:
        inventory = None  # Firebase 오류여도 나머지 카드는 보여 준다
    needs_attention = pending_refunds["n"] + (
        (inventory["low_stock_count"] + inventory["pending_shipments"]) if inventory else 0)
    return {
        "store": {"seq": dealer["seq"], "name": dealer["name"]},
        # 목업 KPI 4개: 오늘 매출 / 진행 주문 / 대여 가능 / 확인 필요
        "kpis": {"today_sales": int(today["s"]), "today_orders": today["n"],
                 "in_progress_orders": shipping["n"],
                 "available_stock": inventory["total_quantity"] if inventory else None,
                 "needs_attention": needs_attention},
        "pending_pickups": shipping["n"],
        "today_pickups": today_pickups["n"],
        "today_returns": today_returns["n"],
        "pending_refunds": pending_refunds["n"],
        "shipping_orders": shipping["n"],
        "total_orders": orders["n"],
        "total_sales": int(orders["s"]),
        "inventory": inventory,
        "notices": dd.get_store_notices(dealer_seq, 5),
    }


# ---------- 2. 수령 확인 (QR) ----------
_PURCHASE_SQL = (
    "SELECT pu.customer_customer_id AS customer_id, pu.p_code, pu.p_date, pu.p_price, p.p_name, p.b_name, "
    "p.p_size, p.p_color, c.name AS customer_name "
    "FROM purchase pu JOIN customer c ON c.customer_id = pu.customer_customer_id "
    "LEFT JOIN product p ON p.p_code = pu.p_code ")


def _lookup_pickup(dealer_seq, qr=None, code=None):
    if qr:
        customer_id, p_code = _parse_qr(qr)
        purchase = db.query_one(
            _PURCHASE_SQL + "WHERE pu.customer_customer_id=%s AND pu.p_code=%s ORDER BY pu.p_date DESC LIMIT 1",
            (customer_id, p_code))
    elif code:
        # 아직 이 매장에서 수령하지 않은 구매만 후보로 두고 난수가 일치하는 건을 찾는다.
        rows = db.query(
            _PURCHASE_SQL + "LEFT JOIN pickup k ON k.customer_customer_id = pu.customer_customer_id "
            "AND k.authorized_dealer_seq = %s WHERE k.customer_customer_id IS NULL", (dealer_seq,))
        hits = [r for r in rows if hmac.compare_digest(pickup_code(r["customer_id"], r["p_code"]), code)]
        if len(hits) > 1:
            raise HTTPException(409, "같은 난수의 주문이 여러 건입니다. QR 로 인증해 주세요.")
        purchase = hits[0] if hits else None
    else:
        raise HTTPException(422, "qr 또는 code 가 필요합니다.")
    if not purchase:
        raise HTTPException(404, "해당 구매 내역을 찾을 수 없습니다.")
    done = db.query_one(
        "SELECT pickup_date FROM pickup WHERE customer_customer_id=%s AND authorized_dealer_seq=%s",
        (purchase["customer_id"], dealer_seq))
    return purchase, done


@router.post("/pickups/verify")
def verify_pickup(dealer_seq: int, body: schemas.PickupScan):
    """QR 을 읽은 직후 호출. DB 를 바꾸지 않고 구매 정보와 수령 가능 여부만 돌려준다."""
    get_dealer_or_404(dealer_seq)
    purchase, done = _lookup_pickup(dealer_seq, body.qr, body.code)
    return {"purchase": purchase, "already_picked_up": bool(done),
            "picked_up_at": done["pickup_date"] if done else None}


@router.post("/pickups/confirm", status_code=201)
def confirm_pickup(dealer_seq: int, body: schemas.PickupConfirm):
    dealer = get_dealer_or_404(dealer_seq)
    purchase, done = _lookup_pickup(dealer_seq, body.qr, body.code)
    if done:
        raise HTTPException(409, "이미 수령 처리된 주문입니다.")
    pickup_id = "PK-" + uuid.uuid4().hex[:12].upper()
    try:
        db.execute(
            "INSERT INTO pickup (customer_customer_id, authorized_dealer_seq, staff_id, pickup_id, pickup_date) "
            "VALUES (%s,%s,%s,%s,NOW())",
            (purchase["customer_id"], dealer_seq, body.staff_id, pickup_id))
    except db.DBError as e:
        raise HTTPException(400, "수령 처리에 실패했습니다. 이미 처리됐거나 직원 ID를 확인해 주세요.") from e
    return {"pickup_id": pickup_id, "customer_id": purchase["customer_id"], "p_code": purchase["p_code"],
            "stock_updated": _add_stock(dealer, purchase["p_code"], -1)}


@router.get("/pickups")
def list_pickups(dealer_seq: int, limit: int = Query(50, ge=1, le=200), offset: int = Query(0, ge=0)):
    get_dealer_or_404(dealer_seq)
    return dd.get_store_pickups(dealer_seq, limit, offset)


# ---------- 3. 반품 처리 ----------
@router.get("/returns")
def list_returns(dealer_seq: int, pending_only: bool = False,
                 limit: int = Query(50, ge=1, le=200), offset: int = Query(0, ge=0)):
    get_dealer_or_404(dealer_seq)
    rows = dd.get_store_returns(dealer_seq, limit, offset)
    return [r for r in rows if not r["refund"]] if pending_only else rows


@router.get("/returns/candidates")
def return_candidates(dealer_seq: int):
    """반품 접수 대상: 이 매장에서 수령 완료됐고 아직 반품 접수되지 않은 주문."""
    get_dealer_or_404(dealer_seq)
    return db.query(
        "SELECT pu.customer_customer_id AS customer_id, c.name AS customer_name, pu.p_code, p.p_name, p.b_name, "
        "p.p_size, p.p_color, pu.p_price, k.pickup_date "
        "FROM pickup k JOIN purchase pu ON pu.customer_customer_id = k.customer_customer_id "
        "JOIN customer c ON c.customer_id = pu.customer_customer_id "
        "LEFT JOIN product p ON p.p_code = pu.p_code "
        "LEFT JOIN p_return r ON r.customer_customer_id = k.customer_customer_id "
        "AND r.authorized_dealer_seq = k.authorized_dealer_seq "
        "WHERE k.authorized_dealer_seq = %s AND r.customer_customer_id IS NULL ORDER BY k.pickup_date DESC",
        (dealer_seq,))


@router.post("/returns", status_code=201)
def create_return(dealer_seq: int, body: schemas.ReturnCreate):
    """반품 접수. 구매 내역이 있어야 하고, 접수되면 반품 상품 1개가 매장 재고로 돌아온다."""
    dealer = get_dealer_or_404(dealer_seq)
    if not db.query_one(
            "SELECT 1 x FROM purchase WHERE customer_customer_id=%s AND p_code=%s", (body.customer_id, body.p_code)):
        raise HTTPException(404, "해당 구매 내역을 찾을 수 없습니다.")
    if db.query_one("SELECT 1 x FROM p_return WHERE customer_customer_id=%s AND authorized_dealer_seq=%s",
                    (body.customer_id, dealer_seq)):
        raise HTTPException(409, "이미 반품 접수된 건입니다.")
    try:
        db.execute(
            "INSERT INTO p_return (customer_customer_id, authorized_dealer_seq, p_id, reason, p_date, refund, staff_id) "
            "VALUES (%s,%s,%s,%s,NOW(),0,%s)",
            (body.customer_id, dealer_seq, body.p_code, body.reason, body.staff_id))
    except db.DBError as e:
        raise HTTPException(400, "반품 접수에 실패했습니다. 직원 ID 등을 확인해 주세요.") from e
    return {"stock_updated": _add_stock(dealer, body.p_code, 1)}


@router.post("/returns/{customer_id}/refund")
def refund_return(dealer_seq: int, customer_id: str, body: schemas.RefundRequest):
    get_dealer_or_404(dealer_seq)
    if not db.execute(
            "UPDATE p_return SET refund = 1, staff_id = %s "
            "WHERE customer_customer_id = %s AND authorized_dealer_seq = %s AND refund = 0",
            (body.staff_id, customer_id, dealer_seq)):
        raise HTTPException(404, "반품 내역이 없거나 이미 환불 처리되었습니다.")
    return {"refunded": True}


# ---------- 4. 재고 관리 (Firebase distributor_inventory / send) ----------
@router.get("/inventory")
def inventory(dealer_seq: int, low_only: bool = False):
    dealer = get_dealer_or_404(dealer_seq)
    items = [{"id": d.id, **d.to_dict()} for d in _stock_docs(dealer)]
    products = dd.get_products_by_codes([i["productId"] for i in items if i.get("productId")])
    for i in items:
        i["product"] = products.get(i.get("productId"))
        i["low_stock"] = i.get("quantity", 0) <= LOW_STOCK
    return [i for i in items if i["low_stock"]] if low_only else items


# 고정 경로(/inventory/shipments)가 /inventory/{product_id} 보다 먼저 등록돼야 한다
@router.get("/inventory/shipments")
def shipments(dealer_seq: int, pending_only: bool = False):
    """본사가 이 매장으로 보낸 재고(Firebase send)."""
    from google.cloud.firestore_v1.base_query import FieldFilter

    dealer = get_dealer_or_404(dealer_seq)
    q = _fs().collection("send").where(filter=FieldFilter("branchName", "==", dealer["name"]))
    rows = [{"id": d.id, **d.to_dict()} for d in q.stream()]
    return [r for r in rows if not r.get("isReceived")] if pending_only else rows


@router.get("/inventory/movements")
def movements(dealer_seq: int, limit: int = Query(50, ge=1, le=200)):
    """입출고 내역(최신순). 입고 = 본사 발송(Firebase send), 반납 = 고객 반품(MySQL p_return)."""
    from google.cloud.firestore_v1.base_query import FieldFilter

    dealer = get_dealer_or_404(dealer_seq)
    rows = []
    for d in _fs().collection("send").where(filter=FieldFilter("branchName", "==", dealer["name"])).stream():
        v = d.to_dict()
        rows.append({"at": v.get("sentAt"), "kind": "입고", "p_name": None, "size": None, "color": None,
                     "quantity": v.get("quantity"), "staff_id": v.get("employeeId"),
                     "note": "수령 완료" if v.get("isReceived") else "수령 대기"})
    for r in db.query(
            "SELECT r.p_date AS at, p.p_name, p.p_size AS size, p.p_color AS color, r.staff_id, r.reason, r.refund "
            "FROM p_return r LEFT JOIN product p ON p.p_code = r.p_id WHERE r.authorized_dealer_seq = %s "
            "ORDER BY r.p_date DESC LIMIT %s", (dealer_seq, limit)):
        rows.append({"at": r["at"], "kind": "반납", "p_name": r["p_name"], "size": r["size"], "color": r["color"],
                     "quantity": 1, "staff_id": r["staff_id"], "note": r["reason"]})
    rows.sort(key=lambda x: str(x["at"] or ""), reverse=True)
    return rows[:limit]


@router.post("/inventory/shipments/{shipment_id}/receive")
def receive_shipment(dealer_seq: int, shipment_id: str, body: schemas.ShipmentReceive):
    dealer = get_dealer_or_404(dealer_seq)
    ref = _fs().collection("send").document(shipment_id)
    snap = ref.get()
    data = snap.to_dict() if snap.exists else None
    if not data or data.get("branchName") != dealer["name"]:
        raise HTTPException(404, "발송 내역을 찾을 수 없습니다.")
    if data.get("isReceived"):
        raise HTTPException(409, "이미 수령 처리된 발송입니다.")
    ref.update({"isReceived": True})
    stock_updated = bool(body.product_id) and _add_stock(dealer, body.product_id, int(data.get("quantity", 0)))
    return {"received": True, "stock_updated": stock_updated}


@router.put("/inventory/{product_id}")
def set_inventory(dealer_seq: int, product_id: str, body: schemas.StockAdjust):
    """재고 실사 등으로 수량을 직접 맞춘다."""
    dealer = get_dealer_or_404(dealer_seq)
    docs = _stock_docs(dealer, product_id)
    if not docs:
        raise HTTPException(404, "매장 재고에 없는 상품입니다.")
    docs[0].reference.update({"quantity": body.quantity})
    return {"productId": product_id, "quantity": body.quantity}


# ---------- 5. 주문 현황 ----------
@router.get("/orders")
def orders(dealer_seq: int, status: str | None = Query(None, pattern="^(배송중|배송완료|수령완료|반납완료)$"),
           limit: int = Query(50, ge=1, le=200), offset: int = Query(0, ge=0)):
    get_dealer_or_404(dealer_seq)
    sql = (f"SELECT * FROM (SELECT pu.customer_customer_id AS customer_id, c.name AS customer_name, pu.p_code, "
           f"p.p_name, p.b_name, pu.p_price, pu.p_date, ({_STATUS_SQL}) AS status {_STORE_ORDERS_SQL}) t ")
    params = {"d": dealer_seq, "limit": limit, "offset": offset}
    if status:
        sql += "WHERE t.status = %(status)s "
        params["status"] = status
    sql += "ORDER BY t.p_date DESC LIMIT %(limit)s OFFSET %(offset)s"
    return db.query(sql, params)


# ---------- 6. 매장 통계 ----------
def _period_windows(period, day):
    """(KPI 구간, 차트 버킷 목록). 일별=선택일 / 7일 추이, 주별=선택일까지 7일 / 4주 추이, 월별=선택월 / 6개월 추이."""
    if period == "daily":
        kpi = (day, day + timedelta(days=1))
        buckets = [(day - timedelta(days=i), day - timedelta(days=i - 1), f"{(day - timedelta(days=i)).month}/{(day - timedelta(days=i)).day}")
                   for i in range(6, -1, -1)]
    elif period == "weekly":
        kpi = (day - timedelta(days=6), day + timedelta(days=1))
        buckets = [(day - timedelta(days=7 * i + 6), day - timedelta(days=7 * (i - 1) + 6), f"{4 - i}주")
                   for i in range(3, -1, -1)]
    else:
        first = day.replace(day=1)
        month_start = lambda back: date(first.year + (first.month - 1 - back) // 12, (first.month - 1 - back) % 12 + 1, 1)
        kpi = (first, month_start(-1))
        buckets = [(month_start(i), month_start(i - 1), f"{month_start(i).month}월") for i in range(5, -1, -1)]
    return kpi, buckets


@router.get("/statistics")
def statistics(dealer_seq: int, period: str = Query("daily", pattern="^(daily|weekly|monthly)$"),
               day: date | None = Query(None, alias="date")):
    """목업의 일별/주별/월별 탭 + 날짜 선택. 매출 추이, 매장 주문, 수령 현황, 운영 지표, 제품별 수령 수량."""
    get_dealer_or_404(dealer_seq)
    day = day or date.today()
    (start, end), buckets = _period_windows(period, day)
    p = {"d": dealer_seq, "start": start, "end": end}
    sales = db.query_one(
        "SELECT COALESCE(SUM(pu.p_price),0) AS sales, COUNT(*) AS orders " + _STORE_ORDERS_SQL +
        " AND pu.p_date >= %(start)s AND pu.p_date < %(end)s", p)
    pickup = db.query_one(
        "SELECT COUNT(*) AS pickups, AVG(TIMESTAMPDIFF(MINUTE, pu.p_date, k.pickup_date)) AS avg_minutes "
        "FROM pickup k LEFT JOIN purchase pu ON pu.customer_customer_id = k.customer_customer_id "
        "WHERE k.authorized_dealer_seq = %(d)s AND k.pickup_date >= %(start)s AND k.pickup_date < %(end)s", p)
    returns = db.query_one(
        "SELECT COUNT(*) AS n FROM p_return WHERE authorized_dealer_seq = %(d)s "
        "AND p_date >= %(start)s AND p_date < %(end)s", p)
    top = db.query(
        "SELECT pu.p_code, p.p_name, COUNT(*) AS quantity FROM pickup k "
        "JOIN purchase pu ON pu.customer_customer_id = k.customer_customer_id "
        "LEFT JOIN product p ON p.p_code = pu.p_code "
        "WHERE k.authorized_dealer_seq = %(d)s AND k.pickup_date >= %(start)s AND k.pickup_date < %(end)s "
        "GROUP BY pu.p_code, p.p_name ORDER BY quantity DESC LIMIT 5", p)
    rows = db.query(
        "SELECT pu.p_date AS at, pu.p_price AS price " + _STORE_ORDERS_SQL +
        " AND pu.p_date >= %(s)s AND pu.p_date < %(e)s", {"d": dealer_seq, "s": buckets[0][0], "e": buckets[-1][1]})
    series = [{"label": label, "sales": sum(int(r["price"] or 0) for r in rows if b0 <= r["at"].date() < b1)}
              for b0, b1, label in buckets]
    return {
        "period": period, "date": day, "range": {"start": start, "end": end},
        "sales": int(sales["sales"]), "orders": sales["orders"],
        "pickups": pickup["pickups"], "returns": returns["n"],
        "avg_pickup_minutes": round(float(pickup["avg_minutes"]), 1) if pickup["avg_minutes"] is not None else None,
        "sales_series": series,
        "pickup_by_product": top,
    }


# ---------- 7. 매장 정보 (+ 네이버 지도) ----------
# MySQL authorized_dealer 에 없는 사진/영업시간은 Firestore store_profile/{dealer_seq} 문서에 둔다.
_PROFILE_FIELDS = ("open_time", "close_time", "photo_url")


def _profile(dealer_seq):
    try:
        snap = _fs().collection("store_profile").document(str(dealer_seq)).get()
        data = snap.to_dict() if snap.exists else {}
    except HTTPException:
        data = {}
    return {k: data.get(k) for k in _PROFILE_FIELDS}


@router.get("/info")
def store_info(dealer_seq: int):
    dealer = get_dealer_or_404(dealer_seq)
    return {
        "store": dealer,
        "profile": _profile(dealer_seq),
        # 지도용 JS 키(ncpKeyId)는 앱/브라우저에 공개되는 값이다. Secret 은 절대 내려보내지 않는다.
        "map": {"provider": "naver", "client_id": os.getenv("NAVER_MAP_CLIENT_ID"),
                "lat": dealer["lat"], "lng": dealer["lng"], "zoom": 16},
        "notices": dd.get_store_notices(dealer_seq, 10),
    }


@router.put("/info")
def update_store_info(dealer_seq: int, body: schemas.StoreInfoUpdate):
    get_dealer_or_404(dealer_seq)
    fields = body.model_dump(exclude_none=True)
    if not fields:
        raise HTTPException(422, "수정할 항목이 없습니다.")
    profile = {k: fields.pop(k) for k in _PROFILE_FIELDS if k in fields}
    if profile:
        _fs().collection("store_profile").document(str(dealer_seq)).set(profile, merge=True)
    if fields:
        cols = ", ".join(f"{k}=%s" for k in fields)  # 키는 pydantic 모델의 고정 필드명이라 안전
        db.execute(f"UPDATE authorized_dealer SET {cols} WHERE seq=%s", (*fields.values(), dealer_seq))
    return store_info(dealer_seq)


@router.get("/info/geocode")
def geocode(dealer_seq: int, address: str = Query(min_length=2, max_length=100)):
    """주소 -> 좌표 (네이버 Geocoding). 매장 위치를 지도에 맞출 때 사용. NAVER_API_KEY_ID/SECRET 필요."""
    get_dealer_or_404(dealer_seq)
    key_id, secret = os.getenv("NAVER_API_KEY_ID"), os.getenv("NAVER_API_KEY_SECRET")
    if not key_id or not secret:
        raise HTTPException(503, "네이버 지도 API 키가 설정되지 않았습니다.")
    req = urllib.request.Request(
        "https://maps.apigw.ntruss.com/map-geocode/v2/geocode?query=" + urllib.parse.quote(address),
        headers={"X-NCP-APIGW-API-KEY-ID": key_id, "X-NCP-APIGW-API-KEY": secret})
    try:
        with urllib.request.urlopen(req, timeout=5) as res:
            data = json.load(res)
    except Exception as e:
        raise HTTPException(502, "네이버 지도 API 호출에 실패했습니다.") from e
    return [{"address": a.get("roadAddress") or a.get("jibunAddress"), "lat": float(a["y"]), "lng": float(a["x"])}
            for a in data.get("addresses", [])]
