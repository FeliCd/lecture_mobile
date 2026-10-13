import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data_import.dart';
import 'domain.dart';
import 'repository.dart';
import 'widgets.dart';
import 'ocr_import_page.dart';
import 'roster_assignment.dart';

Future<void> openImport(BuildContext context, {Data? cls}) => Navigator.push(
  context,
  MaterialPageRoute<void>(
    builder: (_) => cls == null
        ? const OcrImportPage()
        : RosterAssignmentPage(classes: [cls]),
  ),
);

class ImportPage extends ConsumerStatefulWidget {
  final Data? cls;
  const ImportPage({super.key, this.cls});
  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  bool get timetable => widget.cls == null;
  final text = TextEditingController();
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  ImportPreview? preview;
  bool bulk = false, busy = false;
  bool dirty = false, saved = false;
  int day = 1, slot = 1;
  String? error;
  TextEditingController field(String key, [String initial = '']) =>
      fields.putIfAbsent(key, () => TextEditingController(text: initial));
  @override
  void dispose() {
    text.dispose();
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> pick() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv', 'tsv'],
        withData: true,
      );
      if (picked == null) return;
      final file = picked.files.single;
      if (file.size > 5 * 1024 * 1024 || file.bytes == null) {
        throw const FormatException('Chọn file không quá 5 MB.');
      }
      String raw;
      if (file.extension?.toLowerCase() == 'xlsx') {
        final workbook = await compute(decodeImportWorkbook, file.bytes!);
        final sheets = workbook.entries
            .where((e) => e.value.isNotEmpty)
            .toList();
        if (sheets.isEmpty) {
          throw const FormatException('File Excel không có dữ liệu.');
        }
        var name = sheets.first.key;
        if (sheets.length > 1) {
          if (!mounted) return;
          final selected = await showDialog<String>(
            context: context,
            builder: (c) => SimpleDialog(
              title: const Text('Chọn trang dữ liệu'),
              children: sheets
                  .map(
                    (s) => SimpleDialogOption(
                      onPressed: () => Navigator.pop(c, s.key),
                      child: Text(s.key),
                    ),
                  )
                  .toList(),
            ),
          );
          if (selected == null) return;
          name = selected;
        }
        raw = importTableText(workbook[name]!);
      } else {
        raw = utf8.decode(file.bytes!);
      }
      if (!mounted) return;
      text.text = raw;
      dirty = true;
      review();
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

  void review() {
    try {
      final result = reviewImport(
        parseImportText(text.text),
        timetable: timetable,
        cls: widget.cls ?? {},
      );
      setState(() {
        preview = result;
        error = null;
      });
    } catch (e) {
      setState(
        () => error = e is FormatException ? e.message : errorMessage(e),
      );
    }
  }

