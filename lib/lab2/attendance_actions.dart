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
  String? studentName,
  studentCode,
  contextLabel,
}) async {
  final input = await showDialog<Data>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AttendanceEditDialog(
      status: status,
      notes: notes,
      studentName: studentName,
      studentCode: studentCode,
      contextLabel: contextLabel,
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
  final String? studentName, studentCode, contextLabel;
  final Future<Data> Function(Data)? onSave;
  const AttendanceEditDialog({
    super.key,
    required this.status,
    this.notes = '',
    this.studentName,
    this.studentCode,
    this.contextLabel,
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
      title: const Text('Sửa điểm danh'),
      content: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.studentName != null || widget.studentCode != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.studentName ?? 'Sinh viên',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (widget.studentCode != null) Text(widget.studentCode!),
                      if (widget.contextLabel != null)
                        Text(
                          widget.contextLabel!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ),
                const Divider(),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Trạng thái',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in [
                      'present',
                      'late',
                      'absent',
                      'excused',
                    ])
                      ChoiceChip(
                        label: Text(StatusBadge.label(option)),
                        selected: status == option,
                        onSelected: busy
                            ? null
                            : (_) => setState(() => status = option),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: notes,
                enabled: !busy,
                onChanged: (_) => setState(() {}),
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                scrollPadding: const EdgeInsets.all(24),
                decoration: const InputDecoration(labelText: 'Lý do / ghi chú'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Nhập lý do điều chỉnh.'
                    : null,
              ),
              const Text('Lưu kèm lý do và người sửa.'),
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
