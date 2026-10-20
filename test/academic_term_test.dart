import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lecturer_companion/lab2/academic_term.dart';
import 'package:lecturer_companion/lab2/profile_academic_term.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/repository.dart';
import 'package:lecturer_companion/lab2/timetable.dart';
import 'package:lecturer_companion/lab2/today.dart';
import 'package:lecturer_companion/lab2/classes.dart';
import 'lab2_navigation_test.dart' show FixtureRepository;

const user = UserProfile('owner', 'Giảng viên', 'lecturer', []);

class TermRepository extends FixtureRepository {
  final rows = <Data>[
    {
      'id': 'fall',
      'classCode': 'FALL-CLASS',
      'subjectId': 'PRM232',
      'term': 'FA26',
    },
    {
      'id': 'summer',
      'classCode': 'SUMMER-CLASS',
      'subjectId': 'PRN212',
      'term': 'SU26',
    },
  ];
  @override
  Stream<List<Data>> classes(UserProfile user) => Stream.value(rows);
  @override
  Stream<List<Data>> watch(
    String collection, {
    String? field,
    Object? equals,
    String? uid,
  }) => Stream.value(
    collection == 'schedules'
        ? [
            for (final cls in rows)
              {
                'id': '${cls['id']}-schedule',
                'classCode': cls['classCode'],
                'subjectId': cls['subjectId'],
                'term': cls['term'],
                'lecturerUid': 'owner',
                'dayOfWeek': DateTime.now()
                    .toUtc()
                    .add(const Duration(hours: 7))
                    .weekday,
                'slot': 1,
                'startTime': '07:00',
                'endTime': '09:15',
                'room': 'A201',
              },
          ]
        : [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'default semester uses academic order and explicit saved selection never switches silently',
    () {
      final terms = academicTerms([
        for (final term in ['SU26', 'FA26', 'SP26', 'FA25', 'FA26', '', null])
          {'term': term},
      ]);
      expect(terms, ['FA25', 'SP26', 'SU26', 'FA26']);
      expect(resolveAcademicTerm(terms, null), 'FA26');
      expect(resolveAcademicTerm(terms, 'SU26'), 'SU26');
      expect(resolveAcademicTerm(terms, 'FA24'), 'FA24');
      expect(resolveAcademicTerm([], null), isNull);
    },
  );
  test(
    'semester persists across containers and is isolated by account',
    () async {
      final first = ProviderContainer();
      await first.read(selectedAcademicTermProvider('a').future);
      await first
          .read(selectedAcademicTermProvider('a').notifier)
          .select('SU26');
      await first
          .read(selectedAcademicTermProvider('b').notifier)
          .select('FA26');
      first.dispose();
      final reopened = ProviderContainer();
      addTearDown(reopened.dispose);
      expect(
        await reopened.read(selectedAcademicTermProvider('a').future),
        'SU26',
      );
      expect(
        await reopened.read(selectedAcademicTermProvider('b').future),
        'FA26',
      );
    },
  );
  testWidgets(
    'profile semester picker updates class list and persists without a picker on main screen',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(TermRepository()),
          profileProvider.overrideWith((ref) => Stream.value(user)),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProfileAcademicTermSelector(user: user),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SU26').last);
      await tester.pumpAndSettle();
      expect(
        container.read(selectedAcademicTermProvider('owner')).value,
        'SU26',
      );
      expect(
        (await SharedPreferences.getInstance()).getString(
          AcademicTermSettings.preferenceKey('owner'),
        ),
        'SU26',
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: ClassList(user: user)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('SUMMER-CLASS'), findsOneWidget);
      expect(find.textContaining('FALL-CLASS'), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      await container
          .read(selectedAcademicTermProvider('owner').notifier)
          .select('FA26');
      await tester.pumpAndSettle();
      expect(find.textContaining('FALL-CLASS'), findsOneWidget);
      expect(find.textContaining('SUMMER-CLASS'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Today and timetable read the same saved semester and have no semester dropdown',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        AcademicTermSettings.preferenceKey('owner'): 'SU26',
      });
      final container = ProviderContainer(
        overrides: [
          repositoryProvider.overrideWithValue(TermRepository()),
          profileProvider.overrideWith((ref) => Stream.value(user)),
        ],
      );
      addTearDown(container.dispose);
      await container.read(selectedAcademicTermProvider('owner').future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: TodayPanel(user: user, onTimetable: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Học kỳ SU26'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: LecturerTimetable(user: user)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('SU26'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      await container
          .read(selectedAcademicTermProvider('owner').notifier)
          .select('FA26');
      await tester.pumpAndSettle();
      expect(find.text('FA26'), findsOneWidget);
      expect(find.text('SU26'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
