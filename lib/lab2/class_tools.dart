import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain.dart';
import 'repository.dart';
import 'widgets.dart';

/// Edits are validated again by the shared backend and never change MSSV.
class ClassToolsPage extends ConsumerWidget {
  final Data cls;
  const ClassToolsPage({super.key, required this.cls});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Công cụ lớp học')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Ngoại lệ theo ngày giữ nguyên lịch định kỳ. Buổi đã có phiên điểm danh không thể đổi lịch.',
          ),
          LiveList(
            source: () => repo.watch('schedules'),
            buildEmpty: true,
            builder: (rows) => Column(
              children: [
                for (final s in rows.where((s) => s['classId'] == cls['id']))
                  ListTile(
                    title: Text(
                      '${s['dayOfWeek'] == 7 ? 'Chủ nhật' : 'Thứ ${(s['dayOfWeek'] as num) + 1}'} • Slot ${s['slot']}',
                    ),
                    subtitle: Text(
                      '${s['startTime']} – ${s['endTime']} • ${s['room']}',
                    ),
                    trailing: const Icon(Icons.edit_calendar),
                    onTap: () => showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => ClassToolDialog(cls: cls, schedule: s),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(),
          const Text(
            'Sửa tên / email sinh viên cần lý do. Hồ sơ dùng chung với giảng viên khác cần quản trị viên xử lý.',
          ),
          LiveList(
            source: () => repo
                .memberStream('${cls['id']}')
                .map(
                  (m) => [
                    for (final e in m.entries) {...e.value, 'id': e.key},
                  ],
                ),
            empty: 'Chưa có sinh viên.',
            builder: (members) => Column(
              children: [
                for (final student in members)
                  ListTile(
                    title: Text(
                      '${student['displayName'] ?? student['fullName'] ?? student['name'] ?? ''}',
                    ),
                    subtitle: Text(
                      '${student['studentCode'] ?? ''} • ${student['schoolEmail'] ?? ''}',
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) =>
                          ClassToolDialog(cls: cls, student: student),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ClassToolDialog extends ConsumerStatefulWidget {
  final Data cls;
  final Data? schedule, student;
  const ClassToolDialog({
    super.key,
    required this.cls,
    this.schedule,
    this.student,
  });
  @override
  ConsumerState<ClassToolDialog> createState() => _ClassToolDialogState();
}

class _ClassToolDialogState extends ConsumerState<ClassToolDialog> {
  final form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> fields;
  String kind = 'CANCELLED';
  bool busy = false;
  bool dirty = false;
  static const kinds = {
    'CANCELLED': 'Hủy buổi',
    'RESCHEDULED': 'Dời buổi',
    'MAKEUP': 'Buổi bù',
    'ROOM_CHANGED': 'Đổi phòng',
    'RESTORED': 'Khôi phục lịch gốc',
  };
  Object? error;
  @override
  void initState() {
    super.initState();
    final s = widget.schedule, student = widget.student;
    fields = {
      for (final e in <String, String>{
        if (s != null) ...{
          'date': '',
          'targetDate': '',
          'slot': '${s['slot']}',
          'startTime': '${s['startTime']}',
          'endTime': '${s['endTime']}',
          'room': '${s['room'] ?? ''}',
        },
        if (student != null) ...{
          'fullName':
              '${student['displayName'] ?? student['fullName'] ?? student['name'] ?? ''}',
          'schoolEmail': '${student['schoolEmail'] ?? ''}',
        },
        'reason': '',
      }.entries)
        e.key: TextEditingController(text: e.value),
    };
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (busy) return;
    if (!form.currentState!.validate()) return;
    final description = widget.student != null
        ? 'Họ tên: ${widget.student!['displayName'] ?? widget.student!['fullName'] ?? ''} → ${fields['fullName']!.text.trim()}\nEmail: ${widget.student!['schoolEmail'] ?? ''} → ${fields['schoolEmail']!.text.trim()}'
        : 'Lớp ${widget.cls['classCode'] ?? widget.cls['id']} • ${kinds[kind]} • ngày ${fields['date']!.text.trim()}';
    if (!await campusConfirm(
          context,
          title: 'Xác nhận thay đổi?',
          message: '$description\nLý do: ${fields['reason']!.text.trim()}',
          confirm: 'Xác nhận thay đổi',
          destructive: widget.schedule != null && kind == 'CANCELLED',
        ) ||
        !mounted) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(repositoryProvider).call(
        widget.schedule != null
            ? 'saveScheduleException'
            : 'updateClassStudent',
        {
          'classId': widget.cls['id'],
          if (widget.schedule != null) ...{
            'scheduleId': widget.schedule!['id'],
            'kind': kind,
          },
          if (widget.student != null) 'studentUid': widget.student!['id'],
          for (final e in fields.entries) e.key: e.value.text.trim(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã lưu thay đổi.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CampusDraftGuard(
    dirty: dirty,
    busy: busy,
    child: AlertDialog(
      title: Text(
        widget.schedule != null
            ? 'Ngoại lệ lịch theo ngày'
            : 'Sửa thông tin sinh viên',
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.schedule != null)
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: kind,
                    decoration: const InputDecoration(
                      labelText: 'Thao tác với buổi học',
                    ),
                    items:
                        const {
                              'CANCELLED': 'Hủy buổi',
                              'RESCHEDULED': 'Dời buổi',
                              'MAKEUP': 'Thêm buổi bù',
                              'ROOM_CHANGED': 'Đổi phòng',
                              'RESTORED': 'Khôi phục lịch gốc',
                            }.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                            kind = v!;
                            dirty = true;
                          }),
                  ),
                for (final e in fields.entries)
                  if (e.key != 'targetDate' ||
                      ['RESCHEDULED', 'MAKEUP'].contains(kind))
                    TextFormField(
                      controller: e.value,
                      enabled: !busy,
                      onChanged: (_) => setState(() => dirty = true),
                      decoration: InputDecoration(
                        labelText: const {
                          'date': 'Ngày gốc (YYYY-MM-DD)',
                          'targetDate': 'Ngày mới (YYYY-MM-DD)',
                          'slot': 'Slot',
                          'startTime': 'Bắt đầu (HH:mm)',
                          'endTime': 'Kết thúc (HH:mm)',
                          'room': 'Phòng',
                          'fullName': 'Họ tên',
                          'schoolEmail': 'Email trường',
                          'reason': 'Lý do bắt buộc',
                        }[e.key],
                      ),
                      validator: (v) =>
                          !['room', 'schoolEmail'].contains(e.key) &&
                              (v ?? '').trim().isEmpty
                          ? 'Vui lòng nhập thông tin'
                          : null,
                    ),
                if (error != null)
                  Text(
                    mutationErrorMessage(error!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.maybePop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? 'Đang lưu…' : 'Xác nhận lưu'),
        ),
      ],
    ),
  );
}
