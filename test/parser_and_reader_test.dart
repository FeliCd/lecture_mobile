import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/services/markbook_reader.dart';
import 'package:lecturer_companion/services/schedule_parser.dart';

void main() {
  group('ScheduleParser OCR & Rule Tests', () {
    test('Fix OCR class code characters O->0, l/I->1', () {
      expect(ScheduleParser.fixClassCodeOcr('SE17O1'), 'SE1701');
      expect(ScheduleParser.fixClassCodeOcr('SEl801'), 'SE1801');
      expect(ScheduleParser.fixClassCodeOcr('SEI801'), 'SE1801');
      expect(ScheduleParser.fixClassCodeOcr('ai19o2'), 'AI1902');
      expect(ScheduleParser.fixClassCodeOcr('IA1601'), 'IA1601');
    });

    test('FPT A/P Block expansion into correct days of week', () {
      expect(ScheduleParser.getDaysForBlock('A'), [1, 4]); // Mon & Thu
      expect(ScheduleParser.getDaysForBlock('P'), [2, 5]); // Tue & Fri
      expect(ScheduleParser.getDaysForBlock('B'), [2, 5]);
      expect(ScheduleParser.getDaysForBlock('C'), [3, 6]); // Wed & Sat
    });

    test('Parse FPT Block format A1 automatically duplicates into 2 sessions', () {
      const ocrText = '''
FA24
A1: PRM393 SE1701 NVH201
P2: SWE201c SE1702 BE-301
''';
      final parsed = ScheduleParser.parseOcrText(ocrText);
      expect(parsed.length, 4);

      final prmMonday = parsed.firstWhere((s) => s.subjectCode == 'PRM393' && s.dayOfWeek == 1);
      final prmThursday = parsed.firstWhere((s) => s.subjectCode == 'PRM393' && s.dayOfWeek == 4);
      expect(prmMonday.slot, 1);
      expect(prmMonday.classCode, 'SE1701');
      expect(prmMonday.room, 'NVH201');
      expect(prmThursday.slot, 1);
      expect(prmThursday.classCode, 'SE1701');

      final sweTuesday = parsed.firstWhere((s) => s.subjectCode == 'SWE201C' && s.dayOfWeek == 2);
      final sweFriday = parsed.firstWhere((s) => s.subjectCode == 'SWE201C' && s.dayOfWeek == 5);
      expect(sweTuesday.slot, 2);
      expect(sweTuesday.classCode, 'SE1702');
      expect(sweFriday.slot, 2);
    });

    test('Parse explicit day of week, slot, time and room', () {
      const ocrText = '''
Thứ 2 Slot 3 PRM393 SE17O1 NVH 102
Thứ 4 Tiết 5 LAB211 IA1602 P.304
''';
      final parsed = ScheduleParser.parseOcrText(ocrText, defaultSemester: 'FA24');
      expect(parsed.length, 2);

      final item1 = parsed[0];
      expect(item1.dayOfWeek, 1);
      expect(item1.slot, 3);
      expect(item1.subjectCode, 'PRM393');
      expect(item1.classCode, 'SE1701'); // O corrected to 0
      expect(item1.startTime, '11:00');
      expect(item1.endTime, '12:30');

      final item2 = parsed[1];
      expect(item2.dayOfWeek, 3);
      expect(item2.slot, 5);
      expect(item2.subjectCode, 'LAB211');
      expect(item2.classCode, 'IA1602');
    });
  });

  group('MarkbookReader Tests', () {
    test('Subject code extraction from sheet name', () {
      expect(MarkbookReader.extractSubjectCode('23_PRM393'), 'PRM393');
      expect(MarkbookReader.extractSubjectCode('FA24_SWE201c_SE1701'), 'SWE201C');
      expect(MarkbookReader.extractSubjectCode('PRN231'), 'PRN231');
    });

    test('Parse CSV content correctly with student deduplication', () {
      const csvData = '''
Class,RollNumber,FullName,Email
SE1701,SE170101,Nguyen Van A,anvse170101@fpt.edu.vn
SE1701,SE170102,Tran Thi B,bttse170102@fpt.edu.vn
SE1701,SE170101,Nguyen Van A,anvse170101@fpt.edu.vn
''';
      final bytes = utf8.encode(csvData);
      final result = MarkbookReader.parseBytes(
        bytes: bytes,
        fileName: '23_PRM393.csv',
      );

      expect(result.suggestedSubjectCode, 'PRM393');
      expect(result.detectedClassCode, 'SE1701');
      expect(result.students.length, 2); // Duplicate SE170101 ignored
      expect(result.students[0].studentCode, 'SE170101');
      expect(result.students[0].fullName, 'Nguyen Van A');
      expect(result.students[1].studentCode, 'SE170102');
      expect(result.students[1].fullName, 'Tran Thi B');
    });

    test('Reject conflicting names for same student roll number', () {
      const csvConflict = '''
Class,RollNumber,FullName,Email
SE1701,SE170101,Nguyen Van A,anv@fpt.edu.vn
SE1701,SE170101,Le Van C,cvl@fpt.edu.vn
''';
      final bytes = utf8.encode(csvConflict);
      expect(
        () => MarkbookReader.parseBytes(
          bytes: bytes,
          fileName: 'PRM393.csv',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
