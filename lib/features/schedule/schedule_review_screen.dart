import 'package:flutter/material.dart';
import '../../api/repository.dart';
import '../../models/domain.dart';
import '../../services/schedule_parser.dart';

class ScheduleReviewScreen extends StatefulWidget {
  final LecturerRepository repo;
  final Lecturer lecturer;
  final List<ParsedScheduleItem> initialItems;
  final String semester;

  const ScheduleReviewScreen({
    super.key,
    required this.repo,
    required this.lecturer,
    required this.initialItems,
    this.semester = '',
  });

  @override
  State<ScheduleReviewScreen> createState() => _ScheduleReviewScreenState();
}

class _ScheduleReviewScreenState extends State<ScheduleReviewScreen> {
  late List<ParsedScheduleItem> items;
  bool _confirmedChecked = false;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    items = List.from(widget.initialItems);
    if (items.isEmpty) {
      items.add(ParsedScheduleItem(
        semester: widget.semester.isNotEmpty ? widget.semester : 'FA24',
        subjectCode: '',
        classCode: '',
        dayOfWeek: 1,
        slot: 1,
      ));
    }
  }

  void _addNewItem() {
    setState(() {
      final last = items.isNotEmpty ? items.last : null;
      items.add(ParsedScheduleItem(
        semester: last?.semester ?? widget.semester,
        subjectCode: last?.subjectCode ?? '',
        classCode: last?.classCode ?? '',
        dayOfWeek: ((last?.dayOfWeek ?? 0) % 7) + 1,
        slot: last?.slot ?? 1,
        startTime: last?.startTime ?? '07:30',
        endTime: last?.endTime ?? '09:00',
        room: last?.room ?? '',
        sourceType: 'IMAGE',
      ));
    });
  }

  void _removeItem(int index) {
    setState(() {
      items.removeAt(index);
    });
  }

  Future<void> _saveAll() async {
    if (!_confirmedChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng xác nhận đã kiểm tra đối chiếu trước khi lưu.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Danh sách lịch học đang trống.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Validate all items
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      if (it.subjectCode.trim().isEmpty) {
        setState(() => _errorMessage = 'Buổi ${i + 1}: Thiếu mã môn học.');
        return;
      }
      if (it.classCode.trim().isEmpty) {
        setState(() => _errorMessage = 'Buổi ${i + 1}: Thiếu mã lớp.');
        return;
      }
      if (it.startTime.compareTo(it.endTime) >= 0) {
        setState(() => _errorMessage = 'Buổi ${i + 1}: Giờ bắt đầu phải trước giờ kết thúc.');
        return;
      }
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final schedules = items.map((it) => it.toSchedule(lecturerId: widget.lecturer.lecturerId)).toList();
      await widget.repo.batchUpdateSchedules(schedules);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã lưu thành công ${schedules.length} buổi học vào hệ thống!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = e.toString().replaceAll('AppFailure: ', '').replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const dayNames = {
      1: 'Thứ 2',
      2: 'Thứ 3',
      3: 'Thứ 4',
      4: 'Thứ 5',
      5: 'Thứ 6',
      6: 'Thứ 7',
      7: 'Chủ Nhật',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kiểm tra & Xác nhận OCR'),
        actions: [
          IconButton(
            tooltip: 'Thêm buổi học',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _saving ? null : _addNewItem,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Theme.of(context).colorScheme.primaryContainer.withAlpha(80),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tìm thấy ${items.length} buổi học. Hãy chỉnh sửa các ô nếu OCR bị mờ/thiếu.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final it = items[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Buổi ${index + 1}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'Xóa buổi này',
                                onPressed: () => _removeItem(index),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  initialValue: it.subjectCode,
                                  decoration: const InputDecoration(
                                    labelText: 'Mã môn *',
                                    isDense: true,
                                  ),
                                  textCapitalization: TextCapitalization.characters,
                                  onChanged: (v) => it.subjectCode = v.toUpperCase(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  initialValue: it.classCode,
                                  decoration: const InputDecoration(
                                    labelText: 'Mã lớp *',
                                    isDense: true,
                                  ),
                                  textCapitalization: TextCapitalization.characters,
                                  onChanged: (v) => it.classCode = v.toUpperCase(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: it.semester,
                                  decoration: const InputDecoration(
                                    labelText: 'Học kỳ',
                                    isDense: true,
                                  ),
                                  textCapitalization: TextCapitalization.characters,
                                  onChanged: (v) => it.semester = v.toUpperCase(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<int>(
                                  initialValue: it.dayOfWeek,
                                  decoration: const InputDecoration(
                                    labelText: 'Thứ',
                                    isDense: true,
                                  ),
                                  items: dayNames.entries
                                      .map((e) => DropdownMenuItem(
                                            value: e.key,
                                            child: Text(e.value),
                                          ))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() => it.dayOfWeek = v);
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<int>(
                                  initialValue: it.slot,
                                  decoration: const InputDecoration(
                                    labelText: 'Slot',
                                    isDense: true,
                                  ),
                                  items: List.generate(12, (i) => i + 1)
                                      .map((s) => DropdownMenuItem(
                                            value: s,
                                            child: Text('Slot $s'),
                                          ))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) {
                                      setState(() {
                                        it.slot = v;
                                        final times = ScheduleParser.fptSlotTimes[v];
                                        if (times != null) {
                                          it.startTime = times.$1;
                                          it.endTime = times.$2;
                                        }
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  initialValue: it.room,
                                  decoration: const InputDecoration(
                                    labelText: 'Phòng học',
                                    isDense: true,
                                  ),
                                  onChanged: (v) => it.room = v,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  key: ValueKey('${it.slot}_${it.startTime}'),
                                  initialValue: it.startTime,
                                  decoration: const InputDecoration(
                                    labelText: 'Giờ bắt đầu',
                                    isDense: true,
                                  ),
                                  onChanged: (v) => it.startTime = v,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  key: ValueKey('${it.slot}_${it.endTime}'),
                                  initialValue: it.endTime,
                                  decoration: const InputDecoration(
                                    labelText: 'Giờ kết thúc',
                                    isDense: true,
                                  ),
                                  onChanged: (v) => it.endTime = v,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Material(
              color: Theme.of(context).colorScheme.surface,
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _confirmedChecked,
                      onChanged: (val) => setState(() => _confirmedChecked = val ?? false),
                      title: const Text(
                        'Tôi đã kiểm tra đối chiếu kỹ thông tin lịch dạy trên.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: !_confirmedChecked || _saving ? null : _saveAll,
                        icon: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.cloud_upload_outlined),
                        label: Text(_saving ? 'Đang lưu vào hệ thống...' : 'Lưu vào hệ thống (${items.length} buổi)'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
