import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/lab2/class_attendance_config.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/repository.dart';
import 'lab2_navigation_test.dart' show FixtureRepository;

class ConfigRepository extends FixtureRepository {
  final calls = <Data>[];
  Object? failure;
  @override
  Future<Data> call(String name, Data input) async {
    calls.add({'name': name, ...input});
    if (failure != null) throw failure!;
    return {'saved': true, 'totalSlots': input['totalSlots']};
  }
}

void main() {
  testWidgets(
    'course total editor validates whole slots and saves only an explicit valid total',
    (tester) async {
      final repo = ConfigRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            home: Scaffold(body: ClassAttendanceConfig(cls: {'id': 'c'})),
          ),
        ),
      );
      await tester.tap(find.text('Thiết lập'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '20.5');
      await tester.tap(find.text('Lưu tổng slot'));
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);
      expect(find.text('Nhập số nguyên từ 1 đến 1000'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '20');
      await tester.tap(find.text('Lưu tổng slot'));
      await tester.pumpAndSettle();
      expect(repo.calls.single, {
        'name': 'setClassAttendanceConfig',
        'classId': 'c',
        'totalSlots': 20,
      });
      expect(find.text('Đã lưu tổng slot môn học'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'rejected total shows server error and does not change displayed plan',
    (tester) async {
      final repo = ConfigRepository()
        ..failure = StateError('TOTAL_SLOTS_BELOW_COMPLETED');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            home: Scaffold(
              body: ClassAttendanceConfig(cls: {'id': 'c', 'totalSlots': 20}),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Thiết lập'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '1');
      await tester.tap(find.text('Lưu tổng slot'));
      await tester.pumpAndSettle();
      expect(
        find.text('Tổng slot không thể nhỏ hơn số slot đã hoàn tất điểm danh.'),
        findsOneWidget,
      );
      expect(find.textContaining('Tổng môn học: 20 slot'), findsOneWidget);
      expect(find.text('Đã lưu tổng slot môn học'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
