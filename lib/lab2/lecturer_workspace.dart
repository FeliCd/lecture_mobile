import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain.dart';
import 'repository.dart';
import 'widgets.dart';
import 'timetable_domain.dart';
import 'lecturer_workspace_store.dart';
import 'lecturer_reminders.dart';
import 'lecturer_weekly_report.dart';

String workspaceDate(String? raw) {
  final date = DateTime.tryParse(raw ?? '');
  if (date == null) return 'Chưa đặt hạn';
  final d = date.toUtc().add(const Duration(hours: 7));
  return '${timetableDate(d)}/${d.year} ${teachingTime(d.hour * 60 + d.minute)}';
}

class WorkspaceShortcut extends ConsumerWidget {
  final UserProfile user;
  const WorkspaceShortcut({super.key, required this.user});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(workspaceProvider(user.uid));
    final count = data.value?.tasks.where((t) => t['done'] != true).length;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.checklist),
        title: const Text('Trợ lý giảng dạy'),
        subtitle: Text(
          count == null
              ? 'Việc cần làm · Sổ tay · Tổng kết tuần'
              : '$count việc chưa xong · Dữ liệu trên máy',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LecturerWorkspacePage(user: user),
          ),
        ),
      ),
    );
  }
}

class LecturerWorkspacePage extends ConsumerStatefulWidget {
  final UserProfile user;
  final String? selectedTask;
  const LecturerWorkspacePage({
    super.key,
    required this.user,
    this.selectedTask,
  });
  @override
  ConsumerState<LecturerWorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends ConsumerState<LecturerWorkspacePage> {
  bool showDone = false;
  String? reminderStatus;
  Future<void> sync() async {
    try {
      final data = await ref
          .read(workspaceStoreProvider(widget.user.uid))
          .read();
      await LecturerReminders.instance.sync(widget.user.uid, data);
      final enabled = await LecturerReminders.instance.enabled();
      if (mounted) {
        setState(
          () => reminderStatus = enabled
              ? 'Thông báo đã bật. Android có thể nhắc trễ khi tiết kiệm pin.'
              : 'Thông báo đang tắt hoặc thiết bị chưa hỗ trợ. Việc vẫn được lưu trên máy.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => reminderStatus =
              'Đã lưu dữ liệu; chưa cập nhật được lịch thông báo. Bấm kiểm tra để thử lại.',
        );
      }
    }
  }

  Future<void> edit([Data? task]) async {
    final result = await showDialog<Data>(
      context: context,
      builder: (_) => TaskEditor(
        task: task,
        onSave: ref.read(workspaceStoreProvider(widget.user.uid)).saveTask,
      ),
    );
    if (result == null || !mounted) return;
    await sync();
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(workspaceProvider(widget.user.uid));
    final store = ref.read(workspaceStoreProvider(widget.user.uid));
    return Scaffold(
      appBar: AppBar(title: const Text('Trợ lý giảng dạy')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => edit(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm việc'),
      ),
      body: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          e,
          () => ref.invalidate(workspaceProvider(widget.user.uid)),
        ),
        data: (data) {
          final tasks =
              data.tasks.where((t) => showDone || t['done'] != true).toList()
                ..sort(
                  (a, b) => '${a['due'] ?? '9999'}'.compareTo(
                    '${b['due'] ?? '9999'}',
                  ),
                );
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
            children: [
              const Text(
                'Riêng tài khoản này • Lưu trên máy, chưa đồng bộ. Gỡ ứng dụng sẽ mất dữ liệu cá nhân.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LecturerWeeklyReportPage(user: widget.user),
                  ),
                ),
                icon: const Icon(Icons.summarize_outlined),
                label: const Text('Tổng kết tuần và xuất Excel'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Yên lặng 22:00–07:00 (UTC+7)'),
                subtitle: const Text(
                  'Bỏ qua thông báo trong khung giờ này; vẫn hiện việc đến hạn.',
                ),
                value: data.quiet,
                onChanged: (v) => runAction(context, () async {
                  await store.setQuiet(v);
                  await sync();
                }),
              ),
              TextButton.icon(
                icon: const Icon(Icons.notifications_outlined),
                label: const Text('Bật / kiểm tra thông báo'),
                onPressed: () async {
                  try {
                    await LecturerReminders.instance.enable();
                    await sync();
                  } catch (_) {
                    if (mounted) {
                      setState(
                        () => reminderStatus =
                            'Chưa bật được thông báo. Hãy kiểm tra quyền trong Cài đặt Android.',
                      );
                    }
                  }
                },
              ),
              if (reminderStatus != null) Text(reminderStatus!),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hiện cả việc đã xong'),
                value: showDone,
                onChanged: (v) => setState(() => showDone = v!),
              ),
              if (tasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Chưa có việc cần làm. Thêm việc chuẩn bị bài hoặc hạn chấm bài.',
                  ),
                ),
              for (final t in tasks)
                Card(
                  color: t['id'] == widget.selectedTask
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : null,
                  child: ListTile(
                    leading: Checkbox(
                      value: t['done'] == true,
                      onChanged: (v) => runAction(context, () async {
                        await store.saveTask({...t, 'done': v});
                        await sync();
                      }),
                    ),
                    title: Text('${t['title']}'),
                    subtitle: Text(
                      '${workspaceDate(t['due'] as String?)}${t['label'] == null ? '' : '\n${t['label']}'}${t['remind'] == true ? '\nNhắc trước ${t['lead'] ?? 0} phút' : ''}',
                    ),
                    onTap: () => edit(t),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) => runAction(context, () async {
                        if (action == 'snooze') {
                          final due = DateTime.tryParse('${t['due']}');
                          final base =
                              due != null && due.isAfter(DateTime.now())
                              ? due
                              : DateTime.now();
                          await store.saveTask({
                            ...t,
                            'due': base
                                .add(const Duration(days: 1))
                                .toUtc()
                                .toIso8601String(),
                            'done': false,
                          });
                        } else {
                          await store.deleteTask('${t['id']}');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Đã xóa việc'),
                                action: SnackBarAction(
                                  label: 'Hoàn tác',
                                  onPressed: () async {
                                    await store.saveTask(t);
                                    await sync();
                                  },
                                ),
                              ),
                            );
                          }
                        }
                        await sync();
                      }),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'snooze',
                          child: Text('Hoãn 1 ngày'),
                        ),
                        PopupMenuItem(value: 'delete', child: Text('Xóa việc')),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Sổ tay buổi dạy',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'Mở sổ tay ngay trên thẻ buổi học trong Hôm nay hoặc Lịch dạy.',
              ),
              for (final e in data.notes.entries)
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text('${e.value['label'] ?? 'Buổi dạy'}'),
                  subtitle: Text(
                    'Đã lưu trên máy • ${workspaceDate(e.value['updatedAt'] as String?)}',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LessonNotebookPage(
                        uid: widget.user.uid,
                        noteId: e.key,
                        metadata: e.value,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class TaskEditor extends StatefulWidget {
  final Data? task;
  final Future<void> Function(Data)? onSave;
  const TaskEditor({super.key, this.task, this.onSave});
  @override
  State<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<TaskEditor> {
  late final title = TextEditingController(
    text: '${widget.task?['title'] ?? ''}',
  );
  late DateTime? due = DateTime.tryParse('${widget.task?['due']}');
  late bool remind = widget.task?['remind'] == true;
  late int lead = widget.task?['lead'] as int? ?? 15;
  String? error;
  bool saving = false;
  bool changed = false;
  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CampusDraftGuard(
    dirty: changed,
    busy: saving,
    child: AlertDialog(
      title: Text(widget.task == null ? 'Thêm việc' : 'Sửa việc'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              onChanged: (_) => setState(() => changed = true),
              autofocus: true,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: 'Việc cần làm',
                errorText: error,
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.event),
              label: Text(workspaceDate(due?.toIso8601String())),
              onPressed: () async {
                final local = (due ?? DateTime.now()).toUtc().add(
                  const Duration(hours: 7),
                );
                final day = await showDatePicker(
                  context: context,
                  initialDate: DateTime(local.year, local.month, local.day),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (day == null || !context.mounted) return;
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: local.hour,
                    minute: local.minute,
                  ),
                );
                if (time != null && mounted) {
                  changed = true;
                  setState(
                    () => due = DateTime.utc(
                      day.year,
                      day.month,
                      day.day,
                      time.hour,
                      time.minute,
                    ).subtract(const Duration(hours: 7)),
                  );
                }
              },
            ),
            const Text(
              'Ngày và giờ theo Việt Nam (UTC+7). Nhắc theo ngày đã chọn; hãy sửa hạn nếu buổi học dời hoặc hủy.',
            ),
            SwitchListTile(
              title: const Text('Nhắc trước hạn'),
              value: remind,
              onChanged: (v) => setState(() {
                changed = true;
                remind = v;
              }),
            ),
            if (remind)
              DropdownButtonFormField<int>(
                initialValue: lead,
                items: [0, 10, 15, 30]
                    .map(
                      (v) => DropdownMenuItem(value: v, child: Text('$v phút')),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  changed = true;
                  lead = v!;
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.maybePop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  if (title.text.trim().isEmpty || (remind && due == null)) {
                    setState(
                      () => error = 'Nhập tên việc và chọn hạn nếu cần nhắc.',
                    );
                    return;
                  }
                  if (remind &&
                      !due!
                          .subtract(Duration(minutes: lead))
                          .isAfter(DateTime.now())) {
                    setState(
                      () => error = 'Giờ nhắc phải nằm trong tương lai.',
                    );
                    return;
                  }
                  final task = <String, dynamic>{
                    ...?widget.task,
                    'id':
                        widget.task?['id'] ??
                        DateTime.now().microsecondsSinceEpoch.toString(),
                    'title': title.text,
                    'due': due?.toUtc().toIso8601String(),
                    'remind': remind,
                    'lead': lead,
                    'done': widget.task?['done'] ?? false,
                  };
                  setState(() => saving = true);
                  try {
                    await widget.onSave?.call(task);
                    if (context.mounted) Navigator.pop(context, task);
                  } catch (_) {
                    if (mounted) {
                      setState(
                        () => error =
                            'Chưa lưu được. Nội dung vẫn còn; hãy thử lại.',
                      );
                    }
                  } finally {
                    if (mounted) setState(() => saving = false);
                  }
                },
          child: Text(saving ? 'Đang lưu…' : 'Lưu trên máy'),
        ),
      ],
    ),
  );
}

