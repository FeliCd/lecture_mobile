import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cloud_services.dart';

class CloudDiagnostics {
  final String projectId, bucket;
  final bool firebaseReady,
      signedIn,
      analyticsEnabled,
      crashlyticsEnabled,
      androidCloud;
  const CloudDiagnostics({
    this.projectId = '',
    this.bucket = '',
    this.firebaseReady = false,
    this.signedIn = false,
    this.analyticsEnabled = false,
    this.crashlyticsEnabled = false,
    this.androidCloud = false,
  });
  bool get storageConfigured => firebaseReady && bucket.trim().isNotEmpty;
}

class StorageProbe {
  final bool responded;
  final String message;
  const StorageProbe(this.responded, this.message);
}

abstract class CloudDiagnosticsService {
  Future<CloudDiagnostics> inspect();
  Future<StorageProbe> checkStorage();
}

class FirebaseCloudDiagnostics implements CloudDiagnosticsService {
  @override
  Future<CloudDiagnostics> inspect() async {
    if (Firebase.apps.isEmpty) return const CloudDiagnostics();
    final options = Firebase.app().options;
    return CloudDiagnostics(
      projectId: options.projectId,
      bucket: options.storageBucket ?? '',
      firebaseReady: true,
      signedIn: FirebaseAuth.instance.currentUser != null,
      androidCloud: androidCloudSupported,
      analyticsEnabled: CloudTelemetry.analyticsEnabled,
      crashlyticsEnabled: CloudTelemetry.crashlyticsEnabled,
    );
  }

  @override
  Future<StorageProbe> checkStorage() async {
    final config = await inspect();
    if (!config.storageConfigured) {
      return const StorageProbe(
        false,
        'Chưa cấu hình nơi lưu báo cáo. Liên hệ quản trị viên.',
      );
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const StorageProbe(
        false,
        'Đăng nhập lại để kiểm tra lưu báo cáo.',
      );
    }
    try {
      // Read metadata only: no test upload, report contents or sharing changes.
      await FirebaseStorage.instance
          .ref('reports/$uid/cloud-check.xlsx')
          .getMetadata()
          .timeout(const Duration(seconds: 15));
      if (FirebaseAuth.instance.currentUser?.uid != uid) {
        return const StorageProbe(
          false,
          'Tài khoản đã thay đổi. Kiểm tra lại.',
        );
      }
      return const StorageProbe(
        true,
        'Đọc được thông tin tệp kiểm tra. Để xác nhận upload, lưu một báo cáo ở Tổng kết tuần.',
      );
    } on FirebaseException catch (e) {
      if (FirebaseAuth.instance.currentUser?.uid != uid) {
        return const StorageProbe(
          false,
          'Tài khoản đã thay đổi. Kiểm tra lại.',
        );
      }
      if (e.code == 'object-not-found') {
        return const StorageProbe(
          true,
          'Storage đã phản hồi; chưa có tệp kiểm tra. Quyền upload chưa được xác minh.',
        );
      }
      return StorageProbe(false, reportUploadError(e));
    } catch (_) {
      return const StorageProbe(
        false,
        'Chưa kiểm tra được Storage. Kiểm tra mạng rồi thử lại.',
      );
    }
  }
}

final cloudDiagnosticsServiceProvider = Provider<CloudDiagnosticsService>(
  (ref) => FirebaseCloudDiagnostics(),
);
final cloudDiagnosticsProvider = FutureProvider.autoDispose<CloudDiagnostics>(
  (ref) => ref.watch(cloudDiagnosticsServiceProvider).inspect(),
);
