import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'domain.dart';
import 'repository.dart';
import 'widgets.dart';
import 'desktop_sync.dart';
import 'dashboard_widgets.dart';
import 'theme.dart';
import 'student_support.dart';
import 'attendance_history.dart';
import 'class_attendance_config.dart';

final classAttendanceSessionsProvider = StreamProvider.autoDispose
    .family<List<Data>, String>(
      (ref, id) => ref
          .watch(repositoryProvider)
          .watch('attendanceSessions', field: 'classId', equals: id),
    );
final classAttendanceRecordsProvider = StreamProvider.autoDispose
    .family<List<Data>, String>((ref, id) {
      final user = ref.watch(profileProvider).value;
      if (user == null) return Stream.value(<Data>[]);
      return ref
          .watch(repositoryProvider)
          .watch(
            'attendanceRecords',
            field: 'classId',
            equals: id,
            uid: user.isLecturer ? null : user.uid,
          );
    });

class ClassAttendanceOverview extends ConsumerStatefulWidget {
  final Data cls;
  final bool showStudents;
  final bool showIdentity;
  const ClassAttendanceOverview({
    super.key,
    required this.cls,
    this.showStudents = false,
    this.showIdentity = true,
  });
  @override
  ConsumerState<ClassAttendanceOverview> createState() =>
      _ClassAttendanceOverviewState();
}

