import 'dart:typed_data';
import 'package:excel/excel.dart' hide Data;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'domain.dart';
import 'repository.dart';
import 'timetable_domain.dart';
import 'widgets.dart';
import 'lecturer_workspace_store.dart';

bool inReportWeek(DateTime date, DateTime start) {
  final day = campusDay(date);
  return !day.isBefore(start) &&
      day.isBefore(start.add(const Duration(days: 7)));
}

List<Data> weeklySessions(
  UserProfile user,
  List<Data> classes,
  List<Data> sessions,
  DateTime start,
) {
  final assigned = {for (final c in classes) '${c['id']}': c};
  return [
    for (final s in sessions)
      if (assigned.containsKey('${s['classId']}') &&
          s['lecturerUid'] == user.uid &&
          s['status'] != 'reset' &&
          s['startsAt'] != null &&
          inReportWeek(dateValue(s['startsAt']), start))
        {
          ...s,
          'classCode': assigned['${s['classId']}']!['classCode'],
          'term': assigned['${s['classId']}']!['term'],
          'subjectId': assigned['${s['classId']}']!['subjectId'],
        },
  ]..sort(
    (a, b) => dateValue(a['startsAt']).compareTo(dateValue(b['startsAt'])),
  );
}

Uint8List weeklyWorkbook({
  required UserProfile user,
  required DateTime start,
  required DateTime capturedAt,
  required List<Data> sessions,
  required WorkspaceData local,
}) {
  final book = Excel.createExcel();
  book.rename('Sheet1', 'Thông tin');
  void row(String sheet, List<Object?> values) => book[sheet].appendRow(
    values
        .map((v) => TextCellValue(v == null ? 'Chưa có dữ liệu' : '$v'))
        .toList(),
  );
  row('Thông tin', [
    'Tổng kết tuần',
    start.toIso8601String().substring(0, 10),
    start.add(const Duration(days: 6)).toIso8601String().substring(0, 10),
  ]);
  row('Thông tin', ['Giảng viên', user.name, user.lecturerId]);
  row('Thông tin', [
    'Lấy snapshot lúc (UTC)',
    capturedAt.toUtc().toIso8601String(),
  ]);
  row('Thông tin', [
    'Nguồn',
    'classSessions thuộc lớp được phân công; việc và sổ tay trên thiết bị này. Snapshot có thể chưa là dữ liệu mới nhất.',
  ]);
  row('Thông tin', [
    'Giới hạn',
    'Đã chốt là trạng thái phiên điểm danh, không chứng minh số giờ đã dạy. Không có phiên không có nghĩa bỏ dạy. Không thống kê số buổi chưa có phiên vì chưa xác nhận khoảng ngày học kỳ.',
  ]);
  row('Thông tin', [
    'Đồng bộ cá nhân',
    'Chỉ lưu trên máy; chưa đồng bộ backend. Nội dung sổ tay riêng không được xuất mặc định.',
  ]);
  row('Phiên điểm danh', [
    'Mã phiên nguồn',
    'Mã lớp nguồn',
    'Lớp',
    'Môn',
    'Học kỳ',
    'Bắt đầu (UTC)',
    'Slot',
    'Trạng thái',
  ]);
  for (final s in sessions) {
    row('Phiên điểm danh', [
      s['id'],
      s['classId'],
      s['classCode'],
      s['subjectId'],
      s['term'],
      dateValue(s['startsAt']).toUtc().toIso8601String(),
      s['slot'],
      s['status'],
    ]);
  }
  row('Việc trong tuần', [
    'Mã việc',
    'Việc',
    'Hạn (UTC)',
    'Trạng thái',
    'Liên kết buổi',
  ]);
  row('Việc còn lại', ['Mã việc', 'Việc', 'Hạn (UTC)', 'Liên kết buổi']);
  for (final t in local.tasks) {
    final due = DateTime.tryParse('${t['due']}');
    if (due != null && inReportWeek(due, start)) {
      row('Việc trong tuần', [
        t['id'],
        t['title'],
        t['due'],
        t['done'] == true ? 'Đã xong' : 'Chưa xong',
        t['label'],
      ]);
    }
    if (t['done'] != true) {
      row('Việc còn lại', [t['id'], t['title'], t['due'], t['label']]);
    }
  }
  return Uint8List.fromList(book.encode()!);
}

