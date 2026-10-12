import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'lab2/app.dart';
import 'lab2/theme.dart';
import 'lab2/desktop_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    const env = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    const emulator = bool.fromEnvironment('USE_EMULATORS');
    const project = String.fromEnvironment('FIREBASE_PROJECT_ID');
    if (useSharedDesktop &&
        (emulator ||
            !DesktopSync.validEndpoint(
              const String.fromEnvironment('APPS_SCRIPT_URL'),
            ))) {
      throw StateError(
        'Cấu hình dữ liệu Desktop chưa hợp lệ. Dùng config/lab2.free.json.',
      );
    }
    if (env == 'prod' && emulator) {
      throw StateError('Production không được dùng emulator.');
    }
    if (project.isEmpty) {
      throw StateError(
        'Chưa cấu hình Firebase. Chạy bằng config/lab2.emulator.json hoặc cấu hình project thật.',
      );
    }
    const api = String.fromEnvironment('FIREBASE_API_KEY'),
        app = String.fromEnvironment('FIREBASE_APP_ID'),
        sender = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    if (!emulator && (api.isEmpty || app.isEmpty || sender.isEmpty)) {
      throw StateError('Thiếu Firebase Android config.');
    }
    if (emulator && !project.startsWith('demo-')) {
      throw StateError('Emulator yêu cầu project ID demo-.');
    }
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: emulator ? 'emulator-only-api-key' : api,
        appId: emulator ? '1:123456789:android:emulator' : app,
        messagingSenderId: emulator ? '123456789' : sender,
        projectId: project,
      ),
    );
    if (emulator) {
      const host = String.fromEnvironment(
        'EMULATOR_HOST',
        defaultValue: '10.0.2.2',
      );
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).useFunctionsEmulator(host, 5001);
    }
    runApp(const ProviderScope(child: CampusApp()));
  } catch (error) {
    runApp(
      MaterialApp(
        theme: campusTheme(Brightness.light),
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: SelectableText(
                  'Cần cấu hình FAP Smart Lecturer\n\n$error',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
