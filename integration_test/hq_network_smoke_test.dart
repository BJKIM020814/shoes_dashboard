import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:integration_test/integration_test.dart';
import 'package:bootcamp_shoe_store_admin_app/features/hq/data/hq_api.dart';
import 'package:bootcamp_shoe_store_admin_app/features/hq/hq_shell_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const email = String.fromEnvironment('HQ_TEST_EMAIL');
  const password = String.fromEnvironment('HQ_TEST_PASSWORD');

  testWidgets('iPad app reaches the configured HQ API', (tester) async {
    final health = await HqApi.instance.get('/health');
    expect(health['status'], 'ok');
  });

  testWidgets(
    'HQ lists render rows returned by the live API',
    (tester) async {
      await HqApi.instance.login(email, password);
      await tester.pumpWidget(
        MaterialApp(home: HqShellPage(dark: false, onThemeChanged: () {})),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 30),
      );

      Future<void> openList(String label, int expectedRows) async {
        await tester.tap(find.text(label).first);
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 30),
        );
        final table = tester.widget<DataTable>(find.byType(DataTable));
        expect(table.rows, hasLength(expectedRows), reason: label);
      }

      await openList('회원 관리', 9);
      await openList('리뷰 관리', 5);
      await openList('문의 관리', 4);
      await openList('계약 관리', 5);
    },
    skip: email.isEmpty || password.isEmpty,
  );
}
