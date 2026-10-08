typedef Json = Map<String, dynamic>;
String text(Json j, String key) => '${j[key] ?? ''}'.trim();
int number(Json j, String key) => int.tryParse(text(j, key)) ?? 0;
String normalizeCode(String value) => value.trim().toUpperCase();
String mappingKey(String semester, String subject, String code) =>
    [semester, subject, code].map(normalizeCode).join('_');

class Lecturer {
  final String lecturerId, lecturerCode, fullName, email, department;
  Lecturer.fromJson(Json j)
    : lecturerId = text(j, 'lecturerId'),
      lecturerCode = text(j, 'lecturerCode'),
      fullName = text(j, 'fullName'),
      email = text(j, 'email'),
      department = text(j, 'department');
}

class ClassModel {
  final String classId,
      semester,
      subjectCode,
      subjectName,
      classCode,
      lecturerId;
  ClassModel({
    required this.classId,
    required this.semester,
    required this.subjectCode,
    required this.subjectName,
    required this.classCode,
    required this.lecturerId,
  });

  ClassModel.fromJson(Json j)
    : classId = text(j, 'classId'),
      semester = text(j, 'semester'),
      subjectCode = text(j, 'subjectCode'),
      subjectName = text(j, 'subjectName'),
      classCode = text(j, 'classCode'),
      lecturerId = text(j, 'lecturerId');

  String get key => mappingKey(semester, subjectCode, classCode);
  Json get rosterTarget => {
    'semester': semester,
    'subjectCode': subjectCode,
    'classCode': classCode,
  };

  Json toJson() => {
    'classId': classId,
    'semester': semester,
    'subjectCode': subjectCode,
    'subjectName': subjectName,
    'classCode': classCode,
    'lecturerId': lecturerId,
  };
}

typedef TeachingClass = ClassModel;

class Student {
  final String studentId, studentCode, fullName, schoolEmail;
  Student.fromJson(Json j)
    : studentId = text(j, 'studentId'),
      studentCode = text(j, 'studentCode'),
      fullName = text(j, 'fullName'),
      schoolEmail = text(j, 'schoolEmail');
}

class RosterStudent {
  final String classCode;
  final String studentCode;
  final String fullName;
  final String schoolEmail;

  RosterStudent({
    required this.classCode,
    required this.studentCode,
    required this.fullName,
    this.schoolEmail = '',
  });

  RosterStudent.fromJson(Json j)
    : classCode = text(j, 'classCode'),
      studentCode = text(j, 'studentCode').isNotEmpty
          ? text(j, 'studentCode')
          : text(j, 'rollNumber'),
      fullName = text(j, 'fullName'),
      schoolEmail = text(j, 'schoolEmail').isNotEmpty
          ? text(j, 'schoolEmail')
          : text(j, 'email');

  Json toJson() => {
    'classCode': classCode,
    'studentCode': studentCode,
    'fullName': fullName,
    'schoolEmail': schoolEmail,
  };
}

class ClassTarget {
  final String semester;
  final String subjectCode;
  final String classCode;
  final String subjectName;
  final String? classId;

  ClassTarget({
    required this.semester,
    required this.subjectCode,
    required this.classCode,
    required this.subjectName,
    this.classId,
  });

  String get key => mappingKey(semester, subjectCode, classCode);

  bool matches(String sem, String subj, String cls) =>
      normalizeCode(semester) == normalizeCode(sem) &&
      normalizeCode(subjectCode) == normalizeCode(subj) &&
      normalizeCode(classCode) == normalizeCode(cls);

  Json toJson() => {
    'semester': semester,
    'subjectCode': subjectCode,
    'classCode': classCode,
    'subjectName': subjectName,
    if (classId != null && classId!.isNotEmpty) 'classId': classId,
  };
}

class FapImportDto {
  final String semester;
  final String subjectCode;
  final String subjectName;
  final String classCode;
  final List<Schedule> schedules;
  final List<RosterStudent> students;

  FapImportDto({
    required this.semester,
    required this.subjectCode,
    required this.subjectName,
    required this.classCode,
    this.schedules = const [],
    this.students = const [],
  });

  Json toJson() => {
    'semester': semester,
    'subjectCode': subjectCode,
    'subjectName': subjectName,
    'classCode': classCode,
    'schedules': schedules.map((s) => s.toJson()).toList(),
    'students': students.map((s) => s.toJson()).toList(),
  };
}

class Schedule {
  final String scheduleId,
      lecturerId,
      semester,
      subjectCode,
      subjectName,
      classCode,
      startTime,
      endTime,
      room,
      sourceType;
  final int dayOfWeek, slot;