class _ClassAttendanceOverviewState
    extends ConsumerState<ClassAttendanceOverview> {
  String search = '', filter = 'all';
  final searchController = TextEditingController();
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.cls['id'] as String;
    final user = ref.watch(profileProvider).value;
    final support = widget.showStudents && user?.isLecturer == true
        ? ref.watch(studentSupportProvider(user!.uid))
        : null;
    final sessions = ref.watch(classAttendanceSessionsProvider(id));
    final records = ref.watch(classAttendanceRecordsProvider(id));
    final members = ref.watch(memberNamesProvider(id));
    for (final data in <AsyncValue<dynamic>>[sessions, records, members]) {
      if (data.hasError) {
        return ErrorState(data.error!, () {
          ref.invalidate(classAttendanceSessionsProvider(id));
          ref.invalidate(classAttendanceRecordsProvider(id));
          ref.invalidate(memberNamesProvider(id));
        });
      }
    }
    if (!sessions.hasValue || !records.hasValue || !members.hasValue) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final finalized = sessions.value!
        .where(
          (s) =>
              s['status'] == 'finalized' && s['attendanceCompleted'] != false,
        )
        .map((s) => s['id'])
        .toSet();
    final completedRecords = records.value!
        .where((r) => finalized.contains(r['attendanceSessionId']))
        .toList();
    final finalizedSlotCount = sessions.value!
        .where((s) => finalized.contains(s['id']))
        .map(attendanceSlotKey)
        .toSet()
        .length;
    final groups = <String, List<Data>>{
      for (final uid in members.value!.keys) uid: [],
    };
    for (final row in completedRecords) {
      groups.putIfAbsent(row['studentUid'] as String, () => []).add(row);
    }
    for (final uid in groups.keys.toList()) {
      groups[uid] = studentAttendanceSlots(
        uid,
        sessions.value!,
        records.value!,
      );
    }
    final summary = attendanceSummary(
      ref,
      groups.values.expand((rows) => rows).map((r) => '${r['status']}'),
    );
    final attendanceRate = summary.rate;
    final totalSlots = courseSlotTotal(widget.cls['totalSlots']);
    final studentSummaries = {
      for (final entry in groups.entries)
        entry.key: attendanceSummary(
          ref,
          entry.value.map((r) => r['status'] as String),
          totalSlots: totalSlots,
        ),
    };
    final currentSummaries = members.value!.keys.map(
      (uid) => studentSummaries[uid]!,
    );
    final limit = summary.policy.limitPercent.toStringAsFixed(0);
    final warning = summary.policy.warningPercent.toStringAsFixed(0);
    final near = currentSummaries.where((s) => s.nearAbsenceLimit).length;
    final exceeded = currentSummaries
        .where((s) => s.exceedsAbsenceLimit)
        .length;
    final unclassified = currentSummaries
        .where(
          (s) =>
              !s.hasSlotTotal ||
              s.pending > 0 ||
              s.present + s.late + s.missedSlots == 0,
        )
        .where((s) => !s.nearAbsenceLimit && !s.exceedsAbsenceLimit)
        .length;
    final runs = {
      for (final uid in members.value!.keys)
        uid: consecutiveAbsences(uid, sessions.value!, records.value!),
    };
    Data noteFor(String uid) =>
        support?.value?[studentSupportKey(id, uid)] ?? {};
    bool needsFollowUp(String uid) =>
        runs[uid]!.length >= 2 ||
        studentSummaries[uid]!.missedSlots >= 3 ||
        studentSummaries[uid]!.nearAbsenceLimit ||
        studentSummaries[uid]!.exceedsAbsenceLimit ||
        noteFor(uid)['followUp'] == true;
    final students = members.value!.entries.where((entry) {
      final s = studentSummaries[entry.key]!;
      return attendanceSearchText(
            '${entry.value['displayName']} ${entry.value['studentCode']}',
          ).contains(search) &&
          (filter == 'all' ||
              filter == 'frequent' && s.missedSlots >= 3 ||
              filter == 'consecutive' && runs[entry.key]!.length >= 2 ||
              filter == 'followUp' && needsFollowUp(entry.key) ||
              filter == 'near' && s.nearAbsenceLimit ||
              filter == 'exceeded' && s.exceedsAbsenceLimit);
    }).toList();
    students.sort((a, b) {
      final riskOrder = (studentSummaries[b.key]!.absenceRate ?? -1).compareTo(
        studentSummaries[a.key]!.absenceRate ?? -1,
      );
      return riskOrder != 0
          ? riskOrder
          : '${a.value['displayName']}'.compareTo('${b.value['displayName']}');
    });
    final overview = CampusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showStudents && user?.isLecturer == true)
            ClassAttendanceConfig(cls: widget.cls),
          if (widget.showIdentity) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.cls['classCode']}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.cls['subjectId']} • ${widget.cls['term'] ?? 'Học kỳ hiện tại'}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.showStudents)
                  IconButton(
                    onPressed: () => context.push('/class/$id'),
                    tooltip: 'Quản lý lớp và điểm danh',
                    icon: const Icon(Icons.arrow_outward_rounded, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SoftLabel(
                '${members.value!.length} sinh viên',
                icon: Icons.people_outline,
              ),
              SoftLabel(
                'Buổi đã chốt: $finalizedSlotCount',
                icon: Icons.event_available_outlined,
              ),
            ],
          ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TỶ LỆ CHUYÊN CẦN',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      attendanceRate == null
                          ? 'Chưa đủ dữ liệu'
                          : '${attendanceRate.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontSize: attendanceRate == null ? 18 : 28,
                          ),
                    ),
                  ],
                ),
              ),
              if (attendanceRate != null) ...[
                const SizedBox(width: 12),
                ExcludeSemantics(
                  child: SizedBox.square(
                    dimension: 52,
                    child: CircularProgressIndicator(
                      value: (attendanceRate / 100).clamp(0.0, 1.0),
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHigh,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          AttendanceBar(counts: summary),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              for (final item in {
                'present': 'Có mặt: ${summary.present}',
                'late': 'Đi trễ: ${summary.late}',
                'excused': 'Vắng có phép: ${summary.excused}',
                'absent': 'Vắng: ${summary.absent}',
              }.entries)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: CampusColors.status(
                          item.key,
                          Theme.of(context).brightness == Brightness.dark,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        item.value,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const Divider(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SoftLabel(
                'Sắp vượt $limit%: $near',
                icon: Icons.warning_amber_rounded,
                color: CampusColors.status(
                  'late',
                  Theme.of(context).brightness == Brightness.dark,
                ),
              ),
              SoftLabel(
                'Vượt $limit%: $exceeded',
                icon: Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
              ),
            ],
          ),
          if (widget.showStudents) ...[
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              dense: true,
              title: Text(
                'Cách tính & ngưỡng cảnh báo',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              children: [
                Text(
                  'Tỷ lệ nghỉ = số slot vắng (kể cả có phép) / tổng slot cả môn × 100%. Mỗi buổi là 1 slot, không chia theo số phút hay số lần quét QR. Cảnh báo từ $warning%; vượt $limit% mới cấm thi. Ví dụ 20 slot: được nghỉ tối đa 4, nghỉ 5 sẽ bị cấm thi. Chỉ tính kết quả đã chốt; bản nháp và buổi chưa điểm danh không tự tính vắng.',
                  style: TextStyle(fontSize: 14, height: 1.6),
                ),
              ],
            ),
          ],
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showStudents) ...[
          _RosterOverview(
            rate: attendanceRate,
            slots: finalizedSlotCount,
            safe: members.value!.length - near - exceeded - unclassified,
            near: near,
            exceeded: exceeded,
            unclassified: unclassified,
            hasSlotTotal: totalSlots != null,
            details: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Chuyên cần'),
              children: [overview],
            ),
          ),
        ] else
          overview,
        if (widget.showStudents) ...[
          const SizedBox(height: 12),
          CampusSearchField(
            controller: searchController,
            hint: 'Tìm tên hoặc MSSV',
            onChanged: (value) =>
                setState(() => search = attendanceSearchText(value)),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 8,
              children: [
                for (final option in {
                  'all': 'Tất cả (${members.value!.length})',
                  'followUp': 'Cần theo dõi',
                  'frequent': 'Nghỉ từ 3 slot',
                  'consecutive': 'Nghỉ liên tục',
                  'near': 'Sắp vượt $limit%',
                  'exceeded': 'Vượt $limit%',
                }.entries)
                  ChoiceChip(
                    label: Text(option.value),
                    selected: filter == option.key,
                    onSelected: (_) => setState(() => filter = option.key),
                  ),
              ],
            ),
          ),
          if (filter == 'followUp')
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Nghỉ từ 3 slot, nghỉ từ 2 slot liên tục, chạm ngưỡng cảnh báo hoặc được đánh dấu cần trao đổi.',
              ),
            ),
          if (support?.hasError == true)
            TextButton.icon(
              onPressed: () =>
                  ref.invalidate(studentSupportProvider(user!.uid)),
              icon: const Icon(Icons.refresh),
              label: const Text('Chưa tải được ghi chú riêng · Thử lại'),
            ),
          if (filter == 'followUp' &&
              support != null &&
              !support.hasValue &&
              !support.hasError)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Đang tải ghi chú riêng…'),
            ),
          if (students.isEmpty &&
              !(filter == 'followUp' &&
                  support != null &&
                  !support.hasValue &&
                  !support.hasError))
            EmptyState(
              filter == 'followUp' && support?.hasError == true
                  ? 'Chưa thấy cảnh báo từ điểm danh. Ghi chú riêng chưa tải được.'
                  : 'Không có sinh viên phù hợp.',
              actionLabel: search.isNotEmpty || filter != 'all'
                  ? 'Xóa bộ lọc'
                  : null,
              onAction: () => setState(() {
                search = '';
                filter = 'all';
                searchController.clear();
              }),
            ),
          if (students.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: CampusSectionHeader(
                title: 'Danh sách sinh viên',
                description:
                    '${students.length} sinh viên · Vắng nhiều trước${useSharedDesktop ? ' · Đồng bộ từ Sheet' : ''}',
              ),
            ),
          ...students.map((entry) {
            final s = studentSummaries[entry.key]!;
            return StudentAttendanceRow(
              key: ValueKey(entry.key),
              name: '${entry.value['displayName'] ?? 'Chưa có tên'}',
              code: '${entry.value['studentCode'] ?? 'Chưa có MSSV'}',
              summary: s,
              attention: [
                if (runs[entry.key]!.length >= 2)
                  'Vắng ${runs[entry.key]!.length} buổi liên tiếp',
                if (noteFor(entry.key)['followUp'] == true)
                  'Cần trao đổi'
                else if (noteFor(entry.key).isNotEmpty)
                  'Có ghi chú riêng',
              ].join(' · '),
              onTap: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('${entry.value['displayName']}'),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        Text('${entry.value['studentCode'] ?? 'Chưa có MSSV'}'),
                        const SizedBox(height: 12),
                        Text(
                          'Có mặt ${s.present} • Đi trễ ${s.late} • Vắng ${s.absent} • Có phép ${s.excused}',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tỷ lệ vắng: ${s.absenceRate == null ? 'Chưa đủ dữ liệu' : '${s.absenceRate!.toStringAsFixed(1)}%'}',
                        ),
                        const SizedBox(height: 8),
                        Text(attendanceWarningLabel(s)),
                        if (runs[entry.key]!.length >= 2) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Vắng ${runs[entry.key]!.length} buổi liên tiếp',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          ...runs[entry.key]!.map(
                            (session) => Text(absenceRunDate(session)),
                          ),
                          const Text(
                            'Đếm vắng và vắng có phép ở các slot đã chốt gần nhất; có mặt, đi trễ hoặc bản ghi thiếu ngắt chuỗi.',
                          ),
                        ],
                        if (user?.isLecturer == true)
                          Consumer(
                            builder: (context, ref, _) {
                              final current = ref.watch(
                                studentSupportProvider(user!.uid),
                              );
                              final note =
                                  current.value?[studentSupportKey(
                                    id,
                                    entry.key,
                                  )] ??
                                  {};
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if ('${note['note'] ?? ''}'.isNotEmpty)
                                    Text('Ghi chú riêng: ${note['note']}'),
                                  if ('${note['next'] ?? ''}'.isNotEmpty)
                                    Text('Trao đổi buổi sau: ${note['next']}'),
                                  TextButton.icon(
                                    onPressed:
                                        !current.hasValue || current.hasError
                                        ? null
                                        : () => showModalBottomSheet<void>(
                                            context: context,
                                            isScrollControlled: true,
                                            isDismissible: false,
                                            enableDrag: false,
                                            builder: (_) => StudentSupportEditor(
                                              accountUid: user.uid,
                                              classId: id,
                                              studentUid: entry.key,
                                              name:
                                                  '${entry.value['displayName']}',
                                              initial: note,
                                            ),
                                          ),
                                    icon: const Icon(Icons.edit_note),
                                    label: const Text('Ghi chú riêng'),
                                  ),
                                ],
                              );
                            },
                          ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tính từ các bản ghi điểm danh đã chốt. Đi trễ và vắng có phép phụ thuộc quy định đã cấu hình.',
                        ),
                        const Divider(),
                        if (groups[entry.key]!.isEmpty)
                          const Text('Chưa có bản ghi điểm danh đã chốt.'),
                        ...groups[entry.key]!.map(
                          (r) => ListTile(
                            title: Text(attendanceSessionLabel(r, widget.cls)),
                            subtitle: StatusBadge(r['status'] as String),
                          ),
                        ),
                      ],
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
            );
          }),
        ],
      ],
    );
  }
}

