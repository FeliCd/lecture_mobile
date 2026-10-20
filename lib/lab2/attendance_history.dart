import 'domain.dart';
import 'timetable_domain.dart';
import 'repository.dart' show dateValue;

/// A date + slot is one lesson, irrespective of duration or QR rotations.
String attendanceSlotKey(Data session) {
  final date = '${session['sessionDate'] ?? ''}';
  final time = dateValue(session['opensAt']);
  final day = date.isNotEmpty
      ? date
      : time.millisecondsSinceEpoch > 0
      ? campusDay(time).toIso8601String().substring(0, 10)
      : '';
  return day.isNotEmpty && session['slot'] != null
      ? '${session['classId'] ?? ''}|$day|${session['slot']}'
      : 'session:${session['id']}';
}

/// Missing/conflicting records remain pending; never invent absences.
List<Data> studentAttendanceSlots(
  String uid,
  List<Data> sessions,
  List<Data> records,
) {
  final grouped = <String, List<Data>>{};
  for (final session in sessions) {
    if (session['status'] != 'finalized' ||
        session['attendanceCompleted'] == false ||
        (session['eligibleStudentUids'] is List &&
            !(session['eligibleStudentUids'] as List).contains(uid))) {
      continue;
    }
    grouped.putIfAbsent(attendanceSlotKey(session), () => []).add(session);
  }
  final bySession = <Object?, List<Data>>{};
  for (final record in records.where((r) => r['studentUid'] == uid)) {
    bySession.putIfAbsent(record['attendanceSessionId'], () => []).add(record);
  }
  return [
    for (final entry in grouped.entries)
      (() {
        final statuses = <String>{};
        final representativeRecords = bySession[entry.value.first['id']] ?? [];
        var incomplete = false;
        for (final session in entry.value) {
          final matches = bySession[session['id']] ?? [];
          if (matches.isEmpty) incomplete = true;
          statuses.addAll(
            matches.map((r) => attendanceStatus('${r['status']}')),
          );
        }
        return <String, dynamic>{
          if (representativeRecords.isNotEmpty) ...representativeRecords.first,
          ...entry.value.first,
          'slotKey': entry.key,
          'studentUid': uid,
          'status': !incomplete && statuses.length == 1
              ? statuses.single
              : 'pending',
        };
      })(),
  ];
}

/// Small history hint; drafts are excluded, including the open lesson.
String studentAbsenceHint(AttendanceSummary summary, int consecutive) => [
  if (summary.missedSlots >= 3 ||
      summary.nearAbsenceLimit ||
      summary.exceedsAbsenceLimit)
    'Đã nghỉ ${summary.missedSlots}${summary.hasSlotTotal ? '/${summary.totalSlots}' : ''} slot${summary.absenceRate == null ? '' : ' (${summary.absenceRate!.toStringAsFixed(0)}%)'}',
  if (summary.exceedsAbsenceLimit)
    'Cấm thi'
  else if (summary.missedSlots > 0 && summary.remainingAbsences == 0)
    'Đã chạm giới hạn'
  else if (summary.nearAbsenceLimit)
    'Còn được nghỉ ${summary.remainingAbsences} slot',
  if (consecutive >= 2) 'Nghỉ $consecutive slot liên tục',
  if (summary.pending > 0) '${summary.pending} slot chưa rõ kết quả',
].join(' · ');
