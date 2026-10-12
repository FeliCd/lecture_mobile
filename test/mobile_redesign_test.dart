import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:lecturer_companion/lab2/app.dart';
import 'package:lecturer_companion/lab2/live_attendance.dart';
import 'package:lecturer_companion/lab2/repository.dart';
import 'package:lecturer_companion/lab2/theme.dart';
import 'package:lecturer_companion/lab2/timetable_card.dart';
import 'package:lecturer_companion/lab2/timetable_domain.dart';
import 'package:lecturer_companion/lab2/subject_updates.dart';
import 'package:lecturer_companion/lab2/today.dart';
import 'package:lecturer_companion/lab2/article_library.dart';
import 'lab2_navigation_test.dart' show FixtureRepository;
import 'refactor_live_test.dart' show LiveFixture;
import 'attendance_slot_flow_test.dart' show SlotFixture, user;
import 'subject_updates_test.dart' show UpdatesFixture;

class LoginFixture extends FixtureRepository {
  int attempts = 0;
  @override
  Future<void> loginWithGoogle() async {
    attempts++;
    throw StateError('PROFILE_NOT_REGISTERED');
  }
}

void main() {
  testWidgets(
    'Google is the only Mobile login action; denied account gets useful feedback',
    (tester) async {
      final repo = LoginFixture();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            profileProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: MaterialApp(
            theme: campusTheme(Brightness.light),
            home: const CampusLogin(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Đăng ký'), findsNothing);
      expect(find.text('Quên mật khẩu'), findsNothing);
      await tester.tap(find.text('Tiếp tục với Google'));
      await tester.pumpAndSettle();
      expect(repo.attempts, 1);
      expect(find.textContaining('giảng viên'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('stale live data hides QR, pending students remain pending', (
    tester,
  ) async {
    final repo = LiveFixture();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: campusTheme(Brightness.dark),
          home: const LiveAttendancePage(sessionId: 's'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    repo.fail = true;
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    expect(
      find.textContaining('Số liệu bên dưới có thể đã cũ'),
      findsOneWidget,
    );
    expect(find.textContaining('Chưa điểm danh'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  test(
    'feed normalization keeps real URL, source, excerpt, subject and research type',
    () {
      final article = normalizedUpdate({
        'canonicalUrl': 'https://example.org/paper',
        'sourceName': 'Crossref',
        'excerpt': 'Abstract',
        'subjectCodes': ['PRM393'],
        'contentType': 'RESEARCH',
      });
      expect(article['url'], 'https://example.org/paper');
      expect(article['source'], 'Crossref');
      expect(article['abstractSnippet'], 'Abstract');
      expect(article['subjectIds'], ['PRM393']);
      expect(article['contentType'], 'RESEARCH');
    },
  );

  test(
    'cancelled teaching occurrence is visible only when requested and cannot offer starting attendance',
    () {
      final repo = SlotFixture();
      final periods = teachingPeriods(
        user: user,
        day: campusDay(DateTime.now()),
        term: 'FA26',
        schedules: [repo.schedule],
        classes: [repo.cls],
        sessions: [],
        includeCancelled: true,
        exceptions: [
          {
            'id': 'e',
            'classId': 'c1',
            'scheduleId': 's1',
            'date': campusDay(
              DateTime.now(),
            ).toIso8601String().substring(0, 10),
            'kind': 'CANCELLED',
          },
        ],
      );
      expect(periods.single.cancelled, isTrue);
      expect(periodAction(periods.single), 'Đã hủy');
      expect(roomLabel(' '), 'Chưa cập nhật phòng');
    },
  );

  for (final size in [
    const Size(360, 900),
    const Size(393, 852),
    const Size(430, 932),
    const Size(844, 390),
    const Size(800, 1000),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('login, Today and live layouts $size dark=$dark text=1.8', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final screen in [
          'login',
          'today',
          'live',
          'settings',
          'updates',
        ]) {
          await tester.pumpWidget(
            ProviderScope(
              key: ValueKey(screen),
              overrides: [
                repositoryProvider.overrideWithValue(
                  screen == 'live'
                      ? LiveFixture()
                      : screen == 'updates'
                      ? UpdatesFixture()
                      : SlotFixture(),
                ),
                savedArticlesProvider.overrideWith((ref) => Stream.value([])),
                profileProvider.overrideWith(
                  (ref) => Stream.value(screen == 'login' ? null : user),
                ),
              ],
              child: MaterialApp(
                theme: campusTheme(dark ? Brightness.dark : Brightness.light),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.8)),
                  child: child!,
                ),
                home: screen == 'login'
                    ? const CampusLogin()
                    : screen == 'live'
                    ? const LiveAttendancePage(sessionId: 's')
                    : screen == 'settings'
                    ? const SettingsPage()
                    : screen == 'updates'
                    ? const Scaffold(body: SubjectUpdatesPage(user: user))
                    : Scaffold(
                        body: TodayPanel(user: user, onTimetable: () {}),
                      ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: screen);
          if (screen == 'today') {
            await tester.scrollUntilVisible(
              find.text('Chưa cập nhật phòng'),
              160,
              scrollable: find.byType(Scrollable).first,
            );
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  }
}
