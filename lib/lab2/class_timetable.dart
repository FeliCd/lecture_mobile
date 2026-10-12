import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain.dart';
import 'timetable.dart';
import 'timetable_domain.dart';
import 'widgets.dart';
import 'timetable_card.dart';

class ClassTimetable extends ConsumerStatefulWidget {
  final Data cls;
  final UserProfile user;
  final DateTime? now;
  const ClassTimetable({
    super.key,
    required this.cls,
    required this.user,
    this.now,
  });
  @override
  ConsumerState<ClassTimetable> createState() => _ClassTimetableState();
}

class _ClassTimetableState extends ConsumerState<ClassTimetable> {
  int week = 0;
  @override
  Widget build(BuildContext context) {
    final exceptions = ref.watch(teachingExceptionsProvider(widget.user.uid));
    final now = widget.now ?? DateTime.now();
    final today = campusDay(now);
    final monday = weekStart(today).add(Duration(days: week * 7));
    final schedules = ref.watch(teachingSchedulesProvider(widget.user.uid));
    final sessions = ref.watch(teachingSessionsProvider('${widget.cls['id']}'));
    for (final source in [schedules, sessions, exceptions]) {
      if (source.hasError) {
        return ErrorState(source.error!, () {
          ref.invalidate(teachingSchedulesProvider(widget.user.uid));
          ref.invalidate(teachingSessionsProvider('${widget.cls['id']}'));
          ref.invalidate(teachingExceptionsProvider(widget.user.uid));
        });
      }
    }
    if (!schedules.hasValue || !sessions.hasValue || !exceptions.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    final periodsByDay = <DateTime, List<TeachingPeriod>>{};
    for (final day in days) {
      periodsByDay[day] = teachingPeriods(
        user: widget.user,
        day: day,
        term: '${widget.cls['term']}',
        schedules: schedules.value!,
        classes: [widget.cls],
        sessions: sessions.value!,
        exceptions: exceptions.value ?? [],
        includeCancelled: true,
      ).where((p) => p.classId == widget.cls['id']).toList();
    }
    final count = periodsByDay.values.fold(0, (n, p) => n + p.length);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          subjectLabel(widget.cls),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text('Lớp ${widget.cls['classCode']} • ${widget.cls['term']}'),
        const SizedBox(height: 16),
        Row(
          children: [
            IconButton(
              tooltip: 'Tuần trước',
              onPressed: () => setState(() => week--),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${timetableDate(monday)} – ${timetableDate(days.last)}',
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              tooltip: 'Tuần sau',
              onPressed: () => setState(() => week++),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        TextButton(
          onPressed: () => setState(() => week = 0),
          child: const Text('Về tuần hiện tại'),
        ),
        Text('$count buổi học', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (count == 0) const EmptyState('Không có lịch học trong tuần này.'),
        for (final entry in periodsByDay.entries.where(
          (e) => e.value.isNotEmpty,
        )) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '${teachingDayName(entry.key.weekday)} • ${timetableDate(entry.key)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final period in entry.value) TeachingPeriodCard(period: period),
        ],
        const SizedBox(height: 12),
        const Text(
          'Chọn buổi học để điểm danh hoặc xem kết quả. Buổi bù và thay đổi lịch được quản lý trong Công cụ lớp học.',
        ),
      ],
    );
  }
}
