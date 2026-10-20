import 'motion.dart';
import 'theme.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'domain.dart';
import 'repository.dart';
import 'widgets.dart';
import 'import_page.dart';
import 'desktop_sync.dart';
import 'class_attendance_overview.dart';
import 'attendance_actions.dart';
import 'class_timetable.dart';
import 'class_tools.dart';
import 'timetable_card.dart' show roomLabel;

class ClassTile extends StatelessWidget {
  final Data data;
  const ClassTile({super.key, required this.data});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), scheme = Theme.of(context).colorScheme;
    final code = '${data['subjectId'] ?? ''}';
    final accent = code.startsWith('SW') ? CampusColors.blue : scheme.primary;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/class/${data['id']}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      code.length > 3 ? code.substring(0, 3) : code,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$code · Lớp ${data['classCode']}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subjectLabel(data),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    CampusStatusChip(
                      '${data['studentCount'] ?? '—'} sinh viên',
                      icon: Icons.groups_outlined,
                      color: scheme.secondary,
                    ),
                    CampusStatusChip(
                      '${data['term'] ?? 'Chưa có học kỳ'}',
                      icon: Icons.calendar_today_outlined,
                      color: scheme.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final actions = [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () =>
                          context.push('/class/${data['id']}?tab=2'),
                      icon: const Icon(Icons.how_to_reg_outlined, size: 18),
                      label: const Text('Chọn buổi điểm danh'),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () => context.push('/class/${data['id']}'),
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('Chi tiết lớp'),
                    ),
                  ];
                  return constraints.maxWidth < 360 ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.3
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            actions[0],
                            const SizedBox(height: 8),
                            actions[1],
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: actions[0]),
                            const SizedBox(width: 10),
                            Expanded(child: actions[1]),
                          ],
                        );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ClassList extends ConsumerStatefulWidget {
  final UserProfile user;
  const ClassList({super.key, required this.user});
  @override
  ConsumerState<ClassList> createState() => _ClassListState();
}

