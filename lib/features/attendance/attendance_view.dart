import 'package:flutter/material.dart';
import '../../api/repository.dart';
import '../../core/widgets.dart';
import '../../models/domain.dart';
import 'qr_screen.dart';

class AttendanceView extends StatefulWidget {
  final LecturerRepository repo;
  final Lecturer lecturer;
  final TeachingClass cls;
  final SessionAttendance data;
  final Future<void> Function() refresh;
  const AttendanceView({
    super.key,
    required this.repo,
    required this.lecturer,
    required this.cls,
    required this.data,
    required this.refresh,
  });
  @override
  State<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<AttendanceView> {
  String search = '', filter = 'All';
  bool busy = false, report = false;
  Future<void> mutate(Future<void> Function() operation) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await operation();
    } catch (e) {
      if (mounted) await showFailure(context, e);
    } finally {
      if (mounted) {
        setState(() => busy = false);
        await widget.refresh();
      }
    }
  }

  Future<void> correct(Student student) async {
    final note = TextEditingController(
      text: widget.data.recordFor(student)?.note ?? '',
    );
    var status = widget.data.recordFor(student)?.status ?? 'PRESENT';
    if (!['PRESENT', 'LATE', 'ABSENT'].contains(status)) status = 'PRESENT';
    final result = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  student.fullName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(student.studentCode),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(
                    labelText: 'Attendance status',
                  ),
                  items: ['PRESENT', 'LATE', 'ABSENT']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setSheetState(() => status = v!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: note,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Correction note (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, (status, note.text.trim())),
                  child: const Text('Save attendance'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // The sheet controller is disposed after its exit animation releases the field.
    Future<void>.delayed(const Duration(milliseconds: 400), note.dispose);
    if (result != null && mounted) {
      await mutate(
        () => widget.repo.update(widget.data, student, result.$1, result.$2),
      );
    }
  }

  Future<void> finish() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish attendance?'),
        content: const Text(
          'The session will close and enrolled students without a record will be marked ABSENT. Manual corrections remain available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep open'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await mutate(() => widget.repo.finish(widget.data));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final students = data.roster.where((s) {
      final status =
          data.recordFor(s)?.status ?? (report ? 'ABSENT' : 'UNRECORDED');
      return '${s.fullName} ${s.studentCode}'.toLowerCase().contains(
            search.toLowerCase(),
          ) &&
          (filter == 'All' || status == filter);
    }).toList();
    return RefreshIndicator(
      onRefresh: widget.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: students.length + 1,
        itemBuilder: (context, index) {
          if (index > 0) {
            final student = students[index - 1],
                record = data.recordFor(students[index - 1]);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(student.studentCode),
                    Wrap(
                      spacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusChip(
                          record?.status ?? (report ? 'ABSENT' : 'UNRECORDED'),
                        ),
                        TextButton(
                          onPressed: busy ? null : () => correct(student),
                          child: const Text('Correct attendance'),
                        ),
                      ],
                    ),
                    if (record == null && report)
                      const Text(
                        'No saved record; counted absent in report.',
                        style: TextStyle(fontSize: 12),
                      ),
                    if (record != null && record.note.isNotEmpty)
                      Text(record.note),
                  ],
                ),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${data.session.date} · Slot ${data.session.slot}\n${data.session.startTime}–${data.session.endTime}',
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: StatusChip(data.session.status),
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Attendance')),
                  ButtonSegment(value: true, label: Text('Report')),
                ],
                selected: {report},
                onSelectionChanged: (v) => setState(() {
                  report = v.single;
                  filter = 'All';
                }),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data.count('PRESENT')} / ${data.roster.length} present',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${data.count('LATE')} late · ${report ? data.reportAbsent : data.count('ABSENT')} absent · ${data.unrecorded} unrecorded',
                      ),
                      if (report)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Report absence includes unrecorded roster students, matching the desktop report. Late is counted separately.',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (!report && data.session.isOpen)
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => QrScreen(
                                repo: widget.repo,
                                lecturer: widget.lecturer,
                                cls: widget.cls,
                                sessionId: data.session.sessionId,
                              ),
                            ),
                          );
                          if (mounted) await widget.refresh();
                        },
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Display QR attendance'),
                ),
              if (data.session.isOpen)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: OutlinedButton(
                    onPressed: busy ? null : finish,
                    child: const Text('Finish attendance'),
                  ),
                ),
              if (!data.session.isOpen && data.unrecorded > 0)
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => mutate(() => widget.repo.finish(data)),
                  child: const Text('Finalize missing attendance'),
                ),
              if (busy)
                const LinearProgressIndicator(
                  semanticsLabel: 'Saving attendance',
                ),
              const SizedBox(height: 20),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search student',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => search = v),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: ['All', 'PRESENT', 'ABSENT', 'LATE', 'UNRECORDED']
                    .map(
                      (s) => FilterChip(
                        label: Text(s),
                        selected: filter == s,
                        onSelected: (_) => setState(() => filter = s),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              if (students.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No students match this view.'),
                ),
            ],
          );
        },
      ),
    );
  }
}
