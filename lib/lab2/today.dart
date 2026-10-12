import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain.dart';
import 'repository.dart';
import 'timetable_card.dart';
import 'timetable_domain.dart';
import 'widgets.dart';
import 'timetable.dart';

class TodayPanel extends ConsumerStatefulWidget {
  final UserProfile user;
  final VoidCallback onTimetable;
  const TodayPanel({super.key, required this.user, required this.onTimetable});
  @override
  ConsumerState<TodayPanel> createState() => _TodayPanelState();
}

class _TodayPanelState extends ConsumerState<TodayPanel> {
  String? term;
  @override
  Widget build(BuildContext context) {
    final repo = ref.read(repositoryProvider), day = campusDay(DateTime.now());
    final exceptions = ref.watch(teachingExceptionsProvider(widget.user.uid));
    if (exceptions.hasError) {
      return ErrorState(
        exceptions.error!,
        () => ref.invalidate(teachingExceptionsProvider(widget.user.uid)),
      );
    }
    if (!exceptions.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    return CampusRefreshList(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Chào ${widget.user.name}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text('${teachingDayName(day.weekday)}, ${timetableDate(day)}'),
        OutlinedButton(
          onPressed: widget.onTimetable,
          child: const Text('Xem thời khóa biểu'),
        ),
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
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selected,
                  decoration: const InputDecoration(labelText: 'Học kỳ'),
                  items: terms
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => term = v),
                ),
                if (selected == null)
                  const EmptyState('Chọn học kỳ để xem các buổi hôm nay.'),
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
                          return const EmptyState(
                            'Không có lịch hôm nay. Kiểm tra Lịch dạy hoặc thêm buổi bù trong công cụ quản lý lịch.',
                          );
                        }
                        final completed = periods
                            .where((p) => p.completed)
                            .length;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                children: [
                                  Text('${periods.length} buổi học'),
                                  Text('$completed đã chốt'),
                                  Text(
                                    '${periods.where((p) => !p.completed && !p.cancelled).length} còn lại',
                                  ),
                                ],
                              ),
                            ),
                            const CampusSectionHeader(
                              title: 'Lịch hôm nay',
                              description: 'Chọn buổi học để điểm danh',
                            ),
                            for (final p in periods)
                              TeachingPeriodCard(period: p, showAction: true),
                          ],
                        );
                      },
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
