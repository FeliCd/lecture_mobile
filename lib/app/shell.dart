import 'dart:async';
import 'package:flutter/material.dart';
import '../api/repository.dart';
import '../core/widgets.dart';
import '../features/auth/auth.dart';
import '../features/classes/class_screen.dart';
import '../features/sessions/session_screen.dart';
import '../models/domain.dart';

class LecturerShell extends StatefulWidget {
  final AuthController auth;
  const LecturerShell({super.key, required this.auth});
  @override
  State<LecturerShell> createState() => _LecturerShellState();
}

class _LecturerShellState extends State<LecturerShell>
    with WidgetsBindingObserver {
  int tab = 0;
  int revision = 0;
  bool week = false;
  String query = '';
  String semester = '';
  Timer? clock;
  Lecturer get lecturer => widget.auth.lecturer!;
  LecturerRepository get repo => widget.auth.repository!;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(() => revision++);
  }

  Future<void> openSession(TeachingClass cls, TeachingSession session) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionScreen(
          repo: repo,
          lecturer: lecturer,
          cls: cls,
          sessionId: session.sessionId,
        ),
      ),
    );
    if (mounted) setState(() => revision++);
  }

  Future<void> openClass(TeachingClass cls) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClassScreen(repo: repo, lecturer: lecturer, cls: cls),
      ),
    );
    if (mounted) setState(() => revision++);
  }

  @override
  Widget build(BuildContext context) {
    const titles = [
      'Your teaching day',
      'Schedule',
      'My classes',
      'Reports',
      'Profile',
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[tab]),
        actions: [
          if (tab != 4)
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => setState(() => revision++),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: SafeArea(
        child: tab == 4
            ? profile()
            : AsyncPanel<Overview>(
                key: ValueKey(revision),
                load: () => repo.overview(lecturer.lecturerId),
                builder: (context, data, refresh) {
                  final terms =
                      data.schedules.map((s) => s.semester).toSet().toList()
                        ..sort();
                  final selected = terms.contains(semester)
                      ? semester
                      : (terms.length == 1 ? terms.single : '');
                  return RefreshIndicator(
                    onRefresh: refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if ((tab == 0 || tab == 1) && terms.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DropdownButtonFormField<String>(
                              initialValue: selected,
                              decoration: const InputDecoration(
                                labelText: 'Teaching semester',
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('Select semester'),
                                ),
                                ...terms.map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ),
                                ),
                              ],
                              onChanged: (value) =>
                                  setState(() => semester = value ?? ''),
                            ),
                          ),
                        ...switch (tab) {
                          0 => home(data, selected),
                          1 => schedule(data, selected),
                          2 => classes(data),
                          _ => reports(data),
                        },
                      ],
                    ),
                  );
                },
              ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() {
          tab = value;
          query = '';
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            label: 'Classes',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  List<Widget> home(Overview data, String term) {
    final now = CampusClock.now(), today = CampusClock.date(CampusClock.now());
    final current = data.sessions
        .where(
          (s) =>
              s.isOpen && CampusClock.current(s.date, s.startTime, s.endTime),
        )
        .toList();
    final todaySchedules =
        data.schedules
            .where((s) => s.semester == term && s.dayOfWeek == now.weekday)
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final upcoming = todaySchedules
        .where(
          (s) =>
              (CampusClock.minutes(s.endTime) ?? 0) >
              now.hour * 60 + now.minute,
        )
        .toList();
    final pending = data.sessions.where((s) => s.isOpen).toList();
    return [
      Text(
        'Hello, ${lecturer.fullName}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      Text(today, style: Theme.of(context).textTheme.bodyMedium),
      const SectionTitle('Focus for today'),
      if (current.isNotEmpty)
        sessionCard(data, current.first, prominent: true)
      else if (upcoming.isNotEmpty)
        scheduleCard(data, upcoming.first, today, prominent: true)
      else
        const Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No current or next class today. Your day is clear.'),
          ),
        ),
      const SectionTitle("Today's schedule"),
      if (term.isEmpty && data.schedules.isNotEmpty)
        const Text('Select a semester to view recurring teaching times.'),
      if (todaySchedules.isEmpty) const Text('No teaching schedule for today.'),
      ...todaySchedules.map((s) => scheduleCard(data, s, today)),
      const SectionTitle('Pending actions'),
      if (pending.isEmpty) const Text('No open attendance sessions.'),
      ...pending.take(5).map((s) => sessionCard(data, s)),
      if (pending.length > 5)
        TextButton(
          onPressed: () => setState(() => tab = 3),
          child: Text('View all ${pending.length} open sessions in Reports'),
        ),
      const SizedBox(height: 16),
      Text(
        '${data.classes.length} classes • ${data.sessions.where((s) => s.status == 'CLOSED').length} closed sessions',
      ),
    ];
  }

  List<Widget> schedule(Overview data, String term) {
    final now = CampusClock.now();
    final start = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: week ? now.weekday - 1 : 0));
    return [
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('Today')),
          ButtonSegment(value: true, label: Text('Week')),
        ],
        selected: {week},
        onSelectionChanged: (value) => setState(() => week = value.single),
      ),
      const SizedBox(height: 16),
      const Text(
        'Campus time · UTC+7. Recurring timetable; confirm the teaching date before starting attendance.',
      ),
      if (term.isEmpty && data.schedules.isNotEmpty)
        const MessagePanel(
          message: 'Select a semester to display its timetable.',
        ),
      for (var offset = 0; offset < (week ? 7 : 1); offset++) ...[
        SectionTitle(CampusClock.date(start.add(Duration(days: offset)))),
        ...dayCards(data, term, start.add(Duration(days: offset))),
      ],
    ];
  }

  List<Widget> dayCards(Overview data, String term, DateTime day) {
    final rows =
        data.schedules
            .where((s) => s.semester == term && s.dayOfWeek == day.weekday)
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return rows.isEmpty
        ? [const Text('No classes scheduled.')]
        : rows
              .map((s) => scheduleCard(data, s, CampusClock.date(day)))
              .toList();
  }

  Widget scheduleCard(
    Overview data,
    Schedule row,
    String date, {
    bool prominent = false,
  }) {
    final cls = data.mappedClass(row);
    final sessions = data.sessions
        .where(
          (s) =>
              s.classId == cls?.classId && s.date == date && s.slot == row.slot,
        )
        .toList();
    return Card(
      color: prominent ? Theme.of(context).colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (prominent)
              Text(
                CampusClock.current(date, row.startTime, row.endTime)
                    ? 'CURRENT CLASS'
                    : 'NEXT CLASS',
              ),
            const SizedBox(height: 6),
            Text(
              '${row.subjectCode} · ${row.classCode}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '${row.startTime} – ${row.endTime} · Slot ${row.slot}\n${row.room}',
            ),
            const SizedBox(height: 12),
            if (sessions.length == 1)
              FilledButton(
                onPressed: cls == null
                    ? null
                    : () => openSession(cls, sessions.single),
                child: Text('Open attendance · ${sessions.single.status}'),
              )
            else if (sessions.length > 1)
              const Text(
                'Multiple sessions found. Ask your administrator to resolve this conflict.',
              )
            else
              FilledButton(
                onPressed: cls == null
                    ? null
                    : () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => StartSessionScreen(
                              repo: repo,
                              lecturer: lecturer,
                              cls: cls,
                              schedule: row,
                              date: date,
                            ),
                          ),
                        );
                        if (mounted) setState(() => revision++);
                      },
                child: const Text('Start attendance'),
              ),
            if (cls == null)
              const Text(
                'A unique class mapping is required. Import the class roster in the attendance system.',
              ),
          ],
        ),
      ),
    );
  }

  Widget sessionCard(
    Overview data,
    TeachingSession session, {
    bool prominent = false,
  }) {
    final cls = data.classFor(session.classId);
    if (prominent) {
      return Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CURRENT SESSION'),
              const SizedBox(height: 8),
              Text(
                cls == null
                    ? 'Class unavailable'
                    : '${cls.subjectCode} · ${cls.classCode}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '${session.startTime}–${session.endTime} · Slot ${session.slot}',
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: cls == null ? null : () => openSession(cls, session),
                child: const Text('Open attendance'),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      color: prominent ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          cls == null
              ? 'Class unavailable'
              : '${cls.subjectCode} · ${cls.classCode}',
        ),
        subtitle: Text(
          '${session.date} · ${session.startTime}–${session.endTime}\nSlot ${session.slot}',
        ),
        trailing: StatusChip(session.status),
        onTap: cls == null ? null : () => openSession(cls, session),
      ),
    );
  }

  List<Widget> classes(Overview data) {
    final filtered = data.classes
        .where(
          (c) => '${c.subjectCode} ${c.classCode} ${c.semester}'
              .toLowerCase()
              .contains(query.toLowerCase()),
        )
        .toList();
    return [
      TextField(
        decoration: const InputDecoration(
          labelText: 'Search classes',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (v) => setState(() => query = v),
      ),
      const SizedBox(height: 20),
      if (filtered.isEmpty) const MessagePanel(message: 'No classes found.'),
      ...filtered.map(
        (cls) => Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text('${cls.subjectCode} · ${cls.classCode}'),
            subtitle: Text(
              '${cls.semester}\n${data.sessions.where((s) => s.classId == cls.classId).length} attendance sessions',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openClass(cls),
          ),
        ),
      ),
    ];
  }

  List<Widget> reports(Overview data) => [
    const Text(
      'Reports use the same session records as attendance. Open a session for its report, or a class for its summary.',
    ),
    const SectionTitle('Class summaries'),
    ...data.classes.map(
      (cls) => Card(
        child: ListTile(
          title: Text('${cls.subjectCode} · ${cls.classCode}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openClass(cls),
        ),
      ),
    ),
    const SectionTitle('Recent sessions'),
    if (data.sessions.isEmpty)
      const MessagePanel(message: 'No attendance reports yet.'),
    ...data.sessions.take(50).map((s) => sessionCard(data, s)),
    if (data.sessions.length > 50)
      const Text(
        'Showing the 50 most recent sessions. Open a class for its full session list.',
      ),
    const SizedBox(height: 16),
    const Text(
      'Excel export is available in the desktop system. A mobile export service is not yet available.',
    ),
  ];
  Widget profile() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const CircleAvatar(
        radius: 36,
        child: Icon(Icons.person_outline, size: 40),
      ),
      SectionTitle(lecturer.fullName),
      Text(lecturer.email),
      const SizedBox(height: 16),
      Text('Lecturer code: ${lecturer.lecturerCode}'),
      Text('Department: ${lecturer.department}'),
      const SizedBox(height: 24),
      const Text(
        'Your access is verified by the attendance service. Attendance changes require an internet connection.',
      ),
      const SizedBox(height: 24),
      OutlinedButton.icon(
        onPressed: widget.auth.busy ? null : widget.auth.logout,
        icon: const Icon(Icons.logout),
        label: const Text('Log out'),
      ),
    ],
  );
}
