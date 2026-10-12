import 'domain.dart';
import 'repository.dart';

DateTime campusDay(DateTime instant) {
  final local = instant.toUtc().add(const Duration(hours: 7));
  return DateTime.utc(local.year, local.month, local.day);
}

DateTime weekStart(DateTime day) =>
    day.subtract(Duration(days: day.weekday - 1));
String timetableDate(DateTime day) =>
    '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}';
String teachingDayName(int weekday) => const [
  'Thứ 2',
  'Thứ 3',
  'Thứ 4',
  'Thứ 5',
  'Thứ 6',
  'Thứ 7',
  'Chủ nhật',
][weekday - 1];
int? teachingMinutes(dynamic value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch('$value');
  if (match == null) return null;
  final h = int.parse(match[1]!), m = int.parse(match[2]!);
  return h < 24 && m < 60 ? h * 60 + m : null;
}

String teachingTime(int value) =>
    '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
int? teachingSlot(dynamic value) {
  final slot = int.tryParse('$value');
  return slot != null && slot >= 1 && slot <= 12 ? slot : null;
}

class TeachingPeriod {
  final DateTime day;
  final String? classId, sessionId, scheduleId, exceptionId;
  final String classCode, subjectId, subjectName, room, term;
  final int? slot;
  final int start, end;
  final bool recurring, completed, cancelled;
  const TeachingPeriod({
    required this.day,
    required this.classId,
    required this.sessionId,
    required this.classCode,
    required this.subjectId,
    required this.subjectName,
    required this.room,
    required this.term,
    required this.slot,
    required this.start,
    required this.end,
    required this.recurring,
    this.completed = false,
    this.cancelled = false,
    this.scheduleId,
    this.exceptionId,
  });
  String get sessionDate => day.toIso8601String().substring(0, 10);
  DateTime get scheduledStartAt => day.add(Duration(minutes: start - 420));
  DateTime get scheduledEndAt =>
      day.add(Duration(minutes: end - 420 + (end < start ? 1440 : 0)));
  Data get selector => {
    'classId': classId,
    'sessionDate': sessionDate,
    'slot': slot,
    if (scheduleId != null) 'scheduleId': scheduleId,
    if (exceptionId != null) 'exceptionId': exceptionId,
    if (sessionId != null) 'sessionId': sessionId,
  };
  String get timeRange => '${teachingTime(start)} – ${teachingTime(end)}';
  bool overlaps(TeachingPeriod other) =>
      scheduledStartAt.isBefore(other.scheduledEndAt) &&
      other.scheduledStartAt.isBefore(scheduledEndAt);
}

List<TeachingPeriod> teachingPeriods({
  required UserProfile user,
  required DateTime day,
  required String term,
  required List<Data> schedules,
  required List<Data> classes,
  required List<Data> sessions,
  List<Data> exceptions = const [],
  bool includeCancelled = false,
}) {
  final periods = <TeachingPeriod>[];
  final assigned = {for (final c in classes) c['id'] as String: c};
  for (final s in schedules) {
    if (s['lecturerUid'] != user.uid || s['term'] != term) {
      continue;
    }
    final start = teachingMinutes(s['startTime']),
        end = teachingMinutes(s['endTime']);
    if (start == null || end == null || end == start) continue;
    final matches = classes
        .where(
          (c) =>
              c['classCode'] == s['classCode'] &&
              c['subjectId'] == s['subjectId'] &&
              c['term'] == term,
        )
        .toList();
    final cls = matches.length == 1 ? matches.single : null;
    final date = day.toIso8601String().substring(0, 10);
    final changes = exceptions
        .where(
          (e) =>
              cls != null &&
              e['scheduleId'] == s['id'] &&
              e['classId'] == cls['id'],
        )
        .toList();
    final override = changes
        .where((e) => e['date'] == date && e['kind'] != 'MAKEUP')
        .firstOrNull;
    final occurrences = <Data>[];
    if (int.tryParse('${s['dayOfWeek']}') == day.weekday &&
        !['CANCELLED', 'RESCHEDULED'].contains(override?['kind'])) {
      occurrences.add(override ?? s);
    }
    if (includeCancelled &&
        override?['kind'] == 'CANCELLED' &&
        int.tryParse('${s['dayOfWeek']}') == day.weekday) {
      occurrences.add({...s, ...override!, 'cancelled': true});
    }
    occurrences.addAll(
      changes.where(
        (e) =>
            e['targetDate'] == date &&
            ['RESCHEDULED', 'MAKEUP'].contains(e['kind']),
      ),
    );
    for (final occurrence in occurrences) {
      final from = teachingMinutes(occurrence['startTime']),
          to = teachingMinutes(occurrence['endTime']);
      if (from == null || to == null || to == from) continue;
      periods.add(
        TeachingPeriod(
          day: day,
          classId: cls?['id'] as String?,
          sessionId: null,
          scheduleId: '${s['id']}',
          exceptionId: identical(occurrence, s) ? '' : '${occurrence['id']}',
          classCode: '${s['classCode'] ?? ''}',
          subjectId: '${s['subjectId'] ?? ''}',
          subjectName: '${s['subjectName'] ?? cls?['subjectName'] ?? ''}',
          room: '${occurrence['room'] ?? ''}',
          term: term,
          slot: teachingSlot(occurrence['slot']),
          start: from,
          end: to,
          recurring: true,
          cancelled: occurrence['cancelled'] == true,
        ),
      );
    }
  }
  for (final s in sessions) {
    final cls = assigned[s['classId']];
    if (cls == null ||
        cls['term'] != term ||
        s['lecturerUid'] != user.uid ||
        s['status'] == 'reset') {
      continue;
    }
    if (s['startsAt'] == null || s['endsAt'] == null) continue;
    final startAt = dateValue(s['startsAt']), endAt = dateValue(s['endsAt']);
    if (campusDay(startAt) != day || !endAt.isAfter(startAt)) {
      continue;
    }
    final localStart = startAt.toUtc().add(const Duration(hours: 7)),
        localEnd = endAt.toUtc().add(const Duration(hours: 7));
    final slot =
        teachingSlot(s['slot']) ??
        teachingSlot(RegExp(r'^Slot\s+(\d+)$').firstMatch('${s['title']}')?[1]);
    final existing = periods
        .where((p) => p.classId == cls['id'] && p.slot == slot && slot != null)
        .toList();
    final room =
        '${s['room'] ?? (existing.isEmpty ? '' : existing.first.room)}';
    periods.removeWhere(
      (p) =>
          p.recurring &&
          p.classId == cls['id'] &&
          p.slot == slot &&
          slot != null,
    );
    if (s['status'] == 'cancelled') continue;
    periods.add(
      TeachingPeriod(
        day: day,
        classId: cls['id'] as String,
        sessionId: s['id'] as String,
        scheduleId: existing.firstOrNull?.scheduleId,
        exceptionId: existing.firstOrNull?.exceptionId,
        classCode: '${cls['classCode']}',
        subjectId: '${cls['subjectId']}',
        subjectName: '${cls['subjectName'] ?? ''}',
        room: room,
        term: term,
        slot: slot,
        start: localStart.hour * 60 + localStart.minute,
        end: localEnd.hour * 60 + localEnd.minute,
        recurring: false,
        completed: s['status'] == 'completed',
      ),
    );
  }
  periods.sort(
    (a, b) => a.start != b.start
        ? a.start.compareTo(b.start)
        : (a.slot ?? 99).compareTo(b.slot ?? 99),
  );
  return periods;
}
