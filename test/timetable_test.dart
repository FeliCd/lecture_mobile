import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/timetable_domain.dart';
import 'package:lecturer_companion/lab2/timetable.dart';
import 'package:lecturer_companion/lab2/timetable_card.dart';
import 'package:lecturer_companion/lab2/desktop_session_dialog.dart';
import 'package:lecturer_companion/lab2/repository.dart';
import 'attendance_slot_flow_test.dart' show SlotFixture;
import 'package:lecturer_companion/lab2/theme.dart';

const teacher = UserProfile('teacher', 'Giảng viên', 'lecturer', [
  'PRM393',
  'PRN212',
]);
const teachingClasses = <Data>[
  {
    'id': 'mobile',
    'classCode': 'SE1928',
    'subjectId': 'PRM393',
    'subjectName': 'Lập trình di động',
    'term': 'Fall 2026',
  },
  {
    'id': 'net',
    'classCode': 'SE1929',
    'subjectId': 'PRN212',
    'term': 'Fall 2026',
  },
];
const teachingSchedules = <Data>[
  {
    'id': 's1',
    'lecturerUid': 'teacher',
    'classCode': 'SE1928',
    'subjectId': 'PRM393',
    'subjectName': 'Lập trình di động',
    'term': 'Fall 2026',
    'dayOfWeek': 5,
    'slot': 1,
    'startTime': '07:30',
    'endTime': '09:50',
    'room': 'A201',
  },
  {
    'id': 's2',
    'lecturerUid': 'teacher',
    'classCode': 'SE1929',
    'subjectId': 'PRN212',
    'term': 'Fall 2026',
    'dayOfWeek': 5,
    'slot': 3,
    'startTime': '12:50',
    'endTime': '15:10',
    'room': 'B302',
  },
];