  Schedule({
    required this.scheduleId,
    required this.lecturerId,
    required this.semester,
    required this.subjectCode,
    required this.subjectName,
    required this.classCode,
    required this.dayOfWeek,
    required this.slot,
    required this.startTime,
    required this.endTime,
    required this.room,
    this.sourceType = 'MANUAL',
  });

  Schedule.fromJson(Json j)
    : scheduleId = text(j, 'scheduleId'),
      lecturerId = text(j, 'lecturerId'),
      semester = text(j, 'semester'),
      subjectCode = text(j, 'subjectCode'),
      subjectName = text(j, 'subjectName'),
      classCode = text(j, 'classCode'),
      startTime = text(j, 'startTime'),
      endTime = text(j, 'endTime'),
      room = text(j, 'room'),
      sourceType = text(j, 'sourceType').isNotEmpty ? text(j, 'sourceType') : 'MANUAL',
      dayOfWeek = number(j, 'dayOfWeek'),
      slot = number(j, 'slot');

  String get key => mappingKey(semester, subjectCode, classCode);

  Json toJson() => {
    'scheduleId': scheduleId,
    'lecturerId': lecturerId,
    'semester': semester,
    'subjectCode': subjectCode,
    'subjectName': subjectName,
    'classCode': classCode,
    'dayOfWeek': dayOfWeek,
    'slot': slot,
    'startTime': startTime,
    'endTime': endTime,
    'room': room,
    'sourceType': sourceType,
  };

  Schedule copyWith({
    String? scheduleId,
    String? lecturerId,
    String? semester,
    String? subjectCode,
    String? subjectName,
    String? classCode,
    int? dayOfWeek,
    int? slot,
    String? startTime,
    String? endTime,
    String? room,
    String? sourceType,
  }) => Schedule(
    scheduleId: scheduleId ?? this.scheduleId,
    lecturerId: lecturerId ?? this.lecturerId,
    semester: semester ?? this.semester,
    subjectCode: subjectCode ?? this.subjectCode,
    subjectName: subjectName ?? this.subjectName,
    classCode: classCode ?? this.classCode,
    dayOfWeek: dayOfWeek ?? this.dayOfWeek,
    slot: slot ?? this.slot,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    room: room ?? this.room,
    sourceType: sourceType ?? this.sourceType,
  );
}

class TeachingSession {
  final String sessionId,
      classId,
      date,
      startTime,
      endTime,
      status,
      currentToken,
      currentSecretCode,
      tokenExpiredAt,
      createdBy;
  final int slot;
  TeachingSession.fromJson(Json j)
    : sessionId = text(j, 'sessionId'),
      classId = text(j, 'classId'),
      date = normalizeDate(text(j, 'date')),
      startTime = text(j, 'startTime'),
      endTime = text(j, 'endTime'),
      status = text(j, 'status').toUpperCase(),
      currentToken = text(j, 'currentToken').split('#').first,
      currentSecretCode = text(j, 'currentSecretCode').isNotEmpty
          ? text(j, 'currentSecretCode')
          : (text(j, 'currentToken').contains('#')
                ? text(j, 'currentToken').split('#').last
                : ''),
      tokenExpiredAt = text(j, 'tokenExpiredAt'),
      createdBy = text(j, 'createdBy'),
      slot = number(j, 'slot');
  bool get isOpen => status == 'OPEN';
  bool get editable => status == 'OPEN' || status == 'CLOSED';
  static String normalizeDate(String value) {
    final match = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(value);
    return match == null
        ? value
        : '${match[3]}-${match[2]!.padLeft(2, '0')}-${match[1]!.padLeft(2, '0')}';
  }
}

class AttendanceRecord {
  final String attendanceId,
      sessionId,
      studentId,
      studentCode,
      fullName,
      status,
      note,
      checkInTime;
  AttendanceRecord.fromJson(Json j)
    : attendanceId = text(j, 'attendanceId'),
      sessionId = text(j, 'sessionId'),
      studentId = text(j, 'studentId'),
      studentCode = text(j, 'studentCode'),
      fullName = text(j, 'fullName'),
      status = text(j, 'status'),
      note = text(j, 'note'),
      checkInTime = text(j, 'checkInTime');
}

abstract final class CampusClock {
  static DateTime now([DateTime? instant]) =>
      (instant ?? DateTime.now()).toUtc().add(const Duration(hours: 7));
  static String date(DateTime value) =>
      value.toIso8601String().substring(0, 10);
  static int? minutes(String value) {
    if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value)) return null;
    final parts = value.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static bool current(
    String dateValue,
    String start,
    String end, [
    DateTime? instant,
  ]) {
    final local = now(instant), from = minutes(start), to = minutes(end);
    final minute = local.hour * 60 + local.minute;
    return dateValue == date(local) &&
        from != null &&
        to != null &&
        minute >= from &&
        minute < to;
  }
}
