import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/attendance_history.dart';
import 'package:lecturer_companion/lab2/student_support.dart';

Data session(String id, int day, {int slot = 1, String status = 'finalized'}) =>
    {
      'id': id,
      'classId': 'c',
      'slot': slot,
      'status': status,
      'opensAt': DateTime.utc(2026, 10, day, slot).millisecondsSinceEpoch,
      'eligibleStudentUids': ['s'],
    };
Data mark(String id, String status) => {
  'attendanceSessionId': id,
  'studentUid': 's',
  'status': status,
};

void main() {
  test(
    '20 course slots: first absence is 5%, three warn, four allowed, five barred',
    () {
      AttendanceSummary summary(int n) =>
          AttendanceSummary(List.filled(n, 'absent'), totalSlots: 20);
      expect(summary(1).absenceRate, 5);
      expect(summary(1).exceedsAbsenceLimit, false);
      expect(summary(3).absenceRate, 15);
      expect(summary(3).nearAbsenceLimit, true);
      expect(summary(3).remainingAbsences, 1);
      expect(summary(4).absenceRate, 20);
      expect(summary(4).exceedsAbsenceLimit, false);
      expect(summary(4).remainingAbsences, 0);
      expect(summary(4).absenceWarning, contains('Đã chạm giới hạn'));
      expect(summary(5).absenceRate, 25);
      expect(summary(5).exceedsAbsenceLimit, true);
      expect(summary(5).absenceWarning, contains('Cấm thi'));
    },
  );
  test(
    'excused counts as a missed slot, late does not require a policy to calculate absence',
    () {
      final s = AttendanceSummary([
        'absent',
        'absent',
        'excused',
        'late',
        'present',
      ], totalSlots: 20);
      expect(s.missedSlots, 3);
      expect(s.absenceRate, 15);
      expect(
        studentAbsenceHint(s, 2),
        'Đã nghỉ 3/20 slot (15%) · Còn được nghỉ 1 slot · Nghỉ 2 slot liên tục',
      );
    },
  );
  test(
    'non-multiple of five allows only whole slots and never rounds a decision',
    () {
      final s = AttendanceSummary(List.filled(5, 'absent'), totalSlots: 22);
      expect(s.maxAbsences, 4);
      expect(s.exceedsAbsenceLimit, true);
      expect(
        AttendanceSummary(
          List.filled(4, 'absent'),
          totalSlots: 22,
        ).exceedsAbsenceLimit,
        false,
      );
    },
  );
  test(
    'missing or inconsistent course total never invents a percentage or exam decision',
    () {
      for (final total in [null, 0, -1, 2]) {
        final s = AttendanceSummary(
          List.filled(3, 'absent'),
          totalSlots: total,
        );
        expect(s.absenceRate, isNull);
        expect(s.exceedsAbsenceLimit, false);
      }
      expect(courseSlotTotal('20'), 20);
      for (final value in ['20.5', '-1', '0', '1001', '', null]) {
        expect(courseSlotTotal(value), isNull);
      }
    },
  );
  test(
    'each date and slot counts once, duplicate QR records/sessions cannot inflate absence',
    () {
      final slots = studentAttendanceSlots(
        's',
        [session('a', 1), session('copy', 1), session('b', 1, slot: 2)],
        [
          mark('a', 'absent'),
          mark('a', 'absent'),
          mark('copy', 'absent'),
          mark('b', 'excused'),
        ],
      );
      expect(slots.length, 2);
      expect(
        AttendanceSummary(
          slots.map((s) => '${s['status']}'),
          totalSlots: 20,
        ).missedSlots,
        2,
      );
    },
  );
  test(
    'unconfirmed, cancelled, open and reset slots do not count; missing or conflicting marks stay pending',
    () {
      final slots = studentAttendanceSlots(
        's',
        [
          session('a', 1),
          session('b', 2),
          session('c', 3, status: 'open'),
          session('d', 4, status: 'cancelled'),
          session('e', 5, status: 'reset'),
          {...session('f', 6), 'attendanceCompleted': false},
          {
            ...session('g', 7),
            'eligibleStudentUids': ['other'],
          },
        ],
        [mark('a', 'absent'), mark('a', 'present'), mark('f', 'absent')],
      );
      expect(slots.map((s) => s['status']), ['pending', 'pending']);
      final summary = AttendanceSummary(
        slots.map((s) => '${s['status']}'),
        totalSlots: 20,
      );
      expect(summary.missedSlots, 0);
      expect(summary.pending, 2);
      expect(summary.absenceWarning, contains('chưa rõ kết quả'));
    },
  );
  test(
    'consecutive slots include excused, count two slots on one day, and stop at present',
    () {
      final sessions = [
        session('a', 1),
        session('b', 2),
        session('c', 2, slot: 2),
      ];
      final records = [
        mark('a', 'present'),
        mark('b', 'absent'),
        mark('c', 'excused'),
      ];
      expect(consecutiveAbsences('s', sessions, records).map((s) => s['id']), [
        'c',
        'b',
      ]);
      expect(
        consecutiveAbsences('s', sessions, [...records, mark('c', 'present')]),
        isEmpty,
      );
    },
  );
  test(
    'slot aggregation preserves the saved note and check-in time for report exports',
    () {
      final rows = studentAttendanceSlots(
        's',
        [session('a', 1)],
        [
          {
            ...mark('a', 'present'),
            'notes': 'Checked in classroom',
            'checkedInAt': 123456789,
          },
        ],
      );
      expect(rows.single['notes'], 'Checked in classroom');
      expect(rows.single['checkedInAt'], 123456789);
    },
  );
}
