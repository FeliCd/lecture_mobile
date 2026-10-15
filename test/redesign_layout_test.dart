import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/lab2/app.dart';
import 'package:lecturer_companion/lab2/classes.dart';
import 'package:lecturer_companion/lab2/class_attendance_overview.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/repository.dart';
import 'package:lecturer_companion/lab2/theme.dart';
import 'package:lecturer_companion/lab2/timetable.dart';
import 'package:lecturer_companion/lab2/today.dart';
import 'package:lecturer_companion/lab2/live_attendance.dart';
import 'lab2_navigation_test.dart' show FixtureRepository;
import 'timetable_test.dart' show teachingClasses, teachingSchedules;
import 'attendance_slot_flow_test.dart' show SlotFixture, user;
import 'refactor_live_test.dart' show LiveFixture;

class RoomPreviewFixture extends SlotFixture {
  @override
  Map<String, dynamic> get schedule => {...super.schedule, 'room': 'A201'};
}

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_UI')) {
      final fontRoot = Platform.environment['FLUTTER_PREVIEW_FONTS'];
      if (fontRoot == null) {
        throw StateError(
          'Set FLUTTER_PREVIEW_FONTS to the Flutter material_fonts directory.',
        );
      }
      for (final entry in {
        'Roboto': 'roboto-regular.ttf',
        'MaterialIcons': 'materialicons-regular.otf',
      }.entries) {
        final loader = FontLoader(entry.key);
        loader.addFont(
          File(
            '$fontRoot/${entry.value}',
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
        await loader.load();
      }
    }
  });
  const profile = UserProfile('lecturer', 'Nguyễn Minh Anh', 'lecturer', [
    'PRM393',
  ]);
  const cls = {
    'id': 'class-0',
    'classCode': 'SE1928',
    'subjectId': 'PRM393',
    'term': 'Fall 2026',
    'studentCount': 3,
  };
  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets('redesigned screens at 360px, dark=$dark, text=$scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = ProviderContainer(
          overrides: [
            repositoryProvider.overrideWithValue(FixtureRepository()),
            profileProvider.overrideWith((ref) => Stream.value(profile)),
            teachingClassesProvider(
              profile.uid,
            ).overrideWith((ref) => Stream.value(teachingClasses)),
            teachingSchedulesProvider(profile.uid).overrideWith(
              (ref) => Stream.value(
                teachingSchedules
                    .map((s) => {...s, 'lecturerUid': profile.uid})
                    .toList(),
              ),
            ),
            for (final c in teachingClasses)
              teachingSessionsProvider(
                c['id'] as String,
              ).overrideWith((ref) => Stream.value([])),
            classAttendanceSessionsProvider('class-0').overrideWith(
              (ref) => Stream.value([
                for (var i = 0; i < 20; i++)
                  {'id': '$i', 'status': 'finalized'},
              ]),
            ),
            classAttendanceRecordsProvider('class-0').overrideWith(
              (ref) => Stream.value([
                for (var i = 0; i < 20; i++)
                  for (final uid in ['a', 'b'])
                    {
                      'attendanceSessionId': '$i',
                      'classSessionId': '$i',
                      'studentUid': uid,
                      'status': i < (uid == 'a' ? 3 : 5) ? 'absent' : 'present',
                    },
              ]),
            ),
            memberNamesProvider('class-0').overrideWith(
              (ref) => Stream.value({
                'a': {
                  'displayName': 'Trần Hoàng Nam',
                  'studentCode': 'SE192801',
                },
                'b': {
                  'displayName': 'Lê Phương Linh',
                  'studentCode': 'SE192802',
                },
                'c': {
                  'displayName': 'Nguyễn Thị Minh Châu',
                  'studentCode': 'SE192803',
                },
              }),
            ),
          ],
        );
        addTearDown(container.dispose);
        for (final screen in [
          'home',
          'classes',
          'students',
          'timetable',
          'login',
          'live',
        ]) {
          final boundaryKey = GlobalKey();
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: campusTheme(dark ? Brightness.dark : Brightness.light),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(360, 900),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: RepaintBoundary(
                    key: boundaryKey,
                    child: screen == 'login'
                        ? const CampusLogin()
                        : screen == 'live'
                        ? ProviderScope(
                            overrides: [
                              repositoryProvider.overrideWithValue(
                                LiveFixture(),
                              ),
                            ],
                            child: const LiveAttendancePage(sessionId: 's'),
                          )
                        : Scaffold(
                            appBar: AppBar(
                              title: Text(
                                screen == 'home'
                                    ? 'Hôm nay'
                                    : screen == 'classes'
                                    ? 'Lớp học'
                                    : screen == 'timetable'
                                    ? 'Lịch dạy'
                                    : 'Chi tiết lớp',
                              ),
                            ),
                            body: screen == 'home'
                                ? ProviderScope(
                                    overrides: [
                                      repositoryProvider.overrideWithValue(
                                        RoomPreviewFixture(),
                                      ),
                                    ],
                                    child: TodayPanel(
                                      user: user,
                                      onTimetable: () {},
                                    ),
                                  )
                                : screen == 'classes'
                                ? const ClassList(user: profile)
                                : screen == 'timetable'
                                ? LecturerTimetable(
                                    user: profile,
                                    initialDay: DateTime.utc(2026, 10, 9),
                                  )
                                : screen == 'login'
                                ? const CampusLogin()
                                : screen == 'live'
                                ? ProviderScope(
                                    overrides: [
                                      repositoryProvider.overrideWithValue(
                                        LiveFixture(),
                                      ),
                                    ],
                                    child: const LiveAttendancePage(
                                      sessionId: 's',
                                    ),
                                  )
                                : const SingleChildScrollView(
                                    padding: EdgeInsets.all(20),
                                    child: ClassAttendanceOverview(
                                      cls: cls,
                                      showStudents: true,
                                    ),
                                  ),
                            bottomNavigationBar: NavigationBar(
                              selectedIndex: screen == 'home'
                                  ? 0
                                  : screen == 'timetable'
                                  ? 1
                                  : 2,
                              destinations: const [
                                NavigationDestination(
                                  icon: Icon(Icons.home_outlined),
                                  label: 'Hôm nay',
                                ),
                                NavigationDestination(
                                  icon: Icon(Icons.calendar_month_outlined),
                                  label: 'Lịch dạy',
                                ),
                                NavigationDestination(
                                  icon: Icon(Icons.groups_outlined),
                                  label: 'Lớp học',
                                ),
                                NavigationDestination(
                                  icon: Icon(Icons.article_outlined),
                                  label: 'Cập nhật',
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (screen == 'students') {
            await tester.ensureVisible(find.text('SE192803'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          if (const bool.fromEnvironment('CAPTURE_UI') && scale == 1) {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final output = File(
              'build/ui-previews/$screen-${dark ? 'dark' : 'light'}.png',
            );
            await tester.runAsync(() async {
              final rendered = await boundary.toImage(pixelRatio: 2);
              final bytes = await rendered.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await output.parent.create(recursive: true);
              await output.writeAsBytes(bytes!.buffer.asUint8List());
              rendered.dispose();
            });
          }
        }
      });
    }
  }
}
