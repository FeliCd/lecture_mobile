import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/theme.dart';
import 'package:lecturer_companion/lab2/widgets.dart';
import 'package:lecturer_companion/lab2/quiz.dart';

void main() {
  test('eligibility, excused and risk threshold', () {
    expect(
      AttendanceSummary(['present', 'late', 'absent', 'excused']).rate,
      isNull,
    );
    expect(AttendanceSummary(['excused']).rate, isNull);
    expect(AttendanceSummary(['absent', 'absent']).atRisk, false);
    expect(AttendanceSummary(['absent', 'absent', 'late']).atRisk, false);
    final summary = AttendanceSummary(
      ['present', 'late', 'absent', 'excused'],
      totalSlots: 5,
      policy: const AttendancePolicy(
        lateCountsAsPresent: true,
        excusedInDenominator: false,
      ),
    );
    expect(summary.rate, closeTo(200 / 3, 0.001));
    expect(summary.late, 1);
    expect(summary.excused, 1);
    expect(summary.absent, 1);
    expect(summary.atRisk, true);
  });
  test('CSV BOM, CRLF, Unicode, quotes and formula injection', () {
    final csv = attendanceCsv([
      [
        'SE1928',
        'PRM393',
        '08/10/2026',
        'SE000001',
        'Nguyễn "A", B',
        'present',
        '',
        '=CMD()',
      ],
    ]);
    expect(csv.startsWith('\uFEFF'), true);
    expect(csv, contains('Nguyễn ""A"", B'));
    expect(csv, contains("\"'=CMD()\""));
    expect(csv.endsWith('\r\n'), true);
    expect(csvCell('  @SUM(1)'), contains("'"));
  });
  test('unknown and inactive accounts never receive a role', () {
    expect(
      () => UserProfile.fromMap('u', {'active': true, 'role': 'admin'}),
      throwsStateError,
    );
    expect(
      () => UserProfile.fromMap('u', {'active': false, 'role': 'lecturer'}),
      throwsStateError,
    );
  });
  for (final brightness in Brightness.values) {
    testWidgets('shared UI supports $brightness, narrow width and large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: campusTheme(brightness),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: ListView(
                children: [
                  CampusCard(
                    child: Column(
                      children: [
                        const StatusBadge('late'),
                        QuizOptionTile(
                          text: 'Câu trả lời có nội dung dài bằng tiếng Việt',
                          selected: true,
                          onTap: () {},
                        ),
                        AppPrimaryButton(
                          label: 'Gửi câu trả lời',
                          onPressed: () => pressed = true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Gửi câu trả lời'));
      expect(pressed, true);
      expect(tester.takeException(), isNull);
      expect(find.text('Đi trễ'), findsOneWidget);
    });
  }
}
