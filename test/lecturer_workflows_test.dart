import 'dart:typed_data';
import 'package:excel/excel.dart' hide Data;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/lab2/article_library.dart';
import 'package:lecturer_companion/lab2/data_import.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/import_page.dart';
import 'package:lecturer_companion/lab2/repository.dart';
import 'lab2_navigation_test.dart' show FixtureRepository;

class ImportFixture extends FixtureRepository {
  final List<Data> calls = [];
  @override
  Future<Data> call(String name, Data input) async {
    calls.add({'name': name, ...input});
    return {'added': 1, 'existing': 0, 'saved': 1};
  }
}

void main() {
  test(
    'one mobile role and preserved attendance states; metadata labels never show IDs',
    () {
      expect(
        () =>
            UserProfile.fromMap('student', {'active': true, 'role': 'student'}),
        throwsStateError,
      );
      expect(
        UserProfile.fromMap('teacher', {
          'active': true,
          'role': 'lecturer',
        }).isLecturer,
        true,
      );
      expect(attendanceStatus('LATE'), 'late');
      expect(attendanceStatus('EXCUSED'), 'excused');
      expect(
        AttendanceSummary(['present', 'late', 'absent', 'excused']).rate,
        isNull,
      );
      expect(
        attendanceSessionLabel(
          {'id': 'opaque123', 'slot': 3},
          {'subjectName': 'Lập trình di động', 'subjectId': 'PRM393'},
        ),
        'Lập trình di động (PRM393) • Slot 3',
      );
    },
  );
  test(
    'CSV/Excel paste supports accents, quoted names and rejects duplicates and wrong class',
    () {
      final parsed = parseImportText(
        '\uFEFFMSSV,Họ tên,Email\r\nSE1,"Nguyễn, An",\r\nSE2,Bình,b@fpt.edu.vn',
      );
      final roster = reviewImport(
        parsed,
        timetable: false,
        cls: {'classCode': 'SE99'},
      );
      expect(roster.errors, isEmpty);
      expect(roster.rows.length, 2);
      expect(roster.rows.first['fullName'], 'Nguyễn, An');
      expect(
        reviewImport(
          parseImportText('SE1\tAn\t\nSE1\tAn\t'),
          timetable: false,
          cls: {'classCode': 'SE99'},
        ).errors,
        isNotEmpty,
      );
      expect(
        reviewImport(
          [
            ['MSSV', 'Họ tên', 'Mã lớp'],
            ['SE1', 'An', 'WRONG'],
          ],
          timetable: false,
          cls: {'classCode': 'SE99'},
        ).errors,
        isNotEmpty,
      );
      expect(() => parseImportText('SE1,"Unclosed'), throwsFormatException);
      final timetable = reviewImport([
        [
          'Học kỳ',
          'Mã môn',
          'Tên môn',
          'Mã lớp',
          'Thứ',
          'Slot',
          'Giờ bắt đầu',
          'Giờ kết thúc',
          'Phòng',
        ],
        [
          'FA26',
          'prm393',
          'Mobile',
          'SE99',
          'Thứ 2',
          '3',
          '7:30',
          '09:50',
          'A201',
        ],
      ], timetable: true);
      expect(timetable.errors, isEmpty);
      expect(timetable.rows.single['dayOfWeek'], 1);
      expect(timetable.rows.single['startTime'], '07:30');
    },
  );
  test('XLSX preserves real cell values and time cells', () {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    sheet.appendRow([TextCellValue('startTime'), TextCellValue('endTime')]);
    sheet.appendRow([
      TimeCellValue(hour: 7, minute: 30),
      TimeCellValue(hour: 9, minute: 50),
    ]);
    final tables = decodeImportWorkbook(Uint8List.fromList(excel.encode()!));
    expect(tables['Sheet1']!.last, ['07:30', '09:50']);
  });
  test(
    'saved article keys deduplicate DOI and keep URL articles distinct after saving',
    () {
      expect(
        articleKey({'doi': '10.1/ABC', 'url': 'https://x/a'}),
        articleKey({'doi': '10.1/abc', 'url': 'https://x/b'}),
      );
      expect(
        articleKey({'doi': '', 'url': 'https://x/a'}),
        isNot(articleKey({'doi': '', 'url': 'https://x/b'})),
      );
      expect(
        articleKey({'doi': null, 'url': 'https://x/a'}),
        articleKey({'doi': '', 'url': 'https://x/a'}),
      );
    },
  );
  testWidgets(
    'manual roster import sends selected class; bulk errors prevent submitting',
    (tester) async {
      final repo = ImportFixture();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            home: ImportPage(cls: {'id': 'c1', 'classCode': 'SE99'}),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'SE123');
      await tester.enterText(find.byType(TextFormField).at(1), 'Nguyễn An');
      await tester.ensureVisible(find.text('Nhập vào lớp'));
      await tester.tap(find.text('Nhập vào lớp'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận lưu'));
      await tester.pumpAndSettle();
      expect(repo.calls.single['classId'], 'c1');
      expect(repo.calls.single['name'], 'importClassStudents');
      expect(
        (repo.calls.single['students'] as List).single['studentCode'],
        'SE123',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
