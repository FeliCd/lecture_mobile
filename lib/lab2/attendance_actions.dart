import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain.dart';
import 'repository.dart';
import 'widgets.dart';

Future<void> editAttendance(
  BuildContext context,
  WidgetRef ref, {
  required String sessionId,
  required String studentUid,
  String status = 'present',
  String notes = '',
}) async {
  final input = await showDialog<Data>(
    context: context,
    builder: (_) => AttendanceEditDialog(status: status, notes: notes),
  );
  if (input == null || !context.mounted) return;
  await runAction(context, () async {
    await ref.read(repositoryProvider).call('updateAttendanceRecord', {
      'attendanceSessionId': sessionId,
      'studentUid': studentUid,
      ...input,
    });
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật điểm danh.')));
    }
  });
}

class AttendanceEditDialog extends StatefulWidget {
  final String status, notes;
  const AttendanceEditDialog({
    super.key,
    required this.status,
    this.notes = '',
  });
  @override
  State<AttendanceEditDialog> createState() => _AttendanceEditDialogState();
}

class _AttendanceEditDialogState extends State<AttendanceEditDialog> {
  final form = GlobalKey<FormState>();
  late String status = attendanceStatus(widget.status) == 'pending'
      ? 'present'
      : attendanceStatus(widget.status);
  late final notes = TextEditingController(text: widget.notes);
  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Cập nhật điểm danh'),
    content: Form(
      key: form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Trạng thái'),
              items: ['present', 'late', 'absent', 'excused']
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(StatusBadge.label(s)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => status = v!,
            ),
            TextFormField(
              controller: notes,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Lý do / ghi chú'),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Nhập lý do điều chỉnh.'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, {
              'status': status,
              'notes': notes.text.trim(),
            });
          }
        },
        child: const Text('Lưu'),
      ),
    ],
  );
}
