import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

bool get androidCloudSupported =>
    !kIsWeb &&
    defaultTargetPlatform == TargetPlatform.android &&
    !const bool.fromEnvironment('USE_EMULATORS');

class CloudServiceFailure implements Exception {
  final String code;
  const CloudServiceFailure(this.code);
}

String reportUploadError(Object error) {
  final code = error is CloudServiceFailure
      ? error.code
      : error is FirebaseException
      ? error.code
      : '';
  return switch (code) {
    'no-bucket' || 'bucket-not-found' =>
      'Chưa cấu hình đúng nơi lưu báo cáo. Liên hệ quản trị viên.',
    'unauthenticated' =>
      'Phiên đăng nhập hết hạn. Đăng nhập lại rồi thử lưu báo cáo.',
    'unauthorized' =>
      'Tài khoản chưa có quyền lưu báo cáo. Nhờ quản trị viên kiểm tra quyền Storage.',
    'quota-exceeded' => 'Storage đã hết hạn mức. Liên hệ quản trị viên.',
    'retry-limit-exceeded' =>
      'Kết nối quá thời gian chờ. Kiểm tra mạng rồi thử lại.',
    'canceled' || 'account-changed' =>
      'Đã dừng lưu báo cáo vì tài khoản hoặc thao tác đã thay đổi.',
    'invalid-image' => 'Chọn ảnh PNG/JPEG hợp lệ, tối đa 5 MB.',
    'invalid-report' =>
      'Chọn báo cáo Excel hợp lệ, có nội dung và tối đa 10 MB.',
    _ =>
      'Không tải được báo cáo. Kiểm tra mạng rồi thử lại; nếu còn lỗi, liên hệ quản trị viên.',
  };
}

/// Best effort, bounded telemetry: never sends raw exception text or user content.
class CloudTelemetry {
  static bool enabled = false;
  static bool analyticsEnabled = false, crashlyticsEnabled = false;
  static Future<void> event(
    String name, [
    Map<String, Object>? parameters,
  ]) async {
    if (!analyticsEnabled) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (_) {
      /* telemetry must not fail business actions */
    }
  }

  static Future<void> identity(String? uid) async {
    if (analyticsEnabled) {
      try {
        await FirebaseAnalytics.instance.setUserId(id: uid);
      } catch (_) {}
    }
    if (crashlyticsEnabled) {
      try {
        await FirebaseCrashlytics.instance.setUserIdentifier(uid ?? '');
      } catch (_) {}
    }
  }

  static Future<void> handled(String operation, [Object? error]) async {
    if (!crashlyticsEnabled) return;
    final code = error is FirebaseException ? error.code : 'operation_failed';
    try {
      await FirebaseCrashlytics.instance.setCustomKey('operation', operation);
      await FirebaseCrashlytics.instance.recordError(
        StateError('$operation:$code'),
        StackTrace.current,
        reason: 'handled_service_failure',
        fatal: false,
      );
    } catch (_) {}
  }

  static Future<void> initialize() async {
    enabled = false;
    analyticsEnabled = false;
    crashlyticsEnabled = false;
    if (!androidCloudSupported || Firebase.apps.isEmpty) return;
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
      analyticsEnabled = true;
    } catch (_) {}
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      crashlyticsEnabled = true;
    } catch (_) {}
    enabled = analyticsEnabled || crashlyticsEnabled;
    await identity(FirebaseAuth.instance.currentUser?.uid);
    if (!crashlyticsEnabled) return;
    try {
      await FirebaseCrashlytics.instance.setCustomKey(
        'app_mode',
        'shared_lecturer',
      );
    } catch (_) {}
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      // Redact message/stack content from user-facing errors.
      unawaited(
        FirebaseCrashlytics.instance.recordError(
          StateError('flutter_framework_error'),
          details.stack,
          fatal: true,
        ),
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(
        FirebaseCrashlytics.instance.recordError(
          StateError('unhandled_async_error'),
          stack,
          fatal: true,
        ),
      );
      return true;
    };
  }

  static void demoCrash() {
    if (crashlyticsEnabled) FirebaseCrashlytics.instance.crash();
  }
}

class CloudSettings {
  final bool updatesEnabled;
  final int pageSize;
  final bool usingActivatedValues, fetchFailed;
  final DateTime? lastFetchAt;
  const CloudSettings({
    this.updatesEnabled = true,
    this.pageSize = 20,
    this.usingActivatedValues = false,
    this.fetchFailed = false,
    this.lastFetchAt,
  });
  static CloudSettings fromValues(bool enabled, int size) =>
      CloudSettings(updatesEnabled: enabled, pageSize: size.clamp(5, 30));
  CloudSettings withFetchFailure() => CloudSettings(
    updatesEnabled: updatesEnabled,
    pageSize: pageSize,
    usingActivatedValues: usingActivatedValues,
    fetchFailed: true,
    lastFetchAt: lastFetchAt,
  );
}

