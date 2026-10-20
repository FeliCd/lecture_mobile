import 'motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain.dart';
import 'desktop_sync.dart';
import 'repository.dart';
import 'widgets.dart';
import 'dashboard_widgets.dart';
import 'timetable_domain.dart';
import 'timetable_card.dart';
import 'import_page.dart';

final teachingClassesProvider = StreamProvider.autoDispose
    .family<List<Data>, String>((ref, uid) {
      final user = ref.watch(profileProvider).value;
      if (user == null || !user.isLecturer || user.uid != uid) {
        return Stream.value([]);
      }
      return ref.watch(repositoryProvider).classes(user);
    });
final teachingSchedulesProvider = StreamProvider.autoDispose
    .family<List<Data>, String>(
      (ref, uid) => ref
          .watch(repositoryProvider)
          .watch('schedules', field: 'lecturerUid', equals: uid),
    );
final teachingSessionsProvider = StreamProvider.autoDispose
    .family<List<Data>, String>(
      (ref, id) => ref
          .watch(repositoryProvider)
          .watch('classSessions', field: 'classId', equals: id),
    );

final teachingExceptionsProvider = StreamProvider.autoDispose
    .family<List<Data>, String>(
      (ref, uid) => useSharedDesktop
          ? ref.watch(repositoryProvider).watch('scheduleExceptions')
          : Stream.value([]),
    );

class LecturerTimetable extends ConsumerStatefulWidget {
  final UserProfile user;
  final DateTime? initialDay;
  const LecturerTimetable({super.key, required this.user, this.initialDay});
  @override
  ConsumerState<LecturerTimetable> createState() => _LecturerTimetableState();
}

class _LecturerTimetableState extends ConsumerState<LecturerTimetable> {
  late DateTime selectedDay;
  late ScrollController dayScroll;
  String? selectedTerm;
  String subject = '';
  bool weekly = false;
  bool filtersOpen = false;
  @override
  void initState() {
    super.initState();
    selectedDay = widget.initialDay ?? campusDay(DateTime.now());
    dayScroll = ScrollController(
      initialScrollOffset: (selectedDay.weekday - 1) * 70.0,
    );
  }

  @override
  void dispose() {
    dayScroll.dispose();
    super.dispose();
  }

