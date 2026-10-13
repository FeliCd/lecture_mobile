import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/lab2/attendance_actions.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/import_page.dart';
import 'package:lecturer_companion/lab2/repository.dart';
import 'package:lecturer_companion/lab2/theme.dart';
import 'package:lecturer_companion/lab2/widgets.dart';
import 'package:lecturer_companion/lab2/live_attendance.dart';
import 'package:lecturer_companion/lab2/subject_updates.dart';
import 'package:lecturer_companion/lab2/article_library.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'lab2_navigation_test.dart' show FixtureRepository;
import 'refactor_live_test.dart' show LiveFixture;
import 'subject_updates_test.dart' show UpdatesFixture;

final captureKey = GlobalKey();

class ExpiredQrFixture extends LiveFixture {
  @override
  Future<Data> call(String name, Data input) async {
    final result = await super.call(name, input);
    if (name == 'getQrToken') {
      return {
        ...result,
        'expiresAt': DateTime.now()
            .subtract(const Duration(seconds: 1))
            .millisecondsSinceEpoch,
      };
    }
    return result;
  }
}

Future<void> openEditor(
  WidgetTester tester,
  Future<Data> Function(Data) save,
) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (_, child) => RepaintBoundary(key: captureKey, child: child!),
      theme: campusTheme(Brightness.light),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<Data>(
              context: context,
              builder: (_) =>
                  AttendanceEditDialog(status: 'present', onSave: save),
            ),
            child: const Text('Sửa'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Sửa'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('CAPTURE_UI')) return;
    final fontRoot = Platform.environment['FLUTTER_PREVIEW_FONTS']!;
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      final loader = FontLoader(entry.key);
      loader.addFont(
        File(
          '$fontRoot/${entry.value}',
        ).readAsBytes().then(ByteData.sublistView),
      );
      await loader.load();
    }
  });
  test(
    'write timeout explains uncertain result without exposing backend details',
    () {
      final message = mutationErrorMessage(
        TimeoutException('https://private.example/secret'),
      );
      expect(message, contains('kiểm tra'));
      expect(message, isNot(contains('private.example')));
      expect(
        mutationErrorMessage(StateError('PERMISSION_DENIED')),
        errorMessage(StateError('PERMISSION_DENIED')),
      );
    },
  );

  testWidgets('reset feed filters clears query and resets backend request', (
    tester,
  ) async {
    final repo = UpdatesFixture();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          savedArticlesProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SubjectUpdatesPage(
              user: UserProfile('u', 'Teacher', 'lecturer', ['PRM393']),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Android');
    await tester.tap(find.text('7 ngày'));
    await tester.pumpAndSettle();
    expect(repo.calls.last['days'], 7);
    await tester.ensureVisible(find.text('Đặt lại bộ lọc'));
    await tester.tap(find.text('Đặt lại bộ lọc'));
    await tester.pumpAndSettle();
    expect(repo.calls.last['query'], '');
    expect(repo.calls.last['days'], 30);
    expect(repo.calls.last['source'], '');
    expect(repo.calls.last['sort'], 'LATEST');
    await tester.drag(find.byType(ListView), const Offset(0, 800));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
  });
  testWidgets('expired QR is hidden even when session is still open', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(ExpiredQrFixture())],
        child: const MaterialApp(home: LiveAttendancePage(sessionId: 's')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('Đang chờ mã QR mới'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'failed attendance write keeps reason; pending write cannot be submitted twice',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      final completion = Completer<Data>();
      await openEditor(tester, (_) {
        calls++;
        return completion.future;
      });
      await tester.enterText(find.byType(TextFormField), 'Đối chiếu danh sách');
      await tester.tap(find.text('Lưu'));
      await tester.pump();
      expect(find.text('Đang lưu…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      completion.completeError(StateError('unavailable'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.byType(AttendanceEditDialog), findsOneWidget);
      expect(find.text('Đối chiếu danh sách'), findsOneWidget);
      expect(find.textContaining('Nội dung nhập vẫn được giữ'), findsOneWidget);
      if (const bool.fromEnvironment('CAPTURE_UI')) {
        final boundary =
            captureKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final rendered = await boundary.toImage(pixelRatio: 2);
          final bytes = await rendered.toByteData(
            format: ui.ImageByteFormat.png,
          );
          await File(
            'build/ui-previews/attendance-error.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          rendered.dispose();
        });
      }
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.text('Bỏ thay đổi chưa lưu?'), findsOneWidget);
      await tester.tap(find.text('Hủy').last);
      await tester.pumpAndSettle();
      expect(find.text('Đối chiếu danh sách'), findsOneWidget);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bỏ thay đổi'));
      await tester.pumpAndSettle();
      expect(find.byType(AttendanceEditDialog), findsNothing);
    },
  );

  testWidgets(
    'successful attendance write closes editor only after server response',
    (tester) async {
      final completion = Completer<Data>();
      await openEditor(tester, (_) => completion.future);
      await tester.enterText(
        find.byType(TextFormField),
        'Có mặt theo xác nhận',
      );
      await tester.tap(find.text('Lưu'));
      await tester.pump();
      expect(find.byType(AttendanceEditDialog), findsOneWidget);
      completion.complete({});
      await tester.pumpAndSettle();
      expect(find.byType(AttendanceEditDialog), findsNothing);
      expect(find.text('Bỏ thay đổi chưa lưu?'), findsNothing);
    },
  );

  testWidgets('clear search resets visible text and caller filter', (
    tester,
  ) async {
    var query = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CampusSearchField(
            hint: 'Tìm lớp',
            onChanged: (value) => query = value,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'SE1928');
    await tester.pump();
    await tester.tap(find.byTooltip('Xóa tìm kiếm'));
    await tester.pump();
    expect(query, '');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
  });

  testWidgets('import Back protects unsaved input and cancel preserves form', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(FixtureRepository())],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const ImportPage()),
                ),
                child: const Text('Nhập'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Nhập'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'FA27');
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Bỏ thay đổi chưa lưu?'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(find.text('FA27'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ thay đổi'));
    await tester.pumpAndSettle();
    expect(find.byType(ImportPage), findsNothing);
  });

  for (final brightness in Brightness.values) {
    testWidgets('help and busy state fit 360px with large text in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: campusTheme(brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.8)),
            child: child!,
          ),
          home: Scaffold(
            appBar: AppBar(
              actions: const [
                CampusHelpButton(
                  title: 'Trợ giúp',
                  message:
                      'Kiểm tra buổi học và thời hạn trước khi mở phiên. Khi kết nối gián đoạn, hãy tải lại dữ liệu để xác định kết quả.',
                ),
              ],
            ),
            body: const Padding(
              padding: EdgeInsets.all(20),
              child: AppPrimaryButton(
                label: 'Lưu',
                busy: true,
                busyLabel: 'Đang nhập dữ liệu…',
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Trợ giúp'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Đã hiểu'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Đã hiểu'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Đã hiểu').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Đã hiểu'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Đang nhập dữ liệu…'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
