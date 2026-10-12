import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lecturer_companion/lab2/desktop_session_dialog.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/repository.dart';
import 'package:lecturer_companion/lab2/timetable_domain.dart';
import 'package:lecturer_companion/lab2/timetable_card.dart';
import 'package:lecturer_companion/lab2/today.dart';
import 'package:lecturer_companion/lab2/class_timetable.dart';
import 'lab2_navigation_test.dart' show FixtureRepository;

class SlotFixture extends FixtureRepository {
  final calls = <Data>[];
  String state = 'AVAILABLE';
  double remaining = 5;
  Completer<Data>? pending;
  bool loseFirstResponse = false;
  Data get cls => {
    'id': 'c1',
    'classCode': 'SE1',
    'subjectId': 'PRM393',
    'subjectName': 'Mobile',
    'term': 'FA26',
  };
  Data get schedule => {
    'id': 's1',
    'classId': 'c1',
    'lecturerUid': 'lecturer-l1',
    'classCode': 'SE1',
    'subjectId': 'PRM393',
    'subjectName': 'Mobile',
    'term': 'FA26',
    'dayOfWeek': campusDay(DateTime.now()).weekday,
    'slot': 1,
    'startTime': '00:00',
    'endTime': '23:59',
  };
  @override
  Stream<List<Data>> classes(UserProfile user) => Stream.value([cls]);
  @override
  Stream<List<Data>> watch(
    String collection, {
    String? field,
    Object? equals,
    String? uid,
  }) => Stream.value(collection == 'schedules' ? [schedule] : []);
  @override
  Future<Data> call(String name, Data input) async {
    calls.add({'name': name, ...input});
    if (name == 'getTeachingOccurrence') {
      return {
        'state': state,
        'occurrenceId': 'resolved',
        'sessionId': state == 'OPEN' || state == 'CLOSED' ? 'existing' : null,
        'status': state,
        'serverTime': DateTime.now().millisecondsSinceEpoch,
        'earliestOpenAt': DateTime.now()
            .add(const Duration(hours: 1))
            .millisecondsSinceEpoch,
        'remainingMinutes': remaining,
      };
    }
    if (pending != null) return pending!.future;
    if (loseFirstResponse) {
      loseFirstResponse = false;
      throw StateError('unavailable');
    }
    return {
      'sessionId': 'actual',
      'status': 'OPEN',
      'opensAt': 1,
      'closesAt': 300001,
      'effectiveDurationMinutes': 5,
    };
  }
}

const user = UserProfile('lecturer-l1', 'Teacher', 'lecturer', ['PRM393']);
TeachingPeriod period() => TeachingPeriod(
  day: campusDay(DateTime.now()),
  classId: 'c1',
  sessionId: null,
  scheduleId: 's1',
  exceptionId: '',
  classCode: 'SE1',
  subjectId: 'PRM393',
  subjectName: 'Mobile',
  room: 'A1',
  term: 'FA26',
  slot: 1,
  start: 0,
  end: 1439,
  recurring: true,
);

