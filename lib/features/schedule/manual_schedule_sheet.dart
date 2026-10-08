import 'package:flutter/material.dart';
import '../../api/repository.dart';
import '../../models/domain.dart';
import '../../services/schedule_parser.dart';

class ManualScheduleSheet extends StatefulWidget {
  final LecturerRepository repo;
  final Lecturer lecturer;
  final String defaultSemester;
  final Schedule? initialSchedule;

  const ManualScheduleSheet({
    super.key,
    required this.repo,
    required this.lecturer,
    this.defaultSemester = '',
    this.initialSchedule,
  });

  static Future<bool?> show(
    BuildContext context, {
    required LecturerRepository repo,
    required Lecturer lecturer,
    String defaultSemester = '',
    Schedule? initialSchedule,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ManualScheduleSheet(
        repo: repo,
        lecturer: lecturer,
        defaultSemester: defaultSemester,
        initialSchedule: initialSchedule,
      ),
    );
  }

  @override
  State<ManualScheduleSheet> createState() => _ManualScheduleSheetState();
}

class _ManualScheduleSheetState extends State<ManualScheduleSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _semesterController;
  late TextEditingController _subjectCodeController;
  late TextEditingController _subjectNameController;
  late TextEditingController _classCodeController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  late TextEditingController _roomController;

  late int _dayOfWeek;
  late int _slot;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final init = widget.initialSchedule;
    final sem = init?.semester.isNotEmpty == true
        ? init!.semester
        : (widget.defaultSemester.isNotEmpty ? widget.defaultSemester : _defaultSemester());

    _semesterController = TextEditingController(text: sem);
    _subjectCodeController = TextEditingController(text: init?.subjectCode ?? '');
    _subjectNameController = TextEditingController(text: init?.subjectName ?? '');
    _classCodeController = TextEditingController(text: init?.classCode ?? '');
    _dayOfWeek = init?.dayOfWeek ?? 1;
    _slot = init?.slot ?? 1;

    final defaultTimes = ScheduleParser.fptSlotTimes[_slot] ?? ('07:30', '09:00');
    _startTimeController = TextEditingController(text: init?.startTime ?? defaultTimes.$1);
    _endTimeController = TextEditingController(text: init?.endTime ?? defaultTimes.$2);
    _roomController = TextEditingController(text: init?.room ?? '');
  }

  @override
  void dispose() {
    _semesterController.dispose();
    _subjectCodeController.dispose();
    _subjectNameController.dispose();
    _classCodeController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  String _defaultSemester() {
    final now = DateTime.now();
    final year = (now.year % 100).toString().padLeft(2, '0');
    final m = now.month;
    if (m >= 1 && m <= 4) return 'SP$year';
    if (m >= 5 && m <= 8) return 'SU$year';
    return 'FA$year';
  }

  void _onSlotChanged(int newSlot) {
    setState(() {
      _slot = newSlot;
      final times = ScheduleParser.fptSlotTimes[newSlot];
      if (times != null) {
        _startTimeController.text = times.$1;
        _endTimeController.text = times.$2;
      }
    });
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final current = controller.text.split(':');
    final initialTime = current.length == 2
        ? TimeOfDay(hour: int.tryParse(current[0]) ?? 7, minute: int.tryParse(current[1]) ?? 30)
        : const TimeOfDay(hour: 7, minute: 30);

    final picked = await showTimePicker(context: context, initialTime: initialTime);
    if (picked != null) {
      final h = picked.hour.toString().padLeft(2, '0');
      final m = picked.minute.toString().padLeft(2, '0');
      setState(() => controller.text = '$h:$m');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final start = _startTimeController.text.trim();
    final end = _endTimeController.text.trim();
    if (start.compareTo(end) >= 0) {
      setState(() => _errorMessage = 'Giờ bắt đầu phải trước giờ kết thúc.');
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final scheduleId = widget.initialSchedule?.scheduleId.isNotEmpty == true
          ? widget.initialSchedule!.scheduleId
          : 'sched_${DateTime.now().millisecondsSinceEpoch}';

      final schedule = Schedule(
        scheduleId: scheduleId,
        lecturerId: widget.lecturer.lecturerId,
        semester: _semesterController.text.trim().toUpperCase(),
        subjectCode: _subjectCodeController.text.trim().toUpperCase(),
        subjectName: _subjectNameController.text.trim().isEmpty
            ? _subjectCodeController.text.trim().toUpperCase()
            : _subjectNameController.text.trim(),
        classCode: _classCodeController.text.trim().toUpperCase(),
        dayOfWeek: _dayOfWeek,
        slot: _slot,
        startTime: start,
        endTime: end,
        room: _roomController.text.trim().isEmpty ? 'TBA' : _roomController.text.trim(),
        sourceType: widget.initialSchedule?.sourceType ?? 'MANUAL',
      );

      await widget.repo.batchUpdateSchedules([schedule]);
      if (mounted) {
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    const days = [
      (1, 'Thứ 2'),
      (2, 'Thứ 3'),
      (3, 'Thứ 4'),
      (4, 'Thứ 5'),
      (5, 'Thứ 6'),
      (6, 'Thứ 7'),
      (7, 'CN'),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.initialSchedule == null ? 'Thêm lịch dạy mới' : 'Chỉnh sửa lịch dạy',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
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
                          _errorMessage!,
                          style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _semesterController,
                      decoration: const InputDecoration(
                        labelText: 'Học kỳ *',
                        hintText: 'VD: FA24',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Nhập học kỳ' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _classCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Mã lớp *',
                        hintText: 'VD: SE1701',
                        prefixIcon: Icon(Icons.group_outlined),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Nhập mã lớp' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _subjectCodeController,
                decoration: const InputDecoration(
                  labelText: 'Mã môn học *',
                  hintText: 'VD: PRM393, SWE201c',
                  prefixIcon: Icon(Icons.menu_book_outlined),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Nhập mã môn';
                  final regex = RegExp(r'^[A-Z]{2,6}\d{3}[A-Z0-9]*$', caseSensitive: false);
                  if (!regex.hasMatch(v.trim())) {
                    return 'Mã môn không hợp lệ (VD: PRM393, CS101)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _subjectNameController,
                decoration: const InputDecoration(
                  labelText: 'Tên môn học (tùy chọn)',
                  hintText: 'VD: Lập trình di động',
                  prefixIcon: Icon(Icons.info_outline),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Thứ trong tuần *',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: days.map((d) {
                    final isSelected = _dayOfWeek == d.$1;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(d.$2),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) setState(() => _dayOfWeek = d.$1);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _slot,
                      decoration: const InputDecoration(
                        labelText: 'Slot học *',
                        prefixIcon: Icon(Icons.alarm),
                      ),
                      items: List.generate(12, (i) => i + 1)
                          .map((slot) => DropdownMenuItem(
                                value: slot,
                                child: Text('Slot $slot'),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) _onSlotChanged(v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _roomController,
                      decoration: const InputDecoration(
                        labelText: 'Phòng học *',
                        hintText: 'VD: NVH 102, BE-301',
                        prefixIcon: Icon(Icons.room_outlined),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Nhập phòng học' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startTimeController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Bắt đầu *',
                        suffixIcon: Icon(Icons.access_time),
                      ),
                      onTap: () => _selectTime(_startTimeController),
                      validator: (v) => v == null || v.isEmpty ? 'Chọn giờ bắt đầu' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _endTimeController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Kết thúc *',
                        suffixIcon: Icon(Icons.access_time),
                      ),
                      onTap: () => _selectTime(_endTimeController),
                      validator: (v) => v == null || v.isEmpty ? 'Chọn giờ kết thúc' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Đang lưu vào hệ thống...' : 'Lưu lịch dạy'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
