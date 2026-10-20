import 'motion.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain.dart';
import 'repository.dart';
import 'timetable_card.dart';
import 'timetable_domain.dart';
import 'widgets.dart';
import 'timetable.dart';
import 'lecturer_workspace.dart';
import 'lecturer_workspace_store.dart';
import 'attendance_follow_up.dart';

TeachingPeriod? todayFocus(List<TeachingPeriod> periods, DateTime now) {
  final candidates =
      periods
          .where(
            (p) =>
                !p.cancelled && !p.completed && p.scheduledEndAt.isAfter(now),
          )
          .toList()
        ..sort((a, b) => a.scheduledStartAt.compareTo(b.scheduledStartAt));
  return candidates.firstOrNull;
}

class TodayPanel extends ConsumerStatefulWidget {
  final UserProfile user;
  final VoidCallback onTimetable;
  const TodayPanel({super.key, required this.user, required this.onTimetable});
  @override
  ConsumerState<TodayPanel> createState() => _TodayPanelState();
}

class _TodayPanelState extends ConsumerState<TodayPanel> {
  String? term;
  Timer? clock;
  @override
  void initState() {
    super.initState();
    clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repositoryProvider), day = campusDay(DateTime.now());
    final exceptions = ref.watch(teachingExceptionsProvider(widget.user.uid));
    if (exceptions.hasError) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TodayTaskPreview(user: widget.user),
          ErrorState(
            exceptions.error!,
            () => ref.invalidate(teachingExceptionsProvider(widget.user.uid)),
          ),
        ],
      );
    }
    if (!exceptions.hasValue) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TodayTaskPreview(user: widget.user),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    return CampusRefreshList(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          widget.user.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          '${teachingDayName(day.weekday)}, ${timetableDate(day)} · ${day.year}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        LiveList(
          source: () => repo.classes(widget.user),
          empty: 'Chưa có lớp được phân công.',
          builder: (classes) {
            final terms = classes.map((c) => '${c['term']}').toSet().toList()
              ..sort();
            final selected = terms.contains(term)
                ? term
                : terms.length == 1
                ? terms.single
                : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selected,
                        decoration: const InputDecoration(labelText: 'Học kỳ'),
                        items: terms
                            .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => term = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.outlined(
                      tooltip: 'Lịch dạy',
                      onPressed: widget.onTimetable,
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ],
                ),
                if (selected == null) const EmptyState('Chọn học kỳ'),
                if (selected != null)
                  LiveList(
                    source: () => repo.watch('schedules'),
                    buildEmpty: true,
                    builder: (schedules) => LiveList(
                      source: () => repo.watch('classSessions'),
                      buildEmpty: true,
                      builder: (sessions) {
                        final scheduled = teachingPeriods(
                          user: widget.user,
                          day: day,
                          term: selected,
                          schedules: schedules,
                          classes: classes,
                          sessions: sessions,
                          exceptions: exceptions.value ?? [],
                          includeCancelled: true,
                        );
                        final previous = teachingPeriods(
                          user: widget.user,
                          day: day.subtract(const Duration(days: 1)),
                          term: selected,
                          schedules: schedules,
                          classes: classes,
                          sessions: sessions,
                          exceptions: exceptions.value ?? [],
                          includeCancelled: true,
                        );
                        final periods = [
                          ...previous.where(
                            (p) =>
                                p.end < p.start &&
                                DateTime.now().toUtc().isBefore(
                                  p.scheduledEndAt,
                                ),
                          ),
                          ...scheduled,
                        ];

                        if (periods.isEmpty) {
                          return const EmptyState('Hôm nay không có lịch dạy');
                        }
                        final completed = periods
                            .where((p) => p.completed)
                            .length;
                        final now = DateTime.now().toUtc();
                        final focus = todayFocus(periods, now);
                        final others = periods
                            .where(
                              (p) =>
                                  !identical(p, focus) &&
                                  attendanceFollowUp(p, now) == null,
                            )
                            .toList();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AttendanceFollowUpPanel(periods: periods, now: now),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                children: [
                                  CampusStatusChip(
                                    '${periods.where((p) => !p.cancelled).length} buổi',
                                    icon: Icons.school_outlined,
                                  ),
                                  CampusStatusChip(
                                    '$completed đã chốt',
                                    icon: Icons.task_alt,
                                  ),
                                  if (periods.any((p) => p.cancelled))
                                    CampusStatusChip(
                                      '${periods.where((p) => p.cancelled).length} đã hủy',
                                      icon: Icons.event_busy,
                                    ),
                                ],
                              ),
                            ),
                            if (focus != null &&
                                attendanceFollowUp(focus, now) == null) ...[
                              CampusSectionHeader(
                                title: focus.scheduledStartAt.isAfter(now)
                                    ? 'Sắp dạy'
                                    : 'Đang dạy',
                              ),
                              TeachingPeriodCard(
                                period: focus,
                                showAction: true,
                                featured: true,
                              ),
                            ] else if (focus == null)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Text('Hết lịch hôm nay'),
                              ),
                            if (others.isNotEmpty)
                              ExpansionTile(
                                key: PageStorageKey(
                                  'other-lessons:${widget.user.uid}:$day',
                                ),
                                tilePadding: EdgeInsets.zero,
                                initiallyExpanded: true,
                                childrenPadding: const EdgeInsets.only(top: 8),
                                expansionAnimationStyle: AnimationStyle(
                                  duration: campusReduceMotion(context)
                                      ? Duration.zero
                                      : const Duration(milliseconds: 220),
                                ),
                                title: Text(
                                  '${focus == null ? 'Buổi học' : 'Buổi khác'} (${others.length})',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                children: [
                                  for (final p in others)
                                    TeachingPeriodCard(
                                      period: p,
                                      compact: true,
                                    ),
                                ],
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                if (selected != null)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Cài đặt nhắc điểm danh'),
                    children: [
                      AttendanceReminderToggle(
                        uid: widget.user.uid,
                        term: selected,
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        TodayTaskPreview(user: widget.user),
      ],
    );
  }
}

class TodayTaskPreview extends ConsumerWidget {
  final UserProfile user;
  const TodayTaskPreview({super.key, required this.user});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(workspaceProvider(user.uid));
    void open([String? task]) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LecturerWorkspacePage(user: user, selectedTask: task),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Đến hạn',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Tooltip(
              message: 'Việc cá nhân, sổ tay và báo cáo tuần · Lưu trên máy',
              child: TextButton.icon(
                onPressed: () => open(),
                icon: const Icon(Icons.checklist, size: 18),
                label: const Text('Trợ lý'),
              ),
            ),
          ],
        ),
        value.when(
          loading: () => const Text('Đang tải…'),
          error: (e, _) =>
              ErrorState(e, () => ref.invalidate(workspaceProvider(user.uid))),
          data: (data) {
            final now = DateTime.now().toUtc();
            final tomorrow = campusDay(
              now,
            ).add(const Duration(days: 1, hours: -7));
            final tasks =
                data.tasks.where((t) {
                  final due = DateTime.tryParse('${t['due']}');
                  return t['done'] != true &&
                      due != null &&
                      due.isBefore(tomorrow);
                }).toList()..sort(
                  (a, b) => DateTime.parse(
                    '${a['due']}',
                  ).compareTo(DateTime.parse('${b['due']}')),
                );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (tasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Không có việc đến hạn'),
                  ),
                for (final t in tasks.take(3))
                  CampusEntrance(
                    key: ValueKey(t['id']),
                    child: Card(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: ListTile(
                        leading: Icon(
                          DateTime.parse('${t['due']}').isBefore(now)
                              ? Icons.pending_actions
                              : Icons.checklist,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text('${t['title']}'),
                        subtitle: Text(
                          '${DateTime.parse('${t['due']}').isBefore(now) ? 'Quá hạn · ' : 'Hôm nay · '}${workspaceDate('${t['due']}')}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => open('${t['id']}'),
                      ),
                    ),
                  ),
                if (tasks.length > 3)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => open(),
                      child: Text('Xem tất cả (${tasks.length})'),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
