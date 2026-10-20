import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'domain.dart';
import 'repository.dart';
import 'timetable_domain.dart';

/// Latest uninterrupted absences. Missing/ambiguous data never counts as absent.
List<Data> consecutiveAbsences(
  String uid,
  List<Data> sessions,
  List<Data> records,
) {
  final ordered = sessions
      .where(
        (s) =>
            s['status'] == 'finalized' &&
            (s['eligibleStudentUids'] is! List ||
                (s['eligibleStudentUids'] as List).contains(uid)),
      )
      .toList();
  if (ordered.any((s) => dateValue(s['opensAt']).millisecondsSinceEpoch <= 0)) {
    return [];
  }
  ordered.sort(
    (a, b) => dateValue(b['opensAt']).compareTo(dateValue(a['opensAt'])),
  );
  final result = <Data>[];
  final seen = <Object?>{};
  for (var i = 0; i < ordered.length; i++) {
    final session = ordered[i];
    if (!seen.add(session['id']) ||
        session['id'] == null ||
        (i + 1 < ordered.length &&
            dateValue(session['opensAt']) ==
                dateValue(ordered[i + 1]['opensAt']))) {
      break;
    }
    final matching = records
        .where(
          (r) =>
              r['studentUid'] == uid &&
              r['attendanceSessionId'] == session['id'],
        )
        .toList();
    if (matching.length != 1 || matching.single['status'] != 'absent') break;
    result.add(session);
  }
  return result;
}

String absenceRunDate(Data session) {
  final day = campusDay(dateValue(session['opensAt']));
  return '${timetableDate(day)}/${day.year} · Slot ${session['slot'] ?? '—'}';
}

String studentSupportKey(String classId, String studentUid) =>
    jsonEncode([classId, studentUid]);

final studentSupportStoreProvider = Provider.autoDispose
    .family<StudentSupportStore, String>((ref, uid) {
      final store = StudentSupportStore(uid);
      ref.onDispose(store.dispose);
      return store;
    });
final studentSupportProvider = StreamProvider.autoDispose
    .family<Map<String, Data>, String>(
      (ref, uid) => ref.watch(studentSupportStoreProvider(uid)).watch(),
    );

/// Private device storage, separated from lesson notes and weekly exports.
class StudentSupportStore {
  final String uid;
  final _events = StreamController<Map<String, Data>>.broadcast();
  Future<void> _tail = Future.value();
  StudentSupportStore(this.uid);
  String get key =>
      'lecturer-student-support-v1-${sha256.convert(utf8.encode(uid))}';
  Future<Map<String, Data>> read() async {
    final source = (await SharedPreferences.getInstance()).getString(key);
    if (source == null) return {};
    final decoded = jsonDecode(source) as Map;
    if (decoded['version'] != 1) {
      throw const FormatException('Phiên bản ghi chú chưa được hỗ trợ');
    }
    return {
      for (final e in (decoded['entries'] as Map).entries)
        '${e.key}': Map<String, dynamic>.from(e.value as Map),
    };
  }

  Stream<Map<String, Data>> watch() => Stream.multi((sink) {
    final sub = _events.stream.listen(sink.add, onError: sink.addError);
    _tail.then((_) => read()).then(sink.add, onError: sink.addError);
    sink.onCancel = sub.cancel;
  });
  Future<void> save(
    String classId,
    String studentUid,
    String note,
    String next,
    bool followUp,
  ) {
    if (classId.isEmpty ||
        studentUid.isEmpty ||
        note.length > 2000 ||
        next.length > 1000) {
      throw ArgumentError('Ghi chú không hợp lệ');
    }
    final operation = _tail.then((_) async {
      final entries = await read();
      final id = studentSupportKey(classId, studentUid);
      if (note.trim().isEmpty && next.trim().isEmpty && !followUp) {
        entries.remove(id);
      } else {
        entries[id] = {
          'note': note.trim(),
          'next': next.trim(),
          'followUp': followUp,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        };
      }
      final ok = await (await SharedPreferences.getInstance()).setString(
        key,
        jsonEncode({'version': 1, 'entries': entries}),
      );
      if (!ok) throw StateError('Không lưu được trên máy. Hãy thử lại.');
      if (!_events.isClosed) _events.add(entries);
    });
    _tail = operation.catchError((Object _) {});
    return operation;
  }

  void dispose() => _events.close();
}

class StudentSupportEditor extends ConsumerStatefulWidget {
  final String accountUid, classId, studentUid, name;
  final Data initial;
  const StudentSupportEditor({
    super.key,
    required this.accountUid,
    required this.classId,
    required this.studentUid,
    required this.name,
    required this.initial,
  });
  @override
  ConsumerState<StudentSupportEditor> createState() =>
      _StudentSupportEditorState();
}

class _StudentSupportEditorState extends ConsumerState<StudentSupportEditor> {
  late final note = TextEditingController(
    text: '${widget.initial['note'] ?? ''}',
  );
  late final next = TextEditingController(
    text: '${widget.initial['next'] ?? ''}',
  );
  late bool followUp = widget.initial['followUp'] == true;
  bool saving = false;
  String? error;
  @override
  void dispose() {
    note.dispose();
    next.dispose();
    super.dispose();
  }

  Future<void> close() async {
    if (saving) return;
    final dirty =
        note.text != '${widget.initial['note'] ?? ''}' ||
        next.text != '${widget.initial['next'] ?? ''}' ||
        followUp != (widget.initial['followUp'] == true);
    if (dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Bỏ thay đổi?'),
          content: const Text('Ghi chú vừa nhập chưa được lưu.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Tiếp tục viết'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Bỏ thay đổi'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> save() async {
    if (saving) return;
    final user = ref.read(profileProvider).value;
    if (user?.uid != widget.accountUid || user?.isLecturer != true) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ref
          .read(studentSupportStoreProvider(widget.accountUid))
          .save(
            widget.classId,
            widget.studentUid,
            note.text,
            next.text,
            followUp,
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Chưa lưu được. Giữ nội dung và thử lại.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(profileProvider).value;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Text('Ghi chú riêng · Chỉ lưu trên máy, chưa đồng bộ'),
                const SizedBox(height: 16),
                TextField(
                  controller: note,
                  enabled: !saving,
                  maxLines: 3,
                  maxLength: 2000,
                  decoration: const InputDecoration(labelText: 'Ghi chú'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: next,
                  enabled: !saving,
                  maxLines: 2,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Trao đổi buổi sau',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cần trao đổi'),
                  value: followUp,
                  onChanged: saving
                      ? null
                      : (v) => setState(() => followUp = v),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                FilledButton(
                  onPressed:
                      saving ||
                          user?.uid != widget.accountUid ||
                          user?.isLecturer != true
                      ? null
                      : save,
                  child: Text(saving ? 'Đang lưu…' : 'Lưu ghi chú'),
                ),
                TextButton(
                  onPressed: saving ? null : close,
                  child: const Text('Hủy'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