String attendanceWarningLabel(AttendanceSummary summary) {
  return summary.absenceWarning;
}

class _RosterOverview extends StatelessWidget {
  final double? rate;
  final int slots, safe, near, exceeded, unclassified;
  final bool hasSlotTotal;
  final Widget details;

  const _RosterOverview({
    required this.rate,
    required this.slots,
    required this.safe,
    required this.near,
    required this.exceeded,
    required this.unclassified,
    required this.hasSlotTotal,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final metrics = [
      (
        'An toàn',
        safe,
        Icons.check_circle_outline,
        CampusColors.status('present', dark),
      ),
      (
        'Chú ý',
        near,
        Icons.warning_amber_rounded,
        CampusColors.status('late', dark),
      ),
      ('Nguy cơ', exceeded, Icons.error_outline, colors.error),
    ];
    return CampusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TỔNG QUAN CHUYÊN CẦN',
                      style: theme.textTheme.labelMedium,
                    ),
                    Text(
                      rate == null
                          ? 'Chưa đủ dữ liệu'
                          : '${rate!.toStringAsFixed(1)}%',
                      style: theme.textTheme.headlineMedium,
                    ),
                    Text(
                      '$slots slot đã chốt',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (rate != null)
                ExcludeSemantics(
                  child: SizedBox.square(
                    dimension: 46,
                    child: CircularProgressIndicator(
                      value: (rate! / 100).clamp(0.0, 1.0),
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                      backgroundColor: colors.surfaceContainerHigh,
                    ),
                  ),
                ),
            ],
          ),
          if (hasSlotTotal) ...[
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, box) {
                final tiles = [
                  for (final (label, count, icon, color) in metrics)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, size: 15, color: color),
                          Text(
                            label,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: color,
                            ),
                          ),
                          Text('$count', style: theme.textTheme.titleMedium),
                        ],
                      ),
                    ),
                ];
                return box.maxWidth < 230
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 6,
                        children: tiles,
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 6,
                        children: [
                          for (final tile in tiles) Expanded(child: tile),
                        ],
                      );
              },
            ),
            if (unclassified > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '$unclassified sinh viên cần thêm dữ liệu',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
          details,
        ],
      ),
    );
  }
}

