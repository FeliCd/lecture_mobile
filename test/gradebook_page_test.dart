import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/grades/gradebook_page.dart';
import 'gradebook_controller_test.dart' as fixture;

void main() {
  testWidgets('adding a column saves the shared draft without publishing', (
    tester,
  ) async {
    final calls = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: LecturerGradebookPage(
          classId: 'c1',
          classLabel: 'PRM393 · SE1',
          call: (method, data) async {
            calls.add({'method': method, ...data});
            if (method == 'getGradebook') return fixture.book();
            return {'saved': true, 'version': 1};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm cột điểm'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tên cột'),
      'Lab',
    );
    await tester.tap(find.text('Thêm và lưu nháp'));
    await tester.pumpAndSettle();

    expect(calls.map((c) => c['method']), ['getGradebook', 'saveGradebook']);
    final save = calls.last;
    final column = (save['components'] as List).last as Map;
    expect(save['classId'], 'c1');
    expect(save['version'], 0);
    expect(column['name'], 'Lab');
    expect(save['students'].single['grades'], {'quiz': 5, column['id']: ''});
    expect(find.textContaining('Phiên bản 1'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
    'phone grade editing saves drafts separately from confirmed publication',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final calls = <Map<String, dynamic>>[];
      var published = false;
      await tester.pumpWidget(
        MaterialApp(
          home: LecturerGradebookPage(
            classId: 'c1',
            classLabel: 'PRM393 · SE1',
            call: (method, data) async {
              calls.add({'method': method, ...data});
              if (method == 'getGradebook') {
                final draft = fixture.book();
                if (!published) return draft;
                expect(data['includePublication'], true);
                return {
                  ...draft,
                  'version': 2,
                  'activePublicationId': 'p1',
                  'publication': {
                    'version': 2,
                    'components': draft['components'],
                    'students': [
                      {
                        ...(draft['students'] as List).single as Map,
                        'grades': {'quiz': 0},
                      },
                    ],
                  },
                };
              }
              if (method == 'saveGradebook') {
                return {'version': 1, 'saved': true};
              }
              if (method == 'publishGrades') {
                published = true;
                return {'publicationId': 'p1'};
              }
              return {'saved': true};
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Student'));
      await tester.pumpAndSettle();
      final grade = find.byKey(const ValueKey('grade/s1/quiz/1'));
      await tester.ensureVisible(grade);
      await tester.enterText(grade, '0');
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Xem trước / Công bố'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Lưu bản nháp'));
      await tester.tap(find.text('Lưu bản nháp'));
      await tester.pumpAndSettle();
      expect(calls.last['students'][0]['grades']['quiz'], 0);
      expect(calls.where((c) => c['method'] == 'publishGrades'), isEmpty);
      await tester.tap(find.text('Xem trước / Công bố'));
      await tester.pumpAndSettle();
      expect(find.text('Xem trước công bố điểm'), findsOneWidget);
      expect(calls.where((c) => c['method'] == 'publishGrades'), isEmpty);
      await tester.tap(find.widgetWithText(FilledButton, 'Công bố điểm'));
      await tester.pumpAndSettle();
      expect(calls[calls.length - 2]['method'], 'publishGrades');
      expect(calls.last['method'], 'getGradebook');
      expect(find.textContaining('Có bản đang công bố'), findsOneWidget);
      await tester.tap(find.text('Xem điểm đang công bố'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Student'));
      await tester.pumpAndSettle();
      expect(find.text('0 / 10'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thu hồi'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Thu hồi'));
      await tester.pumpAndSettle();
      expect(calls.last['method'], 'revokeGrades');
      expect(tester.takeException(), isNull);
    },
  );
}
