import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:lecturer_companion/main.dart' as app;
import 'package:lecturer_companion/lab2/desktop_sync.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'free Android uses real Firebase Auth and deployed shared backend',
    (tester) async {
      expect(useSharedDesktop, isTrue);
      expect(quizEnabled, isFalse);
      await app.main();
      expect(Firebase.app().options.projectId, 'fap-attendance-88920');
      // Sign out synthetic credentials left by a previous emulator demo.
      // This test never creates accounts or changes workbook attendance.
      await FirebaseAuth.instance.signOut();
      await tester.pumpAndSettle();
      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(
        find.text('Dùng chung dữ liệu lớp học với Desktop.'),
        findsOneWidget,
      );
      expect(
        find.text('Đăng ký bằng email đã có trong Desktop'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNWidgets(2));
      final probe = DesktopSync(
        endpoint: const String.fromEnvironment('APPS_SCRIPT_URL'),
        token: () async => '',
        identity: () => null,
      );
      final health = await probe.request('lab2Health');
      expect(health['version'], 'lab2-shared-sheets-v1');
      expect(health['authConfigured'], isTrue);
      expect(health['openAlexConfigured'], isTrue);
      expect(health['quizEnabled'], isFalse);
      await probe.dispose();
    },
  );
}
