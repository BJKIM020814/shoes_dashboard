import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bootcamp_shoe_store_admin_app/features/hq/data/hq_api.dart';

void main() {
  test(
    'login verifies employee access and sends the issued session token',
    () async {
      final requests = <http.Request>[];
      final api = HqApi(
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/api/login') {
            expect(jsonDecode(request.body)['password'], ' password ');
            return http.Response(
              jsonEncode({'accessToken': 'test-session'}),
              200,
            );
          }
          expect(request.headers['Authorization'], 'Bearer test-session');
          expect(request.url.path, '/api/v1/headquarters/orders');
          return http.Response('{"items":[],"total":0}', 200);
        }),
      );
      await api.login('staff@example.com', ' password ');
      expect(api.hasToken, isTrue);
      expect(requests.length, 2);
    },
  );

  test(
    'customer login cannot retain HQ session when employee access is denied',
    () async {
      final api = HqApi(
        client: MockClient(
          (request) async => request.url.path == '/api/login'
              ? http.Response('{"accessToken":"customer-session"}', 200)
              : http.Response.bytes(
                  utf8.encode('{"detail":"본사 직원 연결 필요"}'),
                  403,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                ),
        ),
      );
      await expectLater(
        api.login('customer@example.com', 'password'),
        throwsA(
          isA<HqApiException>()
              .having((e) => e.statusCode, 'status', 403)
              .having((e) => e.message, 'Korean message', '본사 직원 연결 필요'),
        ),
      );
      expect(api.hasToken, isFalse);
    },
  );

  test(
    'transport failure gives connection diagnostic rather than an empty result',
    () async {
      final api = HqApi(
        client: MockClient((request) async {
          throw http.ClientException('offline');
        }),
      );
      await expectLater(api.get('/health'), throwsA(isA<HqApiException>()));
    },
  );
}
