import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data_import.dart';
import 'domain.dart';
import 'mobile_ocr.dart';
import 'repository.dart';
import 'roster_assignment.dart';
import 'schedule_parser.dart';
import 'widgets.dart';

class OcrImportPage extends ConsumerStatefulWidget {
  const OcrImportPage({super.key});
  @override
  ConsumerState<OcrImportPage> createState() => _OcrImportPageState();
}

class _OcrImportPageState extends ConsumerState<OcrImportPage> {
  final raw = TextEditingController(), semester = TextEditingController();
  final rows = <Map<String, TextEditingController>>[];
  final warnings = <List<String>>[];
  String? imagePath, error;
  bool busy = false, useNvhTimes = true, confirmed = false;
  static const labels = {
    'subjectCode': 'Mã môn',
    'subjectName': 'Tên môn',
    'classCode': 'Mã lớp',
    'dayOfWeek': 'Thứ (1=Hai, 7=CN)',
    'slot': 'Slot',
    'startTime': 'Bắt đầu (HH:mm)',
    'endTime': 'Kết thúc (HH:mm)',
    'room': 'Phòng',
  };
  void clearRows() {
    for (final row in rows) {
      for (final c in row.values) {
        c.dispose();
      }
    }
    rows.clear();
    warnings.clear();
  }

  @override
  void dispose() {
    raw.dispose();
    semester.dispose();
    clearRows();
    super.dispose();
  }

  bool validTerm() {
    if (semester.text.trim().isEmpty || semester.text.trim().length > 100) {
      setState(() => error = 'Nhập học kỳ trước khi phân tích ảnh.');
      return false;
    }
    return true;
  }

  void addRow(Map<String, String> values, [List<String> notes = const []]) {
    rows.add({
      for (final key in labels.keys)
        key: TextEditingController(text: values[key] ?? ''),
    });
    warnings.add(notes.where((n) => !n.startsWith('Cần bổ sung:')).toList());
  }

  void parse() {
    if (!validTerm()) return;
    final drafts = ScheduleParser().parse(raw.text, useNvhTimes: useNvhTimes);
    if (drafts.length > 100) {
      setState(
        () => error = 'Ảnh có hơn 100 dòng lịch. Hãy chia ảnh trước khi nhập.',
      );
      return;
    }
    setState(() {
      clearRows();
      for (final draft in drafts) {
        addRow(draft.fields, draft.warnings);
      }
      confirmed = false;
      error = rows.isEmpty
          ? 'Chưa nhận diện được lịch. Sửa văn bản OCR hoặc thêm dòng thủ công.'
          : null;
    });
  }

  Future<void> pick() async {
    if (!validTerm()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await recognizeTimetableImage();
      if (!mounted || result == null) return;
      imagePath = result.path;
      raw.text = result.text;
      parse();
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
    if (busy || !confirmed || rows.isEmpty || !validTerm()) return;
    final headers = ['semester', ...labels.keys];
    final result = reviewImport([
      headers,
      for (final row in rows)
        [semester.text.trim(), for (final key in labels.keys) row[key]!.text],
    ], timetable: true);
    if (result.errors.isNotEmpty) {
      setState(() => error = result.errors.join('\n'));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final repo = ref.read(repositoryProvider);
      await repo.call('importTimetable', {'schedules': result.rows});
      final user = ref.read(profileProvider).value!;
      final classes = await repo.classes(user).first;
      final imported = classes
          .where(
            (c) => result.rows.any(
              (r) =>
                  r['semester'] == c['term'] &&
                  r['subjectCode'] == c['subjectId'] &&
                  r['classCode'] == c['classCode'],
            ),
          )
          .toList();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã lưu ${result.rows.length} slot. Tiếp theo, nhập Excel để gán sinh viên.',
          ),
        ),
      );
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => RosterAssignmentPage(classes: imported),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nhập lịch từ ảnh')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          '1. Ảnh → văn bản OCR → duyệt lịch',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const Text('2. Lưu lịch → nhập Excel → gán sinh viên cho lớp'),
        const SizedBox(height: 16),
        TextField(
          controller: semester,
          enabled: !busy,
          onChanged: (_) => setState(() => confirmed = false),
          decoration: const InputDecoration(
            labelText: 'Học kỳ',
            hintText: 'Ví dụ: FA26',
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: busy ? null : pick,
          icon: const Icon(Icons.image_search_outlined),
          label: const Text('Chọn ảnh và đọc OCR'),
        ),
        if (busy) const LinearProgressIndicator(),
        if (imagePath != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(imagePath!),
                height: 180,
                fit: BoxFit.contain,
              ),
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: raw,
          enabled: !busy,
          minLines: 4,
          maxLines: 10,
          onChanged: (_) => setState(() => confirmed = false),
          decoration: const InputDecoration(
            labelText: 'Văn bản OCR (có thể sửa / dán)',
            hintText: 'MON Slot 1 PRM393 SE1928 07:00 09:15 NVH 201',
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: useNvhTimes,
          title: const Text('Điền giờ còn thiếu theo khung NVH'),
          subtitle: const Text(
            'Slot 1–4: 07:00, 09:30, 12:30, 15:00. Cần đối chiếu ảnh.',
          ),
          onChanged: busy
              ? null
              : (v) => setState(() {
                  useNvhTimes = v!;
                  confirmed = false;
                }),
        ),
        OutlinedButton(
          onPressed: busy ? null : parse,
          child: const Text('Phân tích văn bản thành lịch'),
        ),
        const SizedBox(height: 16),
        Text(
          '${rows.length} dòng lịch cần duyệt',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (var i = 0; i < rows.length; i++)
          CampusCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Dòng ${i + 1}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Xóa dòng',
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              for (final c in rows.removeAt(i).values) {
                                c.dispose();
                              }
                              warnings.removeAt(i);
                              confirmed = false;
                            }),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                for (final note in warnings[i])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      note,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                for (final key in labels.keys)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: rows[i][key],
                      enabled: !busy,
                      onChanged: (_) => setState(() => confirmed = false),
                      decoration: InputDecoration(labelText: labels[key]),
                    ),
                  ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: busy || rows.length >= 100
              ? null
              : () => setState(() {
                  addRow({});
                  confirmed = false;
                }),
          icon: const Icon(Icons.add),
          label: const Text('Thêm dòng lịch'),
        ),
        if (rows.isNotEmpty)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: confirmed,
            title: const Text('Tôi đã đối chiếu lịch với ảnh gốc'),
            onChanged: busy ? null : (v) => setState(() => confirmed = v!),
          ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: busy || !confirmed || rows.isEmpty ? null : save,
          child: const Text('Lưu lịch và tiếp tục nhập Excel'),
        ),
      ],
    ),
  );
}
