import 'dart:math';
import 'package:flutter/material.dart';
import 'domain.dart';
import 'widgets.dart';

/// A frozen preview. Server revision checking prevents overwriting new QR scans.
class BulkAttendanceSheet extends StatefulWidget {
  final List<Data> students;
  final String contextLabel;
  final Future<Data> Function(Data) onSave;
  const BulkAttendanceSheet({
    super.key,
    required this.students,
    required this.contextLabel,
    required this.onSave,
  });
  @override
  State<BulkAttendanceSheet> createState() => _BulkAttendanceSheetState();
}

class _BulkAttendanceSheetState extends State<BulkAttendanceSheet> {
  late final rows = widget.students
      .where((s) => s['status'] == 'pending')
      .toList();
  late final statuses = {for (final r in rows) '${r['studentUid']}': 'present'};
  final reason = TextEditingController();
  final requestId = List.generate(
    24,
    (_) => Random.secure().nextInt(16).toRadixString(16),
  ).join();
  bool preview = false, busy = false, failed = false;
  Object? error;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || failed || !preview) return;
    setState(() => busy = true);
    try {
      await widget.onSave({
        'requestId': requestId,
        'notes': reason.text.trim(),
        'changes': [
          for (final r in rows)
            {
              'studentUid': r['studentUid'],
              'status': statuses[r['studentUid']],
            },
        ],
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          failed = true;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = {
      for (final s in ['present', 'late', 'absent', 'excused'])
        s: statuses.values.where((v) => v == s).length,
    };
    if (failed) {
      final original = mutationErrorMessage(error!);
      final message = original.startsWith('Chưa xác nhận')
          ? 'Chưa xác nhận được kết quả lưu. Kiểm tra danh sách trước khi thao tác tiếp.'
          : original;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Kiểm tra kết quả lưu',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(widget.contextLabel),
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          message,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('Lý do: ${reason.text.trim()}'),
                      const Text('Nội dung vừa gửi'),
                      for (final r in rows)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            '${r['displayName']} · ${r['studentCode']} · ${StatusBadge.label(statuses[r['studentUid']]!)}',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy ? null : () => Navigator.pop(context, false),
                child: const Text('Kiểm tra danh sách'),
              ),
            ],
          ),
        ),
      );
    }
    return PopScope(
      canPop: !busy,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  preview ? 'Kiểm tra trước khi lưu' : 'Điểm danh nhanh',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(widget.contextLabel),
                const SizedBox(height: 8),
                Text(
                  '${rows.length} sinh viên còn chờ · Giữ các kết quả đã ghi nhận',
                ),
                const Text(
                  'Áp dụng cho cả nhóm chưa điểm danh. Chọn lại người vắng hoặc đi trễ.',
                ),
                if (preview)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        for (final e in counts.entries)
                          Text('${StatusBadge.label(e.key)}: ${e.value}'),
                      ],
                    ),
                  ),
                if (preview)
                  Text(
                    '${widget.students.length - rows.length} kết quả đã có được giữ nguyên',
                  ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final r = rows[i], id = '${r['studentUid']}';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('${r['displayName']} · ${r['studentCode']}'),
                            if (preview)
                              Text(StatusBadge.label(statuses[id]!))
                            else
                              DropdownButtonFormField<String>(
                                key: ValueKey(id),
                                initialValue: statuses[id],
                                isExpanded: true,
                                items: [
                                  for (final s in counts.keys)
                                    DropdownMenuItem(
                                      value: s,
                                      child: Text(StatusBadge.label(s)),
                                    ),
                                ],
                                onChanged: busy
                                    ? null
                                    : (v) => setState(() => statuses[id] = v!),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (rows.length > 3)
                  Text(
                    'Cuộn danh sách để kiểm tra đủ ${rows.length} sinh viên',
                  ),
                const SizedBox(height: 8),
                if (!preview)
                  TextField(
                    controller: reason,
                    maxLength: 500,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Lý do xác nhận',
                      hintText: 'Ví dụ: Đã đối chiếu danh sách tại lớp',
                    ),
                  )
                else
                  Text('Lý do: ${reason.text.trim()}'),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: busy || failed || rows.isEmpty
                      ? null
                      : () {
                          if (preview) {
                            save();
                          } else if (reason.text.trim().isNotEmpty) {
                            FocusManager.instance.primaryFocus?.unfocus();
                            setState(() => preview = true);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Nhập lý do xác nhận'),
                              ),
                            );
                          }
                        },
                  child: Text(
                    busy
                        ? 'Đang lưu…'
                        : preview
                        ? 'Xác nhận ${rows.length} sinh viên'
                        : 'Xem trước',
                  ),
                ),
                if (preview && !failed)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() => preview = false),
                    child: const Text('Chỉnh lại'),
                  ),
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(context, false),
                  child: const Text('Đóng'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