  void selectDay(DateTime day) {
    setState(() => selectedDay = day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && dayScroll.hasClients) {
        dayScroll.animateTo(
          ((day.weekday - 1) * 70.0).clamp(
            0,
            dayScroll.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void retry(List<Data> classes) {
    ref.invalidate(teachingExceptionsProvider(widget.user.uid));
    ref.invalidate(teachingClassesProvider(widget.user.uid));
    ref.invalidate(teachingSchedulesProvider(widget.user.uid));
    for (final cls in classes) {
      ref.invalidate(teachingSessionsProvider(cls['id'] as String));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.user.isLecturer) {
      return const EmptyState('Lịch dạy dành cho giảng viên.');
    }
    final classesData = ref.watch(teachingClassesProvider(widget.user.uid));
    final schedulesData = ref.watch(teachingSchedulesProvider(widget.user.uid));
    final exceptions = ref.watch(teachingExceptionsProvider(widget.user.uid));
    final classes = classesData.value ?? <Data>[];
    final sources = [
      for (final cls in classes)
        ref.watch(teachingSessionsProvider(cls['id'] as String)),
    ];
    for (final source in [classesData, schedulesData, exceptions, ...sources]) {
      if (source.hasError) {
        return ErrorState(source.error!, () => retry(classes));
      }
    }
    if (!classesData.hasValue ||
        !schedulesData.hasValue ||
        !exceptions.hasValue ||
        sources.any((s) => !s.hasValue)) {
      return const Center(child: CircularProgressIndicator());
    }
    final schedules = schedulesData.value!;
    final sessions = sources.expand((s) => s.value!).toList();
    final terms = {
      ...classes.map((c) => '${c['term'] ?? ''}'),
      ...schedules.map((s) => '${s['term'] ?? ''}'),
    }.where((t) => t.isNotEmpty).toList()..sort();
    final term = terms.contains(selectedTerm)
        ? selectedTerm
        : terms.length == 1
        ? terms.single
        : null;
    final subjects = {
      ...classes
          .where((c) => c['term'] == term)
          .map((c) => '${c['subjectId']}'),
      ...schedules
          .where((s) => s['term'] == term)
          .map((s) => '${s['subjectId']}'),
    }.toList()..sort();
    final effectiveSubject = subjects.contains(subject) ? subject : '';
    final monday = weekStart(selectedDay);
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    final byDay = {
      for (final day in days)
        day:
            teachingPeriods(
                  user: widget.user,
                  day: day,
                  term: term ?? '',
                  schedules: schedules,
                  classes: classes,
                  sessions: sessions,
                  exceptions: exceptions.value ?? [],
                  includeCancelled: true,
                )
                .where(
                  (p) =>
                      effectiveSubject.isEmpty ||
                      p.subjectId == effectiveSubject,
                )
                .toList(),
    };
    final total = byDay.values.fold(0, (sum, periods) => sum + periods.length);
    final today = campusDay(DateTime.now());
    final filterWidth = MediaQuery.textScalerOf(context).scale(1) > 1.5
        ? (MediaQuery.sizeOf(context).width - 40).clamp(190, 400).toDouble()
        : ((MediaQuery.sizeOf(context).width - 52) / 2)
              .clamp(130, 250)
              .toDouble();
    return CampusRefreshList(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        CampusEntrance(
          trigger: selectedDay,
          child: CampusCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Tuần trước',
                      onPressed: () => setState(
                        () => selectedDay = selectedDay.subtract(
                          const Duration(days: 7),
                        ),
                      ),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        '${timetableDate(monday)} – ${timetableDate(days.last)} • ${monday.year}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tuần sau',
                      onPressed: () => setState(
                        () => selectedDay = selectedDay.add(
                          const Duration(days: 7),
                        ),
                      ),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: dayScroll,
                  child: Row(
                    children: [
                      for (final day in days)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Semantics(
                            selected: day == selectedDay,
                            button: true,
                            label:
                                '${teachingDayName(day.weekday)}, ${timetableDate(day)}, ${byDay[day]!.length} buổi học${day == today ? ', hôm nay' : ''}',
                            excludeSemantics: true,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => setState(() => selectedDay = day),
                              child: Container(
                                width: 62,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: day == selectedDay
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: day == today
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      day.weekday == 7
                                          ? 'CN'
                                          : 'T${day.weekday + 1}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: day == selectedDay
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onPrimary
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${day.day}',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: day == selectedDay
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onPrimary
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: byDay[day]!.isEmpty
                                            ? Colors.transparent
                                            : day == selectedDay
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onPrimary
                                            : Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: () => selectDay(today),
                      icon: const Icon(Icons.today_outlined, size: 16),
                      label: const Text('Hôm nay'),
                    ),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Ngày')),
                        ButtonSegment(value: true, label: Text('Tuần')),
                      ],
                      selected: {weekly},
                      showSelectedIcon: false,
                      onSelectionChanged: (value) =>
                          setState(() => weekly = value.single),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SoftLabel(term ?? 'Chọn học kỳ', icon: Icons.school_outlined),
                  if (effectiveSubject.isNotEmpty) SoftLabel(effectiveSubject),
                ],
              ),
            ),
            Tooltip(
              message: 'Lọc lịch dạy',
              child: TextButton.icon(
                onPressed: () => setState(() => filtersOpen = !filtersOpen),
                icon: Icon(
                  filtersOpen
                      ? Icons.filter_list_off_rounded
                      : Icons.tune_rounded,
                ),
                label: Text(filtersOpen ? 'Ẩn lọc' : 'Lọc'),
              ),
            ),
          ],
        ),
        if (filtersOpen || term == null)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: filterWidth,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('term-$term-${terms.join()}'),
                  initialValue: term,
                  decoration: const InputDecoration(labelText: 'Học kỳ'),
                  isExpanded: true,
                  items: terms
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (value) => setState(() {
                    selectedTerm = value;
                    subject = '';
                  }),
                ),
              ),
              SizedBox(
                width: filterWidth,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('subject-$term-$effectiveSubject'),
                  initialValue: effectiveSubject,
                  decoration: const InputDecoration(labelText: 'Môn phụ trách'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Tất cả môn'),
                    ),
                    ...subjects.map(
                      (s) => DropdownMenuItem(value: s, child: Text(s)),
                    ),
                  ],
                  onChanged: (value) => setState(() => subject = value ?? ''),
                ),
              ),
            ],
          ),
        if (effectiveSubject.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => subject = ''),
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('Xóa lọc môn'),
            ),
          ),
        if (term == null)
          EmptyState(
            terms.isEmpty
                ? 'Chưa có lịch hoặc lớp được phân công.'
                : 'Chọn học kỳ để xem lịch dạy.',
          )
        else ...[
          DashboardHeading(
            title: weekly
                ? 'Lịch tuần • $total buổi'
                : '${teachingDayName(selectedDay.weekday)}, ${timetableDate(selectedDay)}',
            subtitle: weekly
                ? 'Theo ngày'
                : '${byDay[selectedDay]!.length} buổi học',
          ),
          if ((weekly && total == 0) ||
              (!weekly && byDay[selectedDay]!.isEmpty))
            EmptyState(
              effectiveSubject.isNotEmpty
                  ? 'Không có buổi học môn $effectiveSubject ${weekly ? 'tuần này' : 'ngày này'}.'
                  : 'Không có lịch dạy ${weekly ? 'trong tuần này' : 'trong ngày này'}.',
              actionLabel: effectiveSubject.isNotEmpty
                  ? 'Xem tất cả môn'
                  : null,
              onAction: () => setState(() => subject = ''),
            )
          else if (weekly)
            CampusEntrance(
              trigger: selectedDay,
              child: _WeekTimetable(days: days, byDay: byDay),
            )
          else
            ...byDay[selectedDay]!.map(
              (p) => TeachingPeriodCard(
                period: p,
                compact: true,
                conflict: byDay[selectedDay]!.any(
                  (other) => !identical(p, other) && p.overlaps(other),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Lịch định kỳ theo học kỳ • Giờ Việt Nam',
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => openImport(context),
            icon: const Icon(Icons.file_upload_outlined, size: 18),
            label: const Text('Nhập thời khóa biểu'),
          ),
        ),
      ],
    );
  }
}

class _WeekTimetable extends StatelessWidget {
  final List<DateTime> days;
  final Map<DateTime, List<TeachingPeriod>> byDay;
  const _WeekTimetable({required this.days, required this.byDay});
  @override
  Widget build(BuildContext context) {
    if (byDay.values.every((rows) => rows.isEmpty)) {
      return const EmptyState('Không có lịch dạy trong tuần này.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final day in days.where((d) => byDay[d]!.isNotEmpty)) ...[
          CampusSectionHeader(
            title: '${teachingDayName(day.weekday)} • ${timetableDate(day)}',
            description: '${byDay[day]!.length} buổi học',
          ),
          for (final p in byDay[day]!)
            TeachingPeriodCard(
              period: p,
              compact: true,
              conflict: byDay[day]!.any(
                (o) => !identical(p, o) && p.overlaps(o),
              ),
            ),
        ],
      ],
    );
  }
}
