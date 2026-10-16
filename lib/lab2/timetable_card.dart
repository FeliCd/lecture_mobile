import 'motion.dart';
import 'package:flutter/material.dart';
import 'desktop_session_dialog.dart';
import 'timetable_domain.dart';
import 'widgets.dart';
import 'theme.dart';
import 'lecturer_workspace.dart';

String roomLabel(String? room) => room == null || room.trim().isEmpty
    ? 'Chưa cập nhật phòng'
    : 'Phòng ${room.trim()}';
String periodAction(TeachingPeriod p) {
  final now = DateTime.now().toUtc();
  if (p.cancelled) return 'Đã hủy';
  if (p.completed) return 'Xem kết quả';
  if (p.sessionId != null) return 'Tiếp tục điểm danh';
  if (now.isBefore(p.scheduledStartAt.subtract(const Duration(minutes: 15)))) {
    return 'Chưa đến giờ';
  }
  if (!now.isBefore(p.scheduledEndAt)) return 'Đã qua giờ';
  return 'Bắt đầu điểm danh';
}

class TeachingPeriodCard extends StatelessWidget {
  final TeachingPeriod period;
  final bool conflict, compact, showAction, featured;
  const TeachingPeriodCard({
    super.key,
    required this.period,
    this.conflict = false,
    this.compact = false,
    this.showAction = false,
    this.featured = false,
  });
  void openClass(BuildContext context) {
    if (period.classId != null && !period.cancelled) {
      openAttendanceForPeriod(context, period);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${period.subjectId} • ${period.classCode}',
              style: Theme.of(c).textTheme.titleLarge,
            ),
            Text(period.timeRange),
            Text(roomLabel(period.room)),
            const SizedBox(height: 16),
            Text(
              period.cancelled
                  ? 'Buổi học đã hủy. Không thể mở điểm danh.'
                  : 'Lịch này chưa được liên kết với một lớp duy nhất. Kiểm tra thông tin lớp trong dữ liệu gốc.',
            ),
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final action = periodAction(period);
    final active =
        !period.cancelled &&
        !period.completed &&
        !DateTime.now().toUtc().isBefore(period.scheduledStartAt) &&
        DateTime.now().toUtc().isBefore(period.scheduledEndAt);
    return CampusEntrance(
      trigger:
          '${period.sessionDate}:${period.slot}:${period.classCode}:${period.sessionId}:$action',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CampusRadius.card),
            side: BorderSide(
              color: featured || active
                  ? scheme.primary.withValues(alpha: .35)
                  : scheme.outlineVariant,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => openClass(context),
            child: Container(
              decoration: featured || active
                  ? BoxDecoration(
                      border: Border(
                        left: BorderSide(color: scheme.primary, width: 4),
                      ),
                    )
                  : null,
              padding: EdgeInsets.all(compact ? 14 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (featured)
                        CampusStatusChip(
                          active ? 'ĐANG DIỄN RA' : 'CA DẠY TIẾP THEO',
                          icon: active
                              ? Icons.radio_button_checked
                              : Icons.schedule,
                          color: scheme.primary,
                        )
                      else
                        Text(
                          '${period.timeRange} · Slot ${period.slot ?? '—'}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      if (conflict)
                        CampusStatusChip(
                          'Trùng giờ',
                          icon: Icons.warning_amber,
                          color: scheme.error,
                        )
                      else if (featured && active)
                        CampusStatusChip(
                          'Còn ${period.scheduledEndAt.difference(DateTime.now().toUtc()).inMinutes} phút',
                          icon: Icons.schedule,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DefaultTextStyle(
                    style:
                        (featured
                                ? Theme.of(context).textTheme.titleLarge!
                                : Theme.of(context).textTheme.titleMedium!)
                            .copyWith(
                              color: featured
                                  ? scheme.onSurface
                                  : scheme.primary,
                            ),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(period.subjectId),
                        Text('· Lớp ${period.classCode}'),
                      ],
                    ),
                  ),
                  if (period.subjectName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      period.subjectName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (featured)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final details = [
                            _PeriodDetail(
                              icon: Icons.meeting_room_outlined,
                              label: 'Phòng học',
                              value: roomLabel(period.room),
                            ),
                            _PeriodDetail(
                              icon: Icons.access_time,
                              label: 'Ca học',
                              value:
                                  'Slot ${period.slot ?? '—'} · ${period.timeRange}',
                            ),
                          ];
                          return constraints.maxWidth < 240 ||
                                  MediaQuery.textScalerOf(context).scale(1) >
                                      1.3
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    details[0],
                                    const SizedBox(height: 12),
                                    details[1],
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: details[0]),
                                    const SizedBox(width: 12),
                                    Expanded(child: details[1]),
                                  ],
                                );
                        },
                      ),
                    )
                  else
                    Row(
                      children: [
                        Icon(
                          Icons.meeting_room_outlined,
                          size: 16,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            roomLabel(period.room),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  if (showAction)
                    FilledButton.icon(
                      onPressed: () => openClass(context),
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: Text(action),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: CampusStatusChip(
                            action,
                            icon: period.completed
                                ? Icons.task_alt
                                : Icons.schedule,
                            color: active ? scheme.primary : scheme.secondary,
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 20),
                      ],
                    ),
                  LessonNotebookButton(period: period),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodDetail extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _PeriodDetail({
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ],
  );
}
