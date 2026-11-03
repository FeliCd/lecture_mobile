import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'cloud_services.dart';
import 'cloud_view_model.dart';
import 'push_notifications.dart';
import 'push_permission_service.dart';
import 'push_view_model.dart';

final pushServiceProvider = Provider((ref) => PushNotifications.instance);
final pushHistoryProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, uid) {
      final service = ref.watch(pushServiceProvider);
      final sub = service.changes.stream.listen((_) {
        ref.invalidateSelf();
      });
      ref.onDispose(() {
        unawaited(sub.cancel());
      });
      return service.history.read(uid);
    });

class NotificationCenter extends ConsumerStatefulWidget {
  final String uid;
  const NotificationCenter({super.key, required this.uid});
  @override
  ConsumerState<NotificationCenter> createState() => _NotificationCenterState();
}

class _NotificationCenterState extends ConsumerState<NotificationCenter>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(pushPermissionProvider.notifier).refresh());
      ref.invalidate(pushHistoryProvider(widget.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.uid;
    final rows = ref.watch(pushHistoryProvider(uid));
    final permission = ref.watch(pushPermissionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(pushHistoryProvider(uid));
          await Future.wait([
            ref.read(pushHistoryProvider(uid).future),
            ref.read(pushPermissionProvider.notifier).refresh(),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Lịch sử push trên thiết bị này. Thông báo nhận khi đã đăng xuất không được lưu.',
            ),
            permission.when(
              data: (value) => Text(pushPermissionLabel(value)),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text(
                'Chưa kiểm tra được quyền thông báo. Kéo xuống để thử lại.',
              ),
            ),
            FilledButton(
              onPressed:
                  permission.isLoading ||
                      permission.value == PushPermission.unsupported
                  ? null
                  : () => ref.read(pushPermissionProvider.notifier).request(),
              child: const Text('Cho phép nhận thông báo'),
            ),
            rows.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, s) =>
                  const Text('Chưa tải được thông báo. Kéo xuống để thử lại.'),
              data: (list) => Column(
                children: [
                  if (list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Chưa có thông báo.'),
                    ),
                  for (final m in list)
                    Card(
                      child: ListTile(
                        title: Text('${m['title']}'),
                        subtitle: Text('${m['body']}\n${m['at']}'),
                        onTap: () => context.go('${m['route']}'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CloudSettingsPage extends ConsumerStatefulWidget {
  const CloudSettingsPage({super.key});
  @override
  ConsumerState<CloudSettingsPage> createState() => _CloudSettingsPageState();
}

class _CloudSettingsPageState extends ConsumerState<CloudSettingsPage> {
  String? status, token;
  bool busy = false;
  Future<void> run(Future<void> Function() fn) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await fn();
    } catch (_) {
      if (mounted) {
        setState(
          () => status =
              'Thao tác chưa hoàn tất. Kiểm tra cấu hình Firebase và mạng.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(cloudSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Dịch vụ đám mây')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Cấu hình cập nhật môn học',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          settings.when(
            data: (s) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cập nhật: ${s.updatesEnabled ? 'đang bật' : 'đang tắt'} · ${s.pageSize} bài/trang',
                ),
                Text(
                  s.usingActivatedValues
                      ? 'Đang dùng cấu hình đã kích hoạt từ Firebase.'
                      : 'Đang dùng cấu hình mặc định.',
                ),
                if (s.fetchFailed)
                  const Text(
                    'Chưa tải được bản mới. Vẫn dùng cấu hình đã lưu hoặc mặc định.',
                  ),
                if (s.lastFetchAt != null)
                  Text(
                    'Lần tải thành công: ${_configTime(s.lastFetchAt!)} (GMT+7)',
                  ),
              ],
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, s) => const Text(
              'Không tải được cấu hình. Giá trị mặc định vẫn được sử dụng.',
            ),
          ),
          const Text(
            'Tải tối đa mỗi 15 phút; nếu mất mạng sẽ dùng bản đã kích hoạt hoặc mặc định. Thay đổi thể hiện ở trang Cập nhật.',
          ),
          OutlinedButton(
            onPressed: busy
                ? null
                : () => run(
                    () => ref.read(cloudSettingsProvider.notifier).refresh(),
                  ),
            child: const Text('Tải lại cấu hình'),
          ),
          if (status != null) Text(status!),
          if (const bool.fromEnvironment('ENABLE_LAB3_DEMO')) ...[
            const Divider(),
            const Text('Khu vực trình diễn Lab 3'),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => run(() async {
                      token = await ref.read(pushServiceProvider).testToken();
                      if (mounted) {
                        setState(
                          () => status =
                              'Dùng token này gửi thông báo test từ Console. Không đưa token vào tài liệu công khai.',
                        );
                      }
                    }),
              child: const Text('Lấy token nhận thông báo test'),
            ),
            if (token != null) SelectableText(token!),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => run(() async {
                      await CloudTelemetry.handled('lab3_demo_nonfatal');
                      if (mounted) {
                        setState(
                          () => status =
                              'Đã gửi lỗi thử nếu Crashlytics đang bật. Kiểm tra Console để xác nhận.',
                        );
                      }
                    }),
              child: const Text('Gửi lỗi non-fatal thử'),
            ),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () async {
                      final yes = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Gây crash thử nghiệm?'),
                          content: const Text(
                            'Ứng dụng sẽ đóng. Chỉ dùng trong buổi demo sau khi lưu dữ liệu.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Hủy'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Gây crash thử'),
                            ),
                          ],
                        ),
                      );
                      if (yes == true && CloudTelemetry.enabled) {
                        CloudTelemetry.demoCrash();
                      }
                    },
              child: const Text('Crash thử nghiệm…'),
            ),
          ],
        ],
      ),
    );
  }
}

String _configTime(DateTime value) {
  final t = value.toUtc().add(const Duration(hours: 7));
  String pad(int n) => '$n'.padLeft(2, '0');
  return '${pad(t.hour)}:${pad(t.minute)} ${pad(t.day)}/${pad(t.month)}/${t.year}';
}
