import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/lab2/class_attendance_overview.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/repository.dart';

void main() {
  test('absence warnings respect 15%, exact 20%, exceeded and excused', () {
    AttendanceSummary summary(int absent, int present) => AttendanceSummary([
      ...List.filled(absent, 'absent'),
      ...List.filled(present, 'present'),
    ]);
    expect(summary(0, 0).absenceRate, isNull);
    expect(summary(1, 9).nearAbsenceLimit, false);
    expect(summary(3, 17).nearAbsenceLimit, true);
    expect(summary(4, 16).nearAbsenceLimit, true);
    expect(summary(4, 16).exceedsAbsenceLimit, false);
    expect(summary(5, 15).exceedsAbsenceLimit, true);
    expect(summary(5, 15).nearAbsenceLimit, false);
    expect(summary(1, 0).exceedsAbsenceLimit, true);
  });

  testWidgets(
    'roster includes unmarked students, refreshes and filters warnings',
    (tester) async {
      final roster = StreamController<Map<String, Data>>();
      addTearDown(roster.close);
      final container = ProviderContainer(
        overrides: [
          profileProvider.overrideWith(
            (ref) =>
                Stream.value(const UserProfile('u', 'Demo', 'lecturer', [])),
          ),
          classAttendanceSessionsProvider('c').overrideWith(
            (ref) => Stream.value([
              for (var i = 0; i < 20; i++) {'id': '$i', 'status': 'finalized'},
              {'id': 'open', 'status': 'open'},
              {'id': 'cancel', 'status': 'cancelled'},
            ]),
          ),
          classAttendanceRecordsProvider('c').overrideWith(
            (ref) => Stream.value([
              for (var i = 0; i < 20; i++)
                for (final uid in ['near', 'over'])
                  {
                    'attendanceSessionId': '$i',
                    'classSessionId': '$i',
                    'studentUid': uid,
                    'status': i < (uid == 'near' ? 3 : 5)
                        ? 'absent'
                        : 'present',
                  },
              for (final id in ['open', 'cancel'])
                {
                  'attendanceSessionId': id,
                  'studentUid': 'near',
                  'status': 'absent',
                },
            ]),
          ),
          memberNamesProvider('c').overrideWith((ref) => roster.stream),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ClassAttendanceOverview(
                  cls: {'id': 'c', 'classCode': 'SE1', 'subjectId': 'PRM'},
                  showStudents: true,
                ),
              ),
            ),
          ),
        ),
      );
      final members = <String, Data>{
        'near': {'displayName': 'An', 'studentCode': 'SE001'},
        'over': {'displayName': 'Bình', 'studentCode': 'SE002'},
        'new': {'displayName': 'Chi', 'studentCode': 'SE003'},
      };
      roster.add(members);
      await tester.pumpAndSettle();
      expect(find.text('3 sinh viên'), findsOneWidget);
      expect(find.text('Buổi đã chốt: 20'), findsOneWidget);
      expect(find.text('Vắng: 8'), findsOneWidget);
      expect(find.text('Sắp vượt 20%: 1'), findsOneWidget);
      expect(find.text('Vượt 20%: 1'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(StudentAttendanceRow),
          matching: find.text('SE003'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Tỷ lệ vắng: 15.0%'), findsOneWidget);
      await tester.ensureVisible(find.text('Sắp vượt 20%'));
      await tester.tap(find.text('Sắp vượt 20%'));
      await tester.pumpAndSettle();
      expect(find.text('SE001'), findsOneWidget);
      expect(find.text('SE002'), findsNothing);
      await tester.tap(find.text('Tất cả'));
      roster.add({
        ...members,
        'added': {'displayName': 'Dung', 'studentCode': 'SE004'},
      });
      await tester.pumpAndSettle();
      expect(find.text('4 sinh viên'), findsOneWidget);
      expect(find.text('SE004'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'SE003');
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(StudentAttendanceRow),
          matching: find.text('SE003'),
        ),
        findsOneWidget,
      );
      expect(find.text('SE001'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty finalized attendance still displays the roster', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(
            (ref) =>
                Stream.value(const UserProfile('u', 'Demo', 'lecturer', [])),
          ),
          classAttendanceSessionsProvider(
            'c',
          ).overrideWith((ref) => Stream.value([])),
          classAttendanceRecordsProvider(
            'c',
          ).overrideWith((ref) => Stream.value([])),
          memberNamesProvider('c').overrideWith(
            (ref) => Stream.value({
              'u': {'displayName': 'An', 'studentCode': 'SE001'},
            }),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ClassAttendanceOverview(
                cls: {'id': 'c', 'classCode': 'SE1', 'subjectId': 'PRM'},
                showStudents: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SE001'), findsOneWidget);
    expect(find.text('Buổi đã chốt: 0'), findsOneWidget);
    expect(find.text('Vượt 20%: 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
