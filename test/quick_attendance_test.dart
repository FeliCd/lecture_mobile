import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/lab2/attendance_reminders.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/quick_attendance.dart';
import 'package:lecturer_companion/lab2/repository.dart';
import 'package:lecturer_companion/lab2/timetable_domain.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lab2_navigation_test.dart' show FixtureRepository;

const selector = {
  'classId': 'c1',
  'sessionDate': '2026-10-19',
  'slot': 2,
  'scheduleId': 's1',
  'exceptionId': '',
};

class QuickFixture extends FixtureRepository {
  final calls = <Data>[];
  int size;
  String state = 'AVAILABLE', status = '';
  Map<int, String> existing = {};
  Object? failSubmit;
  Completer<Data>? pending;
  QuickFixture({this.size = 40});

  Data context() => {
    'classId': 'c1',
    'classCode': 'SE1928',
    'subjectId': 'PRM393',
    'subjectName': 'Lập trình di động',
    'sessionDate': '2026-10-19',
    'slot': 2,
    'room': 'A201',
    'state': state,
    'status': status,
    'editable': state == 'AVAILABLE' || state == 'OPEN',
    'revision': status.isEmpty ? '' : 'rev-1',
    if (status.isNotEmpty) 'sessionId': 'sess-1',
    if (status == 'CLOSED') 'savedAt': 1792384200000,
    'students': [
      for (var i = 1; i <= size; i++)
        {
          'studentId': 'st$i',
          'studentCode': 'SE${i.toString().padLeft(3, '0')}',
          'displayName': 'Sinh viên ${i.toString().padLeft(2, '0')}',
          'status': existing[i],
        },
    ],
  };

  @override
  Future<void> refreshData() async {}

  @override
  Future<Data> call(String name, Data input) async {
    calls.add({'name': name, ...input});
    if (name == 'getQuickAttendanceContext') return context();
    if (name == 'submitQuickAttendance') {
      if (pending != null) return pending!.future;
      if (failSubmit != null) throw failSubmit!;
      state = 'CLOSED';
      status = 'CLOSED';
      final ex = {
        for (final e in input['exceptions'] as List)
          (e as Map)['studentId']: '${e['status']}'.toLowerCase(),
      };
      existing = {
        for (var i = 1; i <= size; i++)
          i: ex['st$i'] ?? existing[i] ?? 'present',
      };
      return {'status': 'CLOSED', 'alreadySaved': false, 'sessionId': 'sess-1'};
    }
    return super.call(name, input);
  }

  int count(String name) => calls.where((c) => c['name'] == name).length;
}

