import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'domain.dart';
import 'repository.dart';
import 'attendance_actions.dart';
import 'widgets.dart';
import 'timetable_card.dart' show roomLabel;
import 'theme.dart';

class LiveAttendancePage extends ConsumerStatefulWidget {
  final String sessionId;
  const LiveAttendancePage({super.key, required this.sessionId});
  @override
  ConsumerState<LiveAttendancePage> createState() => _LiveAttendancePageState();
}

class _LiveAttendancePageState extends ConsumerState<LiveAttendancePage>
    with WidgetsBindingObserver {
  Timer? poll, clock;
  Data? live, qr;
  Object? failure;
  bool loading = false, writing = false, foreground = true;
  int errors = 0, offset = 0;
  bool accessDenied = false;
  String search = '', filter = 'all';
  bool get open => live?['status'] == 'OPEN';
  DateTime get serverNow => DateTime.now().add(Duration(milliseconds: offset));
  bool get canCheckIn =>
      open &&
      failure == null &&
      foreground &&
      live != null &&
      DateTime.parse(live!['expiresAt']).isAfter(serverNow);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
    clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && foreground && open) setState(() {});
    });
  }

  @override
  void dispose() {
    poll?.cancel();
    clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    poll?.cancel();
    if (foreground) refresh();
  }

  Future<void> refresh() async {
    if (loading || !mounted || !foreground) return;
    poll?.cancel();
    setState(() => loading = true);
    try {
      final repo = ref.read(repositoryProvider);
      final result = await repo.call('getAttendanceSessionLive', {
        'sessionId': widget.sessionId,
      });
      if (!mounted) return;
      setState(() {
        live = result;
        failure = null;
        errors = 0;
        accessDenied = false;
        offset =
            DateTime.parse(result['serverTime']).millisecondsSinceEpoch -
            DateTime.now().millisecondsSinceEpoch;
      });
      if (canCheckIn &&
          (qr == null ||
              (qr!['expiresAt'] as num) <= serverNow.millisecondsSinceEpoch)) {
        final value = await repo.call('getQrToken', {
          'attendanceSessionId': widget.sessionId,
        });
        if (mounted) setState(() => qr = value);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          failure = e;
          errors++;
          if ('$e'.contains('PERMISSION_DENIED') ||
              '$e'.contains('UNAUTHENTICATED')) {
            live = null;
            qr = null;
            accessDenied = true;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
        if (foreground && !accessDenied && (live == null || open)) {
          poll = Timer(
            Duration(
              seconds: errors == 0
                  ? 8
                  : (8 * (1 << errors.clamp(0, 3))).clamp(8, 60),
            ),
            refresh,
          );
        }
      }
    }
  }

  Future<void> mutate(String action, [Data values = const {}]) async {
    if (writing) return;
    setState(() => writing = true);
    await runAction(context, () async {
      await ref.read(repositoryProvider).call(action, {
        'attendanceSessionId': widget.sessionId,
        ...values,
      });
      qr = null;
      await refresh();
    });
    if (mounted) setState(() => writing = false);
  }

  @override
  Widget build(BuildContext context) {
    final rows = (live?['students'] as List? ?? [])
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    final visible = rows
        .where(
          (r) =>
              '${r['displayName']} ${r['studentCode']}'.toLowerCase().contains(
                search,
              ) &&
              (filter == 'all' || r['status'] == filter),
        )
        .toList();
    final counts = live?['counts'] as Map? ?? {};
    final remaining = live == null
        ? 0
        : ((DateTime.parse(live!['expiresAt']).millisecondsSinceEpoch -
                      serverNow.millisecondsSinceEpoch) ~/
                  1000)
              .clamp(0, 86400);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phiên điểm danh'),
        actions: [
          IconButton(
            tooltip: 'Cập nhật phiên',
            onPressed: loading ? null : refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      bottomNavigationBar: open
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                  ),
                  onPressed: writing || loading || failure != null
                      ? null
                      : () async {
                          final confirmed = await campusConfirm(
                            context,
                            title: 'Kết thúc điểm danh?',
                            message:
                                'Đã điểm danh: ${(counts['present'] as num? ?? 0) + (counts['late'] as num? ?? 0)} • Còn chờ: ${counts['pending'] ?? 0}. Sinh viên còn chờ sẽ được chốt vắng.',
                            confirm: 'Kết thúc',
                            destructive: true,
                          );
                          if (confirmed && mounted) {
                            await mutate('closeAttendanceSession');
                          }
                        },
                  child: Text(
                    writing ? 'Đang xử lý…' : 'Kết thúc và chốt điểm danh',
                  ),
                ),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (loading) const LinearProgressIndicator(),
            if (live == null && failure == null)
              const CampusLoadingState(message: 'Đang tải phiên điểm danh…'),
            if (failure != null)
              CampusCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chưa đồng bộ được. Số liệu bên dưới có thể đã cũ.',
                    ),
                    Text(errorMessage(failure!)),
                    TextButton(
                      onPressed: loading ? null : refresh,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            if (live != null) ...[
              Text(
                '${live!['subjectName']} • ${live!['classCode']} • Slot ${live!['slot']}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(roomLabel(live!['room'] as String?)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  CampusStatusChip(
                    failure != null
                        ? 'Chưa đồng bộ'
                        : canCheckIn
                        ? 'Đang mở'
                        : open
                        ? 'Đã hết hạn • Đang chốt'
                        : 'Đã kết thúc',
                    icon: open ? Icons.schedule : Icons.task_alt,
                    color: canCheckIn
                        ? CampusColors.status(
                            'present',
                            Theme.of(context).brightness == Brightness.dark,
                          )
                        : null,
                  ),
                  if (canCheckIn)
                    Text(
                      'Còn ${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  Text('Có mặt ${counts['present'] ?? 0}'),
                  Text('Trễ ${counts['late'] ?? 0}'),
                  Text('Còn chờ ${counts['pending'] ?? 0}'),
                ],
              ),
              if (canCheckIn && qr != null) ...[
                const SizedBox(height: 16),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: QrImageView(
                      data: qr!['token'],
                      size: 260,
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                if (qr!['secretEnabled'] == true)
                  Center(
                    child: SelectableText(
                      '${qr!['secretCode']}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Tùy chọn QR'),
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Yêu cầu Secret Code'),
                      value: qr!['secretEnabled'] == true,
                      onChanged: writing || loading
                          ? null
                          : (v) => mutate('rotateAttendanceQr', {
                              'secretEnabled': v,
                            }),
                    ),
                    OutlinedButton(
                      onPressed: writing || loading
                          ? null
                          : () => mutate('rotateAttendanceQr'),
                      child: const Text('Đổi mã QR'),
                    ),
                  ],
                ),
              ],
              Text(
                'Lần đọc từ máy chủ: ${localDate(DateTime.parse(live!['serverTime']))}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (live!['effectiveDurationMinutes'] is num)
                Text(
                  'Thời lượng hiệu lực: ${(live!['effectiveDurationMinutes'] as num).toStringAsFixed(1)} phút.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const CampusSectionHeader(title: 'Sinh viên trong phiên'),
              CampusSearchField(
                hint: 'Tìm tên hoặc MSSV',
                onChanged: (v) =>
                    setState(() => search = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final status in [
                      'all',
                      'present',
                      'late',
                      'absent',
                      'excused',
                      'pending',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            status == 'all'
                                ? 'Tất cả'
                                : StatusBadge.label(status),
                          ),
                          selected: filter == status,
                          onSelected: (_) => setState(() => filter = status),
                        ),
                      ),
                  ],
                ),
              ),
              if (visible.isEmpty)
                const EmptyState('Không có sinh viên phù hợp.'),
              for (final r in visible)
                CampusStudentRow(
                  name: '${r['displayName']}',
                  code: '${r['studentCode']}',
                  detail: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusBadge(r['status']),
                      if ('${r['notes']}'.isNotEmpty) Text('${r['notes']}'),
                    ],
                  ),
                  action: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Sửa điểm danh',
                    onPressed: writing || loading || failure != null
                        ? null
                        : () async {
                            await editAttendance(
                              context,
                              ref,
                              sessionId: widget.sessionId,
                              studentUid: r['studentUid'],
                              status: r['status'],
                              notes: r['notes'] ?? '',
                            );
                            await refresh();
                          },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
