import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/theme.dart';
import 'package:lecturer_companion/lab2/repository.dart';
import 'package:lecturer_companion/lab2/today.dart';
import 'package:lecturer_companion/lab2/live_attendance.dart';
import 'package:lecturer_companion/lab2/bulk_attendance.dart';
import 'package:lecturer_companion/lab2/lecturer_workspace.dart';
import 'package:lecturer_companion/lab2/lecturer_workspace_store.dart';
import 'package:lecturer_companion/lab2/timetable_domain.dart';
import 'attendance_slot_flow_test.dart' show SlotFixture;

// Synthetic data and deterministic actions. This is not a human usability study.
class WalkthroughRepository extends SlotFixture {
  bool closed = false;
  @override
  Data get schedule {
    final minute = DateTime.now().toUtc().add(const Duration(hours: 7));
    final m = minute.hour * 60 + minute.minute;
    return {
      ...super.schedule,
      'startTime': teachingTime((m - 15).clamp(0, 1438)),
      'endTime': teachingTime((m + 75).clamp(1, 1439)),
      'room': 'A201',
    };
  }

  @override
  Future<Data> call(String name, Data input) async {
    if (name == 'createClassSession') {
      return {...await super.call(name, input), 'effectiveDurationMinutes': 10};
    }
    if (name == 'getTeachingOccurrence') {
      remaining = 75;
      return {...await super.call(name, input), 'room': 'A201'};
    }
    if (name == 'getQrToken') {
      return {
        'token': 'https://example.com/test-only',
        'expiresAt': DateTime.now()
            .add(const Duration(minutes: 10))
            .millisecondsSinceEpoch,
        'secretEnabled': false,
      };
    }
    if (name == 'getAttendanceSessionLive') {
      return {
        'sessionId': 'actual',
        'classId': 'c1',
        'classCode': 'SE1',
        'subjectName': 'Lập trình di động',
        'slot': 1,
        'room': 'A201',
        'status': closed ? 'CLOSED' : 'OPEN',
        'expiresAt': DateTime.now()
            .add(const Duration(minutes: 10))
            .toIso8601String(),
        'serverTime': DateTime.now().toIso8601String(),
        'revision': 'fixture-revision',
        'counts': {
          'eligible': 32,
          'present': 10,
          'late': 0,
          'pending': closed ? 0 : 22,
          'absent': closed ? 22 : 0,
          'excused': 0,
        },
        'students': [
          for (var i = 0; i < 32; i++)
            {
              'studentUid': 'student-$i',
              'studentCode': 'SE${1000 + i}',
              'displayName': i == 10
                  ? 'Nguyễn Minh Anh'
                  : 'Sinh viên thử ${i + 1}',
              'status': i < 10
                  ? 'present'
                  : closed
                  ? 'absent'
                  : 'pending',
              'notes': '',
            },
        ],
      };
    }
    if (name == 'bulkUpdatePendingAttendance') {
      calls.add({'name': name, ...input});
      throw TimeoutException('test-only response loss');
    }
    if (name == 'closeAttendanceSession') {
      closed = true;
      return {'closed': true};
    }
    return super.call(name, input);
  }
}

final boundary = GlobalKey();
const teacher = UserProfile('lecturer-l1', 'Nguyễn Văn Minh', 'lecturer', [
  'PRM393',
]);

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_UI')) return;
  await tester.runAsync(() async {
    final b =
        boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final im = await b.toImage(pixelRatio: 1.5);
    final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
    final folder = Directory(
      const String.fromEnvironment(
        'UX_CAPTURE_DIR',
        defaultValue: 'artifacts/ux-lecturer-walkthrough',
      ),
    )..createSync(recursive: true);
    await File(
      '${folder.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    im.dispose();
  });
}

