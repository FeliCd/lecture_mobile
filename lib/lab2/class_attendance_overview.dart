import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'domain.dart';
import 'repository.dart';
import 'widgets.dart';
import 'desktop_sync.dart';
import 'dashboard_widgets.dart';
import 'theme.dart';

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
  const ClassAttendanceOverview({
    super.key,
    required this.cls,
    this.showStudents = false,
  });
  @override
  ConsumerState<ClassAttendanceOverview> createState() =>
      _ClassAttendanceOverviewState();
}

class _ClassAttendanceOverviewState
    extends ConsumerState<ClassAttendanceOverview> {
  String search = '', filter = 'all';
  @override
  Widget build(BuildContext context) {
    final id = widget.cls['id'] as String;
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
        .where((s) => s['status'] == 'finalized')
        .map((s) => s['id'])
        .toSet();
    final completedRecords = records.value!
        .where((r) => finalized.contains(r['attendanceSessionId']))
        .toList();
    final summary = attendanceSummary(
      ref,
      completedRecords.map((r) => r['status'] as String),
    );
    final groups = <String, List<Data>>{
      for (final uid in members.value!.keys) uid: [],
    };
    for (final row in completedRecords) {
      groups.putIfAbsent(row['studentUid'] as String, () => []).add(row);
    }
    final studentSummaries = {
      for (final entry in groups.entries)
        entry.key: attendanceSummary(
          ref,
          entry.value.map((r) => r['status'] as String),
        ),
    };
    final currentSummaries = members.value!.keys.map(
      (uid) => studentSummaries[uid]!,
    );
    final near = currentSummaries.where((s) => s.nearAbsenceLimit).length;
    final exceeded = currentSummaries
        .where((s) => s.exceedsAbsenceLimit)
        .length;
    final students = members.value!.entries.where((entry) {
      final s = studentSummaries[entry.key]!;
      return '${entry.value['displayName']} ${entry.value['studentCode']}'
              .toLowerCase()
              .contains(search) &&
          (filter == 'all' ||
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CampusCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SoftLabel(
                    '${members.value!.length} sinh viên',
                    icon: Icons.people_outline,
                  ),
                  SoftLabel(
                    'Buổi đã chốt: ${finalized.length}',
                    icon: Icons.event_available_outlined,
                  ),
                ],
              ),
              const Divider(),
              Text(
                'TỶ LỆ CHUYÊN CẦN',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                summary.rate == null
                    ? 'Chưa đủ dữ liệu'
                    : '${summary.rate!.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: summary.rate == null ? 18 : 28,
                ),
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
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
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
                    'Sắp vượt 20%: $near',
                    icon: Icons.warning_amber_rounded,
                    color: CampusColors.status(
                      'late',
                      Theme.of(context).brightness == Brightness.dark,
                    ),
                  ),
                  SoftLabel(
                    'Vượt 20%: $exceeded',
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
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  children: const [
                    Text(
                      'Tỷ lệ vắng tính trên các buổi đã chốt. Cảnh báo từ 15% đến 20%; vượt ngưỡng khi trên 20%.',
                      style: TextStyle(fontSize: 12, height: 1.6),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (widget.showStudents) ...[
          const SizedBox(height: 12),
          DashboardHeading(
            title: 'Sinh viên',
            subtitle: useSharedDesktop
                ? 'Đồng bộ từ Sheet • Tự cập nhật mỗi 30 giây'
                : 'Theo dõi chuyên cần và lịch sử từng sinh viên',
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Tìm tên hoặc MSSV',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) =>
                setState(() => search = value.toLowerCase().trim()),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final option in {
                'all': 'Tất cả',
                'near': 'Sắp vượt 20%',
                'exceeded': 'Vượt 20%',
              }.entries)
                ChoiceChip(
                  label: Text(option.value),
                  selected: filter == option.key,
                  onSelected: (_) => setState(() => filter = option.key),
                ),
            ],
          ),
          if (students.isEmpty) const EmptyState('Không có sinh viên phù hợp.'),
          if (students.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '${students.length} sinh viên • Ưu tiên tỷ lệ vắng cao',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ...students.map((entry) {
            final s = studentSummaries[entry.key]!;
            return CampusCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${entry.value['displayName']} • ${entry.value['studentCode']}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'Có mặt ${s.present} • Đi trễ ${s.late} • Vắng ${s.absent} • Có phép ${s.excused}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tỷ lệ vắng: ${s.absenceRate == null ? 'Chưa đủ dữ liệu' : '${s.absenceRate!.toStringAsFixed(1)}%'}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SoftLabel(
                      s.absenceWarning,
                      icon: s.exceedsAbsenceLimit
                          ? Icons.error_outline
                          : s.nearAbsenceLimit
                          ? Icons.warning_amber_rounded
                          : s.eligible == 0
                          ? Icons.hourglass_empty_rounded
                          : Icons.check_circle_outline,
                      color: s.exceedsAbsenceLimit
                          ? Theme.of(context).colorScheme.error
                          : s.eligible == 0
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : CampusColors.status(
                              s.nearAbsenceLimit ? 'late' : 'present',
                              Theme.of(context).brightness == Brightness.dark,
                            ),
                    ),
                  ],
                ),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('${entry.value['displayName']}'),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          if (groups[entry.key]!.isEmpty)
                            const Text('Chưa có bản ghi điểm danh đã chốt.'),
                          ...groups[entry.key]!.map(
                            (r) => ListTile(
                              title: Text(
                                attendanceSessionLabel(r, widget.cls),
                              ),
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
              ),
            );
          }),
        ],
      ],
    );
  }
}
