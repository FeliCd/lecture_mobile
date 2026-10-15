import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lecturer_companion/lab2/attendance_actions.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/live_attendance.dart';
import 'package:lecturer_companion/lab2/lecturer_workspace.dart';
import 'package:lecturer_companion/lab2/lecturer_workspace_store.dart';
import 'package:lecturer_companion/lab2/repository.dart';
import 'package:lecturer_companion/lab2/theme.dart';
import 'refactor_live_test.dart' show LiveFixture;

class LargeRoster extends LiveFixture {
  @override
  Future<Data> call(String name, Data input) async {
    final value = await super.call(name, input);
    if (name != 'getAttendanceSessionLive') return value;
    return {
      ...value,
      'counts': {
        'eligible': 60,
        'present': 15,
        'late': 0,
        'absent': 0,
        'excused': 0,
        'pending': 45,
      },
      'students': [
        for (var i = 0; i < 60; i++)
          {
            'studentUid': 'u$i',
            'displayName': 'Sinh viên $i',
            'studentCode': 'SE${1000 + i}',
            'status': i < 15 ? 'present' : 'pending',
            'notes': '',
          },
      ],
    };
  }
}

void main() {
  for (final sample in [
    (const Size(360, 800), 1.0, 0.0),
    (const Size(360, 800), 2.0, 300.0),
    (const Size(844, 390), 2.0, 120.0),
  ]) {
    testWidgets('editor identifies student and keeps payload at $sample', (
      tester,
    ) async {
      tester.view.physicalSize = sample.$1;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Data? sent;
      await tester.pumpWidget(
        MaterialApp(
          theme: campusTheme(Brightness.dark),
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(
              textScaler: TextScaler.linear(sample.$2),
              viewInsets: EdgeInsets.only(bottom: sample.$3),
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AttendanceEditDialog(
                    studentName: 'Nguyễn Minh Anh',
                    studentCode: 'SE1001',
                    contextLabel: 'SE1928 · Slot 1',
                    status: 'pending',
                    onSave: (data) async {
                      sent = data;
                      return {};
                    },
                  ),
                ),
                child: const Text('Mở'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở'));
      await tester.pumpAndSettle();
      expect(find.text('Nguyễn Minh Anh'), findsOneWidget);
      expect(find.text('SE1001'), findsOneWidget);
      final late = find.widgetWithText(ChoiceChip, 'Đi trễ');
      await tester.ensureVisible(late);
      await tester.pumpAndSettle();
      await tester.tap(late);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Đối chiếu tại lớp');
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(sent, {'status': 'late', 'notes': 'Đối chiếu tại lớp'});
      expect(find.byType(AttendanceEditDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'large roster keeps search reachable and passes identity to editor',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(LargeRoster())],
          child: MaterialApp(
            theme: campusTheme(Brightness.light),
            home: const LiveAttendancePage(sessionId: 's'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sinh viên'));
      await tester.pumpAndSettle();
      final vertical = find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first;
      await tester.drag(vertical, const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(find.byType(TextField).hitTestable(), findsOneWidget);
      expect(find.text('Sinh viên').hitTestable(), findsOneWidget);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      final originalSearch = tester.state(find.byType(TextField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(TextField)), same(originalSearch));
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'SE1059');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Sinh viên 59'),
        150,
        scrollable: vertical,
      );
      final row = find.ancestor(
        of: find.text('Sinh viên 59'),
        matching: find.byType(ListTile),
      );
      final edit = find.descendant(
        of: row,
        matching: find.byTooltip('Sửa điểm danh'),
      );
      await tester.ensureVisible(edit);
      await tester.pumpAndSettle();
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AttendanceEditDialog),
          matching: find.text('Sinh viên 59'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AttendanceEditDialog),
          matching: find.text('SE1059'),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('notebooks filter by class/date and reopen the original note', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = WorkspaceStore('persona');
    for (final code in ['SE1928', 'SE1929']) {
      await store.saveNote(code, {
        'label': '$code · PRM393 · 2026-10-15 · Slot 1',
        'classId': code,
        'subjectId': 'PRM393',
        'date': '2026-10-15',
        'goals': 'Mục tiêu $code',
      });
    }
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LecturerWorkspacePage(
            user: UserProfile('persona', 'Giảng viên', 'lecturer', []),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final search = find.byKey(const ValueKey('notebook-search'));
    await tester.scrollUntilVisible(
      search,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final field = find.descendant(of: search, matching: find.byType(TextField));
    await tester.enterText(field, 'SE1928');
    await tester.pumpAndSettle();
    expect(find.textContaining('SE1929 ·'), findsNothing);
    await tester.enterText(field, '15/10');
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy sổ tay'), findsNothing);
    await tester.enterText(field, 'SE1928');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('SE1928 ·'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Mục tiêu SE1928'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Mục tiêu SE1928'), findsOneWidget);
    expect(find.byTooltip('Lưu trên máy'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
