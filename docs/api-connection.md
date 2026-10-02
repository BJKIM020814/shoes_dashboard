# 앱 API 연결 점검

사용자 모바일 앱의 세 클라이언트(ApiClient, FitpickApiService, DiscoverApi)는 같은 서버를 사용해야 합니다. 기본 주소를 `http://192.168.20.68:8000`으로 통일했습니다. `.env`는 Python 서버용이며 Flutter 앱의 서버 주소는 `--dart-define`으로 지정합니다.

현재 8000 포트의 실행 앱은 별도 사용자 저장소의 `python.fastapi.main:app`입니다. Swagger의 제목은 `FITPICK 페이지 API`이며 고객 API와 `/api/v1/headquarters/orders` 등 본사 라우터를 포함합니다. 관리자 저장소의 `python.headquarters.main:app`는 Firebase ID 토큰을 사용하는 다른 API 계약입니다. 그 서버의 `/auth/login` 토큰은 현재 8000 서버의 고객 세션 토큰과 호환되지 않습니다.

관리자 앱은 `/api/login`으로 세션을 발급받고 `/api/v1/headquarters/orders?limit=1`을 통해 직원 권한을 확인한 뒤 진입합니다. 로그인 이메일에 대응하는 `employee.email`을 서버 관리자가 확인해 연결해야 합니다. 계정 연결이 없는 고객은 403이며 관리자 권한을 얻지 않습니다. 기존 직원 문서는 보존했고, 개발용 `FITPICK-DEMO-HQ` 직원 문서를 별도로 연결했습니다.

개발 테스트 계정은 고객 `fitpick.customer.demo@example.com`, 본사 `fitpick.hq.demo@example.com`입니다. `[DEMO]` 이름과 `FITPICK-DEMO-HQ` 직원 ID로 구별합니다. 비밀번호는 생성 시 전달한 개발용 값이며 Firestore에는 해시로 저장됩니다. 사용자 저장소의 `tool/seed_connection_demo.py`를 `FITPICK_DEMO_PASSWORD` 환경변수와 함께 실행하면 기존 테스트 계정은 덮어쓰지 않고 확인합니다. MySQL customer에는 명시적인 테스트 나이 25를 사용합니다.

```sh
# 사용자 앱 (Bootcamp_TeamProject_1)
flutter run --dart-define=API_BASE_URL=http://192.168.20.68:8000
# 관리자 앱
flutter run --dart-define=HQ_API_BASE_URL=http://192.168.20.68:8000 --dart-define=STORE_API_BASE=http://192.168.20.68:8100
# 대리점 서버 (관리자 저장소 루트, 기존 Python 의존성 설치 후)
python -m uvicorn python.store_api.main:app --host 0.0.0.0 --port 8100
```

실기기는 서버와 같은 LAN에 연결되어야 하며 iOS 로컬 네트워크 접근 요청을 허용해야 합니다. Android 개발 HTTP 허용 대상은 `192.168.20.68`입니다. 기본 dealerSeq=1이지만 실제 DB에 등록된 지점이 없으므로 대리점 대시보드는 404를 반환합니다. 지점 데이터 등록 후 실제 ID를 `STORE_DEALER_SEQ`에 지정하세요.

실데이터 변경 없이 실행하는 연결 테스트:

```sh
flutter test --dart-define=RUN_LIVE_API_TESTS=true test/live_api_connection_test.dart
```

사용자 앱에도 동일한 테스트 파일이 있습니다. 조회 테스트는 health, 상품 조회 및 인증 오류를 확인합니다. 관리자 테스트는 본사 미인증 401과 실제 미등록 지점 404를 확인합니다. `--dart-define=DEMO_TEST_PASSWORD=<개발용비밀번호>`를 추가하면 개발 테스트 계정의 실제 로그인·보호된 조회·로그아웃도 검증합니다.

기존 일반 회원가입은 age 미입력 시 필수 정수 컬럼에 빈 문자열을 넣으려 하므로 MySQL 회원 연결이 지연될 수 있습니다. 이 부분은 연결 주소와 별개인 기존 스키마/입력 계약 문제이며 테스트 계정은 나이를 명시해 생성했습니다.
