import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:samsung_iap_flutter_example/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E', () {
    testWidgets('getPlatformName', (tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get Platform Name'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Platform Name: Android'), findsOneWidget);
    });
  });
}