Future<void> setup(
  WidgetTester tester,
  WalkthroughRepository repo, {
  double scale = 1.3,
  bool live = false,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: live ? '/host/actual' : '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          appBar: AppBar(title: const Text('Hôm nay')),
          body: TodayPanel(user: teacher, onTimetable: () {}),
        ),
      ),
      GoRoute(
        path: '/host/:id',
        builder: (_, s) =>
            LiveAttendancePage(sessionId: s.pathParameters['id']!),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(
        theme: campusTheme(Brightness.light),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(key: boundary, child: child!),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    final appFonts = FontLoader('Be Vietnam Pro');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      appFonts.addFont(
        File(
          'assets/fonts/BeVietnamPro-$weight.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      );
    }
    await appFonts.load();
    if (!const bool.fromEnvironment('CAPTURE_UI')) return;
    final root = Platform.environment['FLUTTER_PREVIEW_FONTS']!;
    for (final f in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      final loader = FontLoader(f.key)
        ..addFont(
          File('$root/${f.value}').readAsBytes().then(ByteData.sublistView),
        );
      await loader.load();
    }
  });
  for (final scale in [1.3, 1.8]) {
    testWidgets('find ongoing class and open attendance at text scale $scale', (
      tester,
    ) async {
      final repo = WalkthroughRepository();
      await setup(tester, repo, scale: scale);
      await capture(tester, '01-today-$scale');
      for (
        var i = 0;
        i < 10 &&
            find
                .textContaining('Chưa mở điểm danh')
                .hitTestable()
                .evaluate()
                .isEmpty;
        i++
      ) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -260));
        await tester.pumpAndSettle();
      }
      expect(
        find.textContaining('Chưa mở điểm danh').hitTestable(),
        findsOneWidget,
      );
      await capture(tester, '01b-today-action-$scale');
      await tester.tap(find.textContaining('Chưa mở điểm danh'));
      await tester.pumpAndSettle();
      await capture(tester, '02-open-session-$scale');
      await tester.ensureVisible(find.text('Bắt đầu điểm danh'));
      await tester.tap(find.text('Bắt đầu điểm danh'));
      await tester.pumpAndSettle();
      expect(find.byType(LiveAttendancePage), findsOneWidget);
      await capture(tester, '03-qr-$scale');
      await tester.tap(find.byTooltip('QR toàn màn hình'));
      await tester.pumpAndSettle();
      await capture(tester, '03b-fullscreen-$scale');
      final qr = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'QrImageView',
      );
      expect(tester.getRect(qr).bottom, lessThanOrEqualTo(852));
      expect(tester.getRect(qr).top, greaterThanOrEqualTo(0));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'find student, inspect bulk preview and recover from uncertain save',
    (tester) async {
      final repo = WalkthroughRepository();
      await setup(tester, repo, live: true);
      await tester.ensureVisible(find.text('Sinh viên'));
      await tester.tap(find.text('Sinh viên'));
      await tester.pumpAndSettle();
      await capture(tester, '04-students');
      await tester.enterText(find.byType(TextField), 'Nguyen');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('1/32 sinh viên'),
        140,
        scrollable: find.byType(Scrollable).first,
      );
      await capture(tester, '04b-search-without-accents');
      await tester.enterText(find.byType(TextField), 'SE1010');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Nguyễn Minh Anh'),
        140,
        scrollable: find.byType(Scrollable).first,
      );
      await capture(tester, '05-search');
      expect(find.text('Điền cho 22 sinh viên'), findsNothing);
      await tester.ensureVisible(find.text('Sửa sinh viên này'));
      await tester.tap(find.text('Sửa sinh viên này'));
      await tester.pumpAndSettle();
      await capture(tester, '05b-single-student');
      expect(find.text('SE1010'), findsWidgets);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Điền cho 22 sinh viên'));
      await tester.tap(find.text('Điền cho 22 sinh viên'));
      await tester.pumpAndSettle();
      await capture(tester, '06-bulk-draft');
      expect(
        find.text('22 sinh viên còn chờ · Giữ các kết quả đã ghi nhận'),
        findsOneWidget,
      );
      await tester.tap(find.byType(SwitchListTile).first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(BulkAttendanceSheet),
          matching: find.byType(TextField),
        ),
        'Đã kiểm tra danh sách tại lớp',
      );
      await tester.ensureVisible(find.text('Xem trước'));
      await tester.tap(find.text('Xem trước'));
      await tester.pumpAndSettle();
      await capture(tester, '07-bulk-preview');
      expect(find.text('Vắng: 1'), findsOneWidget);
      await tester.ensureVisible(find.text('Xác nhận 22 sinh viên'));
      await tester.tap(find.text('Xác nhận 22 sinh viên'));
      await tester.pumpAndSettle();
      await capture(tester, '08-save-uncertain');
      expect(
        repo.calls
            .where((c) => c['name'] == 'bulkUpdatePendingAttendance')
            .length,
        1,
      );
      expect(
        find.textContaining('Chưa xác nhận được kết quả lưu'),
        findsOneWidget,
      );
      expect(find.text('Kiểm tra danh sách').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Kiểm tra danh sách'));
      await tester.pumpAndSettle();
      expect(find.byType(BulkAttendanceSheet), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'closing exposes pending-to-absent consequence before committing',
    (tester) async {
      final repo = WalkthroughRepository();
      await setup(tester, repo, live: true);
      await tester.tap(find.text('Kết thúc điểm danh'));
      await tester.pumpAndSettle();
      await capture(tester, '09-close-confirmation');
      expect(
        find.textContaining('Sinh viên còn chờ sẽ được chốt vắng'),
        findsOneWidget,
      );
      expect(repo.closed, false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'notebook distinguishes local save and restores typed lesson note',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: campusTheme(Brightness.light),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.3)),
              child: RepaintBoundary(key: boundary, child: child!),
            ),
            home: const LessonNotebookPage(
              uid: 'lecturer-l1',
              noteId: 'ux-note',
              metadata: {
                'classId': 'c1',
                'label': 'SE1 · PRM393 · Slot 1',
                'term': 'FA26',
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, '10-notebook');
      await tester.tap(find.text('Sau buổi'));
      await tester.pumpAndSettle();
      await capture(tester, '11-notebook-after-lesson');
      final field = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Ghi nhớ buổi sau',
      );
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Nhắc sinh viên ôn tập trước buổi sau');
      await tester.pumpAndSettle();
      expect(
        (await WorkspaceStore('lecturer-l1').read()).notes['ux-note']?['next'],
        'Nhắc sinh viên ôn tập trước buổi sau',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
