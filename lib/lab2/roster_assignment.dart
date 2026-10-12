import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data_import.dart';
import 'domain.dart';
import 'repository.dart';

class RosterAssignmentPage extends ConsumerStatefulWidget {
  final List<Data> classes;
  const RosterAssignmentPage({super.key, required this.classes});
  @override
  ConsumerState<RosterAssignmentPage> createState() =>
      _RosterAssignmentPageState();
}

class _RosterAssignmentPageState extends ConsumerState<RosterAssignmentPage> {
  Map<String, List<List<String>>> workbook = {};
  String? sheet, classId, error, filename;
  bool busy = false;
  final saved = <String>{};
  Data? get cls => widget.classes.where((c) => c['id'] == classId).firstOrNull;
  ImportPreview? get preview => sheet == null || cls == null
      ? null
      : reviewRosterAssignment(workbook[sheet]!, cls!);
  void suggestClass() {
    if (sheet == null) return;
    final text =
        '${sheet!.toUpperCase()} ${workbook[sheet]!.take(5).expand((r) => r).join(' ').toUpperCase()}';
    final candidates = widget.classes
        .where(
          (c) =>
              text.contains('${c['classCode']}'.toUpperCase()) &&
              text.contains('${c['subjectId']}'.toUpperCase()),
        )
        .toList();
    classId = candidates.length == 1
        ? '${candidates.single['id']}'
        : widget.classes.length == 1
        ? '${widget.classes.single['id']}'
        : null;
  }

  Future<void> pick() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final selected = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv', 'tsv'],
        withData: true,
      );
      if (selected == null) return;
      final file = selected.files.single;
      if (file.bytes == null || file.size > 5 * 1024 * 1024) {
        throw const FormatException('Chọn Excel/CSV tối đa 5 MB.');
      }
      final book = file.extension?.toLowerCase() == 'xlsx'
          ? await compute(decodeRosterWorkbook, file.bytes!)
          : {file.name: parseImportText(utf8.decode(file.bytes!))};
      book.removeWhere((_, rows) => rows.isEmpty);
      if (book.isEmpty) throw const FormatException('File không có dữ liệu.');
      if (!mounted) return;
      setState(() {
        workbook = book;
        filename = file.name;
        sheet = book.keys.first;
        suggestClass();
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is FormatException ? e.message : errorMessage(e),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    final data = preview;
    if (busy ||
        cls == null ||
        data == null ||
        data.errors.isNotEmpty ||
        data.rows.isEmpty) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await ref.read(repositoryProvider).call(
        'importClassStudents',
        {'classId': cls!['id'], 'students': data.rows},
      );
      if (!mounted) return;
      setState(() => saved.add('$sheet|$classId'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã gán lớp ${cls!['classCode']}: ${result['added'] ?? 0} mới, ${result['existing'] ?? 0} đã có. Chọn sheet/lớp tiếp theo nếu cần.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = preview;
    return Scaffold(
      appBar: AppBar(title: const Text('Gán sinh viên từ Excel')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Lịch đã lưu. Chọn file, sheet và lớp tương ứng để nhập danh sách sinh viên.',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: busy ? null : pick,
            icon: const Icon(Icons.upload_file),
            label: const Text('Chọn Excel / CSV sinh viên'),
          ),
          if (filename != null) Text(filename!),
          if (busy) const LinearProgressIndicator(),
          if (workbook.isNotEmpty) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('sheet-$sheet-${workbook.length}'),
              initialValue: sheet,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Sheet trong file'),
              items: [
                for (final name in workbook.keys)
                  DropdownMenuItem(
                    value: name,
                    child: Text(name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                      sheet = v;
                      error = null;
                      suggestClass();
                    }),
            ),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey('class-$classId'),
            initialValue: classId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Lớp nhận sinh viên'),
            items: [
              for (final c in widget.classes)
                DropdownMenuItem(
                  value: '${c['id']}',
                  child: Text(
                    '${c['classCode']} • ${c['subjectId']} • ${c['term']}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: busy
                ? null
                : (v) => setState(() {
                    classId = v;
                    error = null;
                  }),
          ),
          const SizedBox(height: 12),
          const Text(
            'Hỗ trợ bảng markbook có cột Class, RollNumber, FullName, Email và hàng tiêu đề ở giữa sheet. Chỉ nhập hàng thuộc lớp đã chọn; cột điểm không được nhập.',
          ),
          if (data != null) ...[
            const SizedBox(height: 16),
            Text(
              '${data.rows.length} sinh viên của lớp đã chọn',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final e in data.errors)
              Text(
                e,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            for (final row in data.rows.take(10))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${row['studentCode']} • ${row['fullName']}'),
                subtitle: Text('${row['schoolEmail']}'),
              ),
            if (data.rows.length > 10)
              Text('Và ${data.rows.length - 10} sinh viên khác.'),
            if (saved.contains('$sheet|$classId'))
              const Text('Đã nhập sheet này cho lớp đang chọn.'),
          ],
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed:
                busy ||
                    data == null ||
                    data.rows.isEmpty ||
                    data.errors.isNotEmpty
                ? null
                : save,
            child: const Text('Xác nhận gán sinh viên vào lớp'),
          ),
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Hoàn tất / Nhập sinh viên sau'),
          ),
        ],
      ),
    );
  }
}
