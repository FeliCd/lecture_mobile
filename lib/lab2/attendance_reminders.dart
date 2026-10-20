import 'domain.dart';
import 'timetable_card.dart' show roomLabel;
import 'timetable_domain.dart';

/// F02 reminder offsets. ASSUMPTION pending team decision (handoff §11):
/// the 10–15 minute values from the interview summary are not final.
const attendanceReminderBeforeStart = Duration(minutes: 10);
const attendanceReminderBeforeEnd = Duration(minutes: 10);

/// A lesson that has already ended without completed attendance (not
/// cancelled, linked to an assigned class). Drafts never count as done.
/// A lesson still in progress is shown as the "Đang dạy" card and gets the
/// before-end reminder instead, so it is not listed twice.
bool attendancePending(TeachingPeriod p, DateTime now) =>
    !p.cancelled &&
    !p.completed &&
    p.classId != null &&
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

/// Schedule reminders (before start) and "not finished" reminders (before
/// end) for future lessons only. Completed or cancelled lessons produce
/// nothing, so re-planning after a save removes their pending reminders.
List<AttendanceReminder> planAttendanceReminders(
  List<TeachingPeriod> periods,
  DateTime now, {
  Duration beforeStart = attendanceReminderBeforeStart,
  Duration beforeEnd = attendanceReminderBeforeEnd,
}) {
  final out = <AttendanceReminder>[];
  for (final p in periods) {
    if (p.cancelled || p.completed || p.classId == null) continue;
    final id =
        '${p.classId}|${p.sessionDate}|${p.slot}|${p.scheduleId ?? ''}|${p.exceptionId ?? ''}';
    final start = p.scheduledStartAt.subtract(beforeStart);
    if (start.isAfter(now)) {
      out.add(
        AttendanceReminder(
          key: 'start|$id',
          at: start,
          title: 'Sắp đến giờ dạy',
          body:
              '${_lessonLabel(p)} bắt đầu lúc ${teachingTime(p.start)}. Chạm để mở buổi.',
          selector: p.selector,
        ),
      );
    }
    final end = p.scheduledEndAt.subtract(beforeEnd);
    if (end.isAfter(now)) {
      out.add(
        AttendanceReminder(
          key: 'end|$id',
          at: end,
          title: 'Điểm danh chưa hoàn tất',
          body: '${_lessonLabel(p)} sắp kết thúc. Điểm danh chưa hoàn tất.',
          selector: p.selector,
        ),
      );
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}
