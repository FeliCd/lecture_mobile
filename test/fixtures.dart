import 'dart:convert';
import 'package:lecturer_companion/api/client.dart';
import 'package:lecturer_companion/features/auth/auth.dart';
import 'package:lecturer_companion/models/domain.dart';

// Explicit test fixtures only. Never imported by lib/.
final lecturerJson = <String, dynamic>{
  'lecturerId': 'lec-1',
  'lecturerCode': 'GV01',
  'fullName': 'Test Lecturer',
  'email': 'lecturer@fpt.edu.vn',
  'department': 'Computing',
};
final classJson = <String, dynamic>{
  'classId': 'class-1',
  'semester': 'FA26',
  'subjectCode': 'PRM393',
  'subjectName': 'Mobile Programming',
  'classCode': 'SE1901',
  'lecturerId': 'lec-1',
};
final studentJson = <String, dynamic>{
  'studentId': 'std-1',
  'studentCode': 'SE123456',
  'fullName': 'Test Student',
  'schoolEmail': 'student@fpt.edu.vn',
};
Json sessionJson({String status = 'OPEN'}) => {
  'sessionId': 'session-1',
  'classId': 'class-1',
  'date': CampusClock.date(CampusClock.now()),
  'slot': 1,
  'startTime': '00:00',
  'endTime': '23:59',
  'status': status,
  'currentToken': 'test-qr-token',
  'tokenExpiredAt': DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 2))
      .toIso8601String(),
  'createdBy': 'lec-1',
};
Json scheduleJson() => {
  'scheduleId': 'schedule-1',
  ...classJson,
  'dayOfWeek': CampusClock.now().weekday,
  'slot': 1,
  'startTime': '00:00',
  'endTime': '23:59',
  'room': 'Room 201',
};
String validToken() =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.signature';

class MemoryVault implements TokenVault {
  String? value;
  @override
  Future<void> clear() async {
    value = null;
  }

  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String token) async {
    value = token;
  }
}

class TestIdentity implements IdentityProvider {
  bool signedOut = false;
  @override
  Future<String?> signIn({bool silently = false}) async => validToken();
  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

class FixtureApi implements ApplicationApi {
  final calls = <(String, Json)>[];
  final records = <Json>[];
  String status = 'OPEN';
  bool empty = false;
  bool deny = false;
  @override
  Future<dynamic> call(String action, [Json payload = const {}]) async {
    calls.add((action, payload));
    if (deny) throw StateError('Private backend trace');
    switch (action) {
      case 'profile':
        return lecturerJson;
      case 'getRows':
        return empty
            ? <Json>[]
            : switch (payload['sheet']) {
                'Classes' => [classJson],
                'Schedules' => [scheduleJson()],
                'Sessions' => [sessionJson(status: status)],
                _ => <Json>[],
              };
      case 'getRoster':
        return empty ? <Json>[] : [studentJson];
      case 'getSessionAttendance':
      case 'getClassHistory':
        return records;
      case 'createSession':
        return sessionJson(status: status);
      case 'closeSession':
        status = 'CLOSED';
        return {'closed': true};
      case 'markAbsent':
        if (records.isEmpty) records.add(record('ABSENT'));
        return {'saved': true};
      case 'updateAttendance':
        records.clear();
        records.add(record(payload['status'] as String));
        return {'saved': true};
      case 'rotateToken':
        return {'saved': true};
      default:
        throw StateError('Unexpected test action: $action');
    }
  }

  Json record(String value) => {
    'attendanceId': 'att-1',
    'sessionId': 'session-1',
    ...studentJson,
    'status': value,
  };
}
