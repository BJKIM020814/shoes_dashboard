import 'package:flutter_test/flutter_test.dart';
import 'package:bootcamp_shoe_store_admin_app/features/hq/data/hq_api.dart';
import 'package:bootcamp_shoe_store_admin_app/core/api/store_api.dart';

void main() {
  const live = bool.fromEnvironment('RUN_LIVE_API_TESTS');
  const password = String.fromEnvironment('DEMO_TEST_PASSWORD');
  test(
    'demo HQ employee logs in and reads protected orders',
    () async {
      final api = HqApi();
      await api.login('fitpick.hq.demo@example.com', password);
      expect(api.hasToken, isTrue);
      final orders = await api.get('/api/v1/headquarters/orders');
      expect(orders['items'], isA<List>());
      await api.post('/api/login/logout');
      api.clearToken();
    },
    skip: !live || password.isEmpty,
  );
  test(
    'tablet API clients reach actual LAN servers without changing data',
    () async {
      final api = HqApi();
      expect((await api.get('/health'))['status'], 'ok');
      await expectLater(
        api.get('/api/v1/headquarters/orders'),
        throwsA(
          isA<HqApiException>().having(
            (e) => e.statusCode,
            'unauthenticated status',
            401,
          ),
        ),
      );
      // The database has no registered dealer: 404 means server reached, not offline.
      await expectLater(
        StoreApi.instance.dashboard(),
        throwsA(
          isA<StoreApiException>().having(
            (e) => e.statusCode,
            'missing dealer',
            404,
          ),
        ),
      );
    },
    skip: !live,
  );
}