Future<void> pumpPage(WidgetTester tester, QuickFixture repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(c).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const QuickAttendancePage(
                      selector: selector,
                      uid: 'lecturer-1',
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> tapStudent(WidgetTester tester, String name) async {
  final row = find.text(name);
  final list = find.descendant(
    of: find.byType(CustomScrollView),
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(row, 120, scrollable: list.first);
  // The previous change's snackbar may overlap the bottom rows.
  ScaffoldMessenger.of(tester.element(row)).removeCurrentSnackBar();
  await tester.pumpAndSettle();
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

Future<void> toTop(WidgetTester tester) async {
  await tester.drag(find.byType(CustomScrollView), const Offset(0, 3000));
  await tester.pumpAndSettle();
}

Future<void> reviewAndSave(WidgetTester tester) async {
  await tester.tap(find.text('Xem lại'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Xác nhận và lưu'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('opening shows a PRESENT draft and never submits anything', (
    tester,
  ) async {
    final repo = QuickFixture();
    await pumpPage(tester, repo);
    expect(
      find.text('Đang chọn Có mặt cho toàn bộ lớp — chưa lưu'),
      findsOneWidget,
    );
    expect(find.text('Có mặt: 40'), findsOneWidget);
    expect(find.textContaining('Sĩ số 40'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(repo.count('submitQuickAttendance'), 0);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('40 students, 2 absent: two taps, review summary, one save', (
    tester,
  ) async {
    final repo = QuickFixture();
    await pumpPage(tester, repo);
    await tapStudent(tester, 'Sinh viên 03');
    await tapStudent(tester, 'Sinh viên 17');
    expect(find.text('Vắng: 2'), findsOneWidget);
    await tester.tap(find.text('Xem lại'));
    await tester.pumpAndSettle();
    expect(find.text('40 sinh viên: 38 Có mặt, 2 Vắng'), findsOneWidget);
    await tester.tap(find.text('Xác nhận và lưu'));
    await tester.pumpAndSettle();
    final submit = repo.calls.singleWhere(
      (c) => c['name'] == 'submitQuickAttendance',
    );
    expect(submit['studentIds'], hasLength(40));
    expect(submit['exceptions'], [
      {'studentId': 'st3', 'status': 'ABSENT'},
      {'studentId': 'st17', 'status': 'ABSENT'},
    ]);
    expect(submit['slot'], 2);
    expect(find.textContaining('Đã hoàn tất'), findsWidgets);
    expect(find.text('Xem lại'), findsNothing);
  });

  testWidgets('full class is confirmed without touching any student', (
    tester,
  ) async {
    final repo = QuickFixture();
    await pumpPage(tester, repo);
    await tester.tap(find.text('Xem lại'));
    await tester.pumpAndSettle();
    expect(find.text('40 sinh viên: 40 Có mặt'), findsOneWidget);
    expect(find.text('Không có ngoại lệ: toàn bộ lớp Có mặt.'), findsOneWidget);
    await tester.tap(find.text('Xác nhận và lưu'));
    await tester.pumpAndSettle();
    expect(
      repo.calls.last['name'] == 'getQuickAttendanceContext' &&
          repo.count('submitQuickAttendance') == 1,
      isTrue,
    );
  });

  testWidgets('undo and the exceptions filter keep choices of hidden rows', (
    tester,
  ) async {
    final repo = QuickFixture(size: 8);
    await pumpPage(tester, repo);
    await tapStudent(tester, 'Sinh viên 02');
    await tapStudent(tester, 'Sinh viên 05');
    await tester.tap(find.text('Hoàn tác'));
    await tester.pumpAndSettle();
    expect(find.text('Vắng: 1'), findsOneWidget);
    await toTop(tester);
    await tester.tap(find.text('Ngoại lệ (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Sinh viên 02'), findsOneWidget);
    expect(find.text('Sinh viên 01'), findsNothing);
    await tester.tap(find.text('Tất cả (8)'));
    await tester.pumpAndSettle();
    expect(find.text('Vắng: 1'), findsOneWidget);
  });

  testWidgets('save error keeps the draft and never shows success', (
    tester,
  ) async {
    final repo = QuickFixture(size: 5)..failSubmit = StateError('unavailable');
    await pumpPage(tester, repo);
    await tapStudent(tester, 'Sinh viên 04');
    await reviewAndSave(tester);
    expect(find.text('Lưu chưa thành công — chưa hoàn tất'), findsOneWidget);
    expect(find.textContaining('Bản nháp vẫn được giữ'), findsOneWidget);
    expect(find.textContaining('Đã hoàn tất'), findsNothing);
    expect(find.text('Vắng: 1'), findsOneWidget);
    expect(find.text('Kiểm tra và thử lại'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().where((k) => k.startsWith('quickAttendance/')),
      isNotEmpty,
    );
    // Retry first checks the server, then sends the same draft.
    repo.failSubmit = null;
    await tester.tap(find.text('Kiểm tra và thử lại'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận và lưu'));
    await tester.pumpAndSettle();
    expect(repo.count('submitQuickAttendance'), 2);
    expect(find.textContaining('Đã hoàn tất'), findsWidgets);
    expect(
      prefs.getKeys().where((k) => k.startsWith('quickAttendance/')),
      isEmpty,
    );
  });

  testWidgets(
    'uncertain retry on a lesson closed by someone else keeps the draft',
    (tester) async {
      final repo = QuickFixture(size: 4)
        ..failSubmit = StateError('unavailable');
      await pumpPage(tester, repo);
      await tapStudent(tester, 'Sinh viên 02');
      await reviewAndSave(tester);
      expect(find.text('Kiểm tra và thử lại'), findsOneWidget);
      // Meanwhile the QR session was finalized with a different result.
      repo.failSubmit = StateError('ATTENDANCE_ALREADY_FINALIZED');
      await tester.tap(find.text('Kiểm tra và thử lại'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận và lưu'));
      await tester.pumpAndSettle();
      expect(repo.count('submitQuickAttendance'), 2);
      expect(find.textContaining('Đã hoàn tất'), findsNothing);
      expect(find.text('Vắng: 1'), findsOneWidget);
      expect(
        find.textContaining('Buổi này đã hoàn tất điểm danh'),
        findsOneWidget,
      );
    },
  );

  testWidgets('conflict asks to reload and re-applies the lecturer choices', (
    tester,
  ) async {
    final repo = QuickFixture(size: 5)
      ..failSubmit = StateError('ATTENDANCE_CONFLICT');
    await pumpPage(tester, repo);
    await tapStudent(tester, 'Sinh viên 02');
    await reviewAndSave(tester);
    expect(find.text('Tải lại và đối soát'), findsOneWidget);
    repo.failSubmit = null;
    await tester.tap(find.text('Tải lại và đối soát'));
    await tester.pumpAndSettle();
    expect(find.text('Vắng: 1'), findsOneWidget);
    expect(find.text('Xem lại'), findsOneWidget);
  });

  testWidgets('sending blocks a second submit', (tester) async {
    final repo = QuickFixture(size: 3)..pending = Completer<Data>();
    await pumpPage(tester, repo);
    await tester.tap(find.text('Xem lại'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận và lưu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Đang gửi…'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Đang gửi…'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
    repo.pending!.complete({'status': 'CLOSED'});
    repo.status = 'CLOSED';
    repo.state = 'CLOSED';
    await tester.pumpAndSettle();
    expect(repo.count('submitQuickAttendance'), 1);
  });

  testWidgets('completed lesson shows official results, read-only', (
    tester,
  ) async {
    final repo = QuickFixture(size: 3)
      ..state = 'CLOSED'
      ..status = 'CLOSED'
      ..existing = {1: 'present', 2: 'absent', 3: 'late'};
    await pumpPage(tester, repo);
    expect(find.textContaining('Đã hoàn tất lúc'), findsOneWidget);
    expect(find.text('Xem lại'), findsNothing);
    expect(find.text('Vắng: 1'), findsOneWidget);
    expect(find.text('Đi trễ: 1'), findsOneWidget);
    expect(repo.count('submitQuickAttendance'), 0);
  });

  testWidgets('existing QR results are shown, not reset to PRESENT', (
    tester,
  ) async {
    final repo = QuickFixture(size: 3)
      ..state = 'OPEN'
      ..status = 'OPEN'
      ..existing = {1: 'late'};
    await pumpPage(tester, repo);
    expect(find.text('Đi trễ: 1'), findsOneWidget);
    expect(find.textContaining('kết quả đã ghi nhận'), findsOneWidget);
    await reviewAndSave(tester);
    final submit = repo.calls.singleWhere(
      (c) => c['name'] == 'submitQuickAttendance',
    );
    expect(submit['exceptions'], isEmpty);
    expect(submit['expectedRevision'], 'rev-1');
  });

  testWidgets('leaving an unsaved draft offers continue, keep or discard', (
    tester,
  ) async {
    final repo = QuickFixture(size: 4);
    await pumpPage(tester, repo);
    await tapStudent(tester, 'Sinh viên 01');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Điểm danh chưa được lưu'), findsOneWidget);
    await tester.tap(find.text('Tiếp tục chỉnh'));
    await tester.pumpAndSettle();
    expect(find.text('Vắng: 1'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giữ bản nháp'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    // Reopening restores the kept draft for the same lesson.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Bản nháp đã khôi phục — chưa lưu'), findsOneWidget);
    expect(find.text('Vắng: 1'), findsOneWidget);
    expect(repo.count('submitQuickAttendance'), 0);
  });

  testWidgets('360dp with 200% text has no overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpPage(tester, QuickFixture(size: 12));
    expect(tester.takeException(), isNull);
    await tapStudent(tester, 'Sinh viên 01');
    expect(tester.takeException(), isNull);
  });

  group('F02 reminders', () {
    TeachingPeriod lesson({
      bool completed = false,
      bool cancelled = false,
      int start = 7 * 60 + 30,
      int end = 9 * 60 + 50,
      int slot = 1,
    }) => TeachingPeriod(
      day: DateTime.utc(2026, 10, 19),
      classId: 'c1',
      sessionId: null,
      scheduleId: 's$slot',
      exceptionId: '',
      classCode: 'SE1928',
      subjectId: 'PRM393',
      subjectName: 'Mobile',
      room: 'A201',
      term: 'FA26',
      slot: slot,
      start: start,
      end: end,
      recurring: true,
      completed: completed,
      cancelled: cancelled,
    );
    // 07:00 Vietnam time on 19/10.
    final morning = DateTime.utc(2026, 10, 19, 0);

    test('plans a schedule reminder and a not-finished reminder', () {
      final plan = planAttendanceReminders([lesson()], morning);
      expect(plan.map((r) => r.title), [
        'Sắp đến giờ dạy',
        'Điểm danh chưa hoàn tất',
      ]);
      expect(plan.first.at, DateTime.utc(2026, 10, 19, 0, 20));
      expect(plan.last.at, DateTime.utc(2026, 10, 19, 2, 40));
      expect(
        plan.last.body,
        'Lớp SE1928 · Slot 1 · Phòng A201 sắp kết thúc. Điểm danh chưa hoàn tất.',
      );
      expect(plan.last.selector['slot'], 1);
    });

    test('completed or cancelled lessons produce no reminders', () {
      expect(
        planAttendanceReminders([
          lesson(completed: true),
          lesson(cancelled: true, slot: 2),
        ], morning),
        isEmpty,
      );
    });

    test('two slots of one class on one day have distinct targets', () {
      final plan = planAttendanceReminders([
        lesson(),
        lesson(slot: 3, start: 12 * 60 + 50, end: 15 * 60 + 10),
      ], morning);
      final keys = plan.map((r) => r.key).toSet();
      expect(keys, hasLength(4));
      expect(plan.map((r) => r.selector['slot']).toSet(), {1, 3});
    });

    test('pending list holds ended, unfinished lessons only', () {
      // 09:00: slot 1 (07:30–09:50) is still in progress, not pending yet.
      expect(
        pendingAttendancePeriods([lesson()], DateTime.utc(2026, 10, 19, 2)),
        isEmpty,
      );
      // 10:00: slot 1 ended without completion; slot 3 has not ended.
      final at9 = DateTime.utc(2026, 10, 19, 3);
      final pending = pendingAttendancePeriods([
        lesson(),
        lesson(completed: true, slot: 2),
        lesson(slot: 3, start: 12 * 60 + 50, end: 15 * 60 + 10),
      ], at9);
      expect(pending.map((p) => p.slot), [1]);
    });
  });
}
