"""가맹점 API 서버 시작점. 실행: (shoes_dashboard/python 에서) uvicorn store_api.main:app --port 8100"""
import os

from fastapi import Depends, FastAPI, HTTPException, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from .deps import db, dd
from .deps import require_api_key
from .routes import pickup_code, router

app = FastAPI(title="FITPICK 가맹점 API", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in os.getenv("STORE_CORS_ORIGINS", "").split(",") if o.strip()],
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1|192\.168\.\d+\.\d+)(:\d+)?$",
    allow_methods=["GET", "POST", "PUT"],
    allow_headers=["Content-Type", "X-API-Key"],
)
app.include_router(router)


@app.exception_handler(db.DBError)
async def db_error(request: Request, exc: db.DBError):
    # 접속 정보/SQL 은 응답에 노출하지 않는다
    return JSONResponse(status_code=503, content={"detail": "데이터베이스 연결을 확인해 주세요."})


@app.get("/api/store/stores")
def stores():
    """매장 선택 목록 (로그인 화면/설정용)."""
    return [{"seq": d["seq"], "name": d["name"]} for d in dd.get_dealers()]


@app.get("/api/pickup-code", dependencies=[Depends(require_api_key)])
def issue_pickup_code(customer_id: str = Query(max_length=45), p_code: str = Query(max_length=45)):
    """고객 앱이 수령 화면에 보여 줄 6자리 난수(QR 이 안 읽힐 때 매장이 입력). 구매 내역이 있어야 발급."""
    if not db.query_one("SELECT 1 x FROM purchase WHERE customer_customer_id=%s AND p_code=%s", (customer_id, p_code)):
        raise HTTPException(404, "해당 구매 내역을 찾을 수 없습니다.")
    return {"code": pickup_code(customer_id, p_code),
            "qr": f"FITPICK:PICKUP:{customer_id}:{p_code}"}


@app.get("/health")
def health():
    return {"ok": True}
