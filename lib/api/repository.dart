import 'dart:math';
import '../core/config.dart';
import '../models/domain.dart';
import 'client.dart';

class Overview {
  final List<TeachingClass> classes;
  final List<Schedule> schedules;
  final List<TeachingSession> sessions;
  const Overview(this.classes, this.schedules, this.sessions);
  TeachingClass? classFor(String id) {
    final matches = classes.where((c) => c.classId == id).toList();
    return matches.length == 1 ? matches.single : null;
  }

  TeachingClass? mappedClass(Schedule schedule) {
    final matches = classes.where((c) => c.key == schedule.key).toList();
    return matches.length == 1 ? matches.single : null;
  }
}

class SessionAttendance {
  final TeachingSession session;
  final List<Student> roster;
  final List<AttendanceRecord> records;
  SessionAttendance(this.session, this.roster, this.records) {
    final identities = <String>{};
    for (final record in records) {
      if (record.sessionId != session.sessionId ||
          record.studentId.isEmpty ||
          !identities.add(record.studentId)) {
        throw const AppFailure(
          'Attendance contains duplicate or mismatched records. Ask the administrator to review it.',
        );
      }
    }
  }
  AttendanceRecord? recordFor(Student student) {
    for (final record in records) {
      if (record.studentId == student.studentId) return record;
    }
    return null;
  }

  int count(String status) => records.where((r) => r.status == status).length;
  int get unrecorded => roster.where((s) => recordFor(s) == null).length;
  int get reportAbsent => count('ABSENT') + unrecorded;
}

class LecturerRepository {
  final ApplicationApi api;
  LecturerRepository(this.api);
  Future<List<Json>> rows(String action, [Json payload = const {}]) async {
    final result = await api.call(action, payload);
    if (result is! List || result.any((r) => r is! Map)) {
      throw const AppFailure('The server returned invalid data.');
    }
    return result.map((r) => Json.from(r as Map)).toList();
  }

  Future<Lecturer> profile() async {
    final result = await api.call('profile');
    if (result is! Map) {
      throw const AppFailure(
        'The server returned an invalid lecturer profile.',
      );
    }
    final profile = Lecturer.fromJson(Json.from(result));
    if (profile.lecturerId.isEmpty || profile.email.isEmpty) {
      throw const AppFailure('A registered lecturer profile is required.');
    }
    return profile;
  }

  Future<Overview> overview(String owner) async {
    final data = await Future.wait([
      rows('getRows', {'sheet': 'Classes'}),
      rows('getRows', {'sheet': 'Schedules'}),
      rows('getRows', {'sheet': 'Sessions'}),
    ]);
    return Overview(
      data[0]
          .map(TeachingClass.fromJson)
          .where((c) => c.lecturerId == owner)
          .toList(),
      data[1]
          .map(Schedule.fromJson)
          .where((s) => s.lecturerId == owner)
          .toList(),
      data[2]
          .map(TeachingSession.fromJson)
          .where((s) => s.createdBy == owner && s.status != 'RESET')
          .toList()
        ..sort(
          (a, b) =>
              '${b.date} ${b.startTime}'.compareTo('${a.date} ${a.startTime}'),
        ),
    );
  }

  Future<List<Student>> roster(TeachingClass cls) async => (await rows(
    'getRoster',
    cls.rosterTarget,
  )).map(Student.fromJson).toList();
  Future<List<AttendanceRecord>> history(TeachingClass cls) async =>
      (await rows('getClassHistory', {
        'classId': cls.classId,
      })).map(AttendanceRecord.fromJson).toList();
  Future<SessionAttendance> attendance(
    TeachingClass cls,
    String sessionId,
    String owner,
  ) async {
    final results = await Future.wait([
      rows('getRows', {'sheet': 'Sessions'}),
      rows('getRoster', cls.rosterTarget),
      rows('getSessionAttendance', {'sessionId': sessionId}),
    ]);
    final matches = results[0]
        .map(TeachingSession.fromJson)
        .where(
          (s) =>
              s.sessionId == sessionId &&
              s.classId == cls.classId &&
              s.createdBy == owner,
        )
        .toList();
    if (matches.length != 1 || !matches.single.editable) {
      throw const AppFailure('This session is unavailable or has been reset.');
    }
    return SessionAttendance(
      matches.single,
      results[1].map(Student.fromJson).toList(),
      results[2].map(AttendanceRecord.fromJson).toList(),
    );
  }

