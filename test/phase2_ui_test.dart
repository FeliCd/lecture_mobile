import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:lecturer_companion/lab2/classes.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/live_attendance.dart';
import 'package:lecturer_companion/lab2/repository.dart';
import 'package:lecturer_companion/lab2/theme.dart';
import 'refactor_live_test.dart' show LiveFixture;

const lecturer = UserProfile('u', 'Nguyễn Trường Phúc', 'lecturer', ['PRM393']);

class ClassFixture extends LiveFixture {
  final changes = StreamController<Data?>.broadcast();
  final Data cls = {
    'id': 'c',
    'classCode': 'SE1928',
    'subjectId': 'PRM393',
    'subjectName': 'Phát triển ứng dụng di động',
    'term': 'Fall 2026',
    'studentCount': 3,
  };
  @override
  Stream<Data?> document(String path) async* {
    yield cls;
    yield* changes.stream;
  }

  @override
  Stream<Map<String, Data>> memberStream(String classId) => Stream.value({
    'a': {'displayName': 'Nguyễn Minh Anh', 'studentCode': 'SE192801'},
    'b': {'displayName': 'Trần Hoàng Nam', 'studentCode': 'SE192802'},
    'c': {'displayName': 'Lê Phương Linh', 'studentCode': 'SE192803'},
  });
}

class ClosingFixture extends LiveFixture {
  @override
  Future<Data> call(String name, Data input) async {
    if (name == 'closeAttendanceSession') closed = true;
    return super.call(name, input);
  }
}

Future<void> chooseStudents(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Sinh viên'),
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('Sinh viên'));
  await tester.pumpAndSettle();
}

void main() {
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
  testWidgets(
    'live modes preserve search and filter; stale data cannot expose QR or editing',
    (tester) async {
      final repo = LiveFixture();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: LiveAttendancePage(sessionId: 's')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
      await chooseStudents(tester);
      expect(find.byType(QrImageView), findsNothing);
      await tester.scrollUntilVisible(
        find.byType(TextField),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byType(TextField), 'Student');
      await tester.pumpAndSettle();
      final pendingFilter = find.widgetWithText(ChoiceChip, 'Chưa điểm danh');
      await tester.ensureVisible(pendingFilter);
      await tester.pumpAndSettle();
      await tester.tap(pendingFilter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mã QR'));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsOneWidget);
      await chooseStudents(tester);
      await tester.scrollUntilVisible(
        find.byType(TextField),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Student',
      );
      expect(tester.widget<ChoiceChip>(pendingFilter).selected, isTrue);
      repo.fail = true;
      await tester.tap(find.byTooltip('Cập nhật phiên'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byTooltip('Sửa điểm danh'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Sửa điểm danh',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Mã QR'));
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('closed session starts with students and no close action', (
    tester,
  ) async {
    final repo = LiveFixture()..closed = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: LiveAttendancePage(sessionId: 's')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    expect(
      tester
          .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
          .selected,
      {true},
    );
    expect(find.text('Kết thúc và chốt điểm danh'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'close action stays available in both modes and requires confirmation',
    (tester) async {
      final repo = ClosingFixture();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: LiveAttendancePage(sessionId: 's')),
        ),
      );
      await tester.pumpAndSettle();
      await chooseStudents(tester);
      await tester.tap(find.text('Kết thúc và chốt điểm danh'));
      await tester.pumpAndSettle();
      expect(find.text('Kết thúc điểm danh?'), findsOneWidget);
      expect(repo.calls, isNot(contains('closeAttendanceSession')));
      await tester.tap(find.text('Kết thúc'));
      await tester.pumpAndSettle();
      expect(
        repo.calls.where((name) => name == 'closeAttendanceSession').length,
        1,
      );
      expect(find.text('Đã kết thúc'), findsOneWidget);
      expect(find.text('Kết thúc và chốt điểm danh'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'class header and tools survive tab changes; denied data clears context',
    (tester) async {
      final repo = ClassFixture();
      addTearDown(repo.changes.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            profileProvider.overrideWith((ref) => Stream.value(lecturer)),
          ],
          child: const MaterialApp(home: ClassPage(classId: 'c')),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('SE1928')),
        findsOneWidget,
      );
      for (final index in [1, 2, 3, 0]) {
        await tester.ensureVisible(find.byType(Tab).at(index));
        await tester.tap(find.byType(Tab).at(index));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(ClassContextHeader),
            matching: find.text('Fall 2026'),
          ),
          findsOneWidget,
        );
      }
      await tester.tap(find.byTooltip('Công cụ lớp'));
      await tester.pumpAndSettle();
      expect(find.text('Nhập sinh viên vào lớp'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      repo.changes.addError(StateError('PERMISSION_DENIED'));
      await tester.pumpAndSettle();
      expect(find.byType(ClassContextHeader), findsNothing);
      expect(find.text('SE1928'), findsNothing);
      repo.changes.add(null);
      await tester.pumpAndSettle();
      expect(find.textContaining('Không tìm thấy lớp'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final sample in [
    (const Size(360, 900), 1.0, false),
    (const Size(360, 900), 2.0, true),
    (const Size(844, 390), 2.0, false),
    (const Size(800, 1000), 1.8, true),
  ]) {
    testWidgets('phase2 layout ${sample.$1} scale=${sample.$2}', (
      tester,
    ) async {
      tester.view.physicalSize = sample.$1;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = ClassFixture();
      addTearDown(repo.changes.close);
      final boundary = GlobalKey();
      Future<void> show(Widget screen) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              repositoryProvider.overrideWithValue(repo),
              profileProvider.overrideWith((ref) => Stream.value(lecturer)),
            ],
            child: MaterialApp(
              theme: campusTheme(
                sample.$3 ? Brightness.dark : Brightness.light,
              ),
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(
                  c,
                ).copyWith(textScaler: TextScaler.linear(sample.$2)),
                child: child!,
              ),
              home: RepaintBoundary(key: boundary, child: screen),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      Future<void> capture(String label) async {
        if (!const bool.fromEnvironment('CAPTURE_UI')) return;
        final render =
            boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final img = await render.toImage();
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/phase2-ui/$label-${sample.$1.width.toInt()}-${sample.$2}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          img.dispose();
        });
      }

      await show(const ClassPage(classId: 'c'));
      await capture('class');
      await show(const LiveAttendancePage(sessionId: 's'));
      await capture('qr');
      await chooseStudents(tester);
      await capture('students');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
