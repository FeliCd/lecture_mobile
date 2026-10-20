import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lecturer_companion/lab2/repository.dart';
import 'package:lecturer_companion/lab2/weekly_timetable.dart';
import 'package:lecturer_companion/lab2/timetable_domain.dart';
import 'package:lecturer_companion/lab2/timetable_card.dart';
import 'package:lecturer_companion/lab2/theme.dart';

final monday = DateTime.utc(2026, 10, 19);
final days = List.generate(7, (i) => monday.add(Duration(days: i)));
TeachingPeriod lesson(
  int day,
  int slot, {
  String code = 'PRM232',
  bool completed = false,
  bool cancelled = false,
  String? room,
}) => TeachingPeriod(
  day: days[day],
  classId: 'c-$day-$slot-$code',
  sessionId: null,
  classCode: 'SE${1818 + day}',
  subjectId: code,
  subjectName: 'Lập trình ứng dụng di động',
  room: room ?? 'A201',
  term: 'FA26',
  slot: slot,
  start: [420, 570, 750, 900][slot.clamp(1, 4) - 1],
  end: [555, 705, 885, 1035][slot.clamp(1, 4) - 1],
  recurring: true,
  completed: completed,
  cancelled: cancelled,
);
final captureKey = GlobalKey();
Future<void> pumpWeek(
  WidgetTester tester,
  List<TeachingPeriod> lessons, {
  double scale = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [profileProvider.overrideWith((ref) => Stream.value(null))],
      child: MaterialApp(
        theme: campusTheme(brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          appBar: AppBar(title: const Text('Thời khóa biểu tuần')),
          body: SingleChildScrollView(
            child: RepaintBoundary(
              key: captureKey,
              child: ColoredBox(
                color: campusTheme(brightness).scaffoldBackgroundColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: WeeklyTimetable(
                    days: days,
                    byDay: {
                      for (final day in days)
                        day: lessons.where((p) => p.day == day).toList(),
                    },
                    selectedDay: monday,
                    onSelectDay: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
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
    final iconFolder = Platform.environment['FLUTTER_PREVIEW_FONTS'];
    if (iconFolder != null) {
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          File(
            '$iconFolder/materialicons-regular.otf',
          ).readAsBytes().then(ByteData.sublistView),
        );
      await icons.load();
    }
  });
  testWidgets('weekly grid has exactly four slot rows and no lunch row', (
    tester,
  ) async {
    await pumpWeek(tester, [
      lesson(0, 1, completed: true),
      lesson(0, 2),
      lesson(1, 1, code: 'PRN212'),
      lesson(1, 3),
      lesson(2, 4, code: 'SWT301'),
    ]);
    for (var slot = 1; slot <= 4; slot++) {
      expect(find.byKey(ValueKey('week-slot-$slot')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('week-slot-5')), findsNothing);
    expect(find.textContaining('Nghỉ trưa'), findsNothing);
    expect(find.text('07:00–09:15'), findsNWidgets(2));
    expect(find.text('Đã chốt'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('CAPTURE_UI')) {
      await tester.runAsync(() async {
        final boundary =
            captureKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final picture = await boundary.toImage(pixelRatio: 2);
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        await Directory('artifacts/weekly-timetable').create(recursive: true);
        await File(
          'artifacts/weekly-timetable/week-four-slots.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
    }
  });
  testWidgets(
    'horizontal scrolling keeps slot labels fixed; tapping a lesson opens its management card',
    (tester) async {
      final p = lesson(0, 1);
      await pumpWeek(tester, [p, lesson(4, 4)]);
      final anchor = tester.getTopLeft(
        find.byKey(const ValueKey('week-slot-1')),
      );
      await tester.tap(find.text('SE1818'));
      await tester.pumpAndSettle();
      final card = tester.widget<TeachingPeriodCard>(
        find.byType(TeachingPeriodCard),
      );
      expect(card.period, same(p));
      expect(card.showAction, true);
      Navigator.of(tester.element(find.byType(TeachingPeriodCard))).pop();
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('weekly-grid-scroll')),
        const Offset(-580, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('week-slot-1'))),
        anchor,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets('conflicts and cancellation fit at 200% text in $brightness', (
      tester,
    ) async {
      await pumpWeek(
        tester,
        [
          lesson(0, 1),
          lesson(0, 1, code: 'PRN212'),
          lesson(1, 2, cancelled: true, room: 'Phòng thực hành rất dài'),
        ],
        scale: 2,
        brightness: brightness,
      );
      expect(find.text('Trùng giờ'), findsNWidgets(3));
      expect(find.text('Đã hủy'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'out of range legacy slots remain accessible without creating extra grid rows',
    (tester) async {
      await pumpWeek(tester, [lesson(0, 5)]);
      expect(find.byType(TeachingPeriodCard), findsOneWidget);
      expect(find.byKey(const ValueKey('week-slot-5')), findsNothing);
      expect(
        find.text('Lịch cần kiểm tra · Slot ngoài khung 1–4'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