  Future<TeachingSession> start(
    TeachingClass cls,
    Schedule schedule,
    String date,
  ) async {
    if (CampusClock.minutes(schedule.startTime) == null ||
        CampusClock.minutes(schedule.endTime) == null ||
        schedule.startTime.compareTo(schedule.endTime) >= 0 ||
        schedule.slot < 1 ||
        schedule.slot > 12) {
      throw const AppFailure(
        'The schedule has invalid times or slot. Correct it in the source system.',
      );
    }
    final result = await api.call('createSession', {
      'classId': cls.classId,
      'date': date,
      'slot': schedule.slot,
      'startTime': schedule.startTime,
      'endTime': schedule.endTime,
      ...newQrCredentials(),
    });
    return TeachingSession.fromJson(Json.from(result as Map));
  }

  Future<void> update(
    SessionAttendance data,
    Student student,
    String status,
    String note,
  ) async {
    if (!data.session.editable ||
        !['PRESENT', 'LATE', 'ABSENT'].contains(status)) {
      throw const AppFailure('This attendance change is not allowed.');
    }
    await confirmed('updateAttendance', {
      'sessionId': data.session.sessionId,
      'studentCode': student.studentCode,
      'attendanceId': data.recordFor(student)?.attendanceId ?? '',
      'status': status,
      'note': note,
    });
  }

  Future<void> finish(SessionAttendance data) async {
    final id = data.session.sessionId;
    if (data.session.isOpen) {
      final response = await api.call('closeSession', {'sessionId': id});
      if (response is! Map || response['closed'] != true) {
        throw const AppFailure(
          'The server did not confirm closing. Refresh before retrying.',
        );
      }
    }
    try {
      await confirmed('markAbsent', {
        'sessionId': id,
        'studentCodes': data.roster.map((s) => s.studentCode).toList(),
      });
    } on AppFailure catch (error) {
      if (error.unauthenticated) rethrow;
      throw const AppFailure(
        'The session is closed, but absence finalization was not confirmed. Refresh, then tap Finalize missing attendance.',
      );
    }
  }

  Future<void> rotate(TeachingSession session, {required bool secret}) async {
    if (!session.isOpen) {
      throw const AppFailure('Only an open session can display a new QR code.');
    }
    await confirmed('rotateToken', {
      'sessionId': session.sessionId,
      ...newQrCredentials(secret: secret),
    });
  }

  Future<void> confirmed(String action, Json payload) async {
    final response = await api.call(action, payload);
    if (response is! Map || response['saved'] != true) {
      throw const AppFailure(
        'The server did not confirm saving. Refresh before retrying.',
      );
    }
  }

  static Json newQrCredentials({bool secret = false}) {
    final random = Random.secure();
    return {
      'currentToken': List.generate(
        24,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join(),
      'currentSecretCode': secret
          ? (100000 + random.nextInt(900000)).toString()
          : '',
      'tokenExpiredAt': DateTime.now()
          .toUtc()
          .add(const Duration(seconds: 120))
          .toIso8601String(),
    };
  }
}

Uri checkinUri(String base, TeachingSession session) {
  final uri = Uri.tryParse(base);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.host == 'localhost' ||
      uri.host == '127.0.0.1') {
    throw const AppFailure(
      'Configure the existing HTTPS student check-in page to enable QR attendance.',
    );
  }
  return uri.replace(
    queryParameters: {
      'sessionId': session.sessionId,
      'token': session.currentToken,
      'mode': session.currentSecretCode.isEmpty ? 'google' : 'secret',
      'v': '2',
    },
  );
}
