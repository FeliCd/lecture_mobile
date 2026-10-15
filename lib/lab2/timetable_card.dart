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
    return CampusEntrance(
      trigger:
          '${period.sessionDate}:${period.slot}:${period.classCode}:${period.sessionId}:$action',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: featured ? scheme.primaryContainer : scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CampusRadius.card),
            side: BorderSide(
              color: featured ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => openClass(context),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 12 : 16,
                compact ? 12 : 16,
                16,
                compact ? 12 : 16,
              ),
              child: Container(
                padding: EdgeInsets.only(left: compact ? 12 : 0),
                decoration: compact
                    ? BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            width: 3,
                            color: period.cancelled
                                ? scheme.outline
                                : scheme.primary,
                          ),
                        ),
                      )
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Text(
                          '${period.timeRange} · Slot ${period.slot ?? '—'}',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: scheme.primary),
                        ),
                        if (conflict)
                          CampusStatusChip(
                            'Trùng giờ',
                            icon: Icons.warning_amber,
                            color: scheme.error,
                          ),
                      ],
                    ),
                    SizedBox(height: compact ? 8 : 12),
                    Text(
                      period.subjectName.isEmpty
                          ? period.subjectId
                          : period.subjectName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${period.subjectId} · Lớp ${period.classCode}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      roomLabel(period.room),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (showAction)
                      FilledButton(
                        onPressed: () => openClass(context),
                        child: Text(action),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: CampusStatusChip(
                              action,
                              icon: period.completed
                                  ? Icons.task_alt
                                  : period.sessionId != null
                                  ? Icons.play_circle_outline
                                  : Icons.schedule,
                              color:
                                  period.sessionId != null && !period.completed
                                  ? CampusColors.status(
                                      'present',
                                      Theme.of(context).brightness ==
                                          Brightness.dark,
                                    )
                                  : null,
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
      ),
    );
  }
}
