import 'package:flutter/material.dart';
import '../../api/repository.dart';
import '../../models/domain.dart';
import 'class_screen.dart';
import 'roster_import_screen.dart';

class ClassesManagementView extends StatefulWidget {
  final LecturerRepository repo;
  final Lecturer lecturer;
  final Overview overview;
  final VoidCallback onRefreshNeeded;

  const ClassesManagementView({
    super.key,
    required this.repo,
    required this.lecturer,
    required this.overview,
    required this.onRefreshNeeded,
  });

  @override
  State<ClassesManagementView> createState() => _ClassesManagementViewState();
}

class _ClassesManagementViewState extends State<ClassesManagementView> {
  String _search = '';
  String _selectedSemester = '';

  @override
  Widget build(BuildContext context) {
    // Collect all class targets from overview
    final map = <String, ClassTarget>{};
    for (final c in widget.overview.classes) {
      map[c.key] = ClassTarget(
        semester: c.semester,
        subjectCode: c.subjectCode,
        classCode: c.classCode,
        subjectName: c.subjectName,
        classId: c.classId,
      );
    }

    for (final s in widget.overview.schedules) {
      if (!map.containsKey(s.key)) {
        map[s.key] = ClassTarget(
          semester: s.semester,
          subjectCode: s.subjectCode,
          classCode: s.classCode,
          subjectName: s.subjectName,
          classId: null,
        );
      }
    }

    final allTargets = map.values.toList()
      ..sort((a, b) => '${a.semester} ${a.subjectCode} ${a.classCode}'
          .compareTo('${b.semester} ${b.subjectCode} ${b.classCode}'));

    final semesters = allTargets.map((t) => t.semester).toSet().toList()..sort();
    final filtered = allTargets.where((t) {
      final matchSem = _selectedSemester.isEmpty || t.semester == _selectedSemester;
      final matchQuery = _search.isEmpty ||
          '${t.subjectCode} ${t.classCode} ${t.subjectName} ${t.semester}'
              .toLowerCase()
              .contains(_search.toLowerCase());
      return matchSem && matchQuery;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Action Bar with Search & Import Button
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Tìm kiếm lớp, môn học',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: () async {
                final imported = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => RosterImportScreen(
                      repo: widget.repo,
                      lecturer: widget.lecturer,
                      defaultSemester: _selectedSemester,
                    ),
                  ),
                );
                if (imported == true) widget.onRefreshNeeded();
              },
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              label: const Text('Nhập SV'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Semester Chips Filter
        if (semesters.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: const Text('Tất cả học kỳ'),
                    selected: _selectedSemester.isEmpty,
                    onSelected: (sel) {
                      if (sel) setState(() => _selectedSemester = '');
                    },
                  ),
                ),
                ...semesters.map((sem) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(sem),
                        selected: _selectedSemester == sem,
                        onSelected: (sel) {
                          setState(() => _selectedSemester = sel ? sem : '');
                        },
                      ),
                    )),
              ],
            ),
          ),

        const SizedBox(height: 12),

        if (filtered.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: Text('Không tìm thấy lớp học nào phù hợp.'),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            itemBuilder: (ctx, idx) {
              final target = filtered[idx];
              final hasClassRecord = target.classId != null && target.classId!.isNotEmpty;
              final matchingSchedules = widget.overview.schedules
                  .where((s) => s.key == target.key)
                  .toList();
              final matchingSessions = widget.overview.sessions
                  .where((s) => s.classId == target.classId)
                  .length;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${target.subjectCode} · ${target.classCode}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                if (target.subjectName.isNotEmpty &&
                                    target.subjectName != target.subjectCode)
                                  Text(
                                    target.subjectName,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: hasClassRecord
                                  ? Colors.green.shade50
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: hasClassRecord
                                    ? Colors.green.shade600
                                    : Colors.orange.shade600,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hasClassRecord ? Icons.check_circle : Icons.warning_amber,
                                  size: 14,
                                  color: hasClassRecord
                                      ? Colors.green.shade800
                                      : Colors.orange.shade800,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  hasClassRecord ? 'Đã có Roster' : 'Cần nhập SV',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: hasClassRecord
                                        ? Colors.green.shade800
                                        : Colors.orange.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Học kỳ: ${target.semester} · ${matchingSchedules.length} slot học hàng tuần · $matchingSessions buổi điểm danh',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              final imported = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => RosterImportScreen(
                                    repo: widget.repo,
                                    lecturer: widget.lecturer,
                                    preselectedTarget: target,
                                    defaultSemester: target.semester,
                                  ),
                                ),
                              );
                              if (imported == true) widget.onRefreshNeeded();
                            },
                            icon: const Icon(Icons.file_upload_outlined, size: 16),
                            label: const Text('Nhập file'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () async {
                              final teachingClass = widget.overview.classes
                                  .where((c) => c.key == target.key)
                                  .firstOrNull;

                              if (teachingClass != null) {
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ClassScreen(
                                      repo: widget.repo,
                                      lecturer: widget.lecturer,
                                      cls: teachingClass,
                                    ),
                                  ),
                                );
                                widget.onRefreshNeeded();
                              } else {
                                // Prompt to import roster first
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Lớp chưa được đồng bộ danh sách SV. Vui lòng bấm "Nhập file" để gán sinh viên vào lớp.',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.chevron_right, size: 18),
                            label: const Text('Chi tiết'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
