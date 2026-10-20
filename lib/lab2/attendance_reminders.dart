import 'domain.dart';
import 'timetable_card.dart' show roomLabel;
import 'timetable_domain.dart';

/// A lesson that has already ended without completed attendance (not
/// cancelled, linked to an assigned class). Drafts never count as done.
/// A lesson still in progress is shown as the "Đang dạy" card and gets the
/// before-end reminder instead, so it is not listed twice.
bool attendancePending(TeachingPeriod p, DateTime now) =>
    !p.cancelled &&
    !p.completed &&
    p.classId != null &&
    campusDay(now) == p.day &&
    !p.scheduledEndAt.isAfter(now);

List<TeachingPeriod> pendingAttendancePeriods(
  List<TeachingPeriod> periods,
  DateTime now,
) =>
    periods.where((p) => attendancePending(p, now)).toList()
      ..sort((a, b) => a.scheduledStartAt.compareTo(b.scheduledStartAt));

class AttendanceReminder {
  /// Stable per lesson and kind, so the same event is never scheduled twice.
  final String key;
  final DateTime at;
  final String title, body;
  final Data selector;
  const AttendanceReminder({
    required this.key,
    required this.at,
    required this.title,
    required this.body,
    required this.selector,
  });
}

String _lessonLabel(TeachingPeriod p) => [
  'Lớp ${p.classCode}',
  if (p.slot != null) 'Slot ${p.slot}',
  if (p.room.isNotEmpty) roomLabel(p.room),
].join(' · ');

/// Bounded follow-ups for forgotten attendance, all before the day closes.
List<AttendanceReminder> planAttendanceReminders(
  List<TeachingPeriod> periods,
  DateTime now,
) {
  final out = <AttendanceReminder>[];
  final seen = <String>{};
  for (final p in periods) {
    if (p.cancelled || p.completed || p.classId == null || p.slot == null) {
      continue;
    }
    final id =
        '${p.classId}|${p.sessionDate}|${p.slot}|${p.scheduleId ?? ''}|${p.exceptionId ?? ''}';
    if (!seen.add(id)) continue;
    final deadline = p.day.add(const Duration(days: 1, hours: -7));
    final middle = p.scheduledStartAt.add(
      Duration(
        milliseconds:
            p.scheduledEndAt.difference(p.scheduledStartAt).inMilliseconds ~/ 2,
      ),
    );
    final evening = p.day.add(const Duration(hours: 14));
    final times = <DateTime>{};
    for (final entry in [
      ('mid', middle),
      if (p.scheduledEndAt.isAfter(p.scheduledStartAt)) ...[
        if (p.scheduledEndAt
            .subtract(const Duration(minutes: 5))
            .isAfter(middle))
          ('before-end', p.scheduledEndAt.subtract(const Duration(minutes: 5))),
        ('overdue', p.scheduledEndAt.add(const Duration(minutes: 10))),
      ],
      ('evening', evening),
    ]) {
      if (!entry.$2.isAfter(now) || !entry.$2.isBefore(deadline)) continue;
      if (entry.$1 == 'evening' && p.scheduledStartAt.isAfter(evening)) {
        continue;
      }
      if (!times.add(entry.$2)) continue;
      out.add(
        AttendanceReminder(
          key: '${entry.$1}|$id',
          at: entry.$2,
          title: 'Nhắc điểm danh · ${p.classCode}',
          body:
              '${_lessonLabel(p)} ngày ${p.sessionDate} chưa hoàn tất điểm danh. Chạm để điểm danh nhanh trước 00:00.',
          selector: p.selector,
        ),
      );
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}
