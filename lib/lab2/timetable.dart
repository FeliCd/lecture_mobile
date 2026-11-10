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
import 'weekly_timetable.dart';
import 'academic_term.dart';

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
  late final ScrollController dayScroll;
  String subject = '';
  bool weekly = false;
  bool filtersOpen = false;
  static const _dayWidth = 48.0;
  @override
  void initState() {
    super.initState();
    selectedDay = widget.initialDay ?? campusDay(DateTime.now());
    dayScroll = ScrollController(
      initialScrollOffset: (selectedDay.weekday - 1) * _dayWidth,
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
          ((day.weekday - 1) * _dayWidth).clamp(
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
    final termSelection = ref.watch(
      selectedAcademicTermProvider(widget.user.uid),
    );
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
    final terms = academicTerms([...classes, ...schedules]);
    final term = resolveAcademicTerm(terms, termSelection.value);
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        CampusEntrance(
          trigger: selectedDay,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Tuần trước',
                            onPressed: () => selectDay(
                              selectedDay.subtract(const Duration(days: 7)),
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
                            onPressed: () => selectDay(
                              selectedDay.add(const Duration(days: 7)),
                            ),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final fits = constraints.maxWidth >= 44 * days.length;
                          final width = fits
                              ? constraints.maxWidth / days.length
                              : _dayWidth;
                          final strip = Row(
                            children: [
                              for (final day in days)
                                SizedBox(
                                  width: width,
                                  child: _DayTile(
                                    day: day,
                                    count: byDay[day]!.length,
                                    today: day == today,
                                    selected: day == selectedDay,
                                    onTap: () =>
                                        setState(() => selectedDay = day),
                                  ),
                                ),
                            ],
                          );
                          return fits
                              ? strip
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  controller: dayScroll,
                                  child: strip,
                                );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.view_agenda_outlined, size: 17),
                        label: Text('Ngày'),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.view_week_outlined, size: 17),
                        label: Text('Tuần'),
                      ),
                    ],
                    selected: {weekly},
                    showSelectedIcon: false,
                    onSelectionChanged: (value) =>
                        setState(() => weekly = value.single),
                  ),
                  TextButton.icon(
                    onPressed: () => selectDay(today),
                    icon: const Icon(Icons.today_outlined, size: 16),
                    label: const Text('Hôm nay'),
                  ),
                ],
              ),
            ],
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
        if (filtersOpen)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
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
          EmptyState('Chưa có lịch hoặc lớp được phân công.')
        else ...[
          DashboardHeading(
            title: weekly
                ? 'Lịch tuần • $total buổi'
                : '${teachingDayName(selectedDay.weekday)}, ${timetableDate(selectedDay)}',
            subtitle: weekly
                ? '4 slot mỗi ngày · Chạm buổi học để quản lý'
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
              child: WeeklyTimetable(
                days: days,
                byDay: byDay,
                selectedDay: selectedDay,
                onSelectDay: selectDay,
              ),
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

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.day,
    required this.count,
    required this.today,
    required this.selected,
    required this.onTap,
  });

  final DateTime day;
  final int count;
  final bool today, selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.onPrimary : scheme.onSurface;
    return Semantics(
      selected: selected,
      button: true,
      label:
          '${teachingDayName(day.weekday)}, ${timetableDate(day)}, $count buổi học${today ? ', hôm nay' : ''}',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: selected ? scheme.primary : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: today && !selected
                  ? Border.all(color: scheme.primary)
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Text(
                    day.weekday == 7 ? 'CN' : 'T${day.weekday + 1}',
                    style: TextStyle(fontSize: 11, color: foreground),
                  ),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: count == 0 ? Colors.transparent : foreground,
                    ),
                    child: const SizedBox.square(dimension: 4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
