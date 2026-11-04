import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/cloud/cloud_diagnostics.dart';
import 'package:lecturer_companion/cloud/cloud_pages.dart';
import 'package:lecturer_companion/cloud/cloud_services.dart';
import 'package:lecturer_companion/cloud/cloud_view_model.dart';
import 'package:lecturer_companion/cloud/push_permission_service.dart';
import 'package:lecturer_companion/cloud/push_view_model.dart';

class DelayedRemote implements RemoteSettingsService {
  int calls = 0;
  Completer<CloudSettings>? pending;
  @override
  Future<CloudSettings> refresh() {
    calls++;
    return pending?.future ??
        Future.value(
          const CloudSettings(
            updatesEnabled: false,
            pageSize: 7,
            usingActivatedValues: true,
          ),
        );
  }
}

class FakeDiagnostics implements CloudDiagnosticsService {
  CloudDiagnostics value;
  int checks = 0;
  Completer<StorageProbe>? pending;
  FakeDiagnostics(this.value);
  @override
  Future<CloudDiagnostics> inspect() async => value;
  @override
  Future<StorageProbe> checkStorage() async {
    checks++;
    return pending?.future ??
        const StorageProbe(false, 'Tài khoản chưa có quyền lưu báo cáo.');
  }
}

class FakePermission implements PushPermissionService {
  @override
  Future<PushPermission> permissionStatus() async => PushPermission.denied;
  @override
  Future<PushPermission> enableNotifications() => permissionStatus();
}

class PendingStorage implements ReportStorageService {
  final result = Completer<ReportReceipt>();
  @override
  Future<ReportReceipt> upload(
    Uint8List bytes,
    String name,
    void Function(double) progress,
  ) => result.future;
}

void main() {
  test(
    'refresh serializes calls and keeps cached disabled updates visible on failure',
    () async {
      final remote = DelayedRemote();
      final c = ProviderContainer(
        overrides: [remoteSettingsServiceProvider.overrideWithValue(remote)],
      );
      addTearDown(c.dispose);
      await c.read(cloudSettingsProvider.future);
      remote.pending = Completer<CloudSettings>();
      final refresh = c.read(cloudSettingsProvider.notifier).refresh();
      await c.read(cloudSettingsProvider.notifier).refresh();
      expect(remote.calls, 2);
      expect(c.read(cloudSettingsProvider).value!.updatesEnabled, false);
      remote.pending!.completeError(StateError('private endpoint token'));
      await refresh;
      final cached = c.read(cloudSettingsProvider).value!;
      expect(cached.fetchFailed, true);
      expect(cached.updatesEnabled, false);
      expect(cached.pageSize, 7);
    },
  );
  test('initial config load cannot race a manual refresh', () async {
    final remote = DelayedRemote()..pending = Completer<CloudSettings>();
    final c = ProviderContainer(
      overrides: [remoteSettingsServiceProvider.overrideWithValue(remote)],
    );
    addTearDown(c.dispose);
    final initial = c.read(cloudSettingsProvider.future);
    await c.read(cloudSettingsProvider.notifier).refresh();
    expect(remote.calls, 1);
    remote.pending!.complete(const CloudSettings());
    await initial;
  });
  test(
    'service failures explain actionable errors without leaking SDK messages',
    () {
      final denied = reportUploadError(
        FirebaseException(
          plugin: 'firebase_storage',
          code: 'unauthorized',
          message: 'private token and URL',
        ),
      );
      expect(denied, contains('quyền'));
      expect(denied, isNot(contains('private token')));
      expect(
        reportUploadError(const CloudServiceFailure('no-bucket')),
        contains('cấu hình'),
      );
      expect(
        reportUploadError(const CloudServiceFailure('account-changed')),
        contains('Đã dừng'),
      );
    },
  );
  test(
    'invalidating an upload on account change cannot expose its old receipt',
    () async {
      final storage = PendingStorage();
      final c = ProviderContainer(
        overrides: [reportStorageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(c.dispose);
      final sub = c.listen(reportUploadProvider, (_, _) {});
      addTearDown(sub.close);
      final request = c
          .read(reportUploadProvider.notifier)
          .upload(Uint8List(1), 'report.xlsx');
      c.invalidate(reportUploadProvider);
      expect(c.read(reportUploadProvider).receipt, isNull);
      storage.result.complete(
        const ReportReceipt('reports/old/file.xlsx', 'private-old-url'),
      );
      await request;
      expect(c.read(reportUploadProvider).receipt, isNull);
    },
  );

  Future<void> mount(
    WidgetTester tester,
    FakeDiagnostics service, {
    bool narrow = false,
  }) async {
    tester.view.physicalSize = narrow
        ? const Size(320, 800)
        : const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cloudDiagnosticsServiceProvider.overrideWithValue(service),
          remoteSettingsServiceProvider.overrideWithValue(DelayedRemote()),
          pushPermissionServiceProvider.overrideWithValue(FakePermission()),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(narrow ? 2 : 1)),
            child: child!,
          ),
          home: const CloudSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'missing bucket disables probing and does not claim cloud success',
    (tester) async {
      final diagnostics = FakeDiagnostics(
        const CloudDiagnostics(firebaseReady: true, signedIn: true),
      );
      await mount(tester, diagnostics);
      expect(find.text('Thiếu cấu hình'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Kiểm tra lưu báo cáo'),
            )
            .onPressed,
        isNull,
      );
      expect(diagnostics.checks, 0);
      expect(find.text('Khu vực trình diễn Lab 3'), findsNothing);
      expect(find.text('Cập nhật: đang tắt · 7 bài/trang'), findsOneWidget);
    },
  );
  testWidgets(
    'storage probe is explicit, serial and cannot masquerade as an upload test',
    (tester) async {
      final diagnostics = FakeDiagnostics(
        const CloudDiagnostics(
          firebaseReady: true,
          signedIn: true,
          bucket: 'bucket',
        ),
      )..pending = Completer<StorageProbe>();
      await mount(tester, diagnostics);
      expect(diagnostics.checks, 0);
      await tester.tap(find.text('Kiểm tra lưu báo cáo'));
      await tester.pump();
      expect(diagnostics.checks, 1);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Kiểm tra lưu báo cáo'),
            )
            .onPressed,
        isNull,
      );
      diagnostics.pending!.complete(
        const StorageProbe(
          true,
          'Storage đã phản hồi. Quyền upload chưa được xác minh.',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Storage đã phản hồi. Quyền upload chưa được xác minh.'),
        findsOneWidget,
      );
      expect(find.text('Đã upload thành công'), findsNothing);
    },
  );
  testWidgets(
    'service cards remain usable on a narrow screen with large text',
    (tester) async {
      await mount(
        tester,
        FakeDiagnostics(const CloudDiagnostics(firebaseReady: true)),
        narrow: true,
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Tải lại cấu hình'), 350);
      expect(tester.takeException(), isNull);
      expect(find.text('Tải lại cấu hình'), findsOneWidget);
    },
  );
}
