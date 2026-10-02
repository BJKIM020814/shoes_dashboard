# 가맹점 API (store_api)

기존 코드(`db.py`, `dashboard_data.py`, Flutter)는 수정하지 않고 새로 추가한 FastAPI 백엔드입니다.

## 실행
```
pip install fastapi uvicorn pymysql python-dotenv cryptography "google-cloud-firestore>=2.19,<3"
cd shoes_dashboard/python
uvicorn store_api.main:app --host 0.0.0.0 --port 8100   # 문서: /docs
```
`.env`(DB_*, GOOGLE_APPLICATION_CREDENTIALS)는 기존 `db.py`가 읽는 것을 그대로 씁니다. 추가 환경변수(선택):

| 변수 | 용도 |
|---|---|
| `NAVER_MAP_CLIENT_ID` | 네이버 지도 JS 키. `/info` 응답의 `map.client_id`로 내려가 앱이 지도를 그림 |
| `NAVER_API_KEY_ID` / `NAVER_API_KEY_SECRET` | 주소→좌표 변환(`/info/geocode`), 서버 전용 |
| `PICKUP_CODE_SECRET` | 6자리 난수 인증용 서버 비밀키(필수: 난수 입력 수령 확인) |
| `STORE_API_KEY` | 설정하면 모든 요청에 `X-API-Key` 헤더 필요 |
| `STORE_LOW_STOCK` | 재고 부족 기준(기본 5) |
| `STORE_CORS_ORIGINS` | 허용할 추가 Origin(쉼표 구분) |

## 화면 → API (`/api/store/{dealer_seq}` 아래)
| 화면 | 엔드포인트 |
|---|---|
| 대시보드 | `GET /dashboard` |
| 수령 확인 | `POST /pickups/verify`(QR 또는 6자리 `code`로 조회), `POST /pickups/confirm`(수령 확정), `GET /pickups` |
| 반품 처리 | `GET /returns`, `GET /returns/candidates`(접수 대상), `POST /returns`(접수), `POST /returns/{customer_id}/refund` |
| 재고 관리 | `GET /inventory`, `PUT /inventory/{product_id}`, `GET /inventory/movements`(입출고 내역), `GET /inventory/shipments`, `POST /inventory/shipments/{id}/receive` |
| 주문 현황 | `GET /orders?status=배송중\|수령완료\|반납완료` |
| 매장 통계 | `GET /statistics?period=daily\|weekly\|monthly&date=YYYY-MM-DD` |
| 매장 정보 | `GET /info`(사진·영업시간·지도 설정 포함), `PUT /info`, `GET /info/geocode?address=` |
| 매장 목록 | `GET /api/store/stores` |

## QR (카메라로 직접 촬영)
앱(Flutter)이 카메라로 QR을 읽고 그 **문자열을 그대로** `qr`에 담아 보냅니다. 서버는 카메라를 쓰지 않습니다.
형식: `FITPICK:PICKUP:<customer_id>:<p_code>` 또는 JSON `{"customer_id":"..","p_code":".."}`.
고객 앱이 위 형식으로 QR을 만들어야 합니다(형식은 `routes._parse_qr`에서 바꿀 수 있음).

## 데이터 저장소와 가정
- 수령/반품/주문/매장정보: MySQL. 재고/발송: Firebase(`distributor_inventory`, `send`), 매장 연결 키는 `branchName = authorized_dealer.name`.
- `pickup`, `p_return`의 PK가 (고객, 매장)이라 **고객당 매장별 1건**만 저장됩니다. 두 번째 건은 409로 거절합니다.
- `purchase`에 매장 컬럼이 없어 **매장 주문 = 그 매장에서 수령했거나 선호 매장으로 지정한 회원의 구매**로 정의했습니다.
- 수령 확정 시 재고 -1, 반품 접수 시 +1을 Firestore에 반영하고 결과를 `stock_updated`로 알립니다(MySQL 커밋 후 처리라 Firebase 실패 시 false).
- `send` 문서에 상품 코드가 없어 입고 처리 시 `product_id`를 주면 그 상품 재고에 발송수량을 더합니다.
- 직원 ID(`staff_id`)는 요청 본문 값을 그대로 저장합니다. 매장 로그인/인증은 아직 없습니다.

## 고객 앱용 난수 발급
`GET /api/pickup-code?customer_id=&p_code=` → `{"code":"392184","qr":"FITPICK:PICKUP:..."}`.
고객 앱이 수령 화면에 QR/난수를 보여 줄 때 호출합니다. **구매 내역 존재만 확인**하므로 고객 인증이 붙기 전에는
`STORE_API_KEY`로 보호하거나 고객 앱 서버에서만 호출하세요.

## Flutter 실행
```
flutter run --dart-define=STORE_API_BASE=http://<서버IP>:8100 --dart-define=STORE_DEALER_SEQ=1             [--dart-define=STORE_STAFF_ID=<직원ID>] [--dart-define=STORE_API_KEY=<키>]
```
실기기(아이패드/안드로이드)에서는 `localhost` 대신 서버의 PC IP를 쓰고, http 접속은 OS 정책상 개발 중에만 허용하세요(운영은 https).
- 사진/영업시간은 Firestore `store_profile/{dealer_seq}` (`open_time`, `close_time`, `photo_url`)에 저장합니다.
