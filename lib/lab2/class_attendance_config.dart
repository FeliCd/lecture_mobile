import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain.dart';
import 'repository.dart';

class ClassAttendanceConfig extends ConsumerStatefulWidget {
  final Data cls;
  const ClassAttendanceConfig({super.key, required this.cls});
  @override
  ConsumerState<ClassAttendanceConfig> createState() =>
      _ClassAttendanceConfigState();
}

class _ClassAttendanceConfigState extends ConsumerState<ClassAttendanceConfig> {
  bool saving = false;
  Future<void> edit() async {
    var input = courseSlotTotal(widget.cls['totalSlots'])?.toString() ?? '';
    final form = GlobalKey<FormState>();
    final classId = '${widget.cls['id']}';
    final total = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Tổng slot môn học'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nhập tổng slot của cả học kỳ theo kế hoạch môn học. Một buổi 07:00–09:15 là 1 slot. Vắng có phép vẫn tính nghỉ; đi trễ không tính nghỉ.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: input,
                  onChanged: (value) => input = value,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Tổng số slot',
                    hintText: 'Ví dụ: 20',
                  ),
                  validator: (v) => courseSlotTotal(v?.trim()) == null
                      ? 'Nhập số nguyên từ 1 đến 1000'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(c, int.parse(input.trim()));
              }
            },
            child: const Text('Lưu tổng slot'),
          ),
        ],
      ),
    );
    if (total == null || !mounted) return;
    setState(() => saving = true);
    try {
      await ref.read(repositoryProvider).call('setClassAttendanceConfig', {
        'classId': classId,
        'totalSlots': total,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã lưu tổng slot môn học')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage(error))));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = courseSlotTotal(widget.cls['totalSlots']);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.rule_outlined),
      title: Text(
        total == null
            ? 'Chưa cấu hình tổng slot'
            : 'Tổng môn học: $total slot · Được nghỉ tối đa ${total ~/ 5} slot',
      ),
      subtitle: const Text(
        'Nghỉ / tổng slot cả môn × 100%. Vượt 20%: cấm thi.',
      ),
      trailing: TextButton(
        onPressed: saving ? null : edit,
        child: Text(saving ? 'Đang lưu…' : 'Thiết lập'),
      ),
    );
  }
}
