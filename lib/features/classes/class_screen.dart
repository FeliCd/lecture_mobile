import 'package:flutter/material.dart';
import '../../api/repository.dart';
import '../../core/widgets.dart';
import '../../models/domain.dart';
import '../sessions/session_screen.dart';
import 'roster_import_screen.dart';

class ClassData {
  final List<Student> roster;
  final Overview overview;
  final List<AttendanceRecord> history;
  ClassData(this.roster, this.overview, this.history);
}

class ClassScreen extends StatefulWidget {
  final LecturerRepository repo;
  final Lecturer lecturer;
  final TeachingClass cls;
  const ClassScreen({
    super.key,
    required this.repo,
    required this.lecturer,
    required this.cls,
  });
  @override
  State<ClassScreen> createState() => _ClassScreenState();
}

class _ClassScreenState extends State<ClassScreen> {
  String search = '';
  int section = 0;
  Future<ClassData> load() async {
    final results = await Future.wait<Object>([
      widget.repo.roster(widget.cls),
      widget.repo.overview(widget.lecturer.lecturerId),
      widget.repo.history(widget.cls),
    ]);
    return ClassData(
      results[0] as List<Student>,
      results[1] as Overview,
      results[2] as List<AttendanceRecord>,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.cls.classCode),
      actions: [
        IconButton(
          tooltip: 'Nhập danh sách SV',
          icon: const Icon(Icons.file_upload_outlined),
          onPressed: () async {
            final target = ClassTarget(
              semester: widget.cls.semester,
              subjectCode: widget.cls.subjectCode,
              classCode: widget.cls.classCode,
              subjectName: widget.cls.subjectName,
              classId: widget.cls.classId,
            );
            final imported = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => RosterImportScreen(
                  repo: widget.repo,
                  lecturer: widget.lecturer,
                  preselectedTarget: target,
                  defaultSemester: widget.cls.semester,
                ),
              ),
            );
            if (imported == true && context.mounted) setState(() {});
          },
        ),
      ],
    ),
    body: SafeArea(
      child: AsyncPanel<ClassData>(
        load: load,
        builder: (context, data, refresh) {
          final sessions = data.overview.sessions
              .where((s) => s.classId == widget.cls.classId)
              .toList();
          final students = data.roster
              .where(
                (s) => '${s.fullName} ${s.studentCode}'.toLowerCase().contains(
                  search.toLowerCase(),
                ),
              )
              .toList();
          final schedules = data.overview.schedules
              .where((s) => s.key == widget.cls.key)
              .toList();
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: section == 1
                  ? students.length + 1
                  : section == 2
                  ? sessions.length + 1
                  : 1,
              itemBuilder: (context, index) {
                if (index > 0 && section == 1) {
                  final student = students[index - 1];
                  return Card(
                    child: ListTile(
                      title: Text(student.fullName),
                      subtitle: Text(
                        '${student.studentCode}\n${student.schoolEmail}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => StudentScreen(
                            student: student,
                            cls: widget.cls,
                            sessions: sessions,
                            records: data.history,
                          ),
                        ),
                      ),
                    ),
                  );
                }
                if (index > 0 && section == 2) {
                  final session = sessions[index - 1];
                  return Card(
                    child: ListTile(
                      title: Text('${session.date} · Slot ${session.slot}'),
                      subtitle: Text('${session.startTime}–${session.endTime}'),
                      trailing: StatusChip(session.status),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SessionScreen(
                              repo: widget.repo,
                              lecturer: widget.lecturer,
                              cls: widget.cls,
                              sessionId: session.sessionId,
                            ),
                          ),
                        );
                        if (context.mounted) await refresh();
                      },
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.cls.subjectCode,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(widget.cls.subjectName),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.cls.semester} · ${widget.lecturer.fullName}',
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${data.roster.length} students · ${sessions.length} sessions',
                    ),
                    const SizedBox(height: 20),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('Overview')),
                        ButtonSegment(value: 1, label: Text('Students')),
                        ButtonSegment(value: 2, label: Text('Sessions')),
                      ],
                      selected: {section},
                      onSelectionChanged: (v) =>
                          setState(() => section = v.single),
                    ),
                    if (section == 0) ...[
                      const SectionTitle('Teaching times'),
                      if (schedules.isEmpty)
                        const Text(
                          'No recurring timetable linked to this class.',
                        ),
                      ...schedules.map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            '${const ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][s.dayOfWeek.clamp(0, 7)]} · ${s.startTime}–${s.endTime} · ${s.room}',
                          ),
                        ),
                      ),
                      const SectionTitle('Attendance summary'),
                      Text(
                        '${data.history.where((r) => r.status == 'PRESENT').length} present records\n${data.history.where((r) => r.status == 'LATE').length} late records\n${data.history.where((r) => r.status == 'ABSENT').length} saved absent records',
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Counts are saved records across non-reset sessions. Open a session report for roster-complete absence totals. No institution-wide attendance-rate rule is defined by the backend.',
                      ),
                    ],
                    if (section == 1) ...[
                      const SizedBox(height: 20),
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Search roster',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) => setState(() => search = v),
                      ),
                      const SizedBox(height: 12),
                      if (students.isEmpty)
                        const MessagePanel(message: 'No students found.'),
                    ],
                    if (section == 2 && sessions.isEmpty)
                      const MessagePanel(
                        message:
                            'No attendance sessions yet. Start one from Schedule.',
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    ),
  );
}

class StudentScreen extends StatelessWidget {
  final Student student;
  final TeachingClass cls;
  final List<TeachingSession> sessions;
  final List<AttendanceRecord> records;
  const StudentScreen({
    super.key,
    required this.student,
    required this.cls,
    required this.sessions,
    required this.records,
  });
  @override
  Widget build(BuildContext context) {
    final history = records
        .where((r) => r.studentId == student.studentId)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Student')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SectionTitle(student.fullName),
            Text(student.studentCode),
            SelectableText(student.schoolEmail),
            const SizedBox(height: 16),
            Text('${cls.subjectCode} · ${cls.classCode}'),
            const SectionTitle('Attendance in this class'),
            Text(
              '${history.where((r) => r.status == 'PRESENT').length} present · ${history.where((r) => r.status == 'LATE').length} late · ${history.where((r) => r.status == 'ABSENT').length} saved absent',
            ),
            const SizedBox(height: 12),
            const Text(
              'History is scoped to this class. Missing records are shown explicitly; an attendance rate is not supplied by the service.',
            ),
            const SectionTitle('Session history'),
            if (sessions.isEmpty) const Text('No sessions yet.'),
            ...sessions.map((s) {
              final matches = history
                  .where((r) => r.sessionId == s.sessionId)
                  .toList();
              return Card(
                child: ListTile(
                  title: Text('${s.date} · Slot ${s.slot}'),
                  trailing: StatusChip(
                    matches.isEmpty
                        ? 'UNRECORDED'
                        : matches.length == 1
                        ? matches.single.status
                        : 'CONFLICT',
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
