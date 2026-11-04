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
  Future<CloudSettings>? _pending;
  CloudSettings? _last;
  Future<CloudSettings> _fetch() => _pending ??=
      Future<CloudSettings>.sync(
            () => ref.read(remoteSettingsServiceProvider).refresh(),
          )
          .then((value) => _last = value)
          .catchError(
            (Object _) => (_last ?? const CloudSettings()).withFetchFailure(),
          )
          .whenComplete(() => _pending = null);
  @override
  Future<CloudSettings> build() => _fetch();
  Future<void> refresh() async {
    if (state.isLoading || _pending != null) return;
    // Keep the last values visible during refresh; _pending serializes requests.
    final result = await _fetch();
    if (ref.mounted) state = AsyncData(result);
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
  int _generation = 0;
  @override
  ReportUploadState build() {
    _generation++;
    ref.onDispose(() => _generation++);
    return const ReportUploadState();
  }

  Future<void> upload(Uint8List bytes, String name) async {
    if (state.busy) return;
    final generation = _generation;
    state = const ReportUploadState(busy: true);
    try {
      final receipt = await ref.read(reportStorageServiceProvider).upload(
        bytes,
        name,
        (value) {
          if (ref.mounted && generation == _generation) {
            state = ReportUploadState(busy: true, progress: value);
          }
        },
      );
      if (ref.mounted && generation == _generation) {
        state = ReportUploadState(progress: 1, receipt: receipt);
      }
    } catch (e) {
      if (ref.mounted && generation == _generation) {
        state = ReportUploadState(error: reportUploadError(e));
      }
    }
  }
}
