import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'push_notifications.dart';
import 'push_permission_service.dart';

final pushPermissionServiceProvider = Provider<PushPermissionService>(
  (ref) => PushNotifications.instance,
);
final pushPermissionProvider =
    AsyncNotifierProvider.autoDispose<PushPermissionController, PushPermission>(
      PushPermissionController.new,
    );

class PushPermissionController extends AsyncNotifier<PushPermission> {
  bool _busy = false;
  @override
  Future<PushPermission> build() =>
      ref.read(pushPermissionServiceProvider).permissionStatus();

  Future<void> refresh() => _perform(false);
  Future<void> request() => _perform(true);
  Future<void> _perform(bool request) async {
    if (_busy || state.isLoading) return;
    _busy = true;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => request
          ? ref.read(pushPermissionServiceProvider).enableNotifications()
          : ref.read(pushPermissionServiceProvider).permissionStatus(),
    );
    if (ref.mounted) state = result;
    _busy = false;
  }
}

String pushPermissionLabel(PushPermission value) => switch (value) {
  PushPermission.authorized => 'Đã cho phép nhận thông báo',
  PushPermission.provisional => 'Đang nhận thông báo yên lặng',
  PushPermission.denied =>
    'Đã từ chối. Bạn có thể bật lại trong cài đặt thông báo Android.',
  PushPermission.notDetermined => 'Chưa cấp quyền nhận thông báo',
  PushPermission.unsupported =>
    'Thông báo push cần bản Android kết nối Firebase thật.',
};
