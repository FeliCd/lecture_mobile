import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../api/repository.dart';
import '../../models/domain.dart';
import '../../services/schedule_parser.dart';

class FapPortalScreen extends StatefulWidget {
  final LecturerRepository repo;
  final Lecturer lecturer;
  final String semester;

  const FapPortalScreen({
    super.key,
    required this.repo,
    required this.lecturer,
    this.semester = '',
  });

  @override
  State<FapPortalScreen> createState() => _FapPortalScreenState();
}

class _FapPortalScreenState extends State<FapPortalScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _currentUrl = 'https://fap.fpt.edu.vn';
  bool _isExtracting = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (url) {
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });
          },
          onWebResourceError: (error) {
            setState(() => _isLoading = false);
          },
        ),
      )
      ..addJavaScriptChannel(
        'FapChannel',
        onMessageReceived: (JavaScriptMessage msg) {
          _handleExtractedData(msg.message);
        },
      )
      ..loadRequest(Uri.parse(_currentUrl));
  }

  /// Inject JS script to parse FAP DOM
  Future<void> _extractFapData() async {
    setState(() => _isExtracting = true);

    const jsCode = r'''
(function() {
  try {
    var result = {
      subjectCode: '',
      subjectName: '',
      classCode: '',
      slot: 1,
      room: '',
      date: '',
      students: []
    };

    // 1. Try to read Attendance Sheet / Class detail page
    var bodyText = document.body.innerText || '';
    
    // Extract subject code from page
    var subjectMatch = bodyText.match(/\b([A-Z]{2,6}\d{3}[A-Z0-9]*)\b/i);
    if (subjectMatch) result.subjectCode = subjectMatch[1].toUpperCase();

    // Extract class code
    var classMatch = bodyText.match(/\b((?:SE|AI|IA|IS|HE|SS|MC|GD|DS|IT|CS|BA|IB|MKT|FIN|HM|KS)[A-Z0-9]{3,})\b/i);
    if (classMatch) result.classCode = classMatch[1].toUpperCase();

    // Extract room
    var roomMatch = bodyText.match(/\b(NVH\s*[\w\d]+|[A-Z]{1,3}[-_]\d{2,4}|P\.?\s*\d{3})\b/i);
    if (roomMatch) result.room = roomMatch[1];

    // Extract Slot
    var slotMatch = bodyText.match(/(?:slot|tiết|ca)\s*(\d{1,2})/i);
    if (slotMatch) result.slot = parseInt(slotMatch[1], 10);

    // 2. Extract student list from tables
    var tables = document.querySelectorAll('table');
    for (var t = 0; t < tables.length; t++) {
      var rows = tables[t].querySelectorAll('tr');
      if (rows.length < 2) continue;

      var headerRow = rows[0].innerText.toLowerCase();
      if (headerRow.includes('roll') || headerRow.includes('mssv') || headerRow.includes('code') || headerRow.includes('sinh viên')) {
        for (var r = 1; r < rows.length; r++) {
          var cells = rows[r].querySelectorAll('td, th');
          if (cells.length < 3) continue;

          var roll = '';
          var name = '';
          var email = '';
          var cls = result.classCode;

          for (var c = 0; c < cells.length; c++) {
            var txt = cells[c].innerText.trim();
            // Roll number match
            if (!roll && /^[A-Z]{2}\d{4,8}$/i.test(txt)) {
              roll = txt.toUpperCase();
            } else if (!email && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(txt)) {
              email = txt.toLowerCase();
            } else if (!name && txt.length > 3 && !/^\d+$/.test(txt) && !txt.includes('/')) {
              name = txt;
            }
          }

          if (roll && name) {
            result.students.push({
              classCode: cls,
              studentCode: roll,
              fullName: name,
              schoolEmail: email
            });
          }
        }
        if (result.students.length > 0) break;
      }
    }

    if (window.FapChannel) {
      window.FapChannel.postMessage(JSON.stringify(result));
    }
    return JSON.stringify(result);
  } catch (err) {
    if (window.FapChannel) {
      window.FapChannel.postMessage(JSON.stringify({ error: err.toString() }));
    }
  }
})();
''';

    try {
      final res = await _controller.runJavaScriptReturningResult(jsCode);
      if (res is String && res != 'null') {
        _handleExtractedData(res);
      }
    } catch (e) {
      setState(() => _isExtracting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi trích xuất: $e')),
        );
      }
    }
  }

  void _handleExtractedData(String jsonString) {
    setState(() => _isExtracting = false);
    try {
      var clean = jsonString;
      if (clean.startsWith('"') && clean.endsWith('"')) {
        clean = jsonDecode(clean) as String;
      }
      final data = jsonDecode(clean) as Map<String, dynamic>;

      if (data.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi từ trang web: ${data['error']}')),
        );
        return;
      }

      final subjectCode = '${data['subjectCode'] ?? ''}'.toUpperCase();
      final classCode = '${data['classCode'] ?? ''}'.toUpperCase();
      final room = '${data['room'] ?? 'TBA'}';
      final slot = int.tryParse('${data['slot']}') ?? 1;
      final rawStudents = (data['students'] as List? ?? []);

      final students = rawStudents
          .map((s) => RosterStudent.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList();

      if (subjectCode.isEmpty && classCode.isEmpty && students.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy thông tin lịch dạy hoặc danh sách SV trên trang này.'),
          ),
        );
        return;
      }

      _showImportDialog(
        subjectCode: subjectCode,
        classCode: classCode,
        room: room,
        slot: slot,
        students: students,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể giải mã dữ liệu: $e')),
      );
    }
  }

  void _showImportDialog({
    required String subjectCode,
    required String classCode,
    required String room,
    required int slot,
    required List<RosterStudent> students,
  }) {
    final times = ScheduleParser.fptSlotTimes[slot] ?? ('07:30', '09:00');
    final sem = widget.semester.isNotEmpty ? widget.semester : 'FA24';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
                const SizedBox(width: 10),
                Text(
                  'Dữ liệu bóc tách từ FAP',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            Text('• Học kỳ: $sem'),
            Text('• Môn học: ${subjectCode.isNotEmpty ? subjectCode : "Chưa rõ"}'),
            Text('• Lớp học: ${classCode.isNotEmpty ? classCode : "Chưa rõ"}'),
            Text('• Slot: $slot (${times.$1} - ${times.$2}) · Phòng: $room'),
            Text('• Danh sách sinh viên: ${students.length} sinh viên'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _saveFapImport(
                  semester: sem,
                  subjectCode: subjectCode,
                  classCode: classCode,
                  room: room,
                  slot: slot,
                  startTime: times.$1,
                  endTime: times.$2,
                  students: students,
                );
              },
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Lưu Lịch & Đồng bộ Sinh viên'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveFapImport({
    required String semester,
    required String subjectCode,
    required String classCode,
    required String room,
    required int slot,
    required String startTime,
    required String endTime,
    required List<RosterStudent> students,
  }) async {
    setState(() => _isLoading = true);
    try {
      if (subjectCode.isNotEmpty && classCode.isNotEmpty) {
        final schedule = Schedule(
          scheduleId: 'sched_${DateTime.now().millisecondsSinceEpoch}',
          lecturerId: widget.lecturer.lecturerId,
          semester: semester,
          subjectCode: subjectCode,
          subjectName: subjectCode,
          classCode: classCode,
          dayOfWeek: DateTime.now().weekday,
          slot: slot,
          startTime: startTime,
          endTime: endTime,
          room: room,
          sourceType: 'MANUAL',
        );
        await widget.repo.batchUpdateSchedules([schedule]);
      }

      if (students.isNotEmpty && subjectCode.isNotEmpty && classCode.isNotEmpty) {
        await widget.repo.importRoster(
          semester: semester,
          subjectCode: subjectCode,
          classCode: classCode,
          students: students,
        );
      }

      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đồng bộ thành công dữ liệu từ FAP vào hệ thống!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi lưu dữ liệu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cổng FAP In-App'),
        actions: [
          IconButton(
            tooltip: 'Trích xuất dữ liệu FAP',
            icon: _isExtracting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.flash_on),
            onPressed: _isExtracting ? null : _extractFapData,
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () async {
                if (await _controller.canGoBack()) {
                  await _controller.goBack();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () async {
                if (await _controller.canGoForward()) {
                  await _controller.goForward();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _controller.reload(),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _isExtracting ? null : _extractFapData,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Lấy dữ liệu'),
            ),
          ],
        ),
      ),
    );
  }
}
