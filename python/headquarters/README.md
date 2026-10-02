# FITPICK 본사 백엔드

기존 `python/db.py`, `python/dashboard_data.py`, Flutter 로그인·본사 화면, 첨부된 Firebase → MySQL → SQLite ERD와 [관리자 화면 목업](https://fitpick-admin-tablet.higgsfield.app/)을 기준으로 작성한 FastAPI 서버입니다. 기존 Flutter/Python 파일을 변경하지 않고 기능별 파일을 `headquarters`에 분리했습니다.

**현재 검증 범위:** 임시 독립 MySQL에서 API/트랜잭션을 테스트했습니다. 프로젝트에 운영 MySQL `.env`, SQL 덤프, Firebase Admin 자격 증명이 없어 운영 DB/Firestore의 실제 스키마·문서·edition은 확인하지 못했습니다. Firebase CLI도 현재 실행 환경에 없습니다. 아래 매핑은 기존 코드와 ERD를 바탕으로 명시한 연결 계약이며, 실제 데이터에 맞게 확인해야 합니다. Firebase 통신은 테스트에서 대체했습니다. Flutter 화면의 실제 API 연결은 이 백엔드 작업에 포함하지 않았습니다.

## 구성

| 파일 | 기능 |
|---|---|
| `main.py` | 서버, 라우터, CORS, 상태 확인 |
| `login.py` | 로그인, 토큰 갱신, 본사 직원 권한, 로그아웃 |
| `dashboard.py` | 매출·주문·회원·대리점·문의 카드, 최근 공지, 차트 |
| `sales.py` | 기간 선택, 일/주/월 차트, 전기 대비 증감, 상위 상품 |
| `members.py` | 회원명/이메일 검색, 등급 필터, 상세·최근 구매, 등급 수정 |
| `reviews.py` | 작성자·상품·내용 검색, 공개/신고/숨김 필터, 상태 수정 |
| `inquiries.py` | 제목·이메일·문의번호 검색, 답변 대기/완료, 상세·답변 저장 |
| `database.py` / `firebase.py` | MySQL 연결과 Firebase Admin 연동 |
| `config.py` / `common.py` | 환경변수, 날짜·ID·입력 검증 |
| `check_database.py` | 운영 데이터 조회 없이 테이블/컬럼 검사 |
| `migrate.py` / `migrations/001_admin_metadata.sql` | 신규 관리 보조 테이블 생성 |
| `tests/` | 인증 검사 및 임시 MySQL 통합 테스트 |

## 데이터 저장소의 역할

- **MySQL:** `customer`, `purchase`, `product`, `review`, `contact`, `authorized_dealer`, `notice`를 기존 컬럼명으로 사용합니다.
- **Firebase Auth:** 비밀번호 로그인과 ID 토큰 검증. 모든 보호 API에서 만료·취소 여부와 활성 본사 직원 여부를 확인합니다. Firestore의 비밀번호 필드를 직접 비교하거나 반환하지 않습니다. 기존 직원 비밀번호가 Firestore에만 있다면 Firebase Authentication 계정으로 이관해야 합니다.
- **Firestore:** `account`의 이름·전화·성별·주소·가입경로·가입일, `employee`의 본사 권한·직원 정보를 사용합니다. JSON 키는 아래 계약을 따릅니다. 실제 collection 이름은 환경변수로 변경할 수 있습니다. 데이터베이스 edition과 Native Firestore API 지원 여부도 연결 전에 확인하세요. 별도 MongoDB 호환 인터페이스용 구현은 아닙니다.
- **SQLite:** 첨부 ERD의 장바구니, 쿠폰, 결제수단, 최근 본 상품 등 Flutter 단말 로컬 데이터입니다. 본사 서버의 영구 DB나 회원 비밀번호 저장소로 사용하지 않습니다.

MySQL `customer.customer_id`와 Firestore `account`의 문서 ID는 **이메일**로 연결합니다. 직원 문서 ID는 **Firebase Auth UID**이며 `employeeId`는 실제 직원 ID, `headOfficeId`는 MySQL 본사 ID입니다. UID와 직원 ID는 서로 다른 값이어도 됩니다.

확인해야 할 Firestore 문서 계약:

```text
account/{email}
  email, name, phone, gender, address, joinPath, joinedAt

employee/{firebase_auth_uid}
  employeeId: "HQ01"
  headOfficeId: 1                 # 정수, MySQL head_office.id와 매핑
  role: "headquarters"           # 이 값만 본사 접근 허용
  active: true                    # boolean
  name, position, department
```

계정/직원 문서가 다른 키를 사용한다면 `firebase.py`에서 매핑을 조정해야 합니다. 고객 클라이언트가 `employee.role`, `active`, `headOfficeId`를 수정할 수 없도록 기존 Firestore Rules/IAM을 확인하세요. 이 작업은 운영 보안 규칙이나 직원을 자동 생성하지 않습니다. 서버 Admin SDK는 IAM으로 접근하며 Firestore 클라이언트 보안 규칙을 우회합니다.

MySQL 회원이 있지만 해당 `account` 문서가 없으면 `profile: null`, `profile_found: false`를 반환합니다. Firebase 접속 실패는 누락된 프로필처럼 숨기지 않고 503을 반환합니다. 회원명 검색은 Firestore `name` **접두어**, 이메일·상품·문의 본문 검색은 MySQL 부분 일치입니다. 회원명 후보가 500명을 초과하면 검색어를 구체화하도록 422를 반환합니다.

## 실행

프로젝트 루트에서 실행합니다. Python 3.11 이상을 권장합니다. 이 환경의 Python 3.9.6에서도 테스트했으나 Google SDK 지원 종료 및 LibreSSL 관련 경고가 발생했습니다.

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r python/headquarters/requirements.txt
cp python/headquarters/.env.example python/headquarters/.env
```

`python/headquarters/.env`에 MySQL 접속 정보, Firebase Web API Key, 서비스 계정 JSON 경로를 설정합니다. 프로젝트 루트 `.env`도 지원하며 설정 우선순위는 OS 환경변수 → 루트 `.env` → `python/.env` → `python/headquarters/.env`입니다. OS 환경변수가 가장 우선합니다. 서비스 계정 JSON은 저장소 밖에 두세요. 기존 Flutter의 Firebase 설정은 서버용 Admin 자격 증명을 대신하지 않습니다.

그 다음 보조 테이블 SQL을 확인하고 실행합니다. 서버 시작 시 운영 DB에 DDL이나 샘플 데이터를 자동 삽입하지 않습니다.

```bash
# 읽기 전용 SQL 출력
.venv/bin/python -m python.headquarters.migrate

# 검토한 SQL을 설정된 DB에 실행. 기존 테이블은 유지하며 3개 보조 테이블을 생성합니다.
# MySQL DDL은 자동 커밋되므로 롤백되지 않습니다.
.venv/bin/python -m python.headquarters.migrate --apply

# 읽기 전용으로 필수 컬럼 검사. 누락이면 종료 코드 1.
.venv/bin/python -m python.headquarters.check_database

# 개발 서버
.venv/bin/python -m uvicorn python.headquarters.main:app --reload --host 127.0.0.1 --port 8000
```

API 문서: `http://127.0.0.1:8000/docs`.

`DB_UNIX_SOCKET` 환경변수를 지정하면 로컬 MySQL 소켓 접속도 지원합니다. 기본은 `DB_HOST`/`DB_PORT`의 TCP 연결입니다. 런타임 계정에는 SELECT와 관리 테이블 INSERT/UPDATE, `contact` 답변 UPDATE 권한이 필요합니다. 테이블 생성은 별도 DDL 권한 계정으로 수행할 수 있습니다.

## API

기본 경로: `/api/v1/headquarters`. 로그인·토큰 갱신과 `/health`를 제외하면 다음 헤더가 필수입니다.

```http
Authorization: Bearer <access_token>
```

| 메서드 | 기본 경로 뒤에 붙일 URL | 용도 |
|---|---|---|
| POST | `/auth/login` | `{ "email": "...", "password": "..." }` |
| POST | `/auth/refresh` | `{ "refresh_token": "..." }` |
| GET | `/auth/me` | 로그인 직원 정보 |
| POST | `/auth/logout` | 해당 UID의 모든 세션 취소 |
| GET | `/dashboard` | 요약, 공지, 문의 알림, 최근 7일 차트 |
| GET | `/sales?start_date=2026-09-01&end_date=2026-09-30&period=day` | 매출 요약·차트·상위 상품 |
| GET | `/members?keyword=김&grade=vip&page=1&page_size=20` | 회원 검색·등급·페이지 |
| GET | `/members/detail?customer_id=member@example.com` | 회원 상세·최근 구매 |
| PATCH | `/members/grade?customer_id=member@example.com` | `{ "grade": "vip" }` |
| GET | `/reviews?status=reported&keyword=나이키` | 리뷰 검색·필터 |
| GET | `/reviews/{id}` | 리뷰 상세 |
| PATCH | `/reviews/{id}/status` | `{ "status": "hidden", "reason": "검토" }` |
| GET | `/inquiries?status=pending&keyword=배송` | 문의 검색·필터 |
| GET | `/inquiries/{id}` | 문의 상세 |
| PUT | `/inquiries/{id}/answer` | `{ "answer": "답변", "expected_answer": null }` |
| GET | `/ready` | 보호된 스키마 준비 상태 확인 |

- 회원 등급: `general`, `vip`. 등록되지 않은 등급은 `general`로 표시합니다. 금액으로 VIP를 자동 판정하지 않습니다.
- 리뷰 상태: `public`, `reported`, `hidden`. 기록이 없으면 `public`. 기존 신고 데이터를 임의로 생성하지 않습니다. 공개/숨김 처리는 원본을 보존하는 보조 테이블 수정입니다. 고객 앱에서도 숨김 리뷰를 제외하려면 이 상태 테이블을 조회하는 API를 사용해야 합니다. 기존 `review` 직접 조회 코드에는 자동 반영되지 않습니다.
- 문의 상태: `pending`, `answered`. 제목 컬럼이 없어 본문 첫 줄을 `title`로 제공합니다.
- 목록 응답: `{ "items": [...], "total": 30, "page": 1, "page_size": 20 }`. `page_size`는 1~100입니다.
- 매출 `period`: `day`, `week`, `month`. 월 선택 UI는 해당 월의 첫날/마지막날을 `start_date`, `end_date`로 전달합니다. 종료일을 포함하며 조회는 최대 731일입니다. 빈 날짜/주/월은 0으로 채웁니다. 주는 월요일 시작이며 주/월 첫 구간의 라벨은 요청 시작일 이전일 수 있지만 금액은 요청 범위 내 데이터만 포함합니다.
- 리뷰/문의 `id`는 목록에서 제공한 문자열을 그대로 사용합니다. 리뷰는 `(회원, 상품, 리뷰번호)`, 문의는 `(회원, 본사ID, 문의번호)` 전체 키로 한 건만 수정합니다. 표시용 `RV-...`나 `INQ-...` 목업 번호를 DB 키로 사용하지 않습니다.
- 기존 답변을 수정할 때 `expected_answer`에 상세 API의 `c_answer`를 전달하세요. 다른 관리자가 이미 수정했다면 409를 반환합니다. 해당 값을 생략하면 기존 답변이 없는 문의만 저장할 수 있습니다. DB `c_answer`의 실제 컬럼 길이보다 긴 답변은 422를 반환합니다.

로그인/갱신은 `access_token`, `refresh_token`, `token_type`, `expires_in`, `admin`을 반환합니다. Firebase 토큰 검증은 [공식 ID 토큰 검증 방식](https://firebase.google.com/docs/auth/admin/verify-id-tokens)을 따르며 취소 확인도 수행합니다. 로그아웃 성공 후 Flutter는 로컬 토큰도 삭제해야 합니다. 로그인/갱신은 프로세스별 IP당 분당 10회 제한이며, 여러 워커/인스턴스를 운영할 때는 프록시나 Redis의 공통 제한을 추가해야 합니다.

## 기존 스키마의 한계

1. `purchase.p_price`는 행별 **결제금액**으로 합산합니다. SQL 설계에서 금액이 VARCHAR일 수 있으므로 실제 DB 타입과 값이 숫자인지 확인해야 합니다. 가격이 단가라면 수량 컬럼과 함께 집계식을 수정해야 합니다. 주문 수는 구매 **행 수**이며 결제번호별 주문 수가 아닙니다. 환불 차감 전 매출입니다.
2. `purchase`에는 대리점 FK가 없어 매장별 매출을 반환하지 않습니다. 동일 회원의 최신 `pickup`에 구매 전체를 조인하면 매출 지점이 잘못 배정되므로 사용하지 않았습니다.
3. 재고 문서의 실제 필드·상태와 주문 상태 매핑을 확인하지 못해 `available_inventory`, `ongoing_orders`는 `null`입니다. `attention_count`와 알림은 실제 미답변 문의 수만 반영합니다.
4. `purchase.p_date`, `review.r_date`, `contact.c_date` 등 기존 DATETIME은 **Asia/Seoul의 로컬 시각**으로 저장된다는 계약입니다. MySQL 연결은 `+09:00` 세션을 사용합니다. 기존 DB가 UTC DATETIME을 사용하면 기간 경계 변환을 수정해야 합니다.
5. 등급·리뷰 상태·감사 로그는 각각 `hq_member_metadata`, `hq_review_moderation`, `hq_audit_log`에 저장합니다. 관리 변경과 감사 로그는 같은 MySQL 트랜잭션으로 처리합니다. Firestore와 MySQL 사이의 분산 트랜잭션은 수행하지 않습니다. 현재 API는 Firebase 프로필을 읽기만 합니다.
6. 스키마 점검은 필수 테이블/컬럼 존재를 확인하며, 모든 타입·FK·유일성·값의 유효성을 검증하는 마이그레이션 도구는 아닙니다. 기존 ERD와 코드의 컬럼명이 다를 수 있어 운영 연결 후 결과를 보고 SQL을 조정해야 합니다.

## Flutter 연결 예시

기존 `http` 패키지를 사용하면 됩니다. 화면은 기존 모델보다 많은 필드를 필요로 하므로 API JSON에 맞는 모델/컨트롤러를 추가해야 합니다. 현재 역할 선택 로그인은 인증 UI로 교체한 다음 인증 성공 시 본사 화면으로 이동하도록 연결해야 합니다.

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

final base = Uri.parse('http://127.0.0.1:8000/api/v1/headquarters/');
final response = await http.post(
  base.resolve('auth/login'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'email': email, 'password': password}),
).timeout(const Duration(seconds: 15));
if (response.statusCode != 200) {
  throw Exception(jsonDecode(response.body)['detail']);
}
final session = jsonDecode(response.body);
final dashboardResponse = await http.get(
  base.resolve('dashboard'),
  headers: {'Authorization': 'Bearer ${session['access_token']}'},
).timeout(const Duration(seconds: 15));
```

Android 에뮬레이터는 개발 PC를 `10.0.2.2`로 접근합니다. 실제 기기는 개발 PC의 LAN 주소와 접근 가능한 서버 바인딩이 필요합니다. Flutter Web은 `.env`의 `CORS_ORIGINS`에 실제 개발 origin을 넣어야 합니다. 배포 환경에서는 HTTPS 주소를 사용하세요. 비밀번호나 토큰을 SQLite/로그에 저장하지 말고 플랫폼 보안 저장소 등으로 세션 정책을 구현하세요.

## 테스트

```bash
.venv/bin/python -m pip install -r python/headquarters/requirements-dev.txt
.venv/bin/python -m pytest python/headquarters/tests -q
```

`mysqld`가 PATH에 있으면 운영 DB 환경변수와 무관한 **임시 MySQL 인스턴스**를 소켓 전용으로 실행해 테스트하며 종료 시 프로세스를 정리합니다. 없으면 MySQL 통합 테스트만 skip하고 인증 테스트는 실행합니다. 실제 Firebase 로그인·문서 조회 테스트는 자격 증명이 있어야 가능하므로 현재는 SDK/HTTP 응답을 대체해 권한·토큰 흐름을 검증합니다.
