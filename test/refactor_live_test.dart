import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/repository.dart';
import 'package:lecturer_companion/lab2/live_attendance.dart';
import 'package:lecturer_companion/lab2/today.dart';
import 'lab2_navigation_test.dart' show FixtureRepository;

class LiveFixture extends FixtureRepository {
  final calls = <String>[];
  bool fail = false, closed = false;
  String? failureCode;
  @override
  Future<Data> call(String name, Data input) async {
    calls.add(name);
    if (fail) throw StateError(failureCode ?? 'unavailable');
    if (name == 'getQrToken') {
      return {
        'token': 'https://example.com/qr',
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 1))
            .millisecondsSinceEpoch,
        'secretEnabled': false,
      };
    }
    return {
      'sessionId': 's',
      'classId': 'c',
      'classCode': 'SE1',
      'subjectName': 'Mobile',
      'slot': 1,
      'status': closed ? 'CLOSED' : 'OPEN',
      'expiresAt': DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String(),
      'serverTime': DateTime.now().toIso8601String(),
      'counts': {
        'eligible': 1,
        'present': 0,
        'late': 0,
        'pending': 1,
        'absent': 0,
        'excused': 0,
      },
      'students': [
        {
          'studentUid': 'u',
          'displayName': 'Student',
          'studentCode': 'SE1',
          'status': 'pending',
          'notes': '',
        },
      ],
    };
  }
}

void main() {
  testWidgets('fullscreen QR is removed immediately after access is revoked', (
    tester,
  ) async {
    final repo = LiveFixture();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: LiveAttendancePage(sessionId: 's')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('QR toàn màn hình'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.byTooltip('Trở lại điểm danh'), findsOneWidget);
    repo.fail = true;
    repo.failureCode = 'PERMISSION_DENIED';
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.byTooltip('Trở lại điểm danh'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'ownership denial clears cached roster and stops automatic requests',
    (tester) async {
      final repo = LiveFixture();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: LiveAttendancePage(sessionId: 's')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sinh viên'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('Student'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Student'), findsOneWidget);
      repo.fail = true;
      repo.failureCode = 'PERMISSION_DENIED';
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      expect(find.textContaining('Student'), findsNothing);
      final requests = repo.calls.length;
      await tester.pump(const Duration(seconds: 60));
      expect(repo.calls.length, requests);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'focused polling pauses in background, reports stale errors and stops after close',
    (tester) async {
      final repo = LiveFixture();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: LiveAttendancePage(sessionId: 's')),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        repo.calls.where((n) => n == 'getAttendanceSessionLive').length,
        1,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 20));
      expect(
        repo.calls.where((n) => n == 'getAttendanceSessionLive').length,
        1,
      );
      repo.fail = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Số liệu bên dưới có thể đã cũ'),
        findsOneWidget,
      );
      repo.fail = false;
      repo.closed = true;
      await tester.tap(find.byTooltip('Cập nhật phiên'));
      await tester.pumpAndSettle();
      final count = repo.calls.length;
      await tester.pump(const Duration(seconds: 30));
      expect(repo.calls.length, count);
      expect(find.text('Đã kết thúc'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('opening Today never creates an attendance session', (
    tester,
  ) async {
    final repo = LiveFixture();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(
            body: TodayPanel(
              user: const UserProfile('u', 'Teacher', 'lecturer', ['PRM393']),
              onTimetable: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
    expect(find.textContaining('Hôm nay không có lịch dạy'), findsOneWidget);
  });
}