class LecturerWeeklyReportPage extends ConsumerStatefulWidget {
  final UserProfile user;
  const LecturerWeeklyReportPage({super.key, required this.user});
  @override
  ConsumerState<LecturerWeeklyReportPage> createState() => _WeeklyReportState();
}

class _WeeklyReportState extends ConsumerState<LecturerWeeklyReportPage> {
  DateTime start = weekStart(campusDay(DateTime.now()));
  DateTime? capturedAt;
  List<Data>? sessions;
  WorkspaceData? local;
  Object? error;
  bool exporting = false;
  int request = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final ticket = ++request;
    setState(() {
      sessions = null;
      error = null;
    });
    try {
      final repo = ref.read(repositoryProvider);
      final results = await Future.wait<dynamic>([
        repo.classes(widget.user).first.timeout(const Duration(seconds: 30)),
        repo.watch('classSessions').first.timeout(const Duration(seconds: 30)),
        ref.read(workspaceStoreProvider(widget.user.uid)).read(),
      ]);
      if (!mounted || ticket != request) return;
      setState(() {
        sessions = weeklySessions(
          widget.user,
          results[0] as List<Data>,
          results[1] as List<Data>,
          start,
        );
        local = results[2] as WorkspaceData;
        capturedAt = DateTime.now().toUtc();
      });
    } catch (e) {
      if (mounted && ticket == request) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tổng kết tuần')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextButton.icon(
          icon: const Icon(Icons.date_range),
          label: Text(
            'Tuần ${timetableDate(start)} – ${timetableDate(start.add(const Duration(days: 6)))} / ${start.year}',
          ),
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: start,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (date != null && mounted) {
              start = weekStart(DateTime.utc(date.year, date.month, date.day));
              await load();
            }
          },
        ),
        const Text(
          'Snapshot phiên điểm danh thuộc lớp được phân công. Không có phiên không có nghĩa giảng viên bỏ dạy. Chưa tính số buổi chưa có phiên vì thiếu khoảng ngày học kỳ đã xác nhận.',
        ),
        if (error != null)
          ErrorState(error!, load)
        else if (sessions == null)
          const Center(child: CircularProgressIndicator())
        else ...[
          const SizedBox(height: 16),
          Text(
            '${sessions!.length} phiên có dữ liệu • ${sessions!.where((s) => s['status'] == 'completed').length} đã chốt',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text(
            'Trạng thái chốt điểm danh không phải xác nhận giờ giảng thực tế.',
          ),
          for (final s in sessions!)
            ListTile(
              title: Text('${s['subjectId']} · ${s['classCode']}'),
              subtitle: Text(
                '${s['term']} · ${s['startsAt']}\nPhiên ${s['id']} · ${s['status']}',
              ),
            ),
          Text(
            '${local!.tasks.where((t) => t['done'] != true).length} việc cá nhân chưa xong (mọi hạn)',
          ),
          const Text(
            'Excel có việc trong tuần và việc còn lại. Nội dung sổ tay riêng không được xuất. Dữ liệu cá nhân chỉ từ máy này.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.ios_share),
            label: Text(exporting ? 'Đang xuất…' : 'Xuất Excel (.xlsx)'),
            onPressed: exporting
                ? null
                : () async {
                    setState(() => exporting = true);
                    await runAction(context, () async {
                      final bytes = weeklyWorkbook(
                        user: widget.user,
                        start: start,
                        capturedAt: capturedAt!,
                        sessions: sessions!,
                        local: local!,
                      );
                      await SharePlus.instance.share(
                        ShareParams(
                          files: [
                            XFile.fromData(
                              bytes,
                              mimeType:
                                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                            ),
                          ],
                          fileNameOverrides: [
                            'lecturer-week-${start.toIso8601String().substring(0, 10)}.xlsx',
                          ],
                        ),
                      );
                    });
                    if (mounted) setState(() => exporting = false);
                  },
          ),
          TextButton(onPressed: load, child: const Text('Đọc lại snapshot')),
        ],
      ],
    ),
  );
}
