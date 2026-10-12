import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lecturer_companion/lab2/mobile_ocr.dart';
import 'package:lecturer_companion/lab2/schedule_parser.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android ML Kit reads a timetable image locally and produces reviewable schedule rows',
    (tester) async {
      final result = await recognizeTimetablePath(
        '/data/local/tmp/fap_schedule.png',
      );
      expect(result.text, isNotEmpty);
      final rows = ScheduleParser().parse(result.text, useNvhTimes: true);
      expect(rows, isNotEmpty);
      expect(rows.any((r) => r.fields['subjectCode']!.isNotEmpty), true);
      expect(rows.single.fields['startTime'], '07:30');
      expect(rows.single.fields['endTime'], '09:00');
      expect(rows.single.fields['room'], 'AL-201');
      // Capture actual recognition evidence without student data.
      // ignore: avoid_print
      print('OCR_NATIVE rows=${rows.length}\n${result.text}');
    },
  );
}
