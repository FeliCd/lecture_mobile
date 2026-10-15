import 'dart:convert';
import 'package:excel/excel.dart' hide Data;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/lecturer_workspace.dart';
import 'package:lecturer_companion/lab2/lecturer_workspace_store.dart';
import 'package:lecturer_companion/lab2/lecturer_weekly_report.dart';
import 'package:lecturer_companion/lab2/lecturer_reminders.dart';
import 'package:lecturer_companion/lab2/timetable_domain.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('create and complete task through the assistant page', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LecturerWorkspacePage(
            user: UserProfile('u', 'Phúc', 'lecturer', []),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm việc'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Chuẩn bị demo');
    await tester.tap(find.text('Lưu trên máy'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditor), findsNothing);
    expect(find.text('Chuẩn bị demo'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Chuẩn bị demo'),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chuẩn bị demo'), findsNothing);
    expect((await WorkspaceStore('u').read()).tasks.single['done'], true);
    expect(find.text('Đã hoàn thành việc'), findsOneWidget);
    await tester.tap(find.text('Hoàn tác'));
    await tester.pumpAndSettle();
    expect((await WorkspaceStore('u').read()).tasks.single['done'], false);
    expect(find.text('Chuẩn bị demo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'failed task save keeps input; narrow layout supports enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => TaskEditor(
                    onSave: (_) async {
                      throw StateError('disk');
                    },
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
      await tester.enterText(find.byType(TextField), 'Chấm bài');
      await tester.ensureVisible(find.text('Lưu trên máy'));
      await tester.tap(find.text('Lưu trên máy'));
      await tester.pumpAndSettle();
      expect(find.text('Chấm bài'), findsOneWidget);
      expect(
        find.text('Chưa lưu được. Nội dung vẫn còn; hãy thử lại.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'Android scheduling replaces alarms, completion cancels, logout rejects stale saves',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final calls = <MethodCall>[];
      var granted = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'initialize') return true;
            if (call.method == 'areNotificationsEnabled') return granted;
            if (call.method == 'getNotificationAppLaunchDetails') {
              return {'notificationLaunchedApp': false};
            }
            return null;
          });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final reminders = LecturerReminders();
      await reminders.activate('u');
      final task = <String, dynamic>{
        'id': 'a',
        'title': 'Private title',
        'remind': true,
        'due': DateTime.now()
            .add(const Duration(days: 1))
            .toUtc()
            .toIso8601String(),
        'lead': 15,
      };
      final data = WorkspaceData(tasks: [task], quiet: false);
      calls.clear();
      await reminders.sync('u', data);
      expect(calls.first.method, 'cancelAll');
      final first =
          calls.singleWhere((c) => c.method == 'zonedSchedule').arguments
              as Map;
      expect(first['body'], isNot(contains('Private title')));
      calls.clear();
      await reminders.sync('u', data);
      expect(
        (calls.singleWhere((c) => c.method == 'zonedSchedule').arguments
            as Map)['id'],
        first['id'],
      );
      calls.clear();
      await reminders.sync(
        'u',
        WorkspaceData(
          tasks: [
            {...task, 'done': true},
          ],
          quiet: false,
        ),
      );
      expect(calls.any((c) => c.method == 'cancelAll'), isTrue);
      expect(calls.any((c) => c.method == 'zonedSchedule'), isFalse);
      granted = false;
      calls.clear();
      await reminders.sync('u', data);
      expect(calls.any((c) => c.method == 'zonedSchedule'), isFalse);
      granted = true;
      await reminders.activate(null);
      calls.clear();
      await reminders.sync('u', data);
      expect(calls, isEmpty);
    },
  );
  test(
    'concurrent edits persist without losing task or notebook; isolated account',
    () async {
      final a = WorkspaceStore('a'), b = WorkspaceStore('b');
      await Future.wait([
        a.saveTask({'id': '1', 'title': ' Chuẩn bị bài ', 'done': false}),
        a.saveNote('lesson', {'goals': 'Mục tiêu'}),
        a.saveTask({'id': '2', 'title': 'Chấm bài'}),
      ]);
      final reloaded = await WorkspaceStore('a').read();
      expect(reloaded.tasks.length, 2);
      expect(reloaded.tasks.first['title'], 'Chuẩn bị bài');
      expect(reloaded.notes['lesson']!['goals'], 'Mục tiêu');
      expect((await b.read()).tasks, isEmpty);
      expect((await b.read()).notes, isEmpty);
      await a.saveNote('lesson', {'goals': 'Đã sửa'});
      expect((await a.read()).notes['lesson']!['revision'], 2);
      await a.deleteTask('1');
      expect((await a.read()).tasks.single['id'], '2');
    },
  );
  test('invalid stored version is not silently overwritten', () async {
    final store = WorkspaceStore('a');
    await (await SharedPreferences.getInstance()).setString(
      store.key,
      jsonEncode({'version': 99}),
    );
    await expectLater(
      store.saveTask({'id': '1', 'title': 'Không ghi đè'}),
      throwsFormatException,
    );
    expect(
      (await SharedPreferences.getInstance()).getString(store.key),
      contains('99'),
    );
  });
  test('reminders use UTC+7 quiet hours and cancel completed/past tasks', () {
    final now = DateTime.utc(2026, 10, 12);
    final task = <String, dynamic>{
      'remind': true,
      'due': '2026-10-13T01:00:00Z',
      'lead': 15,
    };
    expect(taskReminder(task, true, now), DateTime.utc(2026, 10, 13, 0, 45));
    expect(taskReminder({...task, 'done': true}, true, now), isNull);
    expect(taskReminder(task, true, DateTime.utc(2026, 10, 14)), isNull);
    final night = {...task, 'due': '2026-10-13T15:30:00Z'};
    expect(taskReminder(night, true, now), isNull);
    expect(taskReminder(night, false, now), DateTime.utc(2026, 10, 13, 15, 15));
  });
  test(
    'notebook key isolates parallel classes and days, stable after attendance',
    () {
      TeachingPeriod p({String cls = 'a', String? session, DateTime? day}) =>
          TeachingPeriod(
            day: day ?? DateTime.utc(2026, 10, 13),
            classId: cls,
            sessionId: session,
            classCode: 'SE1',
            subjectId: 'PRM',
            subjectName: '',
            room: '',
            term: 'Fall',
            slot: 1,
            start: 450,
            end: 590,
            recurring: session == null,
            scheduleId: 's',
            exceptionId: '',
          );
      expect(workspaceKey(p()), workspaceKey(p(session: 'created')));
      expect(workspaceKey(p()), isNot(workspaceKey(p(cls: 'b'))));
      expect(
        workspaceKey(p()),
        isNot(workspaceKey(p(day: DateTime.utc(2026, 10, 14)))),
      );
    },
  );
  test(
    'week boundaries are campus dates; unauthorized/reset records excluded; workbook has provenance',
    () {
      const user = UserProfile('u', 'Phúc', 'lecturer', []);
      final start = DateTime.utc(2026, 10, 12);
      final rows = weeklySessions(
        user,
        [
          {'id': 'c', 'classCode': 'SE1', 'subjectId': 'PRM', 'term': 'Fall'},
        ],
        [
              {
                'id': 'allowed',
                'classId': 'c',
                'lecturerUid': 'u',
                'startsAt': '2026-10-11T17:00:00Z',
                'status': 'completed',
              },
              {
                'id': 'other',
                'classId': 'c',
                'lecturerUid': 'other',
                'startsAt': '2026-10-12T01:00:00Z',
              },
              {
                'id': 'reset',
                'classId': 'c',
                'lecturerUid': 'u',
                'startsAt': '2026-10-12T01:00:00Z',
                'status': 'reset',
              },
              {
                'id': 'outside',
                'classId': 'c',
                'lecturerUid': 'u',
                'startsAt': '2026-10-18T17:00:00Z',
              },
              {
                'id': 'unassigned',
                'classId': 'secret',
                'lecturerUid': 'u',
                'startsAt': '2026-10-12T01:00:00Z',
              },
            ]
            .map(
              (s) => {
                ...s,
                'startsAt': DateTime.parse(
                  s['startsAt'] as String,
                ).millisecondsSinceEpoch,
              },
            )
            .toList(),
        start,
      );
      expect(rows.map((r) => r['id']), ['allowed']);
      final bytes = weeklyWorkbook(
        user: user,
        start: start,
        capturedAt: DateTime.utc(2026, 10, 13),
        sessions: rows,
        local: const WorkspaceData(
          notes: {
            'private': {'goals': 'DO NOT EXPORT'},
          },
        ),
      );
      final excel = Excel.decodeBytes(bytes);
      expect(
        excel.tables['Phiên điểm danh']!.rows[1][0]!.value.toString(),
        'allowed',
      );
      expect(
        excel.tables['Phiên điểm danh']!.rows[1][6]!.value.toString(),
        'Chưa có dữ liệu',
      );
      expect(
        excel.tables.values.expand((s) => s.rows).toString(),
        isNot(contains('DO NOT EXPORT')),
      );
      expect(
        excel.tables['Thông tin']!.rows.toString(),
        contains('classSessions'),
      );
    },
  );
  testWidgets('notebook autosaves edits and restores on reopen', (
    tester,
  ) async {
    Future<void> open() async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LessonNotebookPage(
              uid: 'u',
              noteId: 'lesson',
              metadata: {'label': 'PRM · SE1', 'subjectId': 'PRM'},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await open();
    await tester.enterText(find.byType(TextField).first, 'Mục tiêu đã nhập');
    await tester.pumpAndSettle();
    expect(find.text('Đã lưu trên máy • Chưa đồng bộ'), findsOneWidget);
    expect(
      (await WorkspaceStore('u').read()).notes['lesson']!['goals'],
      'Mục tiêu đã nhập',
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await open();
    expect(find.text('Mục tiêu đã nhập'), findsOneWidget);
  });
}
