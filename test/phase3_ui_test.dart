import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/lab2/classes.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/repository.dart';
import 'package:lecturer_companion/lab2/theme.dart';
import 'phase2_ui_test.dart' show ClassFixture, lecturer;
import 'timetable_test.dart' show teacher, teachingClasses, teachingSchedules;
import 'package:lecturer_companion/lab2/timetable.dart';
import 'package:lecturer_companion/lab2/class_attendance_overview.dart';

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('CAPTURE_UI')) return;
    final root = Platform.environment['FLUTTER_PREVIEW_FONTS']!;
    for (final e in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      final loader = FontLoader(e.key)
        ..addFont(
          File('$root/${e.value}').readAsBytes().then(ByteData.sublistView),
        );
      await loader.load();
    }
  });

  test('warning labels follow configured policy and unknown data', () {
    expect(
      attendanceWarningLabel(
        AttendanceSummary([
          'absent',
          'present',
          'present',
        ], policy: const AttendancePolicy(limitPercent: 30)),
      ),
      'Vượt ngưỡng vắng 30%',
    );
    expect(
      attendanceWarningLabel(AttendanceSummary(['late'])),
      contains('Chờ cấu hình'),
    );
    expect(attendanceWarningLabel(AttendanceSummary([])), 'Chưa đủ dữ liệu');
  });
  testWidgets('compact student opens existing history with all counts', (
    tester,
  ) async {
    final repo = ClassFixture();
    addTearDown(repo.changes.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          profileProvider.overrideWith((ref) => Stream.value(lecturer)),
        ],
        child: const MaterialApp(home: ClassPage(classId: 'c')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Nguyễn Minh Anh'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Nguyễn Minh Anh'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text('Có mặt 0 • Đi trễ 0 • Vắng 0 • Có phép 0'),
      findsOneWidget,
    );
    expect(find.text('Chưa có bản ghi điểm danh đã chốt.'), findsOneWidget);
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
  for (final sample in [
    (const Size(360, 900), 1.0, false),
    (const Size(375, 900), 1.0, false),
    (const Size(390, 900), 2.0, true),
    (const Size(412, 900), 1.0, true),
    (const Size(430, 900), 2.0, false),
    (const Size(844, 390), 2.0, true),
  ]) {
    testWidgets('agenda and compact rows layout ${sample.$1} scale=${sample.$2}', (
      tester,
    ) async {
      tester.view.physicalSize = sample.$1;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      Future<void> show(Widget screen) async {
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
              theme: campusTheme(
                sample.$3 ? Brightness.dark : Brightness.light,
              ),
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(
                  c,
                ).copyWith(textScaler: TextScaler.linear(sample.$2)),
                child: child!,
              ),
              home: RepaintBoundary(
                key: boundary,
                child: Scaffold(body: screen),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      Future<void> capture(String label) async {
        if (!const bool.fromEnvironment('CAPTURE_UI')) return;
        final render =
            boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final img = await render.toImage();
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/phase3-ui/$label-${sample.$1.width.toInt()}-${sample.$2}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          img.dispose();
        });
      }

      await show(
        LecturerTimetable(user: teacher, initialDay: DateTime.utc(2026, 10, 9)),
      );
      await capture('timetable');
      await tester.scrollUntilVisible(
        find.byTooltip('Lọc lịch dạy'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Lọc lịch dạy'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Lọc lịch dạy'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(DropdownButtonFormField<String>).last,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('PRM393').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Xóa lọc môn'));
      await tester.tap(find.text('Xóa lọc môn'));
      await tester.pumpAndSettle();
      expect(find.text('Xóa lọc môn'), findsNothing);
      await tester.scrollUntilVisible(
        find.byTooltip('Lọc lịch dạy'),
        -180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Fall 2026'), findsWidgets);
      expect(tester.takeException(), isNull);
      await show(
        ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final statuses in [
              <String>[],
              ['present', 'absent'],
              ['late'],
            ])
              StudentAttendanceRow(
                name:
                    'Nguyễn Trường Phúc — tên sinh viên dài để kiểm tra xuống dòng',
                code: 'SE183277',
                summary: AttendanceSummary(statuses),
                onTap: () {},
              ),
          ],
        ),
      );
      await capture('students');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
