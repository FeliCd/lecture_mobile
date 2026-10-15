import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'domain.dart';
import 'timetable_domain.dart';

String workspaceKey(TeachingPeriod p) => jsonEncode([
  p.term, p.classId ?? p.classCode, p.subjectId, p.sessionDate,
  p.slot, p.scheduleId ?? '', p.exceptionId ?? '',
  // A session created by attendance must not change an existing notebook key.
  if (p.scheduleId == null) p.sessionId ?? '${p.start}',
]);

class WorkspaceData {
  final List<Data> tasks;
  final Map<String, Data> notes;
  final bool quiet;
  const WorkspaceData({
    this.tasks = const [],
    this.notes = const {},
    this.quiet = true,
  });
  factory WorkspaceData.decode(String? source) {
    if (source == null) return const WorkspaceData();
    final d = jsonDecode(source) as Map;
    if (d['version'] != 1) {
      throw const FormatException('Phiên bản sổ tay chưa được hỗ trợ');
    }
    return WorkspaceData(
      tasks: [
        for (final t in d['tasks'] as List) Map<String, dynamic>.from(t as Map),
      ],
      notes: {
        for (final e in (d['notes'] as Map).entries)
          '${e.key}': Map<String, dynamic>.from(e.value as Map),
      },
      quiet: d['quiet'] != false,
    );
  }
  String encode() => jsonEncode({
    'version': 1,
    'tasks': tasks,
    'notes': notes,
    'quiet': quiet,
  });
}

final workspaceStoreProvider = Provider.family<WorkspaceStore, String>((
  ref,
  uid,
) {
  final store = WorkspaceStore(uid);
  ref.onDispose(store.dispose);
  return store;
});
final workspaceProvider = StreamProvider.family<WorkspaceData, String>(
  (ref, uid) => ref.watch(workspaceStoreProvider(uid)).watch(),
);

/// Serial read-modify-write prevents a notebook save from losing a concurrent task.
class WorkspaceStore {
  final String uid;
  final _events = StreamController<WorkspaceData>.broadcast();
  Future<void> _tail = Future.value();
  WorkspaceStore(this.uid);
  String get key => 'lecturer-workspace-v1-${sha256.convert(utf8.encode(uid))}';
  Future<WorkspaceData> read() async => WorkspaceData.decode(
    (await SharedPreferences.getInstance()).getString(key),
  );
  Stream<WorkspaceData> watch() => Stream.multi((sink) {
    final subscription = _events.stream.listen(
      sink.add,
      onError: sink.addError,
    );
    // Subscribe first, then load; every successful write emits its durable value.
    _tail.then((_) => read()).then(sink.add, onError: sink.addError);
    sink.onCancel = subscription.cancel;
  });
  Future<void> update(WorkspaceData Function(WorkspaceData) transform) {
    final result = _tail.then((_) async {
      final next = transform(await read());
      final ok = await (await SharedPreferences.getInstance()).setString(
        key,
        next.encode(),
      );
      if (!ok) throw StateError('Không lưu được trên máy. Hãy thử lại.');
      if (!_events.isClosed) _events.add(next);
    });
    _tail = result.catchError((Object _) {});
    return result;
  }

  Future<void> saveTask(Data task) {
    if ('${task['title'] ?? ''}'.trim().isEmpty) {
      throw ArgumentError('Cần nhập tên việc');
    }
    return update(
      (d) => WorkspaceData(
        tasks: [
          ...d.tasks.where((t) => t['id'] != task['id']),
          {
            ...task,
            'title': '${task['title']}'.trim(),
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          },
        ],
        notes: d.notes,
        quiet: d.quiet,
      ),
    );
  }

  Future<void> deleteTask(String id) => update(
    (d) => WorkspaceData(
      tasks: d.tasks.where((t) => t['id'] != id).toList(),
      notes: d.notes,
      quiet: d.quiet,
    ),
  );
  Future<void> saveNote(String id, Data note) => update(
    (d) => WorkspaceData(
      tasks: d.tasks,
      quiet: d.quiet,
      notes: {
        ...d.notes,
        id: {
          ...note,
          'revision': (d.notes[id]?['revision'] as int? ?? 0) + 1,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        },
      },
    ),
  );
  Future<void> setQuiet(bool quiet) => update(
    (d) => WorkspaceData(tasks: d.tasks, notes: d.notes, quiet: quiet),
  );
  Future<void> carryForward(
    String sourceId,
    String targetId,
    String text,
  ) => update((d) {
    final source = d.notes[sourceId], target = d.notes[targetId];
    if (source == null ||
        target == null ||
        text.trim().isEmpty ||
        source['classId'] == null ||
        source['classId'] != target['classId'] ||
        source['term'] != target['term'] ||
        source['subjectId'] != target['subjectId'] ||
        '${target['date'] ?? ''}'.compareTo('${source['date'] ?? '9999'}') <=
            0) {
      throw StateError('Chọn sổ tay buổi sau cùng lớp, môn và học kỳ.');
    }
    final signature = sha256
        .convert(utf8.encode('$sourceId/${text.trim()}'))
        .toString();
    final carried = List<String>.from(target['carriedFrom'] as List? ?? []);
    if (carried.contains(signature)) return d;
    return WorkspaceData(
      tasks: d.tasks,
      quiet: d.quiet,
      notes: {
        ...d.notes,
        targetId: {
          ...target,
          'goals': [
            if ('${target['goals'] ?? ''}'.trim().isNotEmpty) target['goals'],
            'Tiếp nối ${source['date']}:\n${text.trim()}',
          ].join('\n\n'),
          'carriedFrom': [...carried, signature],
          'revision': (target['revision'] as int? ?? 0) + 1,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        },
      },
    );
  });
  void dispose() {
    _events.close();
  }
}

DateTime? taskReminder(Data task, bool quiet, DateTime now) {
  if (task['done'] == true || task['remind'] != true || task['due'] == null) {
    return null;
  }
  final due = DateTime.tryParse('${task['due']}')?.toUtc();
  if (due == null) return null;
  final at = due.subtract(Duration(minutes: task['lead'] as int? ?? 0));
  final hour = at.add(const Duration(hours: 7)).hour;
  if (!at.isAfter(now.toUtc()) || (quiet && (hour < 7 || hour >= 22))) {
    return null;
  }
  return at;
}
