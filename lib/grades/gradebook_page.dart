import 'package:flutter/material.dart';
import '../lab2/widgets.dart';
import '../lab2/theme.dart';
import '../grade_forecast/grade_forecast_page.dart';
import 'gradebook_controller.dart';

class LecturerGradebookPage extends StatefulWidget {
  final String classId, classLabel;
  final GradebookCall call;
  const LecturerGradebookPage({
    super.key,
    required this.classId,
    required this.classLabel,
    required this.call,
  });
  @override
  State<LecturerGradebookPage> createState() => _LecturerGradebookPageState();
}

class _LecturerGradebookPageState extends State<LecturerGradebookPage> {
  late final GradebookController model;
  bool allowExit = false;
  @override
  void initState() {
    super.initState();
    model = GradebookController(classId: widget.classId, call: widget.call);
    model.load();
  }

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  Future<bool> confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(body)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Quay lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> reload() async {
    if ((model.dirty || model.pendingPublish != null) &&
        !await confirm(
          'Tải lại bảng điểm?',
          'Bỏ bản sửa trên máy và lấy trạng thái hiện tại từ máy chủ. Nếu lần công bố trước chưa rõ kết quả, kiểm tra bản công bố sau khi tải.',
          'Tải lại',
        )) {
      return;
    }
    if (mounted) await model.load();
  }