class _ClassListState extends ConsumerState<ClassList> {
  String query = '', term = '';
  final searchController = TextEditingController();
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CampusRefreshList(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
    children: [
      CampusSearchField(
        controller: searchController,
        hint: 'Tìm lớp hoặc môn',
        onChanged: (v) => setState(() => query = attendanceSearchText(v)),
      ),
      const SizedBox(height: 16),
      LiveList(
        source: () => ref.read(repositoryProvider).classes(widget.user),
        builder: (classes) {
          final terms = classes.map((c) => '${c['term']}').toSet();
          final effectiveTerm = terms.contains(term) ? term : '';
          final filtered = classes
              .where(
                (c) =>
                    (effectiveTerm.isEmpty || c['term'] == effectiveTerm) &&
                    attendanceSearchText(
                      '${c['classCode']} ${c['subjectId']} ${c['subjectName']}',
                    ).contains(query),
              )
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Tất cả kỳ'),
                    selected: effectiveTerm.isEmpty,
                    onSelected: (_) => setState(() => term = ''),
                  ),
                  ...terms.map(
                    (t) => ChoiceChip(
                      label: Text(t),
                      selected: effectiveTerm == t,
                      onSelected: (_) => setState(() => term = t),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${filtered.length} lớp học',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
              if (filtered.isEmpty)
                EmptyState(
                  'Không có lớp phù hợp.',
                  actionLabel: 'Xóa bộ lọc',
                  onAction: () => setState(() {
                    query = '';
                    term = '';
                    searchController.clear();
                  }),
                ),
              CampusEntrance(
                trigger: '$query:$term',
                child: Column(
                  children: [
                    for (final c in filtered)
                      ClassTile(key: ValueKey(c['id']), data: c),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}

class ClassPage extends ConsumerWidget {
  final String classId;
  final int initialTab;
  const ClassPage({super.key, required this.classId, this.initialTab = 0});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(profileProvider).value;
    if (user == null || !user.isLecturer) return const SizedBox();
    final repo = ref.read(repositoryProvider);
    return DefaultTabController(
      key: ValueKey('${user.uid}:$classId'),
      length: 4,
      initialIndex: initialTab.clamp(0, 3),
      child: StreamBuilder<Data?>(
        key: ValueKey('${user.uid}:$classId'),
        stream: repo.document('classes/$classId'),
        builder: (context, s) {
          if (s.hasError) {
            return Scaffold(
              appBar: AppBar(title: const Text('Lớp học')),
              body: ErrorState(
                s.error!,
                () => context.go('/'),
                actionLabel: 'Về Hôm nay',
              ),
            );
          }
          if (!s.hasData) {
            return Scaffold(
              appBar: AppBar(title: const Text('Lớp học')),
              body: s.connectionState == ConnectionState.waiting
                  ? const Center(
                      child: CampusLoadingState(message: 'Đang tải lớp học…'),
                    )
                  : const EmptyState(
                      'Không tìm thấy lớp hoặc lớp không còn được phân công.',
                    ),
            );
          }
          final cls = s.data!;
          return Scaffold(
            appBar: AppBar(title: Text('${cls['classCode'] ?? 'Lớp học'}')),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .3,
                  ),
                  child: SingleChildScrollView(
                    child: ClassContextHeader(cls: cls),
                  ),
                ),
                const TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(
                      icon: Icon(Icons.groups_outlined, size: 18),
                      text: 'Sinh viên',
                    ),
                    Tab(
                      icon: Icon(Icons.how_to_reg_outlined, size: 18),
                      text: 'Điểm danh',
                    ),
                    Tab(
                      icon: Icon(Icons.event_note_outlined, size: 18),
                      text: 'Buổi học',
                    ),
                    Tab(
                      icon: Icon(Icons.query_stats, size: 18),
                      text: 'Thống kê',
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      if (user.isLecturer)
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ClassAttendanceOverview(
                                cls: cls,
                                showStudents: true,
                                showIdentity: false,
                              ),
                            ],
                          ),
                        ),
                      SessionsPanel(cls: cls, user: user),
                      ClassTimetable(cls: cls, user: user),
                      AnalyticsPanel(cls: cls, user: user),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ClassContextHeader extends StatelessWidget {
  final Data cls;
  const ClassContextHeader({super.key, required this.cls});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tooltip(
          message: subjectLabel(cls),
          child: Text(
            subjectLabel(cls),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('${cls['term'] ?? 'Chưa có học kỳ'}'),
            Text(
              cls['studentCount'] == null
                  ? 'Chưa có sĩ số'
                  : '${cls['studentCount']} sinh viên',
            ),
            PopupMenuButton<String>(
              tooltip: 'Công cụ lớp',
              onSelected: (value) {
                if (value == 'import') {
                  openImport(context, cls: cls);
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ClassToolsPage(cls: cls),
                    ),
                  );
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'import',
                  child: Text('Nhập sinh viên vào lớp'),
                ),
                if (useSharedDesktop)
                  const PopupMenuItem(
                    value: 'tools',
                    child: Text('Ngoại lệ lịch / sửa sinh viên'),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.build_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Công cụ lớp',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class SessionsPanel extends ConsumerWidget {
  final Data cls;
  final UserProfile user;
  const SessionsPanel({super.key, required this.cls, required this.user});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    return CampusRefreshList(
      padding: const EdgeInsets.all(16),
      children: [
        Text(subjectLabel(cls), style: Theme.of(context).textTheme.titleLarge),
        Text('Lớp ${cls['classCode']}'),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => DefaultTabController.of(context).animateTo(2),
          icon: const Icon(Icons.calendar_month),
          label: const Text('Chọn buổi học trong lịch để điểm danh'),
        ),
        const SizedBox(height: 20),
        Text(
          'Các phiên điểm danh',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        LiveList(
          source: () => repo.watch(
            'attendanceSessions',
            field: 'classId',
            equals: cls['id'],
          ),
          empty: 'Chưa có phiên. Chọn buổi học trong lịch để điểm danh.',
          builder: (sessions) {
            sessions.sort(
              (a, b) =>
                  dateValue(b['opensAt']).compareTo(dateValue(a['opensAt'])),
            );
            return Column(
              children: sessions
                  .map(
                    (session) => CampusCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(attendanceSessionLabel(session, cls)),
                        subtitle: Text(
                          '${localDate(dateValue(session['opensAt']))} – ${localDate(dateValue(session['closesAt']))}\n'
                          '${roomLabel(session['room'] as String?)} · ${session['status'] == 'open' ? 'Đang mở' : 'Đã chốt'}\n'
                          '${session['checkedInCount'] ?? '—'}/${session['eligibleCount'] ?? (session['eligibleStudentUids'] as List?)?.length ?? '—'} đã điểm danh',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/host/${session['id']}'),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

// Compatibility UI for the Firebase emulator only; shared attendance uses TeachingPeriod.
class OpenAttendanceDialog extends ConsumerStatefulWidget {
  final String sessionId;
  const OpenAttendanceDialog({super.key, required this.sessionId});
  @override
  ConsumerState<OpenAttendanceDialog> createState() =>
      _OpenAttendanceDialogState();
}

class _OpenAttendanceDialogState extends ConsumerState<OpenAttendanceDialog> {
  int duration = 10;
  bool busy = false;
  String? error;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Thời gian tồn tại phiên'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<int>(
          isExpanded: true,
          initialValue: duration,
          decoration: const InputDecoration(labelText: 'Thời lượng'),
          items: [5, 10, 15, 30, 60, 120, 240]
              .map((n) => DropdownMenuItem(value: n, child: Text('$n phút')))
              .toList(),
          onChanged: busy ? null : (v) => duration = v!,
        ),
        if (error != null) Text(error!),
      ],
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      AppPrimaryButton(
        label: 'Tạo QR',
        busy: busy,
        onPressed: () async {
          setState(() => busy = true);
          try {
            final result = await ref.read(repositoryProvider).call(
              'openAttendanceSession',
              {'classSessionId': widget.sessionId, 'durationMinutes': duration},
            );
            if (context.mounted) {
              final router = GoRouter.of(context);
              Navigator.pop(context);
              router.push('/host/${result['attendanceSessionId']}');
            }
          } catch (e) {
            if (mounted) setState(() => error = errorMessage(e));
          } finally {
            if (mounted) setState(() => busy = false);
          }
        },
      ),
    ],
  );
}

class AttendancePanel extends ConsumerWidget {
  final Data cls;
  final UserProfile user;
  final String? sessionId;
  const AttendancePanel({
    super.key,
    required this.cls,
    required this.user,
    this.sessionId,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    final members = user.isLecturer
        ? ref.watch(memberNamesProvider(cls['id'] as String)).value
        : null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: LiveList(
        source: () => repo.watch(
          'attendanceRecords',
          field: 'classId',
          equals: cls['id'],
          uid: user.isLecturer ? null : user.uid,
        ),
        builder: (records) {
          final selected = records
              .where(
                (r) =>
                    sessionId == null || r['attendanceSessionId'] == sessionId,
              )
              .toList();
          return Column(
            children: [
              if (selected.isEmpty)
                const EmptyState('Chưa có bản ghi điểm danh.'),
              ...selected.map(
                (r) => CampusCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(attendanceSessionLabel(r, cls)),
                      if (user.isLecturer)
                        MemberLabel(classId: cls['id'], uid: r['studentUid']),
                      const SizedBox(height: 8),
                      StatusBadge(r['status']),
                      if (r['checkedInAt'] != null)
                        Text(localDate(dateValue(r['checkedInAt']))),
                      if ((r['notes'] ?? '').isNotEmpty) Text(r['notes']),
                      if (user.isLecturer)
                        TextButton.icon(
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Sửa điểm danh'),
                          onPressed: () => editAttendance(
                            context,
                            ref,
                            sessionId: r['attendanceSessionId'],
                            studentUid: r['studentUid'],
                            studentName:
                                members?[r['studentUid']]?['displayName']
                                    as String?,
                            studentCode:
                                members?[r['studentUid']]?['studentCode']
                                    as String?,
                            contextLabel: attendanceSessionLabel(r, cls),
                            status: r['status'],
                            notes: r['notes'] ?? '',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AnalyticsPanel extends ConsumerStatefulWidget {
  final Data cls;
  final UserProfile user;
  const AnalyticsPanel({super.key, required this.cls, required this.user});
  @override
  ConsumerState<AnalyticsPanel> createState() => _AnalyticsPanelState();
}

class _AnalyticsPanelState extends ConsumerState<AnalyticsPanel> {
  Data get cls => widget.cls;
  UserProfile get user => widget.user;
  int days = 0;
  String status = '', search = '', sort = 'absent';
  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repositoryProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: LiveList(
        source: () => repo.watch(
          'attendanceSessions',
          field: 'classId',
          equals: cls['id'],
        ),
        builder: (sessions) {
          final finalized = sessions
              .where(
                (s) =>
                    s['status'] == 'finalized' &&
                    (days == 0 ||
                        dateValue(s['opensAt']).isAfter(
                          DateTime.now().subtract(Duration(days: days)),
                        )),
              )
              .toList();
          final ids = finalized.map((s) => s['id']).toSet();
          return LiveList(
            source: () => repo.watch(
              'attendanceRecords',
              field: 'classId',
              equals: cls['id'],
              uid: user.isLecturer ? null : user.uid,
            ),
            builder: (all) {
              final records = all
                  .where((r) => ids.contains(r['attendanceSessionId']))
                  .toList();
              final summary = attendanceSummary(
                ref,
                records.map((r) => r['status'] as String),
              );
              final groups = <String, List<Data>>{};
              for (final r in records) {
                groups.putIfAbsent(r['studentUid'], () => []).add(r);
              }
              final risk = groups.values.where((r) {
                final student = attendanceSummary(
                  ref,
                  r.map((x) => x['status'] as String),
                );
                return student.nearAbsenceLimit || student.exceedsAbsenceLimit;
              }).length;
              final today = localDate(DateTime.now()).split(' ').first;
              final todayIds = finalized
                  .where(
                    (s) =>
                        localDate(dateValue(s['opensAt'])).split(' ').first ==
                        today,
                  )
                  .map((s) => s['id'])
                  .toSet();
              final absentToday = records
                  .where(
                    (r) =>
                        todayIds.contains(r['attendanceSessionId']) &&
                        r['status'] == 'absent',
                  )
                  .length;
              final memberMaps = user.isLecturer
                  ? ref.watch(memberNamesProvider(cls['id'] as String)).value ??
                        <String, Data>{}
                  : <String, Data>{};
              for (final uid in memberMaps.keys) {
                groups.putIfAbsent(uid, () => []);
              }
              final entries = groups.entries.where((entry) {
                final member = memberMaps[entry.key] ?? {};
                return (status.isEmpty ||
                        entry.value.any((r) => r['status'] == status)) &&
                    '${member['displayName']} ${member['studentCode']} ${entry.key}'
                        .toLowerCase()
                        .contains(search);
              }).toList();
              entries.sort(
                (a, b) => sort == 'name'
                    ? '${memberMaps[a.key]?['displayName'] ?? a.key}'.compareTo(
                        '${memberMaps[b.key]?['displayName'] ?? b.key}',
                      )
                    : attendanceSummary(
                        ref,
                        b.value.map((r) => r['status'] as String),
                      ).absent.compareTo(
                        attendanceSummary(
                          ref,
                          a.value.map((r) => r['status'] as String),
                        ).absent,
                      ),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [0, 30, 90]
                        .map(
                          (d) => ChoiceChip(
                            label: Text(d == 0 ? 'Toàn kỳ' : '$d ngày'),
                            selected: days == d,
                            onSelected: (_) => setState(() => days = d),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  CampusCard(
                    child: Wrap(
                      spacing: 24,
                      runSpacing: 16,
                      children: [
                        Text('Buổi đã học: ${finalized.length}'),
                        Text(
                          'Chuyên cần: ${summary.rate?.toStringAsFixed(1) ?? 'Chưa đủ dữ liệu'}${summary.rate == null ? '' : '%'}',
                        ),
                        Text('Tổng lượt vắng: ${summary.absent}'),
                        Text(
                          'Đi trễ: ${summary.late} • Vắng có phép: ${summary.excused}',
                        ),
                        if (summary.needsPolicy) Text(summary.absenceWarning),
                        Text('Vắng hôm nay: $absentToday'),
                        if (user.isLecturer) Text('Cần theo dõi: $risk'),
                      ],
                    ),
                  ),
                  Text(
                    'Phân bố theo buổi',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  ...finalized.map((s) {
                    final rows = records
                        .where((r) => r['attendanceSessionId'] == s['id'])
                        .toList();
                    final counts = attendanceSummary(
                      ref,
                      rows.map((r) => r['status'] as String),
                    );
                    return CampusCard(
                      child: InkWell(
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text(attendanceSessionLabel(s, cls)),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: rows
                                    .map(
                                      (r) => ListTile(
                                        title: Text(
                                          user.isLecturer
                                              ? (ref
                                                        .read(
                                                          memberNamesProvider(
                                                            cls['id'],
                                                          ),
                                                        )
                                                        .value?[r['studentUid']]?['displayName'] ??
                                                    'Sinh viên')
                                              : 'Điểm danh của bạn',
                                        ),
                                        subtitle: StatusBadge(r['status']),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Đóng'),
                              ),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(localDate(dateValue(s['opensAt']))),
                            const SizedBox(height: 8),
                            AttendanceBar(counts: counts),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: ['present', 'late', 'absent', 'excused']
                                  .map(
                                    (status) => Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        StatusBadge(status),
                                        Text(
                                          ' ${rows.where((r) => r['status'] == status).length}',
                                        ),
                                      ],
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (user.isLecturer)
                    AppPrimaryButton(
                      label: 'Xuất CSV',
                      onPressed: () => runAction(context, () async {
                        final mapping = await repo.members(cls['id']);
                        final byId = {for (final s in finalized) s['id']: s};
                        final csv = attendanceCsv(
                          records.map((r) {
                            final m = mapping[r['studentUid']] ?? {};
                            return [
                              cls['classCode'],
                              cls['subjectId'],
                              localDate(
                                dateValue(
                                  byId[r['attendanceSessionId']]!['opensAt'],
                                ),
                              ).split(' ').first,
                              m['studentCode'],
                              m['displayName'],
                              r['status'],
                              r['checkedInAt'] == null
                                  ? ''
                                  : dateValue(
                                      r['checkedInAt'],
                                    ).toUtc().toIso8601String(),
                              r['notes'] ?? '',
                            ];
                          }),
                        );
                        await SharePlus.instance.share(
                          ShareParams(
                            files: [
                              XFile.fromData(
                                utf8.encode(csv),
                                mimeType: 'text/csv',
                              ),
                            ],
                            fileNameOverrides: [
                              'attendance-${cls['classCode']}.csv',
                            ],
                          ),
                        );
                      }),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    user.isLecturer ? 'Chi tiết sinh viên' : 'Lịch sử của bạn',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Tìm tên hoặc MSSV',
                    ),
                    onChanged: (v) => setState(() => search = v.toLowerCase()),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Tất cả'),
                        selected: status.isEmpty,
                        onSelected: (_) => setState(() => status = ''),
                      ),
                      ...['present', 'late', 'absent', 'excused'].map(
                        (s) => ChoiceChip(
                          label: Text(StatusBadge.label(s)),
                          selected: status == s,
                          onSelected: (_) => setState(() => status = s),
                        ),
                      ),
                    ],
                  ),
                  if (user.isLecturer)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: sort,
                      decoration: const InputDecoration(
                        labelText: 'Sắp xếp sinh viên',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'absent',
                          child: Text('Vắng nhiều trước'),
                        ),
                        DropdownMenuItem(
                          value: 'name',
                          child: Text('Tên sinh viên'),
                        ),
                      ],
                      onChanged: (v) => setState(() => sort = v!),
                    ),
                  const SizedBox(height: 12),
                  ...entries.map((entry) {
                    final student = attendanceSummary(
                      ref,
                      entry.value.map((r) => r['status'] as String),
                    );
                    return CampusCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: MemberLabel(classId: cls['id'], uid: entry.key),
                        subtitle: Text(
                          'Chuyên cần: ${student.rate?.toStringAsFixed(1) ?? 'Chưa đủ dữ liệu'}${student.rate == null ? '' : '%'}\n'
                          'Vắng: ${student.absent} • ${student.absenceRate?.toStringAsFixed(1) ?? 'Chưa đủ dữ liệu'}${student.absenceRate == null ? '' : '%'} • ${student.absenceWarning}',
                        ),
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: MemberLabel(
                              classId: cls['id'],
                              uid: entry.key,
                            ),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: entry.value
                                    .map(
                                      (r) => ListTile(
                                        title: Text(
                                          attendanceSessionLabel(r, cls),
                                        ),
                                        subtitle: StatusBadge(r['status']),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Đóng'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
