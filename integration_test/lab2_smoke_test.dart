import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lecturer_companion/main.dart' as app;
import 'package:lecturer_companion/lab2/repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android Firebase lecturer/student SDK flow', (tester) async {
    const emulator = bool.fromEnvironment('USE_EMULATORS');
    expect(emulator, true, reason: 'Integration smoke test is emulator-only.');
    await app.main();
    const password = String.fromEnvironment(
      'DEMO_PASSWORD',
      defaultValue: 'EmulatorOnly123!',
    );
    final auth = FirebaseAuth.instance, repo = CampusRepository();
    await auth.signInWithEmailAndPassword(
      email: 'lecturer.a@example.test',
      password: password,
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    final lesson = await repo.call('createClassSession', {
      'classId': 'class-0',
      'title': 'Android SDK integration',
    });
    final session = await repo.call('openAttendanceSession', {
      'classSessionId': lesson['classSessionId'],
      'durationMinutes': 10,
      'lateAfterMinutes': 5,
    });
    final qr = await repo.call('getQrToken', {
      'attendanceSessionId': session['attendanceSessionId'],
    });
    await auth.signOut();
    await auth.signInWithEmailAndPassword(
      email: 'student.0@example.test',
      password: password,
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Điểm danh'), findsWidgets);
    final checkedIn = await repo.call('checkInWithQr', {'token': qr['token']});
    expect(['present', 'late'], contains(checkedIn['status']));
    final record = await repo.serverRecord(
      'attendanceRecords/${session['attendanceSessionId']}_${auth.currentUser!.uid}',
    );
    expect(record?['status'], checkedIn['status']);
    await auth.signOut();
    await auth.signInWithEmailAndPassword(
      email: 'lecturer.a@example.test',
      password: password,
    );
    await repo.call('closeAttendanceSession', {
      'attendanceSessionId': session['attendanceSessionId'],
    });
    await auth.signOut();
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Đăng nhập'), findsOneWidget);
  });
}