  Future<void> editComponent([GradeRow? old]) async {
    final name = TextEditingController(text: old?['name'] ?? ''),
        max = TextEditingController(text: '${old?['maxScore'] ?? 10}');
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(old == null ? 'Thêm cột điểm' : 'Sửa cột điểm'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (old == null) ...[
                  const Text(
                    'Cột mới và các thay đổi hiện tại sẽ được lưu vào bản nháp chung với Desktop.',
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: name,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Tên cột'),
                  validator: (v) =>
                      v == null ||
                          v.trim().isEmpty ||
                          model.componentNameTaken(v, old)
                      ? 'Tên trống hoặc trùng'
                      : null,
                ),
                TextFormField(
                  controller: max,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Thang điểm'),
                  validator: (v) {
                    final n = num.tryParse((v ?? '').replaceAll(',', '.'));
                    return n == null || !n.isFinite || n <= 0 || n > 1000
                        ? 'Thang điểm > 0, tối đa 1000'
                        : null;
                  },
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
              if (form.currentState!.validate()) Navigator.pop(c, true);
            },
            child: Text(old == null ? 'Thêm và lưu nháp' : 'Áp dụng'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      model.upsertComponent(
        name.text,
        num.parse(max.text.replaceAll(',', '.')),
        old,
      );
    }
    // Dialog transitions still reference controllers for one frame.
    Future.delayed(const Duration(seconds: 1), () {
      name.dispose();
      max.dispose();
    });
    if (ok == true && old == null && mounted && await model.save() && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu cột điểm vào bản nháp chung.')),
      );
    }
  }

  Future<void> publish() async {
    if (model.pendingPublish == null &&
        !await confirm(
          'Xem trước công bố điểm',
          '${widget.classLabel}\n${model.students.length} sinh viên · ${model.components.length} cột điểm\n${model.components.map((c) => c['name']).join(', ')}\n\n${model.students.fold<int>(0, (sum, s) => sum + model.components.where((c) => (s['grades'] as Map)[c['id']] == null || (s['grades'] as Map)[c['id']] == '').length)} ô chưa có điểm. Nhận xét cũng được công bố.\nSinh viên xem bản này trên Student Web cho đến khi công bố lại hoặc thu hồi.',
          'Công bố điểm',
        )) {
      return;
    }
    if (mounted) await model.publish();
  }

  void viewPublishedGrades() {
    final publication = model.publication!;
    final components = (publication['components'] as List).cast<GradeRow>();
    final students = (publication['students'] as List).cast<GradeRow>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CampusScaffold(
          appBar: AppBar(title: const Text('Điểm đang công bố')),
          body: ListView.builder(
            padding: CampusSpace.pageInsets,
            itemCount: students.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return CampusInfoBanner(
                  icon: Icons.visibility_outlined,
                  title: widget.classLabel,
                  subtitle: "Bản công bố phiên bản ${publication['version']}",
                );
              }
              final student = students[index - 1];
              final grades = student['grades'] as Map;
              final comment = student['comment'] as String? ?? '';
              return Card(
                child: ExpansionTile(
                  title: Text(student['fullName'] ?? student['studentId']),
                  subtitle: Text(student['studentCode'] ?? ''),
                  children: [
                    for (final component in components)
                      ListTile(
                        title: Text(component['name']),
                        trailing: Text(
                          "${grades[component['id']] == '' ? '—' : grades[component['id']] ?? '—'} / ${component['maxScore']}",
                        ),
                      ),
                    if (comment.isNotEmpty)
                      ListTile(
                        title: const Text('Nhận xét'),
                        subtitle: Text(comment),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: model,
    builder: (context, _) => PopScope(
      canPop:
          allowExit ||
          (!model.busy && !model.dirty && model.pendingPublish == null),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || model.busy) return;
        if (await confirm(
              'Rời bảng điểm?',
              'Bản sửa chưa lưu sẽ mất. Nếu công bố chưa rõ kết quả, hãy tải lại khi mở lại lớp trước khi thực hiện thao tác mới.',
              'Rời bảng điểm',
            ) &&
            mounted) {
          setState(() => allowExit = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop();
          });
        }
      },
      child: CampusScaffold(
        appBar: AppBar(title: const Text('Bảng điểm')),
        body: ListView(
          padding: CampusSpace.pageInsets,
          children: [
            CampusInfoBanner(
              icon: Icons.grading_outlined,
              title: widget.classLabel,
              subtitle:
                  'Lưu nháp trước, công bố sau. Sinh viên chỉ xem bản đã công bố.',
            ),
            const SizedBox(height: CampusSpace.md),
            if (model.busy) const LinearProgressIndicator(),
            if (model.error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  model.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const CampusSectionHeader(title: 'Thao tác bảng điểm'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: model.busy ? null : reload,
                  child: const Text('Tải lại'),
                ),
                OutlinedButton(
                  onPressed: model.editable && model.components.length < 30
                      ? () => editComponent()
                      : null,
                  child: const Text('Thêm cột điểm'),
                ),
                FilledButton(
                  onPressed: model.editable && model.dirty ? model.save : null,
                  child: const Text('Lưu bản nháp'),
                ),
                FilledButton(
                  onPressed: model.canPublish ? publish : null,
                  child: Text(
                    model.pendingPublish == null
                        ? 'Xem trước / Công bố'
                        : 'Thử lại cùng lần công bố',
                  ),
                ),
                if (model.publication != null)
                  OutlinedButton(
                    onPressed: model.busy ? null : viewPublishedGrades,
                    child: const Text('Xem điểm đang công bố'),
                  ),
                OutlinedButton(
                  onPressed:
                      model.editable &&
                          !model.dirty &&
                          model.book?['activePublicationId'] != ''
                      ? () async {
                          if (await confirm(
                                'Thu hồi điểm đã công bố?',
                                'Sinh viên sẽ không đọc được điểm từ lần tải tiếp theo. Lịch sử công bố được giữ.',
                                'Thu hồi',
                              ) &&
                              mounted) {
                            await model.revoke();
                          }
                        }
                      : null,
                  child: const Text('Thu hồi'),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          GradeForecastPage(contextLabel: widget.classLabel),
                    ),
                  ),
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('Tính điểm FE/PE'),
                ),
              ],
            ),
            if (model.book != null) ...[
              const SizedBox(height: CampusSpace.sm),
              Wrap(
                spacing: CampusSpace.sm,
                runSpacing: CampusSpace.xs,
                children: [
                  CampusStatusChip(
                    'Phiên bản ${model.book!['version']}',
                    icon: Icons.history,
                  ),
                  CampusStatusChip(
                    model.book!['activePublicationId'] == ''
                        ? 'Chưa công bố'
                        : 'Có bản đang công bố',
                    icon: Icons.visibility_outlined,
                  ),
                  if (model.dirty)
                    const CampusStatusChip(
                      'Có thay đổi chưa lưu',
                      icon: Icons.edit_outlined,
                    ),
                ],
              ),
            ],
            if (model.pendingPublish != null)
              const Text(
                'Đang giữ mã công bố để thử lại an toàn. Các thao tác sửa điểm được khóa đến khi kiểm tra xong.',
              ),
            const CampusSectionHeader(title: 'Cột điểm'),
            Wrap(
              spacing: 8,
              children: model.components
                  .map(
                    (c) => InputChip(
                      label: Text('${c['name']} / ${c['maxScore']}'),
                      onPressed: model.editable ? () => editComponent(c) : null,
                      onDeleted: model.editable
                          ? () async {
                              if (await confirm(
                                    'Xóa cột ${c['name']}?',
                                    'Xóa cột và điểm của cột trong bản nháp. Điểm đã công bố vẫn giữ cho đến khi công bố lại.',
                                    'Xóa cột',
                                  ) &&
                                  mounted) {
                                model.removeComponent(c);
                              }
                            }
                          : null,
                    ),
                  )
                  .toList(),
            ),
            if (model.book != null)
              const CampusSectionHeader(title: 'Điểm theo sinh viên'),
            if (model.book != null && model.students.isEmpty)
              const EmptyState(
                'Chưa có sinh viên. Kiểm tra danh sách lớp trên desktop.',
              ),
            for (final student in model.students)
              Card(
                child: ExpansionTile(
                  key: ValueKey('${student['studentId']}/${model.revision}'),
                  leading: const Icon(Icons.person_outline),
                  title: Text('${student['fullName']}'),
                  subtitle: Text('${student['studentCode']}'),
                  childrenPadding: const EdgeInsets.all(12),
                  children: [
                    for (final component in model.components)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          key: ValueKey(
                            'grade/${student['studentId']}/${component['id']}/${model.revision}',
                          ),
                          initialValue:
                              '${(student['grades'] as Map)[component['id']] ?? ''}',
                          enabled: model.editable,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText:
                                '${component['name']} / ${component['maxScore']}',
                          ),
                          onChanged: (v) =>
                              model.setGrade(student, component['id'], v),
                        ),
                      ),
                    TextFormField(
                      key: ValueKey(
                        'comment/${student['studentId']}/${model.revision}',
                      ),
                      initialValue: student['comment'] ?? '',
                      enabled: model.editable,
                      maxLength: 1000,
                      decoration: const InputDecoration(labelText: 'Nhận xét'),
                      onChanged: (v) => model.setComment(student, v),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
