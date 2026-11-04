import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/lab2/attendance_actions.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/live_attendance.dart';
import 'package:lecturer_companion/lab2/repository.dart';
import 'package:lecturer_companion/lab2/theme.dart';
import 'refactor_live_test.dart' show LiveFixture;

class SwitchFixture extends LiveFixture {
  final updates = <Data>[];
  Completer<void>? pending;
  bool reject = false;
  final rows = <Data>[
    {
      'studentUid': 'u',
      'displayName': 'Nguyễn Mai Hảo Thiên',
      'studentCode': 'SE172145',
      'status': 'absent',
      'notes': 'Ghi chú của giảng viên',
    },
  ];
  SwitchFixture() {
    closed = true;
  }
  @override
  Future<Data> call(String name, Data input) async {
    if (name == 'updateAttendanceRecord') {
      updates.add(Map.of(input));
      await pending?.future;
      if (reject) throw StateError('unavailable');
      final row = rows.firstWhere(
        (r) => r['studentUid'] == input['studentUid'],
      );
      row['status'] = input['status'];
      row['notes'] = input['notes'];
      return {'updated': true};
    }
    final result = await super.call(name, input);
    if (name == 'getAttendanceSessionLive') {
      return {
        ...result,
        'students': [for (final row in rows) Map.of(row)],
        'counts': {
          for (final s in ['present', 'late', 'absent', 'excused', 'pending'])
            s: rows.where((r) => r['status'] == s).length,
        },
      };
    }
    return result;
  }
}

Finder get attendanceSwitch =>
    find.byKey(const ValueKey('attendance-switch/u'));
Future<void> showRoster(WidgetTester tester, SwitchFixture repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: campusTheme(Brightness.light),
        home: const LiveAttendancePage(sessionId: 's'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    attendanceSwitch,
    180,
    scrollable: find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'switch waits for server, prevents duplicate writes and keeps notes',
    (tester) async {
      final repo = SwitchFixture()..pending = Completer<void>();
      await showRoster(tester, repo);
      final change = tester.widget<Switch>(attendanceSwitch).onChanged!;
      change(true);
      change(true);
      await tester.pump();
      expect(repo.updates, hasLength(1));
      expect(repo.updates.single['notes'], 'Ghi chú của giảng viên');
      expect(repo.updates.single['attendanceSessionId'], 's');
      expect(tester.widget<Switch>(attendanceSwitch).value, false);
      expect(tester.widget<Switch>(attendanceSwitch).onChanged, isNull);
      repo.pending!.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(attendanceSwitch).value, true);
      await tester.tap(attendanceSwitch);
      await tester.pumpAndSettle();
      expect(repo.updates.last['status'], 'absent');
      expect(tester.widget<Switch>(attendanceSwitch).value, false);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'failed switch reconciles server state and does not claim success',
    (tester) async {
      final repo = SwitchFixture()..reject = true;
      repo.rows.single['notes'] = '';
      await showRoster(tester, repo);
      await tester.tap(attendanceSwitch);
      await tester.pumpAndSettle();
      expect(repo.updates.single['notes'], contains('Giảng viên xác nhận'));
      expect(tester.widget<Switch>(attendanceSwitch).value, false);
      expect(
        find.textContaining('Chưa xác nhận được kết quả lưu'),
        findsOneWidget,
      );
      expect(tester.widget<Switch>(attendanceSwitch).onChanged, isNotNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('stale roster disables switch and detailed editing', (
    tester,
  ) async {
    final repo = SwitchFixture();
    await showRoster(tester, repo);
    repo.fail = true;
    await tester.tap(find.byTooltip('Cập nhật phiên'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      attendanceSwitch,
      180,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(attendanceSwitch).onChanged, isNull);
    await tester.tap(find.text('Nguyễn Mai Hảo Thiên'));
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceEditDialog), findsNothing);
    expect(repo.updates, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('late stays present on switch and name opens detailed statuses', (
    tester,
  ) async {
    final repo = SwitchFixture();
    repo.rows.single['status'] = 'late';
    await showRoster(tester, repo);
    expect(tester.widget<Switch>(attendanceSwitch).value, true);
    expect(repo.updates, isEmpty);
    await tester.tap(find.text('Nguyễn Mai Hảo Thiên'));
    await tester.pumpAndSettle();
    expect(find.byType(AttendanceEditDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AttendanceEditDialog),
        matching: find.widgetWithText(ChoiceChip, 'Đi trễ'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AttendanceEditDialog),
        matching: find.widgetWithText(ChoiceChip, 'Vắng có phép'),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  for (final brightness in Brightness.values) {
    testWidgets('student dialog uses app surface in $brightness', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: campusTheme(brightness),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const AlertDialog(
                    title: Text('Thông tin sinh viên'),
                    content: Text('PRM393 · Slot 4'),
                  ),
                ),
                child: const Text('Mở'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở'));
      await tester.pumpAndSettle();
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, campusTheme(brightness).colorScheme.surface);
      expect(material.surfaceTintColor, Colors.transparent);
    });
  }
}
