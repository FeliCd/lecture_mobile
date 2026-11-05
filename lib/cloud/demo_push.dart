import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'push_notifications.dart';
import 'cloud_services.dart';

abstract interface class DemoPushService {
  Future<void> send({bool delayed = false});
}

class FirebaseDemoPush implements DemoPushService {
  @override
  Future<void> send({bool delayed = false}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw const CloudServiceFailure('unauthenticated');
    final token = await PushNotifications.instance.testToken();
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw const CloudServiceFailure('account-changed');
    }
    if (token == null) throw const CloudServiceFailure('no-token');
    await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
        .httpsCallable(
          'sendLab3DemoPush',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
        )
        .call<void>({'token': token, 'delaySeconds': delayed ? 15 : 0});
  }
}

final demoPushServiceProvider = Provider<DemoPushService>(
  (ref) => FirebaseDemoPush(),
);
final demoPushProvider =
    NotifierProvider.autoDispose<DemoPushController, AsyncValue<String?>>(
      DemoPushController.new,
    );

class DemoPushController extends Notifier<AsyncValue<String?>> {
  @override
  AsyncValue<String?> build() => const AsyncData(null);
  Future<void> send({bool delayed = false}) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    try {
      await ref.read(demoPushServiceProvider).send(delayed: delayed);
      if (ref.mounted) {
        state = const AsyncData(
          'FCM đã nhận yêu cầu. Kiểm tra thông báo trên điện thoại và Trung tâm thông báo.',
        );
      }
    } catch (e) {
      final code = e is FirebaseFunctionsException
          ? e.code
          : e is CloudServiceFailure
          ? e.code
          : '';
      final message = switch (code) {
        'permission-denied' =>
          'Tài khoản chưa có quyền demo. Thêm Firebase UID vào LAB3_DEMO_UIDS trên backend.',
        'unauthenticated' ||
        'account-changed' => 'Đăng nhập lại trước khi gửi thử.',
        'notification-permission' =>
          'Hãy cho phép nhận thông báo trong Quản lý thông báo.',
        'resource-exhausted' => 'Chờ 30 giây rồi gửi lại.',
        'not-found' || 'unimplemented' =>
          'Chưa triển khai hàm sendLab3DemoPush trên Firebase.',
        'unsupported' => 'Chạy bản Android kết nối Firebase thật để gửi push.',
        _ =>
          'Chưa xác nhận gửi thành công. Kiểm tra mạng/backend; chờ 30 giây trước khi thử lại.',
      };
      if (ref.mounted) state = AsyncError(message, StackTrace.current);
    }
  }
}
