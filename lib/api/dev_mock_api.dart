import 'dart:math';
import '../models/domain.dart';
import 'client.dart';

class DevMockApi implements ApplicationApi {
  final Map<String, dynamic> lecturer = {
    'lecturerId': 'lec-demo',
    'lecturerCode': 'GV_TOAN',
    'fullName': 'Nguyễn Văn Toàn',
    'email': 'toannvse181848@fpt.edu.vn',
    'department': 'Software Engineering',
  };

  final List<Json> classes = [
    {
      'classId': 'cls-prm393',
      'semester': 'FA26',
      'subjectCode': 'PRM393',
      'subjectName': 'Mobile Programming',
      'classCode': 'SE1901',
      'lecturerId': 'lec-demo',
    },
    {
      'classId': 'cls-swd392',
      'semester': 'FA26',
      'subjectCode': 'SWD392',
      'subjectName': 'Software Architecture & Design',
      'classCode': 'SE1902',
      'lecturerId': 'lec-demo',
    },
  ];

  late final List<Json> schedules = [
    {
      'scheduleId': 'sch-1',
      'semester': 'FA26',
      'subjectCode': 'PRM393',
      'subjectName': 'Mobile Programming',
      'classCode': 'SE1901',
      'dayOfWeek': CampusClock.now().weekday,
      'slot': 1,
      'startTime': '07:30',
      'endTime': '09:50',
      'room': 'BE-302',
      'lecturerId': 'lec-demo',
      'sourceType': 'MANUAL',
    },
    {
      'scheduleId': 'sch-2',
      'semester': 'FA26',
      'subjectCode': 'SWD392',
      'subjectName': 'Software Architecture & Design',
      'classCode': 'SE1902',
      'dayOfWeek': CampusClock.now().weekday,
      'slot': 2,
      'startTime': '10:00',
      'endTime': '12:20',
      'room': 'BE-305',
      'lecturerId': 'lec-demo',
      'sourceType': 'MANUAL',
    },
    {
      'scheduleId': 'sch-3',
      'semester': 'FA26',
      'subjectCode': 'PRM393',
      'subjectName': 'Mobile Programming',
      'classCode': 'SE1901',
      'dayOfWeek': (CampusClock.now().weekday % 7) + 1,
      'slot': 3,
      'startTime': '12:50',
      'endTime': '15:10',
      'room': 'BE-302',
      'lecturerId': 'lec-demo',
      'sourceType': 'MANUAL',
    },
  ];

  late final List<Json> sessions = [
    {
      'sessionId': 'sess-1',
      'classId': 'cls-prm393',
      'date': CampusClock.date(CampusClock.now()),
      'slot': 1,
      'startTime': '07:30',
      'endTime': '09:50',
      'status': 'OPEN',
      'currentToken': 'DEMO-TOKEN-PRM393#8888',
      'currentSecretCode': '8888',
      'tokenExpiredAt': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
      'createdBy': 'lec-demo',
    },
  ];

  final Map<String, List<Json>> rosters = {
    'FA26_PRM393_SE1901': [
      {
        'studentId': 'std-1',
        'studentCode': 'SE181848',
        'fullName': 'Nguyễn Văn Toàn',
        'schoolEmail': 'toannvse181848@fpt.edu.vn',
        'classCode': 'SE1901',
      },
      {
        'studentId': 'std-2',
        'studentCode': 'SE181849',
        'fullName': 'Trần Minh Quân',
        'schoolEmail': 'quantmse181849@fpt.edu.vn',
        'classCode': 'SE1901',
      },
      {
        'studentId': 'std-3',
        'studentCode': 'SE181850',
        'fullName': 'Lê Hoàng Nam',
        'schoolEmail': 'namlhse181850@fpt.edu.vn',
        'classCode': 'SE1901',
      },
      {
        'studentId': 'std-4',
        'studentCode': 'SE181851',
        'fullName': 'Phạm Thuỳ Trang',
        'schoolEmail': 'trangptse181851@fpt.edu.vn',
        'classCode': 'SE1901',
      },
    ],
    'FA26_SWD392_SE1902': [
      {
        'studentId': 'std-5',
        'studentCode': 'SE181852',
        'fullName': 'Hoàng Gia Bảo',
        'schoolEmail': 'baohgse181852@fpt.edu.vn',
        'classCode': 'SE1902',
      },
      {
        'studentId': 'std-6',
        'studentCode': 'SE181853',
        'fullName': 'Đỗ Phương Anh',
        'schoolEmail': 'anhdpse181853@fpt.edu.vn',
        'classCode': 'SE1902',
      },
    ],
  };

  final List<Json> attendanceRecords = [
    {
      'attendanceId': 'att-1',
      'sessionId': 'sess-1',
      'studentId': 'std-1',
      'studentCode': 'SE181848',
      'fullName': 'Nguyễn Văn Toàn',
      'schoolEmail': 'toannvse181848@fpt.edu.vn',
      'status': 'PRESENT',
      'method': 'MANUAL',
      'updatedAt': DateTime.now().toIso8601String(),
    },
  ];

