import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/lab2/class_timetable.dart';
import 'package:lecturer_companion/lab2/data_import.dart';
import 'package:lecturer_companion/lab2/ocr_import_page.dart';
import 'package:lecturer_companion/lab2/ocr_layout.dart';
import 'package:lecturer_companion/lab2/schedule_parser.dart';
import 'package:lecturer_companion/lab2/timetable.dart';
import 'timetable_test.dart' show teacher, teachingClasses, teachingSchedules;

void main() {
  test('desktop weekly image coordinates preserve all 20 timetable cells', () {
    final data =
        jsonDecode(
              File(
                'test/fixtures/ocr/weekly.json',
              ).readAsStringSync().replaceFirst('\uFEFF', ''),
            )
            as Map<String, dynamic>;
    final rows = ScheduleParser().parse(
      OcrLayout.reconstruct(data),
      useNvhTimes: true,
    );
    expect(rows, hasLength(20));
    expect(
      rows.every(
        (r) =>
            r.fields['classCode']!.isNotEmpty && r.fields['slot']!.isNotEmpty,
      ),
      true,
    );
    expect(
      rows
          .where((r) => r.fields['subjectCode'] == 'SWD392')
          .map((r) => r.fields['dayOfWeek']),
      ['2', '5'],
    );
  });
  test('A/P recurrence follows desktop; missing classes never guessed', () {
    for (final prefix in ['A', 'P']) {
      for (var i = 1; i <= 6; i++) {
        final rows = ScheduleParser().parse(
          'PRM393 $prefix$i NVH',
          useNvhTimes: true,
        );
        expect(rows.map((r) => r.fields['dayOfWeek']), [
          '${(i - 1) ~/ 2 + 1}',
          '${(i - 1) ~/ 2 + 4}',
        ]);
        expect(
          rows.first.fields['slot'],
          '${(i - 1) % 2 + (prefix == 'A' ? 1 : 3)}',
        );
        expect(rows.first.fields['classCode'], isEmpty);
      }
    }
  });
  test(
    'markbook finds embedded headers, filters selected class, deduplicates exact rows and rejects conflicts',
    () {
      final table = [
        ['FA26', 'Markbook'],
        ['Class', 'RollNumber', 'FullName', 'Email', 'Grade'],
        ['SE1928', 'SE0001', 'Nguyễn An', '', '8'],
        ['SE1929', 'SE0002', 'Bình', '', '7'],
        ['SE1928', 'SE0001', 'Nguyễn An', '', '8'],
      ];
      final result = reviewRosterAssignment(table, {'classCode': 'SE1928'});
      expect(result.errors, isEmpty);
      expect(result.rows, hasLength(1));
      expect(result.rows.single['studentCode'], 'SE0001');
      table.add(['SE1928', 'SE0001', 'Tên khác', '', '8']);
      expect(
        reviewRosterAssignment(table, {'classCode': 'SE1928'}).errors,
        isNotEmpty,
      );
    },
  );
  testWidgets('class week retains ended slots for history and advances week', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 10, 9, 4); // Friday 11:00 in Vietnam.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teachingSchedulesProvider(
            teacher.uid,
          ).overrideWith((ref) => Stream.value(teachingSchedules)),
          teachingSessionsProvider(
            'mobile',
          ).overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ClassTimetable(
              cls: teachingClasses.first,
              user: teacher,
              now: now,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 buổi học'), findsOneWidget);
    await tester.tap(find.byTooltip('Tuần sau'));
    await tester.pumpAndSettle();
    expect(find.text('1 buổi học'), findsOneWidget);
    expect(find.text('Slot 1 • 07:30 – 09:50'), findsOneWidget);
    expect(find.textContaining('Slot 3'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'OCR review requires explicit confirmation and retains fields for correction',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: OcrImportPage())),
      );
      await tester.enterText(find.byType(TextField).at(0), 'FA26');
      await tester.enterText(
        find.byType(TextField).at(1),
        'MON Slot 1 PRM393 SE1928 07:00 09:15 NVH 201',
      );
      await tester.ensureVisible(find.text('Phân tích văn bản thành lịch'));
      await tester.tap(find.text('Phân tích văn bản thành lịch'));
      await tester.pumpAndSettle();
      expect(find.text('1 dòng lịch cần duyệt'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Lưu lịch và tiếp tục nhập Excel'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(
                FilledButton,
                'Lưu lịch và tiếp tục nhập Excel',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
