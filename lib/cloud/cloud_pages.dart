import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'cloud_services.dart';
import 'cloud_view_model.dart';
import 'push_notifications.dart';
import 'push_permission_service.dart';
import 'push_view_model.dart';
import 'cloud_diagnostics.dart';
import 'demo_push.dart';
import 'image_upload_panel.dart';

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
  StorageProbe? storageProbe;
  bool busy = false;
  Future<void> run(Future<void> Function() fn) async {
    if (busy) return;
    setState(() {
      busy = true;
      status = null;
    });
    try {
      await fn();
    } catch (e) {
      if (mounted) {
        setState(
          () => status =
              e is CloudServiceFailure && e.code == 'notification-permission'
              ? 'Cho phép nhận thông báo trong mục Quản lý thông báo rồi thử lại.'
              : 'Thao tác chưa hoàn tất. Kiểm tra cấu hình Firebase và mạng.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(cloudSettingsProvider);
    final diagnostics = ref.watch(cloudDiagnosticsProvider);
    final permission = ref.watch(pushPermissionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Dịch vụ đám mây')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Trạng thái trên thiết bị',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Text(
            'Các trạng thái dưới đây không thay thế kiểm tra gửi và nhận dữ liệu thực tế.',
          ),
          diagnostics.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const Text(
              'Chưa đọc được trạng thái. Bấm Kiểm tra lại dịch vụ.',
            ),
            data: (d) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CloudServiceCard(
                  icon: Icons.cloud_outlined,
                  title: 'Firebase',
                  status: d.firebaseReady ? 'Đã khởi tạo' : 'Chưa khởi tạo',
                  detail: d.firebaseReady
                      ? 'Cấu hình ứng dụng đã được nạp.'
                      : 'Cần cấu hình Firebase trước khi sử dụng.',
                ),
                _CloudServiceCard(
                  icon: Icons.cloud_upload_outlined,
                  title: 'Lưu báo cáo',
                  status: !d.storageConfigured
                      ? 'Thiếu cấu hình'
                      : !d.signedIn
                      ? 'Cần đăng nhập'
                      : 'Đã cấu hình',
                  detail: !d.storageConfigured
                      ? 'Chưa cấu hình nơi lưu báo cáo. Liên hệ quản trị viên.'
                      : 'Báo cáo Excel tối đa 10 MB. Quyền upload cần được kiểm tra bằng một lần lưu báo cáo.',
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.network_check),
                  onPressed: busy || !d.storageConfigured || !d.signedIn
                      ? null
                      : () => run(() async {
                          final probe = await ref
                              .read(cloudDiagnosticsServiceProvider)
                              .checkStorage();
                          if (mounted) setState(() => storageProbe = probe);
                        }),
                  label: const Text('Kiểm tra lưu báo cáo'),
                ),
                if (storageProbe != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(storageProbe!.message),
                  ),
                _CloudServiceCard(
                  icon: Icons.insights_outlined,
                  title: 'Phân tích sử dụng',
                  status: d.analyticsEnabled
                      ? 'Đã bật trên thiết bị'
                      : 'Chưa bật',
                  detail: d.analyticsEnabled
                      ? 'Để xác nhận dữ liệu đã tới máy chủ, quản trị viên kiểm tra Analytics.'
                      : d.androidCloud
                      ? 'SDK chưa khởi tạo thành công.'
                      : 'Bản chạy hiện tại không bật thu thập cloud Android.',
                ),
                _CloudServiceCard(
                  icon: Icons.bug_report_outlined,
                  title: 'Báo lỗi ứng dụng',
                  status: d.crashlyticsEnabled
                      ? 'Đã bật trên thiết bị'
                      : 'Chưa bật',
                  detail: d.crashlyticsEnabled
                      ? 'Để xác nhận báo lỗi đã tới máy chủ, quản trị viên kiểm tra Crashlytics.'
                      : d.androidCloud
                      ? 'SDK chưa khởi tạo thành công.'
                      : 'Bản chạy hiện tại không bật thu thập cloud Android.',
                ),
                ExpansionTile(
                  title: const Text('Chi tiết cấu hình'),
                  children: [
                    ListTile(
                      title: const Text('Project'),
                      subtitle: Text(
                        d.projectId.isEmpty ? 'Chưa có' : d.projectId,
                      ),
                    ),
                    ListTile(
                      title: const Text('Nơi lưu báo cáo'),
                      subtitle: Text(d.bucket.isEmpty ? 'Chưa có' : d.bucket),
                    ),
                  ],
                ),
              ],
            ),
          ),
          permission.when(
            data: (p) => _CloudServiceCard(
              icon: Icons.notifications_outlined,
              title: 'Thông báo',
              status:
                  p == PushPermission.authorized ||
                      p == PushPermission.provisional
                  ? 'Đã cấp quyền'
                  : 'Chưa sẵn sàng',
              detail: pushPermissionLabel(p),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const Text('Chưa kiểm tra được quyền thông báo.'),
          ),
          OutlinedButton(
            onPressed: () => context.push('/notifications'),
            child: const Text('Quản lý thông báo'),
          ),
          TextButton(
            onPressed: busy || diagnostics.isLoading
                ? null
                : () => run(() async {
                    setState(() => storageProbe = null);
                    ref.invalidate(cloudDiagnosticsProvider);
                    await Future.wait([
                      ref.read(cloudDiagnosticsProvider.future),
                      ref.read(pushPermissionProvider.notifier).refresh(),
                    ]);
                  }),
            child: const Text('Kiểm tra lại dịch vụ'),
          ),
          const Divider(),
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
            onPressed: busy || settings.isLoading
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
            const ImageUploadPanel(),
            Consumer(
              builder: (context, ref, _) {
                final demo = ref.watch(demoPushProvider);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilledButton.icon(
                      onPressed: busy || demo.isLoading
                          ? null
                          : () => ref.read(demoPushProvider.notifier).send(),
                      icon: demo.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.notifications_active_outlined),
                      label: Text(
                        demo.isLoading ? 'Đang gửi…' : 'Gửi thông báo thử',
                      ),
                    ),
                    OutlinedButton(
                      onPressed: busy || demo.isLoading
                          ? null
                          : () => ref
                                .read(demoPushProvider.notifier)
                                .send(delayed: true),
                      child: const Text('Gửi sau 15 giây · thử nền/đóng'),
                    ),
                    const Text(
                      'Bấm rồi về Home hoặc vuốt app khỏi Recent. Không Force stop. Chạm thông báo để mở lại.',
                    ),
                    if (demo.hasError)
                      Text(
                        '${demo.error}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (demo.value != null) Text(demo.value!),
                  ],
                );
              },
            ),
            OutlinedButton(
              onPressed:
                  busy ||
                      !diagnostics.hasValue ||
                      !ref.read(pushServiceProvider).supported
                  ? null
                  : () => run(() async {
                      token = await ref.read(pushServiceProvider).testToken();
                      if (mounted) {
                        setState(
                          () => status = token == null
                              ? 'Chưa lấy được token. Kiểm tra quyền thông báo và kết nối.'
                              : 'Dùng token này gửi thông báo test từ Console. Không đưa token vào tài liệu công khai.',
                        );
                      }
                    }),
              child: const Text('Lấy token nhận thông báo test'),
            ),
            if (token != null) SelectableText(token!),
            OutlinedButton(
              onPressed: busy || diagnostics.value?.crashlyticsEnabled != true
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
              onPressed: busy || diagnostics.value?.crashlyticsEnabled != true
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
                      if (yes == true && CloudTelemetry.crashlyticsEnabled) {
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

class _CloudServiceCard extends StatelessWidget {
  final IconData icon;
  final String title, status, detail;
  const _CloudServiceCard({
    required this.icon,
    required this.title,
    required this.status,
    required this.detail,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(status, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(detail),
        ],
      ),
    ),
  );
}

String _configTime(DateTime value) {
  final t = value.toUtc().add(const Duration(hours: 7));
  String pad(int n) => '$n'.padLeft(2, '0');
  return '${pad(t.hour)}:${pad(t.minute)} ${pad(t.day)}/${pad(t.month)}/${t.year}';
}
