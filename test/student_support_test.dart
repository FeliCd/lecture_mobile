import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lecturer_companion/lab2/student_support.dart';
import 'package:lecturer_companion/lab2/class_attendance_overview.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/repository.dart';
import 'package:lecturer_companion/lab2/theme.dart';

Data lesson(int n, {String status = 'finalized'}) => {
  'id': '$n',
  'opensAt': DateTime.utc(2026, 10, n, 1).millisecondsSinceEpoch,
  'slot': 1,
  'status': status,
  'eligibleStudentUids': ['a', 'b'],
};
Data record(int n, String status, {String uid = 'a'}) => {
  'attendanceSessionId': '$n',
  'studentUid': uid,
  'status': status,
};
const user = UserProfile('owner', 'Giảng viên', 'lecturer', []);
final captureKey = GlobalKey();
Widget captureBuilder(BuildContext context, Widget? child) => RepaintBoundary(
  key: captureKey,
  child: MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.3)),
    child: child!,
  ),
);
Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_UI')) return;
  await tester.runAsync(() async {
    final image =
        await (captureKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final folder = Directory('artifacts/student-support-ui');
    await folder.create(recursive: true);
    await File(
      '${folder.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('CAPTURE_UI')) return;
    final loader = FontLoader('Be Vietnam Pro');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(
        File(
          'assets/fonts/BeVietnamPro-$weight.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      );
    }
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        File(
          '${Platform.environment['FLUTTER_PREVIEW_FONTS']!}/materialicons-regular.otf',
        ).readAsBytes().then(ByteData.sublistView),
      );
    await icons.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'latest absences are sorted by session time, ignoring open and cancelled sessions',
    () {
      final sessions = [
        lesson(1),
        lesson(3),
        lesson(2),
        lesson(4, status: 'open'),
        lesson(5, status: 'cancelled'),
      ];
      final records = [
        record(1, 'present'),
        record(2, 'absent'),
        record(3, 'absent'),
        record(4, 'absent'),
      ];
      final run = consecutiveAbsences('a', sessions, records);
      expect(run.map((s) => s['id']), ['3', '2']);
      expect(absenceRunDate(run.first), '03/10/2026 · Slot 1');
    },
  );
  test(
    'present, late, missing and ambiguous records break the chain',
    () {
      for (final status in ['present', 'late', 'pending']) {
        expect(
          consecutiveAbsences(
            'a',
            [lesson(1), lesson(2), lesson(3)],
            [record(1, 'absent'), record(2, status), record(3, 'absent')],
          ).length,
          1,
        );
      }
      expect(
        consecutiveAbsences('a', [lesson(1), lesson(2)], [record(1, 'absent')]),
        isEmpty,
      );
      expect(
        consecutiveAbsences(
          'a',
          [lesson(2)],
          [record(2, 'absent'), record(2, 'present')],
        ),
        isEmpty,
      );
    },
  );
  test(
    'unknown dates and tied times do not invent an absence order; unenrolled lessons are skipped',
    () {
      expect(
        consecutiveAbsences(
          'a',
          [
            lesson(1),
            {'id': 'unknown', 'status': 'finalized'},
          ],
          [record(1, 'absent')],
        ),
        isEmpty,
      );
      expect(
        consecutiveAbsences(
          'a',
          [
            lesson(1),
            {...lesson(1), 'id': 'tie'},
          ],
          [record(1, 'absent')],
        ),
        isEmpty,
      );
      expect(
        consecutiveAbsences(
          'a',
          [
            lesson(1),
            {
              ...lesson(2),
              'eligibleStudentUids': ['b'],
            },
          ],
          [record(1, 'absent')],
        ).length,
        1,
      );
    },
  );
  test(
    'private notes isolate account, class and student; serial saves and reopen preserve both entries',
    () async {
      final store = StudentSupportStore('one'),
          other = StudentSupportStore('two');
      addTearDown(store.dispose);
      addTearDown(other.dispose);
      await Future.wait([
        store.save('c1', 'a', 'Ghi chú một', 'Trao đổi bài lab', true),
        store.save('c2', 'a', 'Ghi chú hai', '', false),
      ]);
      final restored = StudentSupportStore('one');
      addTearDown(restored.dispose);
      expect(
        (await restored.read())[studentSupportKey('c1', 'a')]!['next'],
        'Trao đổi bài lab',
      );
      expect(
        (await restored.read())[studentSupportKey('c2', 'a')]!['note'],
        'Ghi chú hai',
      );
      expect(await other.read(), isEmpty);
      await store.save('c1', 'a', '', '', false);
      expect((await store.read()).keys, [studentSupportKey('c2', 'a')]);
    },
  );
  test('unreadable local notes refuse to overwrite existing storage', () async {
    final store = StudentSupportStore('one');
    addTearDown(store.dispose);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(store.key, '{broken');
    await expectLater(
      store.save('c', 'a', 'new', '', false),
      throwsFormatException,
    );
    expect(prefs.getString(store.key), '{broken');
  });
  testWidgets(
    'follow-up filter combines explicit mark with absence evidence and excludes normal students',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = StudentSupportStore(user.uid);
      addTearDown(store.dispose);
      await store.save('c', 'b', 'Trao đổi riêng', 'Buổi tới', true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith((ref) => Stream.value(user)),
            classAttendanceSessionsProvider(
              'c',
            ).overrideWith((ref) => Stream.value([lesson(1), lesson(2)])),
            classAttendanceRecordsProvider('c').overrideWith(
              (ref) => Stream.value([
                record(1, 'absent'),
                record(2, 'absent'),
                record(1, 'present', uid: 'b'),
                record(2, 'present', uid: 'b'),
              ]),
            ),
            memberNamesProvider('c').overrideWith(
              (ref) => Stream.value({
                'a': {'displayName': 'Nguyễn An', 'studentCode': 'SE01'},
                'b': {'displayName': 'Bình', 'studentCode': 'SE02'},
                'normal': {'displayName': 'Châu', 'studentCode': 'SE03'},
              }),
            ),
          ],
          child: MaterialApp(
            theme: campusTheme(Brightness.light),
            builder: captureBuilder,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ClassAttendanceOverview(
                  cls: {'id': 'c'},
                  showStudents: true,
                  showIdentity: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Cần theo dõi'));
      await tester.pumpAndSettle();
      expect(find.byType(StudentAttendanceRow), findsNWidgets(2));
      expect(find.text('Châu'), findsNothing);
      expect(find.text('Vắng 2 buổi liên tiếp'), findsOneWidget);
      await capture(tester, '01-follow-up');
      await tester.ensureVisible(find.text('Nguyễn An'));
      await tester.tap(find.text('Nguyễn An'));
      await tester.pumpAndSettle();
      expect(find.text('02/10/2026 · Slot 1'), findsOneWidget);
      expect(find.text('01/10/2026 · Slot 1'), findsOneWidget);
      expect(find.text('Cấm thi'), findsNothing);
      await capture(tester, '02-evidence');
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'editor saves explicit follow-up and warns before discarding text at large size',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith((ref) => Stream.value(user)),
          ],
          child: MaterialApp(
            builder: captureBuilder,
            theme: campusTheme(Brightness.light),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(1.8)),
                      child: const StudentSupportEditor(
                        accountUid: 'owner',
                        classId: 'c',
                        studentUid: 'a',
                        name: 'Nguyễn An',
                        initial: {},
                      ),
                    ),
                  ),
                  child: const Text('Mở ghi chú'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mở ghi chú'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'Cần giải thích lại bài lab',
      );
      await tester.ensureVisible(find.text('Hủy'));
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.text('Bỏ thay đổi?'), findsOneWidget);
      await tester.tap(find.text('Tiếp tục viết'));
      await tester.pumpAndSettle();
      await capture(tester, '03-private-note-large');
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Lưu ghi chú'));
      await tester.tap(find.text('Lưu ghi chú'));
      await tester.pumpAndSettle();
      expect(find.byType(StudentSupportEditor), findsNothing);
      final store = StudentSupportStore('owner');
      addTearDown(store.dispose);
      expect(
        (await store.read())[studentSupportKey('c', 'a')]!['followUp'],
        true,
      );
      expect(
        (await store.read())[studentSupportKey('c', 'a')]!['note'],
        'Cần giải thích lại bài lab',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