abstract class RemoteSettingsService {
  Future<CloudSettings> refresh();
}

class FirebaseRemoteSettings implements RemoteSettingsService {
  @override
  Future<CloudSettings> refresh() async {
    if (Firebase.apps.isEmpty || const bool.fromEnvironment('USE_EMULATORS')) {
      return const CloudSettings();
    }
    final remote = FirebaseRemoteConfig.instance;
    var fetchFailed = false;
    try {
      await remote.setDefaults({
        'subject_updates_enabled': true,
        'subject_updates_page_size': 20,
      });
      await remote.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 12),
          minimumFetchInterval: const bool.fromEnvironment('ENABLE_LAB3_DEMO')
              ? Duration.zero
              : const Duration(minutes: 15),
        ),
      );
      await remote.fetchAndActivate();
    } catch (e) {
      fetchFailed = true;
      await CloudTelemetry.handled('remote_config_fetch', e);
    }
    // SDK returns last activated values, or defaults on first offline launch.
    return CloudSettings(
      updatesEnabled: remote.getBool('subject_updates_enabled'),
      pageSize: remote.getInt('subject_updates_page_size').clamp(5, 30),
      fetchFailed: fetchFailed,
      usingActivatedValues: [
        'subject_updates_enabled',
        'subject_updates_page_size',
      ].any((key) => remote.getValue(key).source == ValueSource.valueRemote),
      lastFetchAt: remote.lastFetchTime.year > 1970
          ? remote.lastFetchTime
          : null,
    );
  }
}

class ReportReceipt {
  final String path, url;
  const ReportReceipt(this.path, this.url);
}

abstract class ReportStorageService {
  Future<ReportReceipt> upload(
    Uint8List bytes,
    String name,
    void Function(double) progress,
  );
}

class FirebaseReportStorage implements ReportStorageService {
  final bool image;
  FirebaseReportStorage({this.image = false});
  @override
  Future<ReportReceipt> upload(
    Uint8List bytes,
    String name,
    void Function(double) progress,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw const CloudServiceFailure('unauthenticated');
    if (Firebase.app().options.storageBucket?.trim().isNotEmpty != true) {
      throw const CloudServiceFailure('no-bucket');
    }
    final png =
        bytes.length >= 8 &&
        listEquals(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final jpg =
        bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    if (image && (bytes.length > 5 * 1024 * 1024 || !(png || jpg))) {
      throw const CloudServiceFailure('invalid-image');
    }
    if (!image &&
        (bytes.isEmpty ||
            bytes.length > 10 * 1024 * 1024 ||
            !RegExp(r'^[A-Za-z0-9_-]+\.xlsx$').hasMatch(name))) {
      throw const CloudServiceFailure('invalid-report');
    }
    final path = image
        ? 'images/$uid/${DateTime.now().microsecondsSinceEpoch}.${png ? 'png' : 'jpg'}'
        : 'reports/$uid/${DateTime.now().microsecondsSinceEpoch}-$name';
    final task = FirebaseStorage.instance
        .ref(path)
        .putData(
          bytes,
          SettableMetadata(
            contentType: image
                ? (png ? 'image/png' : 'image/jpeg')
                : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        );
    final subscription = task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) progress(s.bytesTransferred / s.totalBytes);
    }, onError: (Object _) {});
    final authSubscription = FirebaseAuth.instance.authStateChanges().listen((
      u,
    ) {
      if (u?.uid != uid) unawaited(task.cancel());
    });
    try {
      final snapshot = await task;
      if (FirebaseAuth.instance.currentUser?.uid != uid) {
        throw const CloudServiceFailure('account-changed');
      }
      final url = await snapshot.ref.getDownloadURL();
      if (FirebaseAuth.instance.currentUser?.uid != uid) {
        throw const CloudServiceFailure('account-changed');
      }
      await CloudTelemetry.event('report_upload_completed', {
        'bytes': bytes.length,
      });
      if (FirebaseAuth.instance.currentUser?.uid != uid) {
        throw const CloudServiceFailure('account-changed');
      }
      return ReportReceipt(path, url);
    } catch (e) {
      await CloudTelemetry.handled('report_upload', e);
      rethrow;
    } finally {
      await subscription.cancel();
      await authSubscription.cancel();
    }
  }
}
