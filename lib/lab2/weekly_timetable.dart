import 'package:flutter/material.dart';
import 'timetable_domain.dart';
import 'timetable_card.dart';

/// Four teaching slots, without invented time blocks or a lunch row.
class WeeklyTimetable extends StatefulWidget {
  final List<DateTime> days;
  final Map<DateTime, List<TeachingPeriod>> byDay;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelectDay;
  const WeeklyTimetable({
    super.key,
    required this.days,
    required this.byDay,
    required this.selectedDay,
    required this.onSelectDay,
  });
  @override
  State<WeeklyTimetable> createState() => _WeeklyTimetableState();
}

class _WeeklyTimetableState extends State<WeeklyTimetable> {
  final horizontal = ScrollController();
  TeachingPeriod? selected;
  double columnWidth = 132;
  @override
  void initState() {
    super.initState();
    revealDay();
  }

  @override
  void didUpdateWidget(covariant WeeklyTimetable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDay != widget.selectedDay) revealDay();
    if (selected != null) {
      final matches = widget.byDay.values
          .expand((rows) => rows)
          .where(
            (p) =>
                p.sessionDate == selected!.sessionDate &&
                p.slot == selected!.slot &&
                p.classId == selected!.classId &&
                p.scheduleId == selected!.scheduleId &&
                p.exceptionId == selected!.exceptionId,
          )
          .toList();
      selected = matches.length == 1 ? matches.single : null;
    }
  }

  void revealDay() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !horizontal.hasClients) return;
      final index = widget.days.indexOf(widget.selectedDay);
      if (index < 0) return;
      horizontal.animateTo(
        (index * columnWidth).clamp(0, horizontal.position.maxScrollExtent),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    horizontal.dispose();
    super.dispose();
  }

  bool conflict(TeachingPeriod p) =>
      !p.cancelled &&
      (widget.byDay[p.day] ?? []).any(
        (other) =>
            !identical(p, other) && !other.cancelled && p.overlaps(other),
      );
  List<TeachingPeriod> cell(DateTime day, int slot) =>
      (widget.byDay[day] ?? []).where((p) => p.slot == slot).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  void selectPeriod(TeachingPeriod period) {
    setState(() => selected = period);
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${teachingDayName(period.day.weekday)}, ${timetableDate(period.day)}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              TeachingPeriodCard(
                period: period,
                compact: true,
                showAction: true,
                conflict: conflict(period),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final headerHeight = 78.0 * scale;
    final heights = [
      for (var slot = 1; slot <= 4; slot++)
        widget.days.fold<int>(
              1,
              (max, day) =>
                  cell(day, slot).length > max ? cell(day, slot).length : max,
            ) *
            140.0 *
            scale,
    ];
    final outside = widget.byDay.values
        .expand((rows) => rows)
        .where((p) => p.slot == null || p.slot! < 1 || p.slot! > 4)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            _Legend('Lịch dạy', scheme.secondary),
            _Legend('Đang dạy', scheme.primary),
            _Legend('Đã chốt', scheme.tertiary),
            _Legend('Trùng giờ', scheme.error),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.swipe_rounded, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Vuốt ngang xem các ngày · Cột slot luôn cố định',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            columnWidth =
                ((constraints.maxWidth - 58) / 2).clamp(132, 200).toDouble() *
                scale;
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 58,
                      child: Column(
                        children: [
                          _AxisCell(height: headerHeight, label: 'Ca học'),
                          for (var slot = 1; slot <= 4; slot++)
                            _AxisCell(
                              height: heights[slot - 1],
                              label: 'Slot $slot',
                              key: ValueKey('week-slot-$slot'),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Scrollbar(
                        controller: horizontal,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: horizontal,
                          scrollDirection: Axis.horizontal,
                          key: const ValueKey('weekly-grid-scroll'),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final day in widget.days)
                                SizedBox(
                                  width: columnWidth,
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        height: headerHeight,
                                        child: Material(
                                          color: day == widget.selectedDay
                                              ? scheme.primaryContainer
                                              : scheme.surfaceContainerLow,
                                          child: InkWell(
                                            onTap: () =>
                                                widget.onSelectDay(day),
                                            child: Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  right: BorderSide(
                                                    color:
                                                        scheme.outlineVariant,
                                                  ),
                                                  bottom: BorderSide(
                                                    color:
                                                        scheme.outlineVariant,
                                                  ),
                                                ),
                                              ),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    '${day.weekday == 7 ? 'CN' : 'Thứ ${day.weekday + 1}'} · ${timetableDate(day)}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.labelLarge,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${(widget.byDay[day] ?? []).where((p) => !p.cancelled).length} buổi${day == campusDay(DateTime.now()) ? ' · Hôm nay' : ''}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      for (var slot = 1; slot <= 4; slot++)
                                        Container(
                                          key: ValueKey(
                                            'week-cell-${day.toIso8601String()}-$slot',
                                          ),
                                          height: heights[slot - 1],
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: day == widget.selectedDay
                                                ? scheme.primary.withValues(
                                                    alpha: .025,
                                                  )
                                                : scheme.surface,
                                            border: Border(
                                              right: BorderSide(
                                                color: scheme.outlineVariant,
                                              ),
                                              bottom: BorderSide(
                                                color: scheme.outlineVariant,
                                              ),
                                            ),
                                          ),
                                          child: cell(day, slot).isEmpty
                                              ? Center(
                                                  child: Semantics(
                                                    label:
                                                        '${teachingDayName(day.weekday)}, Slot $slot: trống',
                                                    child: Text(
                                                      '—',
                                                      style: TextStyle(
                                                        color: scheme.outline,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : Column(
                                                  children: [
                                                    for (final p in cell(
                                                      day,
                                                      slot,
                                                    ))
                                                      Expanded(
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                vertical: 3,
                                                              ),
                                                          child: _LessonCell(
                                                            period: p,
                                                            conflict: conflict(
                                                              p,
                                                            ),
                                                            selected: identical(
                                                              p,
                                                              selected,
                                                            ),
                                                            onTap: () =>
                                                                selectPeriod(p),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Chạm một buổi học để xem đầy đủ thông tin và điểm danh.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (outside.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Lịch cần kiểm tra · Slot ngoài khung 1–4'),
          for (final p in outside) TeachingPeriodCard(period: p, compact: true),
        ],
      ],
    );
  }
}

class _AxisCell extends StatelessWidget {
  final double height;
  final String label;
  const _AxisCell({super.key, required this.height, required this.label});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(color: scheme.outlineVariant),
          bottom: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final Color color;
  const _Legend(this.label, this.color);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _LessonCell extends StatelessWidget {
  final TeachingPeriod period;
  final bool conflict, selected;
  final VoidCallback onTap;
  const _LessonCell({
    required this.period,
    required this.conflict,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now().toUtc();
    final active =
        !period.cancelled &&
        !period.completed &&
        !now.isBefore(period.scheduledStartAt) &&
        now.isBefore(period.scheduledEndAt);
    final tone = period.cancelled
        ? scheme.onSurfaceVariant
        : conflict
        ? scheme.error
        : period.completed
        ? scheme.tertiary
        : active
        ? scheme.primary
        : scheme.secondary;
    final status = period.cancelled
        ? 'Đã hủy'
        : conflict
        ? 'Trùng giờ'
        : period.completed
        ? 'Đã chốt'
        : active
        ? 'Đang dạy'
        : !now.isBefore(period.scheduledEndAt)
        ? 'Chưa chốt'
        : 'Lịch dạy';
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${period.subjectId}, ${period.classCode}, Slot ${period.slot}, ${period.timeRange}, ${roomLabel(period.room)}, $status',
      child: Material(
        color: tone.withValues(alpha: .08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: tone.withValues(alpha: selected ? 1 : .3),
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(8, 7, 6, 7),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: tone, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  period.subjectId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: tone,
                  ),
                ),
                Text(
                  period.classCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    period.timeRange.replaceAll(' – ', '–'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  roomLabel(period.room),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  status,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
