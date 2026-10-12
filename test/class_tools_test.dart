import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/lab2/class_tools.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/repository.dart';
import 'lab2_navigation_test.dart' show FixtureRepository;

class ToolsFixture extends FixtureRepository {
  Data? request;
  String? action;
  @override
  Future<Data> call(String name, Data input) async {
    action = name;
    request = input;
    return {'updated': true};
  }
}

void main() {
  testWidgets(
    'student edit requires reason, sends stable identity and never sends MSSV',
    (tester) async {
      final repo = ToolsFixture();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const ClassToolDialog(
                      cls: {'id': 'c1'},
                      student: {
                        'id': 'student-s1',
                        'displayName': 'Student',
                        'schoolEmail': 'student@fpt.edu.vn',
                        'studentCode': 'SE1',
                      },
                    ),
                  ),
                  child: const Text('Edit'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận lưu'));
      await tester.pumpAndSettle();
      expect(repo.request, isNull);
      expect(find.text('Vui lòng nhập thông tin'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).last, 'Correct typo');
      await tester.tap(find.text('Xác nhận lưu'));
      await tester.pumpAndSettle();
      expect(repo.request, isNull);
      await tester.tap(find.text('Xác nhận thay đổi'));
      await tester.pumpAndSettle();
      expect(repo.action, 'updateClassStudent');
      expect(repo.request!['studentUid'], 'student-s1');
      expect(repo.request!['fullName'], 'Student');
      expect(repo.request!.containsKey('studentCode'), false);
      expect(tester.takeException(), isNull);
    },
  );
}