Future<void> openDialog(
  WidgetTester tester,
  SlotFixture repo, {
  void Function(Data?)? result,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final value = await showDialog<Data>(
                  context: context,
                  builder: (_) => DesktopSessionDialog(period: period()),
                );
                result?.call(value);
              },
              child: const Text('Select slot'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Select slot'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'selection only reads occurrence; readonly schedule, five durations, cap shown, double submit blocked',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = SlotFixture(), pending = Completer<Data>();
      repo.pending = pending;
      Data? result;
      await openDialog(tester, repo, result: (v) => result = v);
      expect(repo.calls.map((r) => r['name']), ['getTeachingOccurrence']);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
      expect(find.textContaining('Còn 5.0 phút'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      expect(find.text('60 phút'), findsNothing);
      await tester.tap(find.text('30 phút').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mở phiên điểm danh'));
      await tester.pump();
      expect(find.text('Đang mở…'), findsOneWidget);
      await tester.tap(find.text('Đang mở…'));
      await tester.pump();
      expect(
        repo.calls.where((c) => c['name'] == 'createClassSession').length,
        1,
      );
      final input = repo.calls.last;
      expect(input['durationMinutes'], 30);
      expect(input['scheduleId'], 's1');
      expect(input.containsKey('startTime'), false);
      expect(input.containsKey('endTime'), false);
      expect(input.containsKey('title'), false);
      pending.complete({
        'sessionId': 'actual',
        'status': 'OPEN',
        'effectiveDurationMinutes': 5,
      });
      await tester.pumpAndSettle();
      expect(result!['effectiveDurationMinutes'], 5);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('dialog polls only in foreground and rereads server on resume', (
    tester,
  ) async {
    final repo = SlotFixture();
    await openDialog(tester, repo);
    expect(repo.calls.length, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 45));
    expect(repo.calls.length, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repo.calls.length, 2);
    await tester.pumpWidget(const SizedBox());
  });
  for (final state in [
    'OPEN',
    'CLOSED',
    'NOT_YET',
    'ENDED',
    'TOO_SHORT',
    'RESET',
  ]) {
    testWidgets('server state $state cannot open a new session', (
      tester,
    ) async {
      final repo = SlotFixture()..state = state;
      await openDialog(tester, repo);
      expect(find.byType(DesktopSessionDialog), findsOneWidget);
      expect(repo.calls.single['name'], 'getTeachingOccurrence');
      expect(find.text('Mở phiên điểm danh'), findsNothing);
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      if (state == 'OPEN') {
        expect(find.text('Tiếp tục điểm danh'), findsOneWidget);
      }
      if (state == 'CLOSED') {
        expect(find.text('Xem kết quả điểm danh'), findsOneWidget);
      }
      expect(
        repo.calls.where((c) => c['name'] == 'createClassSession'),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'network interruption permits retry with same occurrence selector',
    (tester) async {
      final repo = SlotFixture()..loseFirstResponse = true;
      Data? result;
      await openDialog(tester, repo, result: (v) => result = v);
      await tester.tap(find.text('Mở phiên điểm danh'));
      await tester.pumpAndSettle();
      expect(find.text('Không thể kết nối. Vui lòng thử lại.'), findsOneWidget);
      await tester.tap(find.text('Mở phiên điểm danh'));
      await tester.pumpAndSettle();
      final writes = repo.calls
          .where((r) => r['name'] == 'createClassSession')
          .toList();
      expect(writes.length, 2);
      expect(writes.first, writes.last);
      expect(result!['sessionId'], 'actual');
    },
  );
  for (final entry in ['Today', 'Timetable', 'Class']) {
    testWidgets('$entry uses shared slot flow and actual server session ID', (
      tester,
    ) async {
      final repo = SlotFixture();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: entry == 'Today'
                  ? TodayPanel(user: user, onTimetable: () {})
                  : entry == 'Timetable'
                  ? TeachingPeriodCard(period: period())
                  : ClassTimetable(cls: repo.cls, user: user),
            ),
          ),
          GoRoute(
            path: '/host/:id',
            builder: (_, state) =>
                Scaffold(body: Text('Actual ${state.pathParameters['id']}')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repo)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      if (entry == 'Today') {
        await tester.ensureVisible(find.text('Bắt đầu điểm danh'));
        await tester.tap(find.text('Bắt đầu điểm danh'));
      } else if (entry == 'Timetable') {
        await tester.tap(find.byType(TeachingPeriodCard));
      } else {
        await tester.tap(find.text('Slot 1 • 00:00 – 23:59').first);
      }
      await tester.pumpAndSettle();
      expect(repo.calls.single['name'], 'getTeachingOccurrence');
      await tester.tap(find.text('Mở phiên điểm danh'));
      await tester.pumpAndSettle();
      expect(find.text('Actual actual'), findsOneWidget);
      expect(repo.calls.last['slot'], 1);
    });
  }
}
