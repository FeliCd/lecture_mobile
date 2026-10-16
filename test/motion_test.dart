import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/repository.dart';
import 'package:lecturer_companion/lab2/today.dart';
import 'package:lecturer_companion/lab2/timetable_card.dart';
import 'package:lecturer_companion/lab2/motion.dart';
import 'package:lecturer_companion/lab2/theme.dart';
import 'assistant_ui_test.dart' show TodayFixture, user;

class MoreLessonsFixture extends TodayFixture {
  @override
  Stream<List<Data>> watch(
    String collection, {
    String? field,
    Object? equals,
    String? uid,
  }) => super
      .watch(collection, field: field, equals: equals, uid: uid)
      .map(
        (rows) => [
          ...rows,
          if (collection == 'classSessions')
            {...rows.first, 'id': 'earlier', 'slot': 2, 'status': 'finalized'},
        ],
      );
}

void main() {
  testWidgets(
    'other lessons expand without losing the featured lesson or tasks',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(MoreLessonsFixture()),
            profileProvider.overrideWith((ref) => Stream.value(user)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TodayPanel(user: user, onTimetable: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final section = find.text('Buổi khác (1)');
      await tester.scrollUntilVisible(
        section,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(TeachingPeriodCard), findsNWidgets(2));
      await tester.tap(section);
      await tester.pumpAndSettle();
      expect(find.byType(TeachingPeriodCard), findsOneWidget);
      await tester.tap(section);
      await tester.pumpAndSettle();
      expect(find.byType(TeachingPeriodCard), findsNWidgets(2));
      await tester.scrollUntilVisible(
        find.text('Đến hạn'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Đến hạn'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('entrance preserves input and scroll state on trigger change', (
    tester,
  ) async {
    var trigger = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Scaffold(
              body: CampusEntrance(
                trigger: trigger,
                child: ListView(
                  children: [const TextField(), const SizedBox(height: 1400)],
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Nội dung đang nhập');
    final fieldState = tester.state(find.byType(TextField));
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    final offset = scroll.position.pixels;
    update(() => trigger++);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(TextField)), same(fieldState));
    expect(scroll.position.pixels, offset);
    expect(find.text('Nội dung đang nhập'), findsOneWidget);
  });

  for (final accessible in [false, true]) {
    testWidgets('reduced motion completes immediately accessible=$accessible', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              disableAnimations: !accessible,
              accessibleNavigation: accessible,
            ),
            child: const CampusEntrance(child: Text('Hiện ngay')),
          ),
        ),
      );
      expect(
        tester
            .widget<FadeTransition>(find.byType(FadeTransition).last)
            .opacity
            .value,
        1,
      );
      expect(tester.binding.transientCallbackCount, 0);
    });
  }

  testWidgets('entrance removes replaced sensitive content in the same frame', (
    tester,
  ) async {
    var allowed = true;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return CampusEntrance(
              trigger: allowed,
              child: Text(allowed ? 'Mã QR còn hạn' : 'Không có quyền'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    update(() => allowed = false);
    await tester.pump();
    expect(find.text('Mã QR còn hạn'), findsNothing);
    expect(find.text('Không có quyền'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('highlight reacts only to changed data and cleans up its timer', (
    tester,
  ) async {
    var status = 'pending';
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        theme: campusTheme(Brightness.light),
        home: StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return CampusChangeHighlight(value: status, child: Text(status));
          },
        ),
      ),
    );
    Color? background() =>
        (tester
                    .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                    .decoration
                as BoxDecoration)
            .color;
    final original = background();
    update(() {});
    await tester.pump();
    expect(background(), original);
    update(() => status = 'present');
    await tester.pump();
    expect(background(), isNot(original));
    expect(find.text('pending'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    expect(background(), original);
    update(() => status = 'late');
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