void main() {
  final friday = DateTime.utc(2026, 10, 9);
  List<TeachingPeriod> periods({
    List<Data> schedules = teachingSchedules,
    List<Data> classes = teachingClasses,
    List<Data> sessions = const [],
  }) => teachingPeriods(
    user: teacher,
    day: friday,
    term: 'Fall 2026',
    schedules: schedules,
    classes: classes,
    sessions: sessions,
  );
  Data session({String status = 'scheduled', int? slot = 1}) => {
    'id': 'actual',
    'classId': 'mobile',
    'lecturerUid': 'teacher',
    'slot': slot,
    'startsAt': DateTime.utc(2026, 10, 9, 1).millisecondsSinceEpoch,
    'endsAt': DateTime.utc(2026, 10, 9, 3).millisecondsSinceEpoch,
    'status': status,
  };
  test(
    'overnight teaching period retains date, selector and next-day interval',
    () {
      final values = periods(
        schedules: [
          {
            ...teachingSchedules.first,
            'startTime': '23:30',
            'endTime': '00:30',
          },
        ],
      );
      final p = values.single;
      expect(p.sessionDate, '2026-10-09');
      expect(p.selector['scheduleId'], 's1');
      expect(p.scheduledStartAt, DateTime.utc(2026, 10, 9, 16, 30));
      expect(p.scheduledEndAt, DateTime.utc(2026, 10, 9, 17, 30));
    },
  );
  test('campus date and week use UTC+7 across month/year boundaries', () {
    expect(campusDay(DateTime.utc(2026, 12, 31, 18)), DateTime.utc(2027, 1, 1));
    expect(weekStart(DateTime.utc(2027, 1, 1)), DateTime.utc(2026, 12, 28));
    expect(teachingMinutes('25:00'), isNull);
    expect(teachingMinutes('07:60'), isNull);
  });
  test(
    'dated changes cancel one date and move occurrence without changing weekly schedule',
    () {
      final change = <String, dynamic>{
        'scheduleId': 's1',
        'classId': 'mobile',
        'date': '2026-10-09',
        'kind': 'RESCHEDULED',
        'targetDate': '2026-10-10',
        'slot': '2',
        'startTime': '10:00',
        'endTime': '11:00',
        'room': 'C1',
      };
      List<TeachingPeriod> on(DateTime day, List<Data> changes) =>
          teachingPeriods(
            user: teacher,
            day: day,
            term: 'Fall 2026',
            schedules: teachingSchedules,
            classes: teachingClasses,
            sessions: [],
            exceptions: changes,
          );
      expect(on(friday, [change]).where((p) => p.classId == 'mobile'), isEmpty);
      final moved = on(friday.add(const Duration(days: 1)), [change]).single;
      expect(moved.slot, 2);
      expect(moved.room, 'C1');
      expect(moved.start, 600);
      expect(on(friday.add(const Duration(days: 7)), [change]).length, 2);
      expect(
        on(friday, [
          {...change, 'classId': 'foreign'},
        ]).length,
        2,
      );
      expect(
        on(friday, [
          {...change, 'kind': 'ROOM_CHANGED', 'slot': '1'},
        ]).first.room,
        'C1',
      );
      expect(teachingSchedules.first['room'], 'A201');
    },
  );
  test('lecturer, semester and weekday scope the correct slot and subject', () {
    final result = periods(
      schedules: [
        ...teachingSchedules,
        {...teachingSchedules.first, 'lecturerUid': 'another'},
        {...teachingSchedules.first, 'term': 'Spring 2027'},
        {...teachingSchedules.first, 'dayOfWeek': 1},
        {...teachingSchedules.first, 'startTime': 'broken'},
      ],
    );
    expect(result.length, 2);
    expect(result.map((p) => p.slot), [1, 3]);
    expect(result.first.classId, 'mobile');
    expect(result.first.subjectId, 'PRM393');
    expect(result.first.timeRange, '07:30 – 09:50');
    expect(result.first.room, 'A201');
  });
  test('dated session overrides recurring period and retains room', () {
    final result = periods(sessions: [session()]);
    expect(result.length, 2);
    expect(result.first.recurring, false);
    expect(result.first.timeRange, '08:00 – 10:00');
    expect(result.first.room, 'A201');
    expect(result.first.sessionId, 'actual');
    expect(
      periods(sessions: [session(status: 'cancelled')]).map((p) => p.slot),
      [3],
    );
  });
  test('ambiguous class mapping never opens an arbitrary class', () {
    final result = periods(
      classes: [
        ...teachingClasses,
        {...teachingClasses.first, 'id': 'duplicate'},
      ],
    );
    expect(result.first.classId, isNull);
  });
  test(
    'slots are not guessed and genuine conflicting sessions stay visible',
    () {
      expect(
        periods(schedules: [], sessions: [session(slot: null)]).single.slot,
        isNull,
      );
      final result = periods(
        sessions: [
          session(),
          {...session(), 'id': 'second'},
        ],
      );
      expect(result.length, 3);
      expect(result.first.overlaps(result[1]), true);
    },
  );
  testWidgets('day, week, next week and subject filter work on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teachingClassesProvider(
            'teacher',
          ).overrideWith((ref) => Stream.value(teachingClasses)),
          teachingSchedulesProvider(
            'teacher',
          ).overrideWith((ref) => Stream.value(teachingSchedules)),
          for (final cls in teachingClasses)
            teachingSessionsProvider(
              cls['id'] as String,
            ).overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          theme: campusTheme(Brightness.light),
          home: Scaffold(
            body: LecturerTimetable(user: teacher, initialDay: friday),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) => w is TeachingPeriodCard && w.period.slot == 1,
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byWidgetPredicate(
        (w) => w is TeachingPeriodCard && w.period.slot == 3,
      ),
      200,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is TeachingPeriodCard && w.period.slot == 3,
      ),
      findsOneWidget,
    );
    expect(find.text('PRN212'), findsWidgets);
    await tester.ensureVisible(find.byTooltip('Lọc lịch dạy'));
    await tester.tap(find.byTooltip('Lọc lịch dạy'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byType(DropdownButtonFormField<String>).last,
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('PRM393').last);
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) => w is TeachingPeriodCard && w.period.slot == 3,
      ),
      findsNothing,
    );
    await tester.ensureVisible(find.text('Tuần'));
    await tester.tap(find.text('Tuần'));
    await tester.pumpAndSettle();
    expect(find.text('Lịch tuần • 1 buổi'), findsOneWidget);
    final horizontal = find
        .byWidgetPredicate(
          (w) =>
              w is SingleChildScrollView &&
              w.scrollDirection == Axis.horizontal,
        )
        .last;
    await tester.drag(horizontal, const Offset(-750, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byTooltip('Tuần sau'));
    await tester.tap(find.byTooltip('Tuần sau'));
    await tester.pumpAndSettle();
    expect(find.text('12/10 – 18/10 • 2026'), findsOneWidget);
    expect(find.text('Lịch tuần • 1 buổi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('multiple semesters require explicit selection', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teachingClassesProvider(
            'teacher',
          ).overrideWith((ref) => Stream.value(teachingClasses)),
          teachingSchedulesProvider('teacher').overrideWith(
            (ref) => Stream.value([
              ...teachingSchedules,
              {...teachingSchedules.first, 'term': 'Spring 2027'},
            ]),
          ),
          for (final cls in teachingClasses)
            teachingSessionsProvider(
              cls['id'] as String,
            ).overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: LecturerTimetable(user: teacher, initialDay: friday),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chọn học kỳ để xem lịch dạy.'), findsOneWidget);
    expect(find.text('Slot 1'), findsNothing);
  });
  testWidgets('tapping a teaching period opens readonly occurrence details', (
    tester,
  ) async {
    final repo = SlotFixture()..state = 'NOT_YET';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(body: TeachingPeriodCard(period: periods().first)),
        ),
      ),
    );
    await tester.tap(find.byType(TeachingPeriodCard));
    await tester.pumpAndSettle();
    expect(find.byType(DesktopSessionDialog), findsOneWidget);
    expect(repo.calls.single['scheduleId'], 's1');
    expect(find.text('Mở phiên điểm danh'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
