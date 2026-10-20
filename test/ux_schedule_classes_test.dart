import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lecturer_companion/lab2/class_attendance_overview.dart';
import 'package:lecturer_companion/lab2/classes.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/repository.dart';
import 'package:lecturer_companion/lab2/theme.dart';
import 'package:lecturer_companion/lab2/timetable.dart';
import 'package:lecturer_companion/lab2/timetable_card.dart';
import 'phase2_ui_test.dart' show ClassFixture, lecturer;
import 'timetable_test.dart' show teachingClasses, teachingSchedules, teacher;

class SearchFixture extends ClassFixture {
  @override
  Stream<List<Data>> classes(UserProfile user) => Stream.value([
    cls,
    {
      ...cls,
      'id': 'second',
      'classCode': 'SE1930',
      'subjectName': 'Cơ sở dữ liệu',
    },
  ]);
}

final boundary = GlobalKey();

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_UI')) return;
  await tester.runAsync(() async {
    final image =
        await (boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final folder = Directory('artifacts/ux-schedule-classes');
    await folder.create(recursive: true);
    await File(
      '${folder.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget largeText(BuildContext context, Widget? child) => MediaQuery(
  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.8)),
  child: RepaintBoundary(key: boundary, child: child!),
);

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('CAPTURE_UI')) return;
    final loader = FontLoader('Be Vietnam Pro');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(
        File(
          'assets/fonts/BeVietnamPro-$weight.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      );
    }
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        File(
          '${Platform.environment['FLUTTER_PREVIEW_FONTS']!}/materialicons-regular.otf',
        ).readAsBytes().then(ByteData.sublistView),
      );
    await icons.load();
  });

  testWidgets(
    'class search ignores accents; clear restores classes; action selects a lesson',
    (tester) async {
      phone(tester);
      final repo = SearchFixture();
      addTearDown(repo.changes.close);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              appBar: AppBar(title: const Text('Lớp học')),
              body: const ClassList(user: lecturer),
            ),
          ),
          GoRoute(
            path: '/class/:id',
            builder: (_, state) => Scaffold(
              body: Text(
                'Chọn buổi: ${state.pathParameters['id']} / ${state.uri.queryParameters['tab']}',
              ),
            ),
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
            builder: largeText,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, '01-classes-large');
      await tester.enterText(find.byType(TextField), '  PHAT TRIEN ung dung  ');
      await tester.pumpAndSettle();
      expect(find.byType(ClassTile), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'khong co lop nay');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Xóa bộ lọc'));
      await tester.tap(find.text('Xóa bộ lọc'));
      await tester.pumpAndSettle();
      expect(find.byType(ClassTile), findsNWidgets(2));
      await tester.ensureVisible(find.text('Chọn buổi điểm danh').first);
      await tester.tap(find.text('Chọn buổi điểm danh').first);
      await tester.pumpAndSettle();
      expect(find.text('Chọn buổi: c / 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'student search is reachable before detailed summary and accepts unaccented names',
    (tester) async {
      phone(tester);
      final repo = SearchFixture();
      addTearDown(repo.changes.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            profileProvider.overrideWith((ref) => Stream.value(lecturer)),
          ],
          child: MaterialApp(
            theme: campusTheme(Brightness.light),
            builder: largeText,
            home: Scaffold(
              appBar: AppBar(title: const Text('Sinh viên')),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ClassAttendanceOverview(
                  cls: repo.cls,
                  showStudents: true,
                  showIdentity: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField).hitTestable(), findsOneWidget);
      await capture(tester, '02-students-large');
      await tester.enterText(find.byType(TextField), 'nguyen minh anh');
      await tester.pumpAndSettle();
      expect(find.byType(StudentAttendanceRow), findsOneWidget);
      expect(find.text('Nguyễn Minh Anh'), findsOneWidget);
      await tester.ensureVisible(find.text('Chuyên cần'));
      await tester.tap(find.text('Chuyên cần'));
      await tester.pumpAndSettle();
      expect(find.text('Cách tính & ngưỡng cảnh báo'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'empty subject filter has a recovery action in daily and weekly schedules',
    (tester) async {
      phone(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teachingClassesProvider('teacher').overrideWith(
              (ref) => Stream.value([
                ...teachingClasses,
                {'id': 'empty', 'subjectId': 'EMPTY', 'term': 'Fall 2026'},
              ]),
            ),
            teachingSchedulesProvider(
              'teacher',
            ).overrideWith((ref) => Stream.value(teachingSchedules)),
            teachingSessionsProvider(
              'empty',
            ).overrideWith((ref) => Stream.value([])),
            for (final cls in teachingClasses)
              teachingSessionsProvider(
                cls['id'] as String,
              ).overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            theme: campusTheme(Brightness.light),
            builder: largeText,
            home: Scaffold(
              appBar: AppBar(title: const Text('Lịch dạy')),
              body: LecturerTimetable(
                user: teacher,
                initialDay: DateTime.utc(2026, 10, 9),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, '03-timetable-large');
      await tester.ensureVisible(find.text('Lọc'));
      await tester.tap(find.text('Lọc'));
      await tester.pumpAndSettle();
      final subjectPicker = find.byType(DropdownButtonFormField<String>).last;
      await tester.ensureVisible(subjectPicker);
      await tester.tap(subjectPicker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('EMPTY').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Xem tất cả môn'),
        150,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await capture(tester, '04-filter-empty');
      await tester.scrollUntilVisible(
        find.text('Tuần'),
        -150,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Tuần')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tuần'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Xem tất cả môn'),
        150,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(
        find.text('Không có buổi học môn EMPTY tuần này.'),
        findsOneWidget,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Xem tất cả môn')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem tất cả môn'));
      await tester.pumpAndSettle();
      expect(find.byType(TeachingPeriodCard), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
