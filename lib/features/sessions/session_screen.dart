import 'package:flutter/material.dart';
import '../../api/repository.dart';
import '../../core/widgets.dart';
import '../../models/domain.dart';
import '../attendance/attendance_view.dart';

class StartSessionScreen extends StatefulWidget {
  final LecturerRepository repo;
  final Lecturer lecturer;
  final TeachingClass cls;
  final Schedule schedule;
  final String date;
  const StartSessionScreen({
    super.key,
    required this.repo,
    required this.lecturer,
    required this.cls,
    required this.schedule,
    required this.date,
  });
  @override
  State<StartSessionScreen> createState() => _StartSessionScreenState();
}

class _StartSessionScreenState extends State<StartSessionScreen> {
  bool busy = false;
  String? error;
  Future<void> start() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final session = await widget.repo.start(
        widget.cls,
        widget.schedule,
        widget.date,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SessionScreen(
            repo: widget.repo,
            lecturer: widget.lecturer,
            cls: widget.cls,
            sessionId: session.sessionId,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        await showFailure(context, e);
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Start attendance')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SectionTitle('${widget.cls.subjectCode} · ${widget.cls.classCode}'),
          Text(
            '${widget.date}\n${widget.schedule.startTime}–${widget.schedule.endTime} · Slot ${widget.schedule.slot}\n${widget.schedule.room}',
          ),
          const SizedBox(height: 24),
          const Text(
            'Confirm this is a teaching day. The timetable repeats weekly and does not contain holiday or semester date boundaries.',
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: busy ? null : start,
            child: Text(
              busy ? 'Opening session…' : 'Confirm and start attendance',
            ),
          ),
        ],
      ),
    ),
  );
}

class SessionScreen extends StatefulWidget {
  final LecturerRepository repo;
  final Lecturer lecturer;
  final TeachingClass cls;
  final String sessionId;
  const SessionScreen({
    super.key,
    required this.repo,
    required this.lecturer,
    required this.cls,
    required this.sessionId,
  });
  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('${widget.cls.subjectCode} · ${widget.cls.classCode}'),
    ),
    body: SafeArea(
      child: AsyncPanel<SessionAttendance>(
        load: () => widget.repo.attendance(
          widget.cls,
          widget.sessionId,
          widget.lecturer.lecturerId,
        ),
        builder: (context, data, refresh) => AttendanceView(
          repo: widget.repo,
          lecturer: widget.lecturer,
          cls: widget.cls,
          data: data,
          refresh: refresh,
        ),
      ),
    ),
  );
}
