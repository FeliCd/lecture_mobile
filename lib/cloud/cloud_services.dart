import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Best effort, bounded telemetry: never sends raw exception text or user content.
class CloudTelemetry {
  static bool enabled = false;
  static Future<void> event(
    String name, [
    Map<String, Object>? parameters,
  ]) async {
    if (!enabled) return;
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
    if (!enabled) return;
    try {
      await FirebaseAnalytics.instance.setUserId(id: uid);
      await FirebaseCrashlytics.instance.setUserIdentifier(uid ?? '');
    } catch (_) {}
  }

  static Future<void> handled(String operation, [Object? error]) async {
    if (!enabled) return;
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
    enabled =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        !const bool.fromEnvironment('USE_EMULATORS');
    if (!enabled) return;
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    await FirebaseCrashlytics.instance.setCustomKey(
      'app_mode',
      'shared_lecturer',
    );
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
    await identity(FirebaseAuth.instance.currentUser?.uid);
  }

  static void demoCrash() {
    if (enabled) FirebaseCrashlytics.instance.crash();
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
    var fetchFailed = false;
    try {
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
  @override
  Future<ReportReceipt> upload(
    Uint8List bytes,
    String name,
    void Function(double) progress,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Cần đăng nhập trước khi tải báo cáo.');
    if (bytes.isEmpty ||
        bytes.length > 10 * 1024 * 1024 ||
        !RegExp(r'^[A-Za-z0-9_-]+\.xlsx$').hasMatch(name)) {
      throw StateError('Báo cáo Excel tối đa 10 MB.');
    }
    final path = 'reports/$uid/${DateTime.now().microsecondsSinceEpoch}-$name';
    final task = FirebaseStorage.instance
        .ref(path)
        .putData(
          bytes,
          SettableMetadata(
            contentType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
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
        throw StateError('Tài khoản đã thay đổi.');
      }
      final url = await snapshot.ref.getDownloadURL();
      await CloudTelemetry.event('report_upload_completed', {
        'bytes': bytes.length,
      });
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
