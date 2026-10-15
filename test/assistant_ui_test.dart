import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/repository.dart';
import 'package:lecturer_companion/lab2/today.dart';
import 'package:lecturer_companion/lab2/theme.dart';
import 'package:lecturer_companion/lab2/timetable_domain.dart';
import 'package:lecturer_companion/lab2/lecturer_workspace.dart';
import 'package:lecturer_companion/lab2/lecturer_workspace_store.dart';
import 'lab2_navigation_test.dart' show FixtureRepository;

const user = UserProfile('u', 'Nguyễn Trường Phúc', 'lecturer', ['PRM393']);

class TodayFixture extends FixtureRepository {
  @override
  Stream<List<Data>> classes(UserProfile user) => Stream.value([
    {
      'id': 'c',
      'classCode': 'SE1928',
      'subjectId': 'PRM393',
      'term': 'Fall 2026',
    },
  ]);
  @override
  Stream<List<Data>> watch(
    String collection, {
    String? field,
    Object? equals,
    String? uid,
  }) => Stream.value(
    collection == 'classSessions'
        ? [
            {
              'id': 's',
              'classId': 'c',
              'lecturerUid': 'u',
              'startsAt': DateTime.now()
                  .subtract(const Duration(minutes: 5))
                  .millisecondsSinceEpoch,
              'endsAt': DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch,
              'slot': 1,
              'room': 'A201',
              'status': 'open',
            },
          ]
        : [],
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    if (!const bool.fromEnvironment('CAPTURE_UI')) return;
    final root = Platform.environment['FLUTTER_PREVIEW_FONTS']!;
    for (final e in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      final loader = FontLoader(e.key)
        ..addFont(
          File('$root/${e.value}').readAsBytes().then(ByteData.sublistView),
        );
      await loader.load();
    }
  });
  test(
    'focus skips cancelled, completed and past periods; prefers current over future',
    () {
      TeachingPeriod p(
        int start, {
        bool cancelled = false,
        bool completed = false,
      }) => TeachingPeriod(
        day: DateTime.utc(2026, 10, 15),
        classId: 'c',
        sessionId: null,
        classCode: 'SE',
        subjectId: 'PRM',
        subjectName: '',
        room: '',
        term: 'Fall',
        slot: 1,
        start: start,
        end: start + 90,
        recurring: true,
        cancelled: cancelled,
        completed: completed,
      );
      final current = p(600), future = p(800);
      expect(
        todayFocus([
          future,
          p(500),
          p(550, cancelled: true),
          p(590, completed: true),
          current,
        ], DateTime.utc(2026, 10, 15, 3, 30)),
        same(current),
      );
      expect(todayFocus([p(500)], DateTime.utc(2026, 10, 15, 8)), isNull);
    },
  );
  test(
    'carry forward appends once, preserves target and enforces same class/term',
    () async {
      final store = WorkspaceStore('u');
      await store.saveNote('a', {
        'classId': 'c',
        'term': 'Fall',
        'subjectId': 'PRM',
        'date': '2026-10-15',
        'next': 'Demo',
      });
      await store.saveNote('b', {
        'classId': 'c',
        'term': 'Fall',
        'subjectId': 'PRM',
        'date': '2026-10-16',
        'goals': 'Mục tiêu cũ',
        'taught': 'Giữ nguyên',
      });
      await store.carryForward('a', 'b', 'Demo');
      await store.carryForward('a', 'b', 'Demo');
      final data = await store.read();
      expect(
        data.notes['b']!['goals'],
        'Mục tiêu cũ\n\nTiếp nối 2026-10-15:\nDemo',
      );
      expect(data.notes['b']!['taught'], 'Giữ nguyên');
      expect(data.notes['a']!['next'], 'Demo');
      await expectLater(
        store.carryForward('b', 'a', 'Sai ngày'),
        throwsStateError,
      );
      await store.saveNote('other', {
        'classId': 'other',
        'term': 'Fall',
        'subjectId': 'PRM',
        'date': '2026-10-17',
      });
      await expectLater(
        store.carryForward('a', 'other', 'Sai lớp'),
        throwsStateError,
      );
    },
  );
  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets('assistant Today and notebook 360px dark=$dark scale=$scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = WorkspaceStore('u');
        await store.saveTask({
          'id': 'due',
          'title': 'Chấm bài Lab 3',
          'due': DateTime.now()
              .subtract(const Duration(hours: 1))
              .toUtc()
              .toIso8601String(),
        });
        await store.saveTask({
          'id': 'done',
          'title': 'Không hiện việc đã xong',
          'done': true,
          'due': DateTime.now().toUtc().toIso8601String(),
        });
        await store.saveNote('a', {
          'label': 'PRM393 · SE1928 · Slot 1',
          'goals': 'Vận dụng vòng đời Activity',
          'prep': 'Slide bài 4\nCode demo',
          'checkedPrep': ['Slide bài 4'],
          'taught': 'Nội dung đã hoàn thành',
          'next': 'Demo còn lại',
        });
        final boundary = GlobalKey();
        Future<void> show(Widget screen) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                repositoryProvider.overrideWithValue(TodayFixture()),
                profileProvider.overrideWith((ref) => Stream.value(user)),
              ],
              child: MaterialApp(
                theme: campusTheme(dark ? Brightness.dark : Brightness.light),
                builder: (c, child) => MediaQuery(
                  data: MediaQuery.of(
                    c,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: RepaintBoundary(key: boundary, child: screen),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        Future<void> capture(String name) async {
          if (!const bool.fromEnvironment('CAPTURE_UI')) return;
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final img = await render.toImage();
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            await Directory('build/assistant-ui').create(recursive: true);
            await File(
              'build/assistant-ui/$name-${dark ? 'dark' : 'light'}-$scale.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            img.dispose();
          });
        }

        await show(
          Scaffold(
            appBar: AppBar(title: const Text('Hôm nay')),
            body: TodayPanel(user: user, onTimetable: () {}),
          ),
        );
        expect(find.text('Đang dạy'), findsOneWidget);
        expect(find.text('Phòng A201'), findsOneWidget);
        await capture('today');
        await tester.scrollUntilVisible(
          find.text('Chấm bài Lab 3'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Không hiện việc đã xong'), findsNothing);
        expect(tester.takeException(), isNull);
        await show(
          const LessonNotebookPage(
            uid: 'u',
            noteId: 'a',
            metadata: {'label': 'PRM393 · SE1928 · Slot 1'},
          ),
        );
        await capture('notebook-before');
        await tester.scrollUntilVisible(
          find.text('Vận dụng vòng đời Activity'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Vận dụng vòng đời Activity'), findsOneWidget);
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        if (scale > 1.3) {
          await tester.tap(find.byType(DropdownButtonFormField<int>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Sau buổi').last);
        } else {
          await tester.tap(find.text('Sau buổi'));
        }
        await tester.pumpAndSettle();
        await capture('notebook-after');
        await tester.scrollUntilVisible(
          find.text('Nội dung đã hoàn thành'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Nội dung đã hoàn thành'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }
  }
}
