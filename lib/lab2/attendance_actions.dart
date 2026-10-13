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
    barrierDismissible: false,
    builder: (_) => AttendanceEditDialog(
      status: status,
      notes: notes,
      onSave: (input) => ref.read(repositoryProvider).call(
        'updateAttendanceRecord',
        {'attendanceSessionId': sessionId, 'studentUid': studentUid, ...input},
      ),
    ),
  );
  if (input == null || !context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Đã cập nhật điểm danh.')));
}

class AttendanceEditDialog extends StatefulWidget {
  final String status, notes;
  final Future<Data> Function(Data)? onSave;
  const AttendanceEditDialog({
    super.key,
    required this.status,
    this.notes = '',
    this.onSave,
  });
  @override
  State<AttendanceEditDialog> createState() => _AttendanceEditDialogState();
}

class _AttendanceEditDialogState extends State<AttendanceEditDialog> {
  final form = GlobalKey<FormState>();
  late String status = attendanceStatus(widget.status) == 'pending'
      ? 'present'
      : attendanceStatus(widget.status);
  late final initialStatus = status;
  late final notes = TextEditingController(text: widget.notes);
  bool busy = false, saved = false;
  Object? error;
  bool get dirty => status != initialStatus || notes.text != widget.notes;
  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    final input = <String, dynamic>{
      'status': status,
      'notes': notes.text.trim(),
    };
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onSave?.call(input);
      if (!mounted) return;
      setState(() {
        saved = true;
        busy = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, input);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CampusDraftGuard(
    dirty: !saved && dirty,
    busy: busy,
    child: AlertDialog(
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
                onChanged: busy ? null : (v) => setState(() => status = v!),
              ),
              TextFormField(
                controller: notes,
                enabled: !busy,
                onChanged: (_) => setState(() {}),
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Lý do / ghi chú'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Nhập lý do điều chỉnh.'
                    : null,
              ),
              const Text('Thay đổi được lưu kèm lý do và người điều chỉnh.'),
              if (error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    '${mutationErrorMessage(error!)}\nNội dung nhập vẫn được giữ.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
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
          child: Text(busy ? 'Đang lưu…' : 'Lưu'),
        ),
      ],
    ),
  );
}
