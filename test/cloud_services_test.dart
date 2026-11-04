import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lecturer_companion/cloud/cloud_services.dart';
import 'package:lecturer_companion/cloud/cloud_view_model.dart';
import 'package:lecturer_companion/cloud/push_notifications.dart';

class FakeRemote implements RemoteSettingsService {
  CloudSettings value = const CloudSettings();
  bool fail = false;
  @override
  Future<CloudSettings> refresh() async {
    if (fail) throw StateError('offline');
    return value;
  }
}

class FakeStorage implements ReportStorageService {
  bool fail = false;
  @override
  Future<ReportReceipt> upload(
    Uint8List bytes,
    String name,
    void Function(double) progress,
  ) async {
    progress(.5);
    if (fail) throw StateError('private-error');
    return const ReportReceipt(
      'reports/uid/report.xlsx',
      'https://example.test/report',
    );
  }
}

void main() {
  test('remote values clamp both extremes and preserve disabled state', () {
    expect(CloudSettings.fromValues(false, -1).pageSize, 5);
    expect(CloudSettings.fromValues(true, 999).pageSize, 30);
    expect(CloudSettings.fromValues(false, 20).updatesEnabled, false);
  });
  test(
    'remote ViewModel refresh changes observable settings; error is explicit',
    () async {
      final service = FakeRemote();
      final container = ProviderContainer(
        overrides: [remoteSettingsServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      expect(
        (await container.read(cloudSettingsProvider.future)).updatesEnabled,
        true,
      );
      service.value = const CloudSettings(updatesEnabled: false, pageSize: 7);
      await container.read(cloudSettingsProvider.notifier).refresh();
      expect(container.read(cloudSettingsProvider).value!.pageSize, 7);
      expect(
        container.read(cloudSettingsProvider).value!.updatesEnabled,
        false,
      );
      service.fail = true;
      await container.read(cloudSettingsProvider.notifier).refresh();
      final cached = container.read(cloudSettingsProvider).value!;
      expect(cached.fetchFailed, true);
      expect(cached.updatesEnabled, false);
      expect(cached.pageSize, 7);
    },
  );
  test(
    'upload ViewModel exposes success, then clears receipt and redacts failure',
    () async {
      final service = FakeStorage();
      final container = ProviderContainer(
        overrides: [reportStorageServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(reportUploadProvider, (_, _) {});
      addTearDown(subscription.close);
      await container
          .read(reportUploadProvider.notifier)
          .upload(Uint8List(1), 'report.xlsx');
      expect(
        container.read(reportUploadProvider).receipt!.path,
        'reports/uid/report.xlsx',
      );
      service.fail = true;
      await container
          .read(reportUploadProvider.notifier)
          .upload(Uint8List(1), 'report.xlsx');
      final state = container.read(reportUploadProvider);
      expect(state.busy, false);
      expect(state.receipt, null);
      expect(state.error, isNot(contains('private-error')));
    },
  );
  test(
    'push navigation is allowlisted and never uses arbitrary URL or route',
    () {
      expect(
        pushDestination({'screen': 'class', 'classId': 'c-1'}),
        '/class/c-1',
      );
      expect(
        pushDestination({'screen': 'class', 'classId': '../settings'}),
        '/',
      );
      expect(
        pushDestination({'route': 'https://evil.test', 'screen': 'evil'}),
        '/',
      );
      expect(pushDestination({'screen': 'settings'}), '/settings');
    },
  );
}
