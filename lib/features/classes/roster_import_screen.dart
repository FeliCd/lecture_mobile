import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../api/repository.dart';
import '../../models/domain.dart';
import '../../services/markbook_reader.dart';

class RosterImportScreen extends StatefulWidget {
  final LecturerRepository repo;
  final Lecturer lecturer;
  final ClassTarget? preselectedTarget;
  final String defaultSemester;

  const RosterImportScreen({
    super.key,
    required this.repo,
    required this.lecturer,
    this.preselectedTarget,
    this.defaultSemester = '',
  });

  @override
  State<RosterImportScreen> createState() => _RosterImportScreenState();
}

class _RosterImportScreenState extends State<RosterImportScreen> {
  bool _loadingTargets = true;
  List<ClassTarget> _availableTargets = [];
  ClassTarget? _selectedTarget;

  bool _parsingFile = false;
  String? _pickedFileName;
  MarkbookParseResult? _parseResult;
  String? _parseError;

  bool _isAutoMatched = false;
  String? _matchingWarning;

  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _loadTargets();
  }

  Future<void> _loadTargets() async {
    try {
      final targets = await widget.repo.classTargets(widget.lecturer.lecturerId);
      if (mounted) {
        setState(() {
          _availableTargets = targets;
          _loadingTargets = false;
          if (widget.preselectedTarget != null) {
            _selectedTarget = targets.firstWhere(
              (t) => t.key == widget.preselectedTarget!.key,
              orElse: () => widget.preselectedTarget!,
            );
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTargets = false);
    }
  }

  Future<void> _pickSpreadsheetFile() async {
    setState(() {
      _parseError = null;
      _parseResult = null;
      _isAutoMatched = false;
      _matchingWarning = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'ods', 'csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => _parseError = 'Không đọc được dữ liệu file.');
        return;
      }

      setState(() {
        _pickedFileName = file.name;
        _parsingFile = true;
      });

      // Run on background isolate
      final parsed = await MarkbookReader.parseBytesInBackground(
        bytes: bytes,
        fileName: file.name,
      );

      setState(() {
        _parsingFile = false;
        _parseResult = parsed;
      });

      _autoMatchClass(parsed);
    } catch (e) {
      setState(() {
        _parsingFile = false;
        _parseError = e.toString().replaceAll('FormatException: ', '');
      });
    }
  }

  void _autoMatchClass(MarkbookParseResult parsed) {
    if (_availableTargets.isEmpty) return;

    final detectedClass = parsed.detectedClassCode?.toUpperCase() ?? '';
    final suggestedSubject = parsed.suggestedSubjectCode.toUpperCase();

    // 1. Try exact 3-criteria match: Semester + ClassCode + SubjectCode
    ClassTarget? matched;
    for (final target in _availableTargets) {
      final semMatch = widget.defaultSemester.isEmpty ||
          target.semester.toUpperCase() == widget.defaultSemester.toUpperCase();
      final classMatch = detectedClass.isNotEmpty &&
          target.classCode.toUpperCase() == detectedClass;
      final subjectMatch = suggestedSubject.isNotEmpty &&
          target.subjectCode.toUpperCase() == suggestedSubject;

      if (semMatch && classMatch && subjectMatch) {
        matched = target;
        break;
      }
    }

    // 2. Fallback: match by ClassCode and SubjectCode
    if (matched == null && detectedClass.isNotEmpty && suggestedSubject.isNotEmpty) {
      matched = _availableTargets.firstWhere(
        (t) =>
            t.classCode.toUpperCase() == detectedClass &&
            t.subjectCode.toUpperCase() == suggestedSubject,
        orElse: () => _availableTargets.firstWhere(
          (t) => t.classCode.toUpperCase() == detectedClass,
          orElse: () => _availableTargets.first,
        ),
      );
    }

    if (matched != null &&
        detectedClass.isNotEmpty &&
        matched.classCode.toUpperCase() == detectedClass &&
        (suggestedSubject.isEmpty || matched.subjectCode.toUpperCase() == suggestedSubject)) {
      setState(() {
        _selectedTarget = matched;
        _isAutoMatched = true;
        _matchingWarning = null;
      });
    } else {
      setState(() {
        _isAutoMatched = false;
        _matchingWarning =
            'Chưa thể tự động khớp lớp (Mã lớp trong file: "${detectedClass.isEmpty ? "không rõ" : detectedClass}", Môn từ Sheet: "${suggestedSubject.isEmpty ? "không rõ" : suggestedSubject}"). Vui lòng chọn lớp đích bên dưới.';
      });
    }
  }

  Future<void> _submitImport() async {
    if (_selectedTarget == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn lớp đích cần gán danh sách sinh viên.')),
      );
      return;
    }

    if (_parseResult == null || _parseResult!.students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Danh sách sinh viên trong file đang trống.')),
      );
      return;
    }

    setState(() => _importing = true);

    try {
      // Normalize classCode on student records to match target
      final target = _selectedTarget!;
      final normalizedStudents = _parseResult!.students
          .map((s) => RosterStudent(
                classCode: target.classCode,
                studentCode: s.studentCode,
                fullName: s.fullName,
                schoolEmail: s.schoolEmail,
              ))
          .toList();

      final response = await widget.repo.importRoster(
        semester: target.semester,
        subjectCode: target.subjectCode,
        classCode: target.classCode,
        students: normalizedStudents,
      );

      final added = response['added'] ?? 0;
      final existing = response['existing'] ?? 0;

      setState(() => _importing = false);

      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 10),
                Text('Nhập Roster thành công!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lớp: ${target.subjectCode} · ${target.classCode} (${target.semester})'),
                const SizedBox(height: 12),
                Text('• Thêm mới vào lớp: $added sinh viên'),
                Text('• Đã có từ trước: $existing sinh viên'),
                const SizedBox(height: 8),
                const Text('Danh sách đã được đồng bộ với máy chủ Sheets.'),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop(true);
                },
                child: const Text('Hoàn tất'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _importing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi nhập dữ liệu: ${e.toString().replaceAll("AppFailure: ", "")}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhập SV từ Bảng tính'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Pick File Card
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.primaryContainer.withAlpha(70),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.file_upload_outlined,
                          size: 40, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 10),
                      Text(
                        _pickedFileName ?? 'Chọn file danh sách lớp (.xlsx, .ods, .csv)',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'File Markbook từ FAP hoặc phòng đào tạo. Hỗ trợ tự động nhận diện cột MSSV, Họ tên.',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _parsingFile || _importing ? null : _pickSpreadsheetFile,
                        icon: _parsingFile
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.file_open),
                        label: Text(_parsingFile ? 'Đang đọc file nền...' : 'Chọn file bảng tính'),
                      ),
                    ],
                  ),
                ),
              ),

              if (_parseError != null)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _parseError!,
                          style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_parseResult != null) ...[
                const SizedBox(height: 20),
                // 2. Auto-match & Target selection
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isAutoMatched ? Icons.check_circle : Icons.warning_amber_rounded,
                              color: _isAutoMatched ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isAutoMatched ? 'Khớp lớp đích tự động' : 'Chọn lớp đích cần gán',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        if (_matchingWarning != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _matchingWarning!,
                              style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
                            ),
                          ),
                        const SizedBox(height: 14),
                        if (_loadingTargets)
                          const Center(child: CircularProgressIndicator())
                        else if (_availableTargets.isEmpty)
                          const Text(
                            'Bạn chưa có lớp hoặc lịch dạy nào trên hệ thống. Hãy thêm thời khóa biểu trước.',
                            style: TextStyle(color: Colors.red),
                          )
                        else
                          DropdownButtonFormField<ClassTarget>(
                            initialValue: _selectedTarget,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Lớp đích nhận danh sách SV *',
                              prefixIcon: Icon(Icons.school),
                            ),
                            items: _availableTargets.map((t) {
                              return DropdownMenuItem<ClassTarget>(
                                value: t,
                                child: Text(
                                  '${t.subjectCode} · ${t.classCode} (${t.semester}) ${t.classId != null ? "✓ Đã có" : "• Mới"}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedTarget = val;
                                _matchingWarning = null;
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                // 3. Student count and summary
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Danh sách sinh viên (${_parseResult!.students.length})',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Chip(
                              label: Text('Sheet: ${_parseResult!.sheetName}'),
                              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            ),
                          ],
                        ),
                        if (_parseResult!.warnings.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Cảnh báo: ${_parseResult!.warnings.join(", ")}',
                              style: const TextStyle(color: Colors.orange, fontSize: 12),
                            ),
                          ),
                        const Divider(height: 20),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 280),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _parseResult!.students.length,
                            separatorBuilder: (_, index) => const Divider(height: 1),
                            itemBuilder: (ctx, idx) {
                              final st = _parseResult!.students[idx];
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 14,
                                  child: Text('${idx + 1}', style: const TextStyle(fontSize: 11)),
                                ),
                                title: Text(st.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  '${st.studentCode}${st.schoolEmail.isNotEmpty ? " • ${st.schoolEmail}" : ""}',
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _importing || _selectedTarget == null ? null : _submitImport,
                  icon: _importing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(
                    _importing
                        ? 'Đang đồng bộ lên máy chủ...'
                        : 'Đồng bộ ${_parseResult!.students.length} sinh viên vào lớp',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
