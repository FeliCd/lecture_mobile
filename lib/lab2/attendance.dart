import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'domain.dart';
import 'repository.dart';
import 'widgets.dart';
import 'theme.dart';
import 'attendance_actions.dart';

class AttendanceHost extends ConsumerStatefulWidget {
  final String sessionId;
  const AttendanceHost({super.key, required this.sessionId});
  @override
  ConsumerState<AttendanceHost> createState() => _AttendanceHostState();
}

class _AttendanceHostState extends ConsumerState<AttendanceHost>
    with WidgetsBindingObserver {
  Timer? timer;
  Data? qr;
  String? error;
  bool busy = false, closing = false, rotating = false;
  int offset = 0;
  String search = '', filter = 'all';
  int rosterPage = 0;
  late Stream<Data?> session;
  int get now => DateTime.now().millisecondsSinceEpoch + offset;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    session = ref
        .read(repositoryProvider)
        .document('attendanceSessions/${widget.sessionId}');
    load();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (qr != null && now >= (qr!['expiresAt'] as num) && !busy) {
        qr = null;
        load();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) load();
  }

  Future<void> load() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await ref.read(repositoryProvider).call('getQrToken', {
        'attendanceSessionId': widget.sessionId,
      });
      if (mounted) {
        setState(() {
          qr = result;
          offset =
              (result['serverNow'] as num).toInt() -
              DateTime.now().millisecondsSinceEpoch;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          qr = null;
          error = errorMessage(e);
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> rotate({bool? secretEnabled}) async {
    if (rotating || busy || closing) return;
    setState(() => rotating = true);
    await runAction(context, () async {
      await ref.read(repositoryProvider).call('rotateAttendanceQr', {
        'attendanceSessionId': widget.sessionId,
        'secretEnabled': ?secretEnabled,
      });
      if (mounted) {
        setState(() => qr = null);
        await load();
      }
    });
    if (mounted) setState(() => rotating = false);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Phiên điểm danh QR')),
      body: StreamBuilder<Data?>(
        stream: session,
        builder: (context, s) {
          if (s.hasError) return ErrorState(s.error!, load);
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.data == null) {
            return const EmptyState('Chưa mở phiên điểm danh cho buổi này.');
          }
          final data = s.data!;
          final open =
              data['status'] == 'open' &&
              dateValue(data['closesAt']).millisecondsSinceEpoch > now;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                attendanceSessionLabel(data),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('Lớp ${data['classCode'] ?? ''}'),
              Text(open ? 'Đang điểm danh' : 'Đã kết thúc'),
              if (open)
                Text(
                  'Còn ${((dateValue(data['closesAt']).millisecondsSinceEpoch - now) / 1000).ceil()} giây',
                ),
              Text('Hết hạn: ${localDate(dateValue(data['closesAt']))}'),
              const SizedBox(height: 16),
              if (open && qr != null && now < (qr!['expiresAt'] as num))
                CampusCard(
                  child: Column(
                    children: [
                      Container(
                        color: CampusColors.white,
                        padding: const EdgeInsets.all(24),
                        child: LayoutBuilder(
                          builder: (context, size) => QrImageView(
                            data: attendanceWebQr(qr!['token']),
                            size: size.maxWidth.clamp(160, 300).toDouble(),
                            backgroundColor: CampusColors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'QR còn hiệu lực ${(((qr!['expiresAt'] as num) - now) / 1000).ceil()} giây',
                      ),
                      SwitchListTile(
                        title: const Text('Yêu cầu Secret Code'),
                        subtitle: const Text(
                          'Sinh viên nhập thêm mã giảng viên cung cấp.',
                        ),
                        value: qr!['secretEnabled'] == true,
                        onChanged: busy || rotating || closing
                            ? null
                            : (v) => rotate(secretEnabled: v),
                      ),
                      if (qr!['secretEnabled'] == true)
                        SelectableText(
                          '${qr!['secretCode']}',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(letterSpacing: 6),
                        ),
                      OutlinedButton.icon(
                        onPressed: busy || rotating || closing
                            ? null
                            : () => rotate(),
                        icon: const Icon(Icons.qr_code_2),
                        label: Text(
                          rotating ? 'Đang đổi mã…' : 'Đổi mã QR ngay',
                        ),
                      ),
                    ],
                  ),
                ),
              if (open && error != null) ErrorState(error!, load),
              if (open && busy)
                const Center(child: CircularProgressIndicator()),
              if (open)
                OutlinedButton(
                  onPressed: busy ? null : load,
                  child: const Text('Làm mới QR'),
                ),
              const SizedBox(height: 12),
              LiveList(
                buildEmpty: true,
                source: () => repo.watch(
                  'attendanceRecords',
                  field: 'attendanceSessionId',
                  equals: widget.sessionId,
                ),
                empty: 'Chưa có sinh viên điểm danh.',
                builder: (records) {
                  final summary = attendanceSummary(
                    ref,
                    records.map((r) => r['status'] as String),
                  );
                  final studentUids = {
                    ...List<String>.from(data['eligibleStudentUids'] ?? []),
                    ...records.map((r) => r['studentUid'] as String),
                  };
                  final members =
                      ref
                          .watch(memberNamesProvider(data['classId'] as String))
                          .value ??
                      {};
                  final byUid = {for (final r in records) r['studentUid']: r};
                  final visible = studentUids.where((uid) {
                    final row = byUid[uid], name = members[uid] ?? {};
                    return '${name['displayName'] ?? ''} ${name['studentCode'] ?? ''}'
                            .toLowerCase()
                            .contains(search) &&
                        (filter == 'all' ||
                            attendanceStatus(row?['status'] ?? 'pending') ==
                                filter);
                  }).toList();
                  final pageCount = (visible.length / 30).ceil();
                  final page = rosterPage.clamp(
                    0,
                    pageCount == 0 ? 0 : pageCount - 1,
                  );
                  return Column(
                    children: [
                      CampusCard(
                        child: Text(
                          'Có mặt ${summary.present} • Trễ ${summary.late} • Có phép ${summary.excused} • Vắng ${summary.absent} • Chưa điểm danh ${studentUids.length - records.map((r) => r['studentUid']).toSet().length}',
                        ),
                      ),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Tìm tên hoặc MSSV',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) => setState(() {
                          search = v.toLowerCase().trim();
                          rosterPage = 0;
                        }),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final e in {
                            'all': 'Tất cả',
                            'present': 'Có mặt',
                            'late': 'Đi trễ',
                            'excused': 'Vắng có phép',
                            'absent': 'Vắng',
                            'pending': 'Chưa điểm danh',
                          }.entries)
                            ChoiceChip(
                              label: Text(e.value),
                              selected: filter == e.key,
                              onSelected: (_) => setState(() {
                                filter = e.key;
                                rosterPage = 0;
                              }),
                            ),
                        ],
                      ),
                      ...visible.skip(page * 30).take(30).map((uid) {
                        final r = records
                            .where((r) => r['studentUid'] == uid)
                            .firstOrNull;
                        return CampusCard(
                          child: ListTile(
                            title: MemberLabel(
                              classId: data['classId'],
                              uid: uid,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                StatusBadge(r?['status'] ?? 'pending'),
                                if ((r?['notes'] ?? '').isNotEmpty)
                                  Text(r!['notes']),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Sửa điểm danh',
                              onPressed: closing
                                  ? null
                                  : () => editAttendance(
                                      context,
                                      ref,
                                      sessionId: widget.sessionId,
                                      studentUid: uid,
                                      status: r?['status'] ?? 'present',
                                      notes: r?['notes'] ?? '',
                                    ),
                            ),
                          ),
                        );
                      }),
                      if (visible.isEmpty)
                        const EmptyState('Không có sinh viên phù hợp.'),
                      if (pageCount > 1)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: page > 0
                                  ? () => setState(() => rosterPage = page - 1)
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Text('Trang ${page + 1}/$pageCount'),
                            IconButton(
                              onPressed: page + 1 < pageCount
                                  ? () => setState(() => rosterPage = page + 1)
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                    ],
                  );
                },
              ),
              if (data['status'] == 'open')
                AppPrimaryButton(
                  label: 'Kết thúc và chốt điểm danh',
                  busy: closing || rotating,
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Kết thúc điểm danh?'),
                        content: const Text(
                          'Sinh viên chưa điểm danh sẽ được ghi nhận vắng.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Quay lại'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Kết thúc'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !context.mounted) return;
                    setState(() => closing = true);
                    await runAction(context, () async {
                      await repo.call('closeAttendanceSession', {
                        'attendanceSessionId': widget.sessionId,
                      });
                      if (mounted) setState(() => qr = null);
                    });
                    if (mounted) setState(() => closing = false);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
