import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cloud_services.dart';

final remoteSettingsServiceProvider = Provider<RemoteSettingsService>(
  (ref) => FirebaseRemoteSettings(),
);
final reportStorageServiceProvider = Provider<ReportStorageService>(
  (ref) => FirebaseReportStorage(),
);
final cloudSettingsProvider =
    AsyncNotifierProvider<CloudSettingsController, CloudSettings>(
      CloudSettingsController.new,
    );

class CloudSettingsController extends AsyncNotifier<CloudSettings> {
  @override
  Future<CloudSettings> build() =>
      ref.read(remoteSettingsServiceProvider).refresh();
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(remoteSettingsServiceProvider).refresh(),
    );
  }
}

class ReportUploadState {
  final bool busy;
  final double progress;
  final ReportReceipt? receipt;
  final String? error;
  const ReportUploadState({
    this.busy = false,
    this.progress = 0,
    this.receipt,
    this.error,
  });
}

final reportUploadProvider =
    NotifierProvider.autoDispose<ReportUploadController, ReportUploadState>(
      ReportUploadController.new,
    );

class ReportUploadController extends Notifier<ReportUploadState> {
  @override
  ReportUploadState build() => const ReportUploadState();
  Future<void> upload(Uint8List bytes, String name) async {
    if (state.busy) return;
    state = const ReportUploadState(busy: true);
    try {
      final receipt = await ref.read(reportStorageServiceProvider).upload(
        bytes,
        name,
        (value) {
          if (ref.mounted) {
            state = ReportUploadState(busy: true, progress: value);
          }
        },
      );
      if (ref.mounted) state = ReportUploadState(progress: 1, receipt: receipt);
    } catch (_) {
      if (ref.mounted) {
        state = const ReportUploadState(
          error:
              'Không tải được báo cáo. Kiểm tra mạng, quyền Storage và cấu hình bucket rồi thử lại.',
        );
      }
    }
  }
}
