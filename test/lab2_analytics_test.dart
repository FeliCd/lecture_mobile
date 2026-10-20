import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/lab2/classes.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/repository.dart';
import 'package:lecturer_companion/lab2/theme.dart';
import 'lab2_navigation_test.dart' show FixtureRepository;

class AnalyticsFixture extends FixtureRepository {
  @override
  Stream<List<Data>> watch(
    String collection, {
    String? field,
    Object? equals,
    String? uid,
  }) {
    if (collection == 'attendanceSessions') {
      return Stream.value([
        {
          'id': 'final',
          'classSessionId': 'final',
          'status': 'finalized',
          'opensAt': DateTime.now().millisecondsSinceEpoch,
        },
        {
          'id': 'open',
          'classSessionId': 'open',
          'status': 'open',
          'opensAt': DateTime.now().millisecondsSinceEpoch,
        },
        {
          'id': 'cancel',
          'classSessionId': 'cancel',
          'status': 'cancelled',
          'opensAt': DateTime.now().millisecondsSinceEpoch,
        },
      ]);
    }
    return Stream.value([
      for (final s in ['present', 'late', 'absent', 'excused'])
        {
          'attendanceSessionId': 'final',
          'classSessionId': 'final',
          'studentUid': 'student-$s',
          'status': s,
        },
      {
        'attendanceSessionId': 'open',
        'classSessionId': 'open',
        'studentUid': 'student-0',
        'status': 'absent',
      },
      {
        'attendanceSessionId': 'cancel',
        'classSessionId': 'cancel',
        'studentUid': 'student-0',
        'status': 'absent',
      },
    ]);
  }
}

void main() {
  testWidgets(
    'analytics excludes open/cancelled, preserves excused and withholds unconfigured rates',
    (tester) async {
      const profile = UserProfile('lecturer-0', 'Demo', 'lecturer', ['PRM393']);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith((ref) => Stream.value(profile)),
            repositoryProvider.overrideWithValue(AnalyticsFixture()),
            memberNamesProvider('class-0').overrideWith(
              (ref) => Stream.value({
                for (final status in ['present', 'late', 'absent', 'excused'])
                  'student-$status': {
                    'displayName': 'Nguyễn $status',
                    'studentCode': 'SE$status',
                  },
              }),
            ),
          ],
          child: MaterialApp(
            theme: campusTheme(Brightness.light),
            home: Scaffold(
              body: AnalyticsPanel(
                cls: const {
                  'id': 'class-0',
                  'classCode': 'SE1928',
                  'subjectId': 'PRM393',
                },
                user: profile,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Buổi đã học: 1'), findsOneWidget);
      expect(find.text('Chuyên cần: Chưa đủ dữ liệu'), findsOneWidget);
      expect(find.text('Tổng lượt vắng: 1'), findsOneWidget);
      expect(find.text('Cần theo dõi: 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
