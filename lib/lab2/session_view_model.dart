import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain.dart';
import 'repository.dart';

typedef AttendanceCall = Future<Data> Function(String action, Data input);
final attendanceCallProvider = Provider<AttendanceCall>(
  (ref) => ref.watch(repositoryProvider).call,
);

class SessionState {
  final Data? occurrence;
  final Object? error;
  final bool loading, submitting;
  const SessionState({
    this.occurrence,
    this.error,
    this.loading = false,
    this.submitting = false,
  });
}

final sessionOpeningProvider = NotifierProvider.autoDispose
    .family<SessionOpeningController, SessionState, String>(
      SessionOpeningController.new,
    );

class SessionOpeningController extends Notifier<SessionState> {
  final String selectorJson;
  SessionOpeningController(this.selectorJson);
  @override
  SessionState build() => const SessionState();
  Data get _selector =>
      Map<String, dynamic>.from(jsonDecode(selectorJson) as Map);

  Future<void> load() async {
    if (state.loading || state.submitting) return;
    state = SessionState(loading: true, occurrence: state.occurrence);
    try {
      final value = await ref.read(attendanceCallProvider)(
        'getTeachingOccurrence',
        _selector,
      );
      if (ref.mounted) state = SessionState(occurrence: value);
    } catch (e) {
      if (ref.mounted) state = SessionState(error: e);
    }
  }

  Future<Data?> open(int duration) async {
    if (state.loading ||
        state.submitting ||
        state.occurrence?['state'] != 'AVAILABLE') {
      return null;
    }
    if (duration < 1 || duration > 60) {
      state = SessionState(
        occurrence: state.occurrence,
        error: ArgumentError('Thời lượng từ 1 đến 60 phút.'),
      );
      return null;
    }
    final occurrence = state.occurrence!;
    state = SessionState(occurrence: occurrence, submitting: true);
    try {
      final result =
          await ref.read(attendanceCallProvider)('createClassSession', {
            ..._selector,
            'occurrenceId': occurrence['occurrenceId'],
            'durationMinutes': duration,
          });
      if (ref.mounted) state = SessionState(occurrence: result);
      return result;
    } catch (e) {
      // A timeout may already have created a session. Require a fresh server
      // lookup before another creation attempt; OPEN/CLOSED can then resume.
      if (ref.mounted) state = SessionState(error: e);
      return null;
    }
  }
}

class AttendanceEditState {
  final bool busy;
  final Object? error;
  const AttendanceEditState({this.busy = false, this.error});
}

final attendanceEditProvider = NotifierProvider.autoDispose
    .family<AttendanceEditController, AttendanceEditState, Object>(
      AttendanceEditController.new,
    );

class AttendanceEditController extends Notifier<AttendanceEditState> {
  final Object dialogId;
  AttendanceEditController(this.dialogId);
  @override
  AttendanceEditState build() => const AttendanceEditState();
  Future<bool> save(Data input, Future<Data> Function(Data)? persist) async {
    if (state.busy) return false;
    if (!['present', 'late', 'absent', 'excused'].contains(input['status']) ||
        '${input['notes'] ?? ''}'.trim().isEmpty ||
        '${input['notes'] ?? ''}'.length > 500) {
      state = AttendanceEditState(
        error: ArgumentError('Chọn trạng thái và nhập lý do tối đa 500 ký tự.'),
      );
      return false;
    }
    state = const AttendanceEditState(busy: true);
    try {
      await persist?.call({...input, 'notes': '${input['notes']}'.trim()});
      if (ref.mounted) state = const AttendanceEditState();
      return true;
    } catch (e) {
      if (ref.mounted) state = AttendanceEditState(error: e);
      return false;
    }
  }
}
