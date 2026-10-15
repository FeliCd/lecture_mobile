import 'motion.dart';
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
  final searchController = TextEditingController();
  String search = '', filter = 'all';
  bool studentsMode = false;
  bool expandedQr = false;
  final qrScroll = ScrollController(), studentsScroll = ScrollController();
  bool get open => live?['status'] == 'OPEN';
  DateTime get serverNow => DateTime.now().add(Duration(milliseconds: offset));
  bool get canCheckIn =>
      open &&
      failure == null &&
      foreground &&
      live != null &&
      DateTime.parse(live!['expiresAt']).isAfter(serverNow);
  bool get qrCurrent =>
      qr != null &&
      (qr!['expiresAt'] as num) > serverNow.millisecondsSinceEpoch;

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
    searchController.dispose();
    qrScroll.dispose();
    studentsScroll.dispose();
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
      final firstLoad = live == null;
      setState(() {
        live = result;
        if (firstLoad && result['status'] != 'OPEN') studentsMode = true;
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
    }, mutation: true);
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
    final checkedIn = counts['present'] is num && counts['late'] is num
        ? (counts['present'] as num) + (counts['late'] as num)
        : null;
    final remaining = live == null
        ? 0
        : ((DateTime.parse(live!['expiresAt']).millisecondsSinceEpoch -
                      serverNow.millisecondsSinceEpoch) ~/
                  1000)
              .clamp(0, 86400);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          live == null
              ? 'Phiên điểm danh'
              : '${live!['classCode']} · Slot ${live!['slot']}',
        ),
        actions: [
          const CampusHelpButton(
            title: 'Hướng dẫn điểm danh',
            message:
                'Sinh viên quét QR và đăng nhập Google trên trang điểm danh. '
                'Nếu bật mã xác nhận, cung cấp thêm mã đang hiển thị. Đổi QR không kéo dài phiên. '
                'Khi mất kết nối, QR được ẩn và số liệu có thể đã cũ. '
                'Kết thúc phiên sẽ chốt vắng những sinh viên còn chờ. '
                'Mọi điều chỉnh sau đó cần lý do.',
          ),
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
        child: CampusEntrance(
          trigger: studentsMode,
          child: CustomScrollView(
            key: ValueKey(studentsMode),
            controller: studentsMode ? studentsScroll : qrScroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (loading) const LinearProgressIndicator(),
                      if (live == null && failure == null)
                        const CampusLoadingState(
                          message: 'Đang tải phiên điểm danh…',
                        ),
                      if (failure != null)
                        CampusCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Chưa đồng bộ được. Số liệu bên dưới có thể đã cũ. QR tạm ẩn để tránh dùng thông tin cũ.',
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
                                      Theme.of(context).brightness ==
                                          Brightness.dark,
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
                        Text(
                          '${checkedIn ?? '—'}/${counts['eligible'] ?? '—'} đã điểm danh',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 16,
                          runSpacing: 4,
                          children: [
                            Text('Có mặt ${counts['present'] ?? 0}'),
                            Text('Đi trễ ${counts['late'] ?? 0}'),
                            Text('Còn chờ ${counts['pending'] ?? 0}'),
                            Text('Vắng ${counts['absent'] ?? 0}'),
                            Text('Vắng có phép ${counts['excused'] ?? 0}'),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (live != null)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: AttendanceModeHeader(
                    height: MediaQuery.textScalerOf(context).scale(16) + 40,
                    students: studentsMode,
                    onChanged: (value) {
                      FocusManager.instance.primaryFocus?.unfocus();
                      setState(() => studentsMode = value);
                    },
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList.list(
                  children: [
                    if (live != null) ...[
                      if (!studentsMode && canCheckIn && qrCurrent) ...[
                        const SizedBox(height: 16),
                        Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: expandedQr ? 480 : 260,
                            ),
                            child: LayoutBuilder(
                              builder: (_, constraints) => QrImageView(
                                data: qr!['token'],
                                size: constraints.maxWidth,
                                padding: const EdgeInsets.all(16),
                                backgroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              setState(() => expandedQr = !expandedQr),
                          icon: Icon(
                            expandedQr ? Icons.zoom_out : Icons.zoom_in,
                          ),
                          label: Text(
                            expandedQr ? 'Thu gọn QR' : 'Phóng to QR',
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
                              title: const Text('Yêu cầu mã xác nhận'),
                              subtitle: const Text(
                                'Sinh viên nhập thêm mã bạn cung cấp.',
                              ),
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
                      if (!studentsMode && canCheckIn && !qrCurrent)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Đang chờ mã QR mới. Mã hết hạn được ẩn; bạn có thể bấm Cập nhật phiên.',
                          ),
                        ),
                      if (!studentsMode && !canCheckIn && failure == null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Phiên đã kết thúc hoặc hết hạn nhận điểm danh. Chọn Sinh viên để xem và điều chỉnh kết quả.',
                          ),
                        ),
                      Text(
                        'Lần đọc từ máy chủ: ${localDate(DateTime.parse(live!['serverTime']))}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (live!['effectiveDurationMinutes'] is num)
                        Text(
                          'Thời lượng hiệu lực: ${(live!['effectiveDurationMinutes'] as num).toStringAsFixed(1)} phút.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (studentsMode) ...[
                        const CampusSectionHeader(
                          title: 'Sinh viên trong phiên',
                        ),
                        CampusSearchField(
                          controller: searchController,
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
                                    onSelected: (_) =>
                                        setState(() => filter = status),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (visible.isEmpty)
                          EmptyState(
                            rows.isEmpty
                                ? 'Chưa có sinh viên trong phiên.'
                                : 'Không có sinh viên phù hợp với tìm kiếm hoặc trạng thái đã chọn.',
                            actionLabel: search.isNotEmpty || filter != 'all'
                                ? 'Xóa bộ lọc'
                                : null,
                            onAction: () => setState(() {
                              searchController.clear();
                              search = '';
                              filter = 'all';
                            }),
                          ),
                        for (final r in visible)
                          CampusChangeHighlight(
                            key: ValueKey(r['studentUid']),
                            value: '${r['status']}:${r['notes'] ?? ''}',
                            child: CampusStudentRow(
                              name: '${r['displayName']}',
                              code: '${r['studentCode']}',
                              detail: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  StatusBadge(r['status']),
                                  if ('${r['notes'] ?? ''}'.isNotEmpty)
                                    Text('${r['notes']}'),
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
                          ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AttendanceModeHeader extends SliverPersistentHeaderDelegate {
  final double height;
  final bool students;
  final ValueChanged<bool> onChanged;
  AttendanceModeHeader({
    required this.height,
    required this.students,
    required this.onChanged,
  });
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(
    color: Theme.of(context).scaffoldBackgroundColor,
    elevation: overlapsContent ? 1 : 0,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('Mã QR')),
              ButtonSegment(value: true, label: Text('Sinh viên')),
            ],
            selected: {students},
            onSelectionChanged: (value) => onChanged(value.single),
          ),
        ),
      ),
    ),
  );
  @override
  bool shouldRebuild(covariant AttendanceModeHeader oldDelegate) =>
      oldDelegate.students != students ||
      oldDelegate.height != height ||
      oldDelegate.onChanged != onChanged;
}
