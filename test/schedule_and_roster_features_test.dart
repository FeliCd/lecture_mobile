import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/api/repository.dart';
import 'package:lecturer_companion/features/classes/roster_import_screen.dart';
import 'package:lecturer_companion/features/schedule/manual_schedule_sheet.dart';
import 'package:lecturer_companion/features/schedule/schedule_review_screen.dart';
import 'package:lecturer_companion/models/domain.dart';
import 'package:lecturer_companion/services/schedule_parser.dart';

import 'fixtures.dart';

void main() {
  late FixtureApi api;
  late LecturerRepository repo;
  late Lecturer lecturer;

  setUp(() {
    api = FixtureApi();
    repo = LecturerRepository(api);
    lecturer = Lecturer.fromJson(lecturerJson);
  });

  group('LecturerRepository ClassTarget & Schedule Contracts', () {
    test('classTargets aggregates from both Classes and Schedules', () async {
      final targets = await repo.classTargets(lecturer.lecturerId);
      expect(targets.isNotEmpty, isTrue);

      // classJson from fixtures has PRM393 SE1901 FA26
      final found = targets.where((t) => t.subjectCode == 'PRM393' && t.classCode == 'SE1901');
      expect(found.length, 1);
      expect(found.first.classId, 'class-1');
    });

    test('batchUpdateSchedules sends correct payload to backend', () async {
      final schedule = Schedule(
        scheduleId: 'test-sched-1',
        lecturerId: lecturer.lecturerId,
        semester: 'FA26',
        subjectCode: 'PRM393',
        subjectName: 'Mobile Programming',
        classCode: 'SE1901',
        dayOfWeek: 1,
        slot: 1,
        startTime: '07:30',
        endTime: '09:00',
        room: 'NVH 102',
        sourceType: 'MANUAL',
      );

      await repo.batchUpdateSchedules([schedule]);
      expect(api.calls.any((c) => c.$1 == 'batchUpdate'), isTrue);
      final lastCall = api.calls.firstWhere((c) => c.$1 == 'batchUpdate');
      expect(lastCall.$2['sheet'], 'Schedules');
      final rows = lastCall.$2['rows'] as List;
      expect(rows.length, 1);
      expect(rows[0]['scheduleId'], 'test-sched-1');
      expect(rows[0]['sourceType'], 'MANUAL');
    });

    test('deleteSchedule sends deleteRow action with schedule id', () async {
      await repo.deleteSchedule('test-sched-1');
      expect(api.calls.any((c) => c.$1 == 'deleteRow'), isTrue);
      final call = api.calls.firstWhere((c) => c.$1 == 'deleteRow');
      expect(call.$2['sheet'], 'Schedules');
      expect(call.$2['id'], 'test-sched-1');
    });

    test('importRoster sends normalized student payload', () async {
      final students = [
        RosterStudent(
          classCode: 'SE1901',
          studentCode: 'SE170101',
          fullName: 'Nguyen Van A',
          schoolEmail: 'anv@fpt.edu.vn',
        ),
      ];

      final res = await repo.importRoster(
        semester: 'FA26',
        subjectCode: 'PRM393',
        classCode: 'SE1901',
        students: students,
      );

      expect(res['added'], 1);
      final call = api.calls.firstWhere((c) => c.$1 == 'importRoster');
      expect(call.$2['semester'], 'FA26');
      expect(call.$2['subjectCode'], 'PRM393');
      expect(call.$2['classCode'], 'SE1901');
      final stList = call.$2['students'] as List;
      expect(stList.length, 1);
      expect(stList[0]['studentCode'], 'SE170101');
    });
  });

  group('ManualScheduleSheet UI & Validation', () {
    testWidgets('Renders all input fields and validates before save', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualScheduleSheet(
              repo: repo,
              lecturer: lecturer,
              defaultSemester: 'FA26',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thêm lịch dạy mới'), findsOneWidget);
      expect(find.text('Học kỳ *'), findsOneWidget);
      expect(find.text('Mã môn học *'), findsOneWidget);
      expect(find.text('Mã lớp *'), findsOneWidget);
      expect(find.text('Thứ trong tuần *'), findsOneWidget);
      expect(find.text('Slot học *'), findsOneWidget);
      expect(find.text('Phòng học *'), findsOneWidget);
      expect(find.text('Lưu lịch dạy'), findsOneWidget);

      // Attempt to save while required fields are empty
      await tester.ensureVisible(find.text('Lưu lịch dạy'));
      await tester.tap(find.text('Lưu lịch dạy'));
      await tester.pumpAndSettle();

      expect(find.text('Nhập mã môn'), findsOneWidget);
      expect(find.text('Nhập mã lớp'), findsOneWidget);

      // Fill in valid data
      await tester.enterText(find.widgetWithText(TextFormField, 'Mã môn học *'), 'PRM393');
      await tester.enterText(find.widgetWithText(TextFormField, 'Mã lớp *'), 'SE1901');
      await tester.enterText(find.widgetWithText(TextFormField, 'Phòng học *'), 'NVH 102');
      await tester.pumpAndSettle();

      // Submit
      await tester.ensureVisible(find.text('Lưu lịch dạy'));
      await tester.tap(find.text('Lưu lịch dạy'));
      await tester.pumpAndSettle();

      expect(api.calls.any((c) => c.$1 == 'batchUpdate'), isTrue);
    });
  });

  group('ScheduleReviewScreen (Human-in-the-loop OCR Review)', () {
    testWidgets('Requires checkbox confirmation before saving OCR items', (tester) async {
      final items = [
        ParsedScheduleItem(
          semester: 'FA26',
          subjectCode: 'PRM393',
          classCode: 'SE1901',
          dayOfWeek: 1,
          slot: 1,
          startTime: '07:30',
          endTime: '09:00',
          room: 'NVH 102',
          sourceType: 'IMAGE',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ScheduleReviewScreen(
            repo: repo,
            lecturer: lecturer,
            initialItems: items,
            semester: 'FA26',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kiểm tra & Xác nhận OCR'), findsOneWidget);
      expect(find.text('Buổi 1'), findsOneWidget);

      // The save button is disabled when checkbox is unchecked
      final saveButtonFinder = find.widgetWithText(FilledButton, 'Lưu vào hệ thống (1 buổi)');
      final button = tester.widget<FilledButton>(saveButtonFinder);
      expect(button.onPressed, isNull);

      // Check the confirmation checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Now button is enabled
      final enabledButton = tester.widget<FilledButton>(saveButtonFinder);
      expect(enabledButton.onPressed, isNotNull);

      // Click save
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      expect(api.calls.any((c) => c.$1 == 'batchUpdate'), isTrue);
      final call = api.calls.firstWhere((c) => c.$1 == 'batchUpdate');
      final rows = call.$2['rows'] as List;
      expect(rows[0]['sourceType'], 'IMAGE');
    });
  });

  group('RosterImportScreen UI', () {
    testWidgets('Renders upload options and displays class target options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RosterImportScreen(
            repo: repo,
            lecturer: lecturer,
            defaultSemester: 'FA26',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nhập SV từ Bảng tính'), findsOneWidget);
      expect(find.text('Chọn file bảng tính'), findsOneWidget);
    });
  });
}
