import 'package:flutter/material.dart';
import '../../api/repository.dart';
import '../../models/domain.dart';
import '../sessions/session_screen.dart';
import 'fap_portal_screen.dart';
import 'manual_schedule_sheet.dart';
import 'ocr_scan_screen.dart';

class ScheduleScreen extends StatefulWidget {
  final LecturerRepository repo;
  final Lecturer lecturer;
  final Overview overview;
  final String selectedSemester;
  final VoidCallback onRefreshNeeded;

  const ScheduleScreen({
    super.key,
    required this.repo,
    required this.lecturer,
    required this.overview,
    required this.selectedSemester,
    required this.onRefreshNeeded,
  });

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late int _selectedDayOfWeek;

  @override
  void initState() {
    super.initState();
    final nowWeekday = CampusClock.now().weekday;
    _selectedDayOfWeek = nowWeekday.clamp(1, 7);
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Thêm thời khóa biểu',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_note, color: Colors.deepOrange),
                ),
                title: const Text('Nhập thủ công', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Điền mã môn, lớp, slot và phòng học'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final added = await ManualScheduleSheet.show(
                    context,
                    repo: widget.repo,
                    lecturer: widget.lecturer,
                    defaultSemester: widget.selectedSemester,
                  );
                  if (added == true) widget.onRefreshNeeded();
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.document_scanner, color: Colors.teal),
                ),
                title: const Text('Quét ảnh lịch (OCR On-Device)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Chụp từ camera hoặc ảnh màn hình lịch FAP'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final added = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => OcrScanScreen(
                        repo: widget.repo,
                        lecturer: widget.lecturer,
                        semester: widget.selectedSemester,
                      ),
                    ),
                  );
                  if (added == true) widget.onRefreshNeeded();
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.language, color: Colors.blue),
                ),
                title: const Text('Nhập trực tiếp từ FAP Web',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Đăng nhập và trích xuất tự động qua WebView'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final added = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => FapPortalScreen(
                        repo: widget.repo,
                        lecturer: widget.lecturer,
                        semester: widget.selectedSemester,
                      ),
                    ),
                  );
                  if (added == true) widget.onRefreshNeeded();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Schedule s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa lịch dạy'),
        content: Text(
          'Bạn có chắc chắn muốn xóa buổi học ${s.subjectCode} - Lớp ${s.classCode} vào Slot ${s.slot} không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.repo.deleteSchedule(s.scheduleId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xóa buổi học ${s.subjectCode} - ${s.classCode}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          widget.onRefreshNeeded();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không thể xóa: ${e.toString().replaceAll("AppFailure: ", "")}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = CampusClock.now();
    final todayWeekday = now.weekday;

    // Filter schedules for the selected semester and selected day of week
    final schedulesForDay = widget.overview.schedules
        .where((s) =>
            (widget.selectedSemester.isEmpty || s.semester == widget.selectedSemester) &&
            s.dayOfWeek == _selectedDayOfWeek)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final dayLabels = [
      (1, 'Thứ 2', 'T2'),
      (2, 'Thứ 3', 'T3'),
      (3, 'Thứ 4', 'T4'),
      (4, 'Thứ 5', 'T5'),
      (5, 'Thứ 6', 'T6'),
      (6, 'Thứ 7', 'T7'),
      (7, 'Chủ Nhật', 'CN'),
    ];

    // Compute target date string for the selected day in current week
    final mondayOffset = todayWeekday - 1;
    final mondayDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: mondayOffset));
    final targetDate = mondayDate.add(Duration(days: _selectedDayOfWeek - 1));
    final targetDateStr = CampusClock.date(targetDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Weekly Strip View Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: dayLabels.map((d) {
                final isSelected = _selectedDayOfWeek == d.$1;
                final isToday = todayWeekday == d.$1;
                final count = widget.overview.schedules
                    .where((s) =>
                        (widget.selectedSemester.isEmpty || s.semester == widget.selectedSemester) &&
                        s.dayOfWeek == d.$1)
                    .length;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () => setState(() => _selectedDayOfWeek = d.$1),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : (isToday
                                ? Theme.of(context).colorScheme.primaryContainer.withAlpha(100)
                                : Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(70)),
                        borderRadius: BorderRadius.circular(16),
                        border: isToday && !isSelected
                            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5)
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            d.$3,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withAlpha(50)
                                  : Theme.of(context).colorScheme.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Action Toolbar: Semester info & Add Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lịch dạy: ${dayLabels.firstWhere((d) => d.$1 == _selectedDayOfWeek).$2} · $targetDateStr',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _showAddOptions(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Thêm lịch'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        if (schedulesForDay.isEmpty)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.event_available, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('Không có buổi dạy nào trong ngày này.'),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _showAddOptions(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm thời khóa biểu ngay'),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: schedulesForDay.length,
            itemBuilder: (ctx, idx) {
              final schedule = schedulesForDay[idx];
              return _buildScheduleCard(schedule, targetDateStr);
            },
          ),
      ],
    );
  }

  Widget _buildScheduleCard(Schedule schedule, String dateStr) {
    final cls = widget.overview.mappedClass(schedule);
    final sessions = widget.overview.sessions
        .where((s) => s.classId == cls?.classId && s.date == dateStr && s.slot == schedule.slot)
        .toList();

    final isCurrent = CampusClock.current(dateStr, schedule.startTime, schedule.endTime);
    final now = CampusClock.now();
    final startMin = CampusClock.minutes(schedule.startTime) ?? 0;
    final nowMin = now.hour * 60 + now.minute;
    final isUpcoming = dateStr == CampusClock.date(now) && startMin > nowMin && (startMin - nowMin) <= 120;

    return Dismissible(
      key: Key(schedule.scheduleId),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          await _confirmDelete(schedule);
          return false;
        } else {
          // Edit
          final updated = await ManualScheduleSheet.show(
            context,
            repo: widget.repo,
            lecturer: widget.lecturer,
            defaultSemester: widget.selectedSemester,
            initialSchedule: schedule,
          );
          if (updated == true) widget.onRefreshNeeded();
          return false;
        }
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: Colors.blue.shade600,
        child: const Row(
          children: [
            Icon(Icons.edit, color: Colors.white),
            SizedBox(width: 8),
            Text('Chỉnh sửa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade600,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Xóa lịch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.delete_outline, color: Colors.white),
          ],
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 14),
        elevation: isCurrent ? 2 : 1,
        color: isCurrent
            ? Theme.of(context).colorScheme.primaryContainer
            : (isUpcoming ? Colors.amber.shade50 : null),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: isCurrent
              ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Slot & Status Badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Slot ${schedule.slot}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isCurrent ? Colors.white : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'ĐANG DIỄN RA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else if (isUpcoming)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade800,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'SẮP DIỄN RA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    '${schedule.startTime} – ${schedule.endTime}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${schedule.subjectCode} · ${schedule.classCode}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (schedule.subjectName.isNotEmpty && schedule.subjectName != schedule.subjectCode)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    schedule.subjectName,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.room_outlined, size: 18),
                  const SizedBox(width: 4),
                  Text('Phòng: ${schedule.room}'),
                  const SizedBox(width: 14),
                  Icon(
                    schedule.sourceType == 'IMAGE' ? Icons.camera_alt_outlined : Icons.edit_note,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    schedule.sourceType == 'IMAGE' ? 'OCR' : 'Manual',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: sessions.length == 1
                        ? FilledButton.icon(
                            onPressed: cls == null
                                ? null
                                : () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => SessionScreen(
                                          repo: widget.repo,
                                          lecturer: widget.lecturer,
                                          cls: cls,
                                          sessionId: sessions.single.sessionId,
                                        ),
                                      ),
                                    );
                                    widget.onRefreshNeeded();
                                  },
                            icon: const Icon(Icons.qr_code_2),
                            label: Text('Mở điểm danh (${sessions.single.status})'),
                          )
                        : FilledButton.icon(
                            onPressed: cls == null
                                ? null
                                : () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => StartSessionScreen(
                                          repo: widget.repo,
                                          lecturer: widget.lecturer,
                                          cls: cls,
                                          schedule: schedule,
                                          date: dateStr,
                                        ),
                                      ),
                                    );
                                    widget.onRefreshNeeded();
                                  },
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Bắt đầu điểm danh'),
                          ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'Chỉnh sửa',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      final updated = await ManualScheduleSheet.show(
                        context,
                        repo: widget.repo,
                        lecturer: widget.lecturer,
                        defaultSemester: widget.selectedSemester,
                        initialSchedule: schedule,
                      );
                      if (updated == true) widget.onRefreshNeeded();
                    },
                  ),
                  IconButton.outlined(
                    tooltip: 'Xóa lịch',
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _confirmDelete(schedule),
                  ),
                ],
              ),
              if (cls == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Lớp chưa được gán sinh viên. Hãy import danh sách lớp trong mục "Classes".',
                    style: TextStyle(color: Colors.orange.shade900, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
