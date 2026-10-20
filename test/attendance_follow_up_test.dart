import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/lab2/attendance_follow_up.dart';
import 'package:lecturer_companion/lab2/attendance_reminders.dart';
import 'package:lecturer_companion/lab2/bulk_attendance.dart';
import 'package:lecturer_companion/lab2/lecturer_reminders.dart';
import 'package:lecturer_companion/lab2/timetable_domain.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/lecturer_workspace_store.dart';

TeachingPeriod lesson({
  String? session,
  bool completed = false,
  bool cancelled = false,
  int start = 600,
  int end = 690,
}) => TeachingPeriod(
  day: DateTime.utc(2026, 10, 19),
  classId: 'c',
  sessionId: session,
  classCode: 'SE1',
  subjectId: 'PRM393',
  subjectName: 'Mobile',
  room: 'A101',
  term: 'FA26',
  slot: 1,
  start: start,
  end: end,
  recurring: session == null,
  completed: completed,
  cancelled: cancelled,
  scheduleId: 'schedule',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'reminder help and test action fit a small screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(
            body: AttendanceReminderToggle(uid: 'u', term: 'FA26'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Thông tin nhắc điểm danh'));
      await tester.pumpAndSettle();
      expect(find.text('Thử âm thanh và rung').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test('test alert respects permission and account ownership', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final calls = <MethodCall>[];
    var granted = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'initialize') return true;
          if (call.method == 'requestNotificationsPermission') return granted;
          return null;
        });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final reminders = LecturerReminders()..owner = 'u';
    expect(await reminders.testAttendanceAlert('u'), false);
    expect(calls.where((c) => c.method == 'show'), isEmpty);
    granted = true;
    expect(await reminders.testAttendanceAlert('u'), true);
    final shown = calls.singleWhere((c) => c.method == 'show');
    final android = (shown.arguments as Map)['platformSpecifics'] as Map;
    expect(android['channelId'], 'lecturer_attendance');
    expect(android['playSound'], true);
    expect(android['enableVibration'], true);
    calls.clear();
    reminders.owner = null;
    expect(await reminders.testAttendanceAlert('u'), false);
    expect(calls, isEmpty);
  });
  test(
    'student search ignores Vietnamese accents and extra spaces without changing names',
    () {
      expect(attendanceSearchText('  NGUYỄN   ĐỨC  '), 'nguyen duc');
      expect(attendanceSearchText('Nguye\u0302\u0303n'), 'nguyen');
      expect(attendanceSearchText('SE1010'), 'se1010');
    },
  );
  test(
    'lesson reconciliation preserves task alarms and cancels changed lessons/account alarms',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final calls = <MethodCall>[];
      final pending = <Map<String, dynamic>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (c) async {
            calls.add(c);
            if (c.method == 'initialize' ||
                c.method == 'areNotificationsEnabled') {
              return true;
            }
            if (c.method == 'getNotificationAppLaunchDetails') {
              return {'notificationLaunchedApp': false};
            }
            if (c.method == 'pendingNotificationRequests') return pending;
            if (c.method == 'cancelAll') pending.clear();
            if (c.method == 'cancel') {
              pending.removeWhere((p) => p['id'] == (c.arguments as Map)['id']);
            }
            if (c.method == 'zonedSchedule') {
              final a = Map<String, dynamic>.from(c.arguments as Map);
              pending
                ..removeWhere((p) => p['id'] == a['id'])
                ..add({
                  'id': a['id'],
                  'title': a['title'],
                  'body': a['body'],
                  'payload': a['payload'],
                });
            }
            return null;
          });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final store = WorkspaceStore('u');
      await store.setQuiet(false);
      await store.saveTask({
        'id': 'task',
        'title': 'Private task',
        'done': false,
        'remind': true,
        'due': DateTime.now()
            .add(const Duration(days: 2))
            .toUtc()
            .toIso8601String(),
      });
      final day = campusDay(DateTime.now()).add(const Duration(days: 1));
      TeachingPeriod period({bool complete = false}) => TeachingPeriod(
        day: day,
        classId: 'c',
        sessionId: null,
        classCode: 'Private class',
        subjectId: 'M',
        subjectName: 'M',
        room: 'A',
        term: 'FA26',
        slot: 1,
        start: 600,
        end: 690,
        recurring: true,
        completed: complete,
      );
      final reminders = LecturerReminders();
      await reminders.activate('u');
      await reminders.syncLessons('u', [period()]);
      calls.clear();
      await reminders.setLessonReminders('u', true, 'FA26');
      expect(calls.where((c) => c.method == 'zonedSchedule').length, 5);
      final lessonCalls = calls.where(
        (c) =>
            c.method == 'zonedSchedule' &&
            (c.arguments as Map)['title'].toString().contains('điểm danh'),
      );
      expect(lessonCalls.length, 4);
      for (final call in lessonCalls) {
        final android = (call.arguments as Map)['platformSpecifics'] as Map;
        expect(android['playSound'], true);
        expect(android['enableVibration'], true);
        expect(android['vibrationPattern'], [0, 500, 200, 500, 200, 800]);
        expect(android['channelId'], 'lecturer_attendance');
        final payload =
            jsonDecode((call.arguments as Map)['payload'] as String) as Map;
        expect(payload['uid'], 'u');
        expect(payload['type'], 'attendance');
        expect(payload['kind'], 'lesson');
        expect((payload['selector'] as Map)['classId'], 'c');
        expect((payload['selector'] as Map)['slot'], 1);
        expect(
          (payload['selector'] as Map)['sessionDate'],
          day.toIso8601String().substring(0, 10),
        );
      }
      expect(
        lessonCalls.every(
          (c) =>
              (c.arguments as Map)['body'].toString().contains('Private class'),
        ),
        true,
      );
      calls.clear();
      // A quick-attendance reminder must survive lesson reconciliation.
      await reminders.syncAttendance('u', [
        AttendanceReminder(
          key: 'quick-end',
          at: DateTime.now().add(const Duration(hours: 2)),
          title: 'Điểm danh chưa hoàn tất',
          body: 'Mở đúng buổi',
          selector: const {
            'classId': 'c',
            'sessionDate': '2026-10-19',
            'slot': 1,
          },
        ),
      ]);
      final quickAlarm = pending.singleWhere(
        (p) =>
            '${p['payload']}'.contains('"type":"attendance"') &&
            !'${p['payload']}'.contains('"kind":"lesson"'),
      );
      calls.clear();
      await reminders.syncLessons('u', [period(complete: true)]);
      expect(calls.any((c) => c.method == 'cancelAll'), false);
      expect(calls.where((c) => c.method == 'zonedSchedule').length, 1);
      expect(pending, hasLength(2));
      expect(pending, contains(quickAlarm));
      expect(
        pending.where((p) => '${p['payload']}'.contains('lesson:')),
        isEmpty,
      );
      await reminders.activate(null);
      expect(pending, isEmpty);
      calls.clear();
      await reminders.syncLessons('u', [period()]);
      expect(calls, isEmpty);
    },
  );
  test(
    'follow-up distinguishes missing session, upcoming, closed, cancelled and expiring session',
    () {
      final now = DateTime.utc(2026, 10, 19, 3, 30);
      expect(attendanceFollowUp(lesson(), now), 'Chưa mở điểm danh');
      expect(attendanceFollowUp(lesson(start: 700, end: 800), now), isNull);
      expect(attendanceFollowUp(lesson(completed: true), now), isNull);
      expect(attendanceFollowUp(lesson(cancelled: true), now), isNull);
      expect(
        attendanceFollowUp(lesson(end: 620), now),
        contains('Chưa có phiên'),
      );
      expect(attendanceFollowUp(lesson(session: 's'), now), isNull);
      expect(
        attendanceFollowUp(lesson(session: 's', end: 631), now),
        contains('Kiểm tra và chốt'),
      );
    },
  );
  test(
    'lesson alarms drop completed/cancelled, expired times and respect quiet hours',
    () {
      final now = DateTime.utc(2026, 10, 19, 2);
      final alarms = lessonAlarms(
        [lesson(), lesson(completed: true), lesson(cancelled: true)],
        now,
        false,
      );
      expect(alarms.length, 4);
      expect(alarms.first.at, DateTime.utc(2026, 10, 19, 3, 45));
      expect(alarms.last.at, DateTime.utc(2026, 10, 19, 14));
      expect(alarms.first.payload, contains('schedule'));
      expect(lessonAlarms([lesson(session: 's')], now, false).length, 4);
      expect(
        lessonAlarms([lesson()], DateTime.utc(2026, 10, 19, 5), false),
        hasLength(1),
      );
      expect(
        lessonAlarms([lesson(start: 1380, end: 1430)], now, true),
        isEmpty,
      );
      expect(
        lessonAlarms([lesson(start: 1380, end: 30)], now, false),
        hasLength(1),
      );
    },
  );
  for (final failure in [false, true]) {
    testWidgets(
      'bulk requires preview and reason, preserves recorded students; failure=$failure',
      (tester) async {
        var saves = 0;
        Data? input;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => BulkAttendanceSheet(
                      contextLabel: 'SE1 · Slot 1',
                      students: const [
                        {
                          'studentUid': 'student-a',
                          'displayName': 'An',
                          'studentCode': 'SE01',
                          'status': 'pending',
                        },
                        {
                          'studentUid': 'student-b',
                          'displayName': 'Bình',
                          'studentCode': 'SE02',
                          'status': 'present',
                        },
                      ],
                      onSave: (d) async {
                        saves++;
                        input = d;
                        if (failure) throw StateError('ATTENDANCE_CONFLICT');
                        return {};
                      },
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Bình'), findsNothing);
        await tester.tap(find.text('Xem trước'));
        await tester.pumpAndSettle();
        expect(saves, 0);
        await tester.enterText(find.byType(TextField), 'Đã đối chiếu tại lớp');
        await tester.tap(find.text('Xem trước'));
        await tester.pumpAndSettle();
        expect(find.text('Kiểm tra trước khi lưu'), findsOneWidget);
        expect(saves, 0);
        await tester.tap(find.text('Xác nhận 1 sinh viên'));
        await tester.pumpAndSettle();
        expect(saves, 1);
        expect((input!['changes'] as List).single['studentUid'], 'student-a');
        if (failure) {
          expect(
            find.textContaining('Dữ liệu điểm danh vừa thay đổi'),
            findsOneWidget,
          );
          expect(
            tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
            isNotNull,
          );
          expect(find.text('Kiểm tra danh sách').hitTestable(), findsOneWidget);
          expect(find.text('Xác nhận 1 sinh viên'), findsNothing);
          expect(find.textContaining('Đã đối chiếu tại lớp'), findsOneWidget);
        } else {
          expect(find.byType(BulkAttendanceSheet), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final size in [const Size(360, 800), const Size(844, 390)]) {
    testWidgets(
      'bulk remains scrollable with large text and keyboard at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(2),
                viewInsets: const EdgeInsets.only(bottom: 180),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: BulkAttendanceSheet(
                contextLabel: 'SE1 · Slot 1',
                students: const [
                  {
                    'studentUid': 'student-a',
                    'displayName': 'Nguyễn Minh Anh',
                    'studentCode': 'SE01',
                    'status': 'pending',
                  },
                ],
                onSave: (d) async => {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Xem trước'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
