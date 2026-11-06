import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../groups/group_api.dart';

typedef GradebookCall =
    Future<dynamic> Function(String method, Map<String, dynamic> data);
typedef GradeRow = Map<String, dynamic>;

class GradebookController extends ChangeNotifier {
  final String classId;
  final GradebookCall call;
  GradebookController({required this.classId, required this.call});
  GradeRow? book, pendingPublish;
  bool busy = false, dirty = false, _disposed = false;
  int revision = 0;
  String? error;
  List<GradeRow> get components =>
      (book?['components'] as List? ?? []).cast<GradeRow>();
  List<GradeRow> get students =>
      (book?['students'] as List? ?? []).cast<GradeRow>();
  bool get editable => book != null && !busy && pendingPublish == null;
  bool get canPublish =>
      book != null &&
      !busy &&
      !dirty &&
      components.isNotEmpty &&
      students.isNotEmpty;
  void changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    book = null;
    pendingPublish = null;
    super.dispose();
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (busy || _disposed) return false;
    busy = true;
    error = null;
    changed();
    try {
      await action();
      return !_disposed;
    } catch (e) {
      if (!_disposed) {
        const messages = {
          'VERSION_CONFLICT':
              'Bảng điểm đã thay đổi trên thiết bị khác. Bản sửa vẫn giữ; kiểm tra và tải lại trước khi lưu.',
          'ROSTER_CHANGED': 'Danh sách lớp đã thay đổi. Tải lại bảng điểm.',
          'PERMISSION_DENIED': 'Bạn không có quyền quản lý điểm lớp này.',
          'FEATURE_DISABLED':
              'Cần cập nhật backend chung để mở bảng điểm trên mobile.',
          'UNKNOWN_PORTAL_METHOD':
              'Cần cập nhật backend chung để mở bảng điểm trên mobile.',
          'SHARED_BACKEND_SETUP_REQUIRED':
              'Cần khởi tạo bảng điểm trên backend chung.',
        };
        error =
            messages.entries
                .where((m) => e.toString().contains(m.key))
                .map((m) => m.value)
                .firstOrNull ??
            (e is FormatException
                ? e.message
                : 'Chưa xác nhận kết quả. Giữ bản sửa; tải lại để kiểm tra trước khi gửi lại.');
      }
      return false;
    } finally {
      busy = false;
      changed();
    }
  }

  Future<bool> load() => _run(() async {
    final value = await call('getGradebook', {'classId': classId});
    if (_disposed) return;
    book = Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
    dirty = false;
    pendingPublish = null;
    revision++;
  });
  void setGrade(GradeRow student, String id, String value) {
    if (!editable) return;
    (student['grades'] as Map)[id] = value;
    dirty = true;
    changed();
  }

  void setComment(GradeRow student, String value) {
    if (!editable) return;
    student['comment'] = value;
    dirty = true;
    changed();
  }

  void upsertComponent(String name, num maxScore, [GradeRow? existing]) {
    if (!editable) return;
    if (name.trim().isEmpty ||
        name.trim().length > 100 ||
        !maxScore.isFinite ||
        maxScore <= 0 ||
        maxScore > 1000 ||
        components.any(
          (c) =>
              c['id'] != existing?['id'] &&
              '${c['name']}'.trim().toLowerCase() == name.trim().toLowerCase(),
        ) ||
        (existing == null && components.length >= 30)) {
      throw const FormatException(
        'Tên cột hoặc thang điểm không hợp lệ/trùng.',
      );
    }
    final component = <String, dynamic>{
      'id': existing?['id'] ?? 'c_${groupRequestKey()}',
      'name': name.trim(),
      'maxScore': maxScore,
    };
    if (existing == null) {
      components.add(component);
    } else {
      components[components.indexOf(existing)] = component;
    }
    dirty = true;
    revision++;
    changed();
  }

  void removeComponent(GradeRow component) {
    if (!editable) return;
    components.remove(component);
    for (final s in students) {
      (s['grades'] as Map).remove(component['id']);
    }
    dirty = true;
    revision++;
    changed();
  }

  Future<bool> save() async {
    if (!editable || !dirty) return false;
    return _run(() async {
      if (components.isEmpty) {
        throw const FormatException('Thêm ít nhất một cột điểm.');
      }
      final rows = students.map((s) {
        final grades = <String, dynamic>{};
        for (final c in components) {
          final raw = '${(s['grades'] as Map)[c['id']] ?? ''}'.trim();
          final n = raw.isEmpty ? null : num.tryParse(raw.replaceAll(',', '.'));
          if (raw.isNotEmpty &&
              (n == null || !n.isFinite || n < 0 || n > c['maxScore'])) {
            throw FormatException(
              'Điểm không hợp lệ: ${s['studentCode']} / ${c['name']} (0–${c['maxScore']}).',
            );
          }
          grades[c['id']] = n ?? '';
        }
        return {
          'studentId': s['studentId'],
          'grades': grades,
          'comment': s['comment'] ?? '',
        };
      }).toList();
      final response = await call('saveGradebook', {
        'classId': classId,
        'version': book!['version'],
        'components': components,
        'students': rows,
      });
      if (_disposed) return;
      book!['version'] = response['version'];
      for (var i = 0; i < students.length; i++) {
        students[i]['grades'] = rows[i]['grades'];
      }
      dirty = false;
      revision++;
    });
  }

  Future<bool> publish() async {
    if (!canPublish) return false;
    pendingPublish ??= {
      'classId': classId,
      'version': book!['version'],
      'requestKey': groupRequestKey(),
      'studentIds': students.map((s) => s['studentId']).toList(),
    };
    return _run(() async {
      final response = await call(
        'publishGrades',
        Map<String, dynamic>.from(pendingPublish!),
      );
      if (_disposed) return;
      book!['activePublicationId'] = response['publicationId'];
      book!['version'] = (book!['version'] as num).toInt() + 1;
      pendingPublish = null;
    });
  }

  Future<bool> revoke() async {
    if (!editable || dirty || book!['activePublicationId'] == '') return false;
    return _run(() async {
      await call('revokeGrades', {
        'classId': classId,
        'version': book!['version'],
      });
      if (_disposed) return;
      book!['activePublicationId'] = '';
      book!['version'] = (book!['version'] as num).toInt() + 1;
    });
  }
}
