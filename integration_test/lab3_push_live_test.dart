// Explicit live self-test: sends one fixed demo notification to this device.
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:lecturer_companion/cloud/push_notifications.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Live FCM accepts and delivers a new demo message to signed-in device',
    (tester) async {
      expect(
        const bool.fromEnvironment('ENABLE_LAB3_DEMO'),
        isTrue,
        reason: 'Run explicitly with ENABLE_LAB3_DEMO=true.',
      );
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: pushFirebaseOptions());
      }
      // Wait for native Auth restoration rather than reading currentUser during startup.
      final user = await FirebaseAuth.instance.authStateChanges().first.timeout(
        const Duration(seconds: 15),
      );
      final uid = user?.uid;
      expect(
        uid,
        isNotNull,
        reason: 'Sign in to the demo app before running this test.',
      );
      final received = Completer<RemoteMessage>();
      final started = DateTime.now();
      final sub = FirebaseMessaging.onMessage.listen((message) {
        if (!received.isCompleted &&
            message.data['recipientUid'] == uid &&
            message.notification?.title == 'Thông báo thử Lab 3' &&
            message.sentTime != null &&
            message.sentTime!.isAfter(
              started.subtract(const Duration(seconds: 2)),
            )) {
          received.complete(message);
        }
      });
      try {
        final token = await PushNotifications.instance.testToken();
        expect(token, isNotNull);
        final result =
            await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
                .httpsCallable('sendLab3DemoPush')
                .call<Map<String, dynamic>>({'token': token});
        expect(result.data['accepted'], isTrue);
        final message = await received.future.timeout(
          const Duration(seconds: 45),
        );
        expect(message.messageId, isNotEmpty);
        expect(pushDestination(message.data), '/settings');
        expect(FirebaseAuth.instance.currentUser?.uid, uid);
      } finally {
        await sub.cancel();
      }
    },
  );
}