  @override
  Future<dynamic> call(String action, [Json payload = const {}]) async {
    // Add small delay to mimic async behavior
    await Future<void>.delayed(const Duration(milliseconds: 150));

    switch (action) {
      case 'profile':
        return lecturer;

      case 'getRows':
        final sheet = payload['sheet'];
        if (sheet == 'Classes') return List<Json>.from(classes);
        if (sheet == 'Schedules') return List<Json>.from(schedules);
        if (sheet == 'Sessions') return List<Json>.from(sessions);
        return <Json>[];

      case 'getRoster':
        final sem = payload['semester'] ?? '';
        final subj = payload['subjectCode'] ?? '';
        final code = payload['classCode'] ?? '';
        final key = mappingKey(sem.toString(), subj.toString(), code.toString());
        return List<Json>.from(rosters[key] ?? rosters.values.first);

      case 'getSessionAttendance':
        final sid = payload['sessionId'];
        return attendanceRecords.where((r) => r['sessionId'] == sid).toList();

      case 'getClassHistory':
        return attendanceRecords;

      case 'createSession':
        final sid = 'sess-${DateTime.now().millisecondsSinceEpoch}';
        final newSess = {
          'sessionId': sid,
          'classId': payload['classId'] ?? 'cls-prm393',
          'date': payload['date'] ?? CampusClock.date(CampusClock.now()),
          'slot': payload['slot'] ?? 1,
          'startTime': payload['startTime'] ?? '07:30',
          'endTime': payload['endTime'] ?? '09:50',
          'status': 'OPEN',
          'currentToken': 'DEMO-TOKEN-${Random().nextInt(999999)}#1234',
          'currentSecretCode': '1234',
          'tokenExpiredAt': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
          'createdBy': 'lec-demo',
        };
        sessions.add(newSess);
        return newSess;

      case 'closeSession':
        final sid = payload['sessionId'];
        for (final s in sessions) {
          if (s['sessionId'] == sid) {
            s['status'] = 'CLOSED';
          }
        }
        return {'closed': true};

      case 'rotateToken':
        final sid = payload['sessionId'];
        for (final s in sessions) {
          if (s['sessionId'] == sid) {
            final code = (1000 + Random().nextInt(9000)).toString();
            s['currentToken'] = 'DEMO-TOKEN-${Random().nextInt(999999)}#$code';
            s['currentSecretCode'] = code;
            s['tokenExpiredAt'] = DateTime.now().add(const Duration(minutes: 5)).toIso8601String();
            return s;
          }
        }
        return {'saved': true};

      case 'updateAttendance':
        final sid = payload['sessionId'];
        final stid = payload['studentId'];
        final status = payload['status'];
        final existing = attendanceRecords.firstWhere(
          (r) => r['sessionId'] == sid && r['studentId'] == stid,
          orElse: () => <String, dynamic>{},
        );
        if (existing.isNotEmpty) {
          existing['status'] = status;
          existing['updatedAt'] = DateTime.now().toIso8601String();
        } else {
          attendanceRecords.add({
            'attendanceId': 'att-${DateTime.now().millisecondsSinceEpoch}',
            'sessionId': sid,
            'studentId': stid,
            'status': status,
            'updatedAt': DateTime.now().toIso8601String(),
          });
        }
        return {'saved': true};

      case 'markAbsent':
        return {'saved': true};

      case 'batchUpdate':
        final sheet = payload['sheet'];
        if (sheet == 'Schedules') {
          final rows = (payload['rows'] as List? ?? []).cast<Map>();
          final updated = <Json>[];
          for (final row in rows) {
            final map = Map<String, dynamic>.from(row);
            if ((map['scheduleId'] ?? '').toString().isEmpty) {
              map['scheduleId'] = 'sch-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999)}';
            }
            schedules.removeWhere((s) => s['scheduleId'] == map['scheduleId']);
            schedules.add(map);
            updated.add(map);
          }
          return updated;
        }
        return payload['rows'] ?? [];

      case 'deleteRow':
        final sheet = payload['sheet'];
        final id = payload['id'];
        if (sheet == 'Schedules') {
          schedules.removeWhere((s) => s['scheduleId'] == id);
        }
        return {'saved': true};

      case 'importRoster':
        final sem = payload['semester'] ?? 'FA26';
        final subj = payload['subjectCode'] ?? 'PRM393';
        final code = payload['classCode'] ?? 'SE1901';
        final rawStudents = (payload['students'] as List? ?? []).cast<Map>();
        final key = mappingKey(sem.toString(), subj.toString(), code.toString());

        final converted = rawStudents.map((s) => {
          'studentId': 'std-${Random().nextInt(999999)}',
          'studentCode': s['studentCode'] ?? s['rollNumber'] ?? '',
          'fullName': s['fullName'] ?? '',
          'schoolEmail': s['schoolEmail'] ?? s['email'] ?? '',
          'classCode': code,
        }).toList();

        rosters[key] = converted;

        // Auto create class if not exists
        if (!classes.any((c) => c['semester'] == sem && c['subjectCode'] == subj && c['classCode'] == code)) {
          classes.add({
            'classId': 'cls-${DateTime.now().millisecondsSinceEpoch}',
            'semester': sem,
            'subjectCode': subj,
            'subjectName': subj,
            'classCode': code,
            'lecturerId': 'lec-demo',
          });
        }

        return {
          'added': converted.length,
          'existing': 0,
          'classId': 'cls-auto',
        };

      default:
        return {'success': true};
    }
  }
}
