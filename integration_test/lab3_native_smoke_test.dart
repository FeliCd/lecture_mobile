import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:lecturer_companion/cloud/push_notifications.dart';
import 'package:lecturer_companion/cloud/cloud_services.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Lab3 Android loads native Firebase SDKs and fetches published Remote Config without changing attendance',
    (tester) async {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: pushFirebaseOptions());
      }
      final originalUid = FirebaseAuth.instance.currentUser?.uid;
      expect(Firebase.app().options.projectId, 'fap-attendance-88920');
      final settings = await FirebaseRemoteSettings().refresh();
      expect(settings.updatesEnabled, true);
      expect(settings.pageSize, 20);
      final remote = FirebaseRemoteConfig.instance;
      expect(
        remote.getValue('subject_updates_enabled').source,
        ValueSource.valueRemote,
      );
      expect(
        remote.getValue('subject_updates_page_size').source,
        ValueSource.valueRemote,
      );
      // Read permission status only; no permission dialog, token output, crash or message sent.
      final permission = await FirebaseMessaging.instance
          .getNotificationSettings();
      expect(permission.authorizationStatus, isNotNull);
      expect(
        FirebaseCrashlytics.instance.isCrashlyticsCollectionEnabled,
        isA<bool>(),
      );
      expect(FirebaseAuth.instance.currentUser?.uid, originalUid);
    },
  );
}
