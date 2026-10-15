import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/lab2/attendance_actions.dart';
import 'package:lecturer_companion/lab2/attendance_qr.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/widgets.dart';

void main() {
  test('reads Desktop and signed QR metadata without embedding the secret', () {
    expect(
      attendanceQrMetadata(
        'https://school/checkin?sessionId=s1&token=abc&mode=student-code-secret',
      ),
      {'sessionId': 's1', 'secretRequired': true},
    );
    expect(
      attendanceQrMetadata(
        'faplab2://attendance?sessionId=s1&token=abc',
      )['secretRequired'],
      false,
    );
    final token =
        '${base64Url.encode(utf8.encode(jsonEncode({'sessionId': 's2', 'secretRequired': true})))}.signature';
    expect(attendanceQrMetadata(token)['secretRequired'], true);
    expect(attendanceQrMetadata(token)['sessionId'], 's2');
    expect(attendanceQrMetadata('invalid'), isEmpty);
    expect(errorMessage(StateError('SECRET_INVALID')), contains('không đúng'));
  });
  testWidgets('correction requires a reason and returns status and notes', (
    tester,
  ) async {
    Data? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<Data>(
                  context: context,
                  builder: (_) => const AttendanceEditDialog(status: 'absent'),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập lý do điều chỉnh.'), findsOneWidget);
    expect(result, isNull);
    await tester.tap(find.text('Có mặt').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '  Có giấy phép  ');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(result, {'status': 'present', 'notes': 'Có giấy phép'});
  });
  testWidgets('empty attendance stream still renders the roster controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LiveList(
          buildEmpty: true,
          source: () => Stream.value(<Data>[]),
          builder: (rows) => const Text('Danh sách chưa điểm danh'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Danh sách chưa điểm danh'), findsOneWidget);
  });
}
