import 'package:lecturer_companion/lab2/article_library.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lecturer_companion/lab2/app.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/repository.dart';
import 'package:lecturer_companion/lab2/desktop_sync.dart';

class FixtureRepository implements CampusRepository {
  @override
  Stream<Map<String, Data>> memberStream(String classId) => Stream.value({});
  @override
  Stream<List<Data>> classes(UserProfile user) => Stream.value([
    {
      'id': 'class-0',
      'classCode': 'SE1928',
      'subjectId': 'PRM393',
      'term': 'Fall 2026',
      'studentCount': 10,
    },
  ]);
  @override
  Stream<List<Data>> watch(
    String collection, {
    String? field,
    Object? equals,
    String? uid,
  }) => Stream.value([]);
  @override
  Future<Data> call(String name, Data input) async => {
    'articles': <Data>[],
    'cached': false,
    'fetchedAt': DateTime.now().millisecondsSinceEpoch,
    'nextPage': null,
  };
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final role in ['lecturer']) {
    testWidgets(
      '$role has correct destinations and theme preserves navigation',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final profile = UserProfile('user', 'Người dùng demo', role, [
          'PRM393',
        ]);
        final container = ProviderContainer(
          overrides: [
            savedArticlesProvider.overrideWith((ref) => Stream.value([])),
            authProvider.overrideWith((ref) => Stream.value(null)),
            profileProvider.overrideWith((ref) => Stream.value(profile)),
            repositoryProvider.overrideWithValue(FixtureRepository()),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const CampusApp(),
          ),
        );
        await tester.pumpAndSettle();
        final allLabels = role == 'lecturer'
            ? ['Hôm nay', 'Lịch dạy', 'Lớp học', 'Cập nhật', 'Tương tác']
            : ['Trang chủ', 'Điểm danh', 'Tài liệu', 'Hoạt động'];
        final labels = quizEnabled
            ? allLabels
            : allLabels.take(allLabels.length - 1).toList();
        expect(
          find.byType(NavigationDestination),
          findsNWidgets(labels.length),
        );
        if (!quizEnabled) expect(find.text(allLabels.last), findsNothing);
        for (final label in labels) {
          expect(find.text(label), findsWidgets);
        }
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(labels[2]),
          ),
        );
        await tester.pumpAndSettle();
        container.read(themeProvider.notifier).setMode(ThemeMode.dark);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          2,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'revoked profile removes private routes and shows approved-account message',
    (tester) async {
      final controller = StreamController<UserProfile?>();
      addTearDown(controller.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedArticlesProvider.overrideWith((ref) => Stream.value([])),
            authProvider.overrideWith((ref) => Stream.value(null)),
            profileProvider.overrideWith((ref) => controller.stream),
            repositoryProvider.overrideWithValue(FixtureRepository()),
          ],
          child: const CampusApp(),
        ),
      );
      controller.add(const UserProfile('u', 'Demo', 'lecturer', ['PRM393']));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      controller.addError(StateError('Tài khoản chưa được phân quyền'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Tài khoản chưa được phân quyền'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
