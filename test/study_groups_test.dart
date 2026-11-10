import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/groups/study_groups.dart';
import 'package:lecturer_companion/lab2/theme.dart';

void main() {
  testWidgets('long group names fit on a narrow screen with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const name = 'Nhóm nghiên cứu thiết kế và phát triển ứng dụng di động';
    await tester.pumpWidget(
      MaterialApp(
        theme: campusTheme(Brightness.dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.4)),
          child: child!,
        ),
        home: Scaffold(
          body: StudyGroups(
            classId: 'c1',
            call: (method, _) async => switch (method) {
              'getGroupPlan' => {
                'version': 1,
                'groups': [
                  {
                    'id': 'g1',
                    'name': name,
                    'memberIds': ['s1'],
                  },
                ],
                'students': [
                  {
                    'studentId': 's1',
                    'studentCode': 'SE1',
                    'fullName': 'Sinh viên mẫu',
                  },
                ],
              },
              'getGroupSignupSheet' => {},
              'getGroupMessages' => {'messages': []},
              _ => throw StateError(method),
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final list = find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first;
    final group = find.text('$name · 1 thành viên').hitTestable();
    await tester.scrollUntilVisible(group, 150, scrollable: list);
    await tester.tap(group);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Sinh viên mẫu').hitTestable(),
      150,
      scrollable: list,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'automatic division includes every student exactly once and waits for explicit save',
    (tester) async {
      final students = List.generate(
        5,
        (i) => {
          'studentId': 's$i',
          'studentCode': 'SE$i',
          'fullName': 'Student $i',
        },
      );
      final saved = <Map<String, dynamic>>[];
      Future<dynamic> call(String method, Map<String, dynamic> data) async {
        if (method == 'getGroupPlan') {
          return {'version': 0, 'groups': [], 'students': students};
        }
        if (method == 'getGroupMessages') {
          return {'messages': [], 'older': null};
        }
        if (method == 'saveGroupPlan') {
          saved.add(data);
          return {'saved': true};
        }
        throw StateError(method);
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudyGroups(classId: 'c1', call: call),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chia ngẫu nhiên'));
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
      await tester.tap(find.text('Lưu cách chia nhóm'));
      await tester.pumpAndSettle();
      expect(saved.length, 1);
      final groups = saved.single['groups'] as List;
      final members = groups.expand((g) => g['memberIds'] as List).toList();
      expect(members.toSet(), {'s0', 's1', 's2', 's3', 's4'});
      expect(members.length, 5);
      expect(saved.single['classId'], 'c1');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('load denial shows retry without rendering roster', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudyGroups(
            classId: 'other-class',
            call: (m, d) async => throw StateError('PERMISSION_DENIED'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('PERMISSION_DENIED'), findsOneWidget);
    expect(find.text('Tải lại'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