/// Compact summary; the existing history action exposes counts and records.
class StudentAttendanceRow extends StatelessWidget {
  final String name, code;
  final String attention;
  final AttendanceSummary summary;
  final VoidCallback onTap;
  const StudentAttendanceRow({
    super.key,
    required this.name,
    required this.code,
    required this.summary,
    this.attention = '',
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unknown = !summary.hasSlotTotal;
    final limit = summary.maxAbsences;
    final atLimit = limit == summary.missedSlots && summary.missedSlots > 0;
    final needsCaution = atLimit || summary.nearAbsenceLimit;
    final pendingOnly =
        !unknown &&
        !summary.exceedsAbsenceLimit &&
        !needsCaution &&
        summary.pending > 0;
    final color = unknown || pendingOnly
        ? scheme.onSurfaceVariant
        : summary.exceedsAbsenceLimit
        ? scheme.error
        : CampusColors.status(
            needsCaution ? 'late' : 'present',
            theme.brightness == Brightness.dark,
          );
    final statusIcon = unknown || pendingOnly
        ? Icons.info_outline
        : summary.exceedsAbsenceLimit
        ? Icons.error_outline
        : needsCaution
        ? Icons.warning_amber_rounded
        : Icons.check_circle_outline;
    final words = name.trim().split(RegExp(r'\s+'));
    final initial = words.last.isEmpty ? '?' : words.last.characters.first;
    final remaining = summary.remainingAbsences;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                spacing: 10,
                children: [
                  ExcludeSemantics(
                    child: CircleAvatar(
                      radius: 21,
                      backgroundColor: color.withValues(alpha: .12),
                      foregroundColor: color,
                      child: Text(initial.toUpperCase()),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          code,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              CampusStatusChip(
                attendanceWarningLabel(summary),
                icon: statusIcon,
                color: color,
              ),
              if (attention.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(attention, style: theme.textTheme.labelMedium),
                ),
              if (summary.pending > 0 && !pendingOnly)
                Text('${summary.pending} slot chưa rõ kết quả · Cần đối chiếu'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 2,
                children: [
                  Text(
                    limit == null
                        ? 'Đã nghỉ ${summary.missedSlots} slot'
                        : 'Mức độ vắng · ${summary.missedSlots} / $limit slot',
                    style: theme.textTheme.labelMedium,
                  ),
                  if (remaining != null)
                    Text(
                      'Còn $remaining slot',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: color,
                      ),
                    ),
                ],
              ),
              if (summary.absenceRate case final rate?)
                Text(
                  'Tỷ lệ vắng: ${rate.toStringAsFixed(1)}%',
                  style: theme.textTheme.bodySmall,
                ),
              if (limit != null && limit > 0) ...[
                const SizedBox(height: 6),
                ExcludeSemantics(
                  child: limit <= 8
                      ? Row(
                          spacing: 4,
                          children: [
                            for (var i = 0; i < limit; i++)
                              Expanded(
                                child: Container(
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: i < summary.missedSlots
                                        ? color
                                        : scheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                          ],
                        )
                      : LinearProgressIndicator(
                          value: (summary.missedSlots / limit).clamp(0.0, 1.0),
                          minHeight: 5,
                          borderRadius: BorderRadius.circular(4),
                          color: color,
                          backgroundColor: scheme.surfaceContainerHigh,
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