class LessonNotebookButton extends ConsumerWidget {
  final TeachingPeriod period;
  const LessonNotebookButton({super.key, required this.period});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(profileProvider).value;
    if (user == null || !user.isLecturer || period.classId == null) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      icon: const Icon(Icons.edit_note),
      label: const Text('Sổ tay buổi dạy'),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LessonNotebookPage(
            uid: user.uid,
            noteId: workspaceKey(period),
            metadata: {
              'label':
                  '${period.subjectId} · ${period.classCode} · ${period.sessionDate} · Slot ${period.slot ?? '—'}',
              'subjectId': period.subjectId,
              'term': period.term,
              'classId': period.classId,
              'date': period.sessionDate,
              'startAt': period.scheduledStartAt.toIso8601String(),
              'cancelled': period.cancelled,
            },
          ),
        ),
      ),
    );
  }
}

class LessonNotebookPage extends ConsumerStatefulWidget {
  final String uid, noteId;
  final Data metadata;
  const LessonNotebookPage({
    super.key,
    required this.uid,
    required this.noteId,
    required this.metadata,
  });
  @override
  ConsumerState<LessonNotebookPage> createState() => _NotebookState();
}

class _NotebookState extends ConsumerState<LessonNotebookPage> {
  static const labels = {
    'goals': 'Mục tiêu buổi dạy',
    'prep': 'Chuẩn bị (mỗi dòng một việc)',
    'resources': 'Link slide / code / tài liệu',
    'taught': 'Nội dung đã dạy',
    'next': 'Việc nối tiếp / ghi chú lần sau',
  };
  final fields = <String, TextEditingController>{};
  Data metadata = {};
  String status = 'Đang mở sổ tay…';
  bool ready = false, failed = false;
  int pending = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await ref.read(workspaceStoreProvider(widget.uid)).read();
      if (!mounted) return;
      final note = data.notes[widget.noteId] ?? {};
      metadata = {...note, ...widget.metadata};
      for (final key in labels.keys) {
        fields[key] = TextEditingController(text: '${note[key] ?? ''}')
          ..addListener(save);
      }
      setState(() {
        ready = true;
        status = 'Lưu tự động trên máy • Chưa đồng bộ';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => status =
              'Không mở được sổ tay. Quay lại và thử lại; dữ liệu cũ được giữ nguyên.',
        );
      }
    }
  }

  Future<void> save() async {
    final note = {
      ...metadata,
      for (final e in fields.entries) e.key: e.value.text,
    };
    setState(() {
      pending++;
      status = 'Đang lưu trên máy…';
    });
    try {
      await ref
          .read(workspaceStoreProvider(widget.uid))
          .saveNote(widget.noteId, note);
      failed = false;
    } catch (_) {
      failed = true;
    } finally {
      if (mounted) {
        setState(() {
          pending--;
          status = failed
              ? 'Chưa lưu được. Giữ màn hình này và bấm thử lại.'
              : pending > 0
              ? 'Đang lưu trên máy…'
              : 'Đã lưu trên máy • Chưa đồng bộ';
        });
      }
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CampusDraftGuard(
    dirty: failed,
    busy: pending > 0,
    child: Scaffold(
      appBar: AppBar(title: const Text('Sổ tay buổi dạy')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '${widget.metadata['label'] ?? ''}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(status, key: const ValueKey('notebook-save-status')),
          if (failed)
            TextButton(onPressed: save, child: const Text('Thử lưu lại')),
          if (ready) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.notifications_outlined),
              label: const Text('Tạo việc nhắc chuẩn bị buổi này'),
              onPressed: () async {
                final task = await showDialog<Data>(
                  context: context,
                  builder: (_) => TaskEditor(
                    onSave: ref
                        .read(workspaceStoreProvider(widget.uid))
                        .saveTask,
                    task: {
                      'title': 'Chuẩn bị ${metadata['label']}',
                      'due': metadata['startAt'],
                      'label': metadata['label'],
                      'occurrence': widget.noteId,
                    },
                  ),
                );
                if (task == null || !context.mounted) return;
                await runAction(context, () async {
                  final store = ref.read(workspaceStoreProvider(widget.uid));
                  try {
                    await LecturerReminders.instance.sync(
                      widget.uid,
                      await store.read(),
                    );
                  } catch (_) {}
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Đã lưu việc. Bật/kiểm tra thông báo trong Trợ lý giảng dạy.',
                        ),
                      ),
                    );
                  }
                });
              },
            ),
            OutlinedButton(
              onPressed: () async {
                final data = await ref
                    .read(workspaceStoreProvider(widget.uid))
                    .read();
                if (!context.mounted) return;
                final candidates = data.notes.entries
                    .where(
                      (e) =>
                          e.key != widget.noteId &&
                          e.value['subjectId'] == metadata['subjectId'],
                    )
                    .toList();
                final source = await showDialog<Data>(
                  context: context,
                  builder: (c) => SimpleDialog(
                    title: const Text('Sao chép kế hoạch cùng môn'),
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Thay mục tiêu, chuẩn bị và tài liệu bằng nội dung buổi đã chọn. Nội dung đã dạy và ghi chú lần sau được giữ.',
                        ),
                      ),
                      if (candidates.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Chưa có sổ tay khác của môn này.'),
                        ),
                      for (final e in candidates)
                        SimpleDialogOption(
                          onPressed: () => Navigator.pop(c, e.value),
                          child: Text('${e.value['label']}'),
                        ),
                    ],
                  ),
                );
                if (source == null || !mounted) return;
                for (final k in ['goals', 'prep', 'resources']) {
                  fields[k]!.text = '${source[k] ?? ''}';
                }
              },
              child: const Text('Dùng kế hoạch từ buổi khác'),
            ),
            for (final e in labels.entries)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: TextField(
                  controller: fields[e.key],
                  minLines: 2,
                  maxLines: 8,
                  maxLength: 10000,
                  decoration: InputDecoration(
                    labelText: e.value,
                    alignLabelWithHint: true,
                  ),
                ),
              ),
            if (fields['prep']!.text.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Checklist chuẩn bị',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final line
                  in fields['prep']!.text
                      .split('\n')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toSet())
                CheckboxListTile(
                  title: Text(line),
                  contentPadding: EdgeInsets.zero,
                  value: (metadata['checkedPrep'] as List? ?? []).contains(
                    line,
                  ),
                  onChanged: (done) {
                    final checked = Set<String>.from(
                      metadata['checkedPrep'] as List? ?? [],
                    );
                    if (done == true) {
                      checked.add(line);
                    } else {
                      checked.remove(line);
                    }
                    metadata['checkedPrep'] = checked.toList();
                    save();
                  },
                ),
            ],
          ],
        ],
      ),
    ),
  );
}