  Future<void> save() async {
    if (busy) return;
    List<Data> rows;
    if (bulk) {
      review();
      if (preview == null ||
          preview!.errors.isNotEmpty ||
          preview!.rows.isEmpty) {
        return;
      }
      rows = preview!.rows;
    } else {
      if (!form.currentState!.validate()) return;
      final headers = timetable
          ? [
              'semester',
              'subjectCode',
              'subjectName',
              'classCode',
              'dayOfWeek',
              'slot',
              'startTime',
              'endTime',
              'room',
            ]
          : ['studentCode', 'fullName', 'schoolEmail'];
      final values = headers
          .map(
            (k) => k == 'dayOfWeek'
                ? '$day'
                : k == 'slot'
                ? '$slot'
                : field(k).text,
          )
          .toList();
      final result = reviewImport(
        [headers, values],
        timetable: timetable,
        cls: widget.cls ?? {},
      );
      if (result.errors.isNotEmpty) {
        setState(() => error = result.errors.join('\n'));
        return;
      }
      rows = result.rows;
    }
    if (!mounted) return;
    final confirmed = await campusConfirm(
      context,
      title: timetable ? 'Lưu thời khóa biểu?' : 'Nhập sinh viên?',
      message:
          'Xác nhận nhập ${rows.length} dòng đã kiểm tra. Dữ liệu sẽ được đối chiếu với danh sách hiện có.',
      confirm: 'Xác nhận lưu',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await ref
          .read(repositoryProvider)
          .call(timetable ? 'importTimetable' : 'importClassStudents', {
            if (!timetable) 'classId': widget.cls!['id'],
            timetable ? 'schedules' : 'students': rows,
          });
      if (!mounted) return;
      setState(() => saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            timetable
                ? 'Đã lưu ${result['saved'] ?? rows.length} buổi học.'
                : 'Đã thêm ${result['added'] ?? 0} sinh viên; ${result['existing'] ?? 0} đã có trong lớp.',
          ),
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      if (mounted) setState(() => error = mutationErrorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget input(
    String key,
    String label, {
    String initial = '',
    bool optional = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: field(key, initial),
      enabled: !busy,
      onChanged: (_) => setState(() => dirty = true),
      decoration: InputDecoration(labelText: label),
      keyboardType: key.toLowerCase().contains('email')
          ? TextInputType.emailAddress
          : TextInputType.text,
      validator: (v) =>
          !optional && (v == null || v.trim().isEmpty) ? 'Nhập $label.' : null,
    ),
  );
  @override
  Widget build(BuildContext context) => CampusDraftGuard(
    dirty: dirty && !saved,
    busy: busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          timetable
              ? 'Nhập thời khóa biểu'
              : 'Nhập sinh viên • ${widget.cls!['classCode']}',
        ),
        actions: const [
          CampusHelpButton(
            title: 'Hướng dẫn nhập dữ liệu',
            message:
                'Chọn nhập từng dòng hoặc từ Excel/CSV tối đa 5 MB. '
                'Kiểm tra bản xem trước và sửa tất cả lỗi trước khi lưu. '
                'Mẫu chỉ để tham khảo: thay bằng dữ liệu thật. '
                'Danh sách hiện có được đối chiếu, không bị xóa.',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Nhập từng dòng'),
                icon: Icon(Icons.edit_outlined),
              ),
              ButtonSegment(
                value: true,
                label: Text('Nhập từ file'),
                icon: Icon(Icons.upload_file),
              ),
            ],
            selected: {bulk},
            onSelectionChanged: busy
                ? null
                : (s) => setState(() {
                    bulk = s.first;
                    error = null;
                  }),
          ),
          const SizedBox(height: 20),
          if (!bulk)
            Form(
              key: form,
              child: Column(
                children: [
                  if (timetable) ...[
                    input('semester', 'Học kỳ', initial: 'FA26'),
                    input('subjectCode', 'Mã môn'),
                    input('subjectName', 'Tên môn', optional: true),
                    input('classCode', 'Mã lớp'),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: day,
                      decoration: const InputDecoration(labelText: 'Thứ'),
                      items: List.generate(
                        7,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text(i == 6 ? 'Chủ nhật' : 'Thứ ${i + 2}'),
                        ),
                      ),
                      onChanged: busy
                          ? null
                          : (v) => setState(() {
                              day = v!;
                              dirty = true;
                            }),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: slot,
                      decoration: const InputDecoration(labelText: 'Slot'),
                      items: List.generate(
                        12,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text('Slot ${i + 1}'),
                        ),
                      ),
                      onChanged: busy
                          ? null
                          : (v) => setState(() {
                              slot = v!;
                              dirty = true;
                            }),
                    ),
                    const SizedBox(height: 12),
                    input('startTime', 'Giờ bắt đầu (HH:mm)', initial: '07:30'),
                    input('endTime', 'Giờ kết thúc (HH:mm)', initial: '09:50'),
                    input('room', 'Phòng', optional: true),
                  ] else ...[
                    input('studentCode', 'MSSV'),
                    input('fullName', 'Họ tên'),
                    input('schoolEmail', 'Email (tùy chọn)', optional: true),
                  ],
                ],
              ),
            ),
          if (bulk) ...[
            OutlinedButton.icon(
              onPressed: busy ? null : pick,
              icon: const Icon(Icons.upload_file),
              label: const Text('Chọn Excel (.xlsx) hoặc CSV'),
            ),
            const SizedBox(height: 12),
            Text(
              timetable
                  ? 'Cột: semester, subjectCode, subjectName, classCode, dayOfWeek, slot, startTime, endTime, room. Thứ: 1 = thứ Hai, 7 = Chủ nhật.'
                  : 'Cột: studentCode, fullName, schoolEmail. Có thể dán bảng Excel hoặc dữ liệu MSSV, họ tên, email. Email không bắt buộc.',
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () {
                      text.text = timetable
                          ? 'semester,subjectCode,subjectName,classCode,dayOfWeek,slot,startTime,endTime,room\nFA26,PRM393,Lập trình di động,SE1928,1,1,07:30,09:50,A201'
                          : 'studentCode,fullName,schoolEmail\nSE000001,Sinh viên mẫu,';
                      setState(() {
                        preview = null;
                        dirty = true;
                      });
                    },
              child: const Text('Điền mẫu để tham khảo'),
            ),
            TextField(
              controller: text,
              enabled: !busy,
              minLines: 5,
              maxLines: 12,
              onChanged: (_) => setState(() {
                preview = null;
                dirty = true;
              }),
              decoration: const InputDecoration(
                labelText: 'Dán / chỉnh sửa dữ liệu',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: busy ? null : review,
              child: const Text('Kiểm tra và xem trước'),
            ),
            if (preview != null) ...[
              Text(
                '${preview!.rows.length} dòng hợp lệ • ${preview!.errors.length} lỗi',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ...preview!.errors.map(
                (e) => Text(
                  e,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              ...preview!.rows
                  .take(10)
                  .map(
                    (r) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        timetable
                            ? '${r['subjectCode']} • ${r['classCode']} • Slot ${r['slot']}'
                            : '${r['studentCode']} • ${r['fullName']}',
                      ),
                      subtitle: Text(
                        timetable
                            ? 'Thứ ${r['dayOfWeek'] == 7 ? 'CN' : r['dayOfWeek'] + 1} • ${r['startTime']}–${r['endTime']} • ${r['room']?.toString().trim().isNotEmpty == true ? r['room'] : 'Chưa cập nhật phòng'}'
                            : '${r['schoolEmail']}',
                      ),
                    ),
                  ),
              if (preview!.rows.length > 10)
                Text('Và ${preview!.rows.length - 10} dòng khác.'),
            ],
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            'Dữ liệu đã có sẽ được đối chiếu; danh sách hiện tại không bị xóa.',
          ),
          const SizedBox(height: 12),
          AppPrimaryButton(
            label: timetable ? 'Lưu thời khóa biểu' : 'Nhập vào lớp',
            busy: busy,
            busyLabel: 'Đang nhập dữ liệu…',
            onPressed:
                bulk &&
                    (preview == null ||
                        preview!.errors.isNotEmpty ||
                        preview!.rows.isEmpty)
                ? null
                : save,
          ),
        ],
      ),
    ),
  );
}
