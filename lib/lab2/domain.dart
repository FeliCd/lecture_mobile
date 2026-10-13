import 'package:google_sign_in/google_sign_in.dart';

typedef Data = Map<String, dynamic>;

class UserProfile {
  final String uid, name, role;
  final List<String> subjectIds;
  final AttendancePolicy attendancePolicy;
  final String email, lecturerId, department;
  const UserProfile(
    this.uid,
    this.name,
    this.role,
    this.subjectIds, {
    this.attendancePolicy = const AttendancePolicy(),
    this.email = '',
    this.lecturerId = '',
    this.department = '',
  });
  bool get isLecturer => role == 'lecturer';
  factory UserProfile.fromMap(String uid, Data d) {
    if (d['active'] != true || d['role'] != 'lecturer') {
      throw StateError('Tài khoản chưa được phân quyền');
    }
    return UserProfile(
      uid,
      d['displayName'] ?? '',
      d['role'],
      List<String>.from(d['subjectIds'] ?? []),
      attendancePolicy: AttendancePolicy.fromMap(
        d['attendancePolicy'] as Map? ?? {},
      ),
      email: '${d['email'] ?? ''}',
      lecturerId: '${d['lecturerId'] ?? ''}',
      department: '${d['department'] ?? ''}',
    );
  }
}

String attendanceStatus(String status) => switch (status.toLowerCase()) {
  'present' => 'present',
  'late' => 'late',
  'absent' => 'absent',
  'excused' => 'excused',
  _ => 'pending',
};

String subjectLabel(Data cls) => '${cls['subjectName'] ?? ''}'.trim().isNotEmpty
    ? '${cls['subjectName']} (${cls['subjectId'] ?? cls['subjectCode'] ?? ''})'
    : '${cls['subjectId'] ?? cls['subjectCode'] ?? 'Môn học'}';

String attendanceSessionLabel(Data session, [Data cls = const {}]) =>
    '${subjectLabel({...cls, ...session, if ('${session['subjectName'] ?? ''}'.trim().isEmpty && cls['subjectName'] != null) 'subjectName': cls['subjectName'], if ('${session['subjectId'] ?? ''}'.trim().isEmpty && cls['subjectId'] != null) 'subjectId': cls['subjectId']})} • Slot ${session['slot'] ?? '—'}';

String attendanceWebQr(String token) {
  final uri = Uri.tryParse(token);
  if (uri == null ||
      uri.queryParameters['sessionId'] == null ||
      uri.queryParameters['token'] == null) {
    return token;
  }
  return Uri.https('fap-attendance-88920.web.app', '/checkin', {
    'sessionId': uri.queryParameters['sessionId']!,
    'token': uri.queryParameters['token']!,
    'mode': (uri.queryParameters['mode'] ?? '').contains('secret')
        ? 'google-secret'
        : 'google',
    'v': '5',
  }).toString();
}

class AttendancePolicy {
  final bool? lateCountsAsPresent, excusedInDenominator;
  final double warningPercent, limitPercent;
  const AttendancePolicy({
    this.lateCountsAsPresent,
    this.excusedInDenominator,
    this.warningPercent = 15,
    this.limitPercent = 20,
  });
  factory AttendancePolicy.fromMap(Map d) => AttendancePolicy(
    lateCountsAsPresent: d['lateCountsAsPresent'] as bool?,
    excusedInDenominator: d['excusedInDenominator'] as bool?,
  );
}

class AttendanceSummary {
  final int present, late, absent, excused;
  final AttendancePolicy policy;
  AttendanceSummary(
    Iterable<String> values, {
    this.policy = const AttendancePolicy(),
  }) : present = values.where((v) => attendanceStatus(v) == 'present').length,
       late = values.where((v) => attendanceStatus(v) == 'late').length,
       absent = values.where((v) => attendanceStatus(v) == 'absent').length,
       excused = values.where((v) => attendanceStatus(v) == 'excused').length;
  bool get needsPolicy =>
      (late > 0 && policy.lateCountsAsPresent == null) ||
      (excused > 0 && policy.excusedInDenominator == null);
  int get eligible =>
      present +
      late +
      absent +
      (policy.excusedInDenominator == true ? excused : 0);
  double? get rate => needsPolicy || eligible == 0
      ? null
      : (present + (policy.lateCountsAsPresent == true ? late : 0)) /
            eligible *
            100;
  bool get atRisk => eligible >= 3 && exceedsAbsenceLimit;
  double? get absenceRate =>
      needsPolicy || eligible == 0 ? null : absent / eligible * 100;
  bool get exceedsAbsenceLimit =>
      absenceRate != null && absenceRate! > policy.limitPercent;
  bool get nearAbsenceLimit =>
      absenceRate != null &&
      absenceRate! >= policy.warningPercent &&
      !exceedsAbsenceLimit;
  String get absenceWarning => needsPolicy
      ? 'Chờ cấu hình quy định đi trễ / vắng có phép'
      : exceedsAbsenceLimit
      ? 'Vượt ngưỡng vắng 20%'
      : nearAbsenceLimit
      ? 'Sắp vượt ngưỡng vắng 20%'
      : eligible == 0
      ? 'Chưa đủ dữ liệu'
      : 'Trong ngưỡng cho phép';
}

String csvCell(Object? value) {
  var text = '${value ?? ''}';
  if (RegExp(r'^\s*[=+\-@\t\r]').hasMatch(text)) text = "'$text";
  return '"${text.replaceAll('"', '""')}"';
}

String attendanceCsv(Iterable<List<Object?>> rows) =>
    '\uFEFF${[
      ['classCode', 'subjectCode', 'sessionDate', 'studentCode', 'studentName', 'status', 'checkedInAt', 'notes'],
      ...rows,
    ].map((r) => r.map(csvCell).join(',')).join('\r\n')}\r\n';
String localDate(DateTime value) {
  final v = value.toUtc().add(const Duration(hours: 7));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(v.day)}/${two(v.month)}/${v.year} ${two(v.hour)}:${two(v.minute)}';
}

String mutationErrorMessage(Object error) {
  final value = error.toString().toLowerCase();
  if ([
    'timeout',
    'deadline-exceeded',
    'network',
    'unavailable',
    'socket',
    'connection',
  ].any(value.contains)) {
    return 'Chưa xác nhận được kết quả lưu do kết nối gián đoạn. '
        'Tải lại dữ liệu để kiểm tra thao tác đã được ghi nhận chưa trước khi gửi lại.';
  }
  return errorMessage(error);
}

String errorMessage(Object error) {
  if (error is GoogleSignInException) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled =>
        'Đăng nhập Google chưa hoàn tất. Bạn có thể thử lại.',
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        'Google Sign-In chưa được cấu hình đúng cho bản cài đặt này. Vui lòng liên hệ quản trị viên.',
      _ => 'Chưa kết nối được Google. Kiểm tra mạng và thử lại.',
    };
  }
  const messages = {
    'GOOGLE_ONLY':
        'Vui lòng đăng nhập bằng Google để sử dụng ứng dụng giảng viên.',
    'LECTURER_REQUIRED':
        'Tài khoản Google này chưa được cấp quyền giảng viên. Vui lòng liên hệ quản trị viên.',
    'OCCURRENCE_NOT_FOUND':
        'Không tìm thấy buổi học hợp lệ. Kiểm tra lịch gốc hoặc ngoại lệ lịch.',
    'OCCURRENCE_DUPLICATE':
        'Buổi học có dữ liệu lịch trùng. Cần kiểm tra dữ liệu gốc.',
    'OCCURRENCE_NOT_YET': 'Chưa đến thời gian mở điểm danh của buổi học.',
    'OCCURRENCE_ENDED': 'Buổi học đã kết thúc. Không thể mở phiên mới.',
    'OCCURRENCE_TOO_SHORT': 'Còn dưới 1 phút giờ học. Không thể mở phiên mới.',
    'SESSION_RESET_REQUIRES_DESKTOP':
        'Phiên đã reset. Kiểm tra phiên kế tiếp hoặc xử lý từ Desktop.',
    'INVALID_OCCURRENCE':
        'Dữ liệu buổi học không hợp lệ. Kiểm tra giờ và slot trong lịch.',
    'ATTENDANCE_ADJUSTED':
        'Điểm danh đã được giảng viên điều chỉnh. Liên hệ giảng viên.',
    'SHARED_STUDENT_ADMIN_REQUIRED':
        'Hồ sơ dùng chung với giảng viên khác. Liên hệ quản trị viên để chỉnh sửa.',
    'OCCURRENCE_HAS_SESSION':
        'Buổi này đã có phiên điểm danh. Không thể thay đổi lịch.',
    'OCCURRENCE_CANCELLED':
        'Buổi này đã hủy hoặc dời. Chọn lịch hiện tại của lớp.',
    'SCHEDULE_CONFLICT': 'Thời gian trùng với lịch dạy khác.',
    'CONTENT_CHANGED':
        'Bảng tin đã thay đổi. Tải lại trước khi xem trang tiếp theo.',
    'LOCK_BUSY': 'Hệ thống đang xử lý thao tác khác. Vui lòng thử lại.',
    'ATTENDANCE_BACKEND_UPDATE_REQUIRED':
        'Cần cập nhật Apps Script để sử dụng nhập liệu và quản lý điểm danh mới.',
    'TIMETABLE_BACKEND_UPDATE_REQUIRED':
        'Cần cập nhật Apps Script để tải thời khóa biểu từ Sheet.',
    'EMAIL_NOT_VERIFIED':
        'Tài khoản Google chưa có email được xác minh. Vui lòng liên hệ quản trị viên.',
    'PROFILE_NOT_REGISTERED':
        'Tài khoản Google này chưa được cấp quyền giảng viên. Vui lòng liên hệ quản trị viên.',
    'DUPLICATE_PROFILE': 'Email bị trùng trong dữ liệu Desktop. Cần sửa hồ sơ.',
    'SHARED_BACKEND_SETUP_REQUIRED':
        'Backend chung chưa được cấu hình. Cần cập nhật Apps Script.',
    'FEATURE_DISABLED': 'Chức năng này đã tắt trong bản Lab miễn phí.',
    'OPENALEX_SETUP_REQUIRED':
        'Backend chưa cấu hình key OpenAlex. Có thể dùng Crossref.',
    'email-already-in-use':
        'Email đã có tài khoản. Hãy đăng nhập hoặc đặt lại mật khẩu.',
    'weak-password': 'Mật khẩu cần ít nhất 6 ký tự.',
    'UNAUTHENTICATED': 'Vui lòng đăng nhập.',
    'PERMISSION_DENIED': 'Bạn không có quyền thao tác với lớp này.',
    'NOT_ENROLLED': 'Bạn chưa được ghi danh vào lớp.',
    'QR_EXPIRED': 'Mã QR đã hết hạn. Hãy quét mã mới.',
    'QR_INVALID': 'Mã QR không hợp lệ.',
    'SECRET_INVALID':
        'Secret Code không đúng. Hãy nhập lại mã giảng viên cung cấp.',
    'SECRET_REQUIRED':
        'Buổi học yêu cầu mã xác nhận của giảng viên. Hãy quét lại QR.',
    'SESSION_CLOSED': 'Phiên điểm danh đã kết thúc.',
    'ALREADY_CHECKED_IN': 'Bạn đã điểm danh buổi này.',
    'ALREADY_SUBMITTED': 'Bạn đã gửi câu trả lời.',
    'QUIZ_CLOSED': 'Hoạt động đã đóng.',
    'RATE_LIMITED': 'Thao tác quá nhanh. Vui lòng thử lại sau.',
    'ARTICLE_SOURCE_UNAVAILABLE': 'Chưa thể tải bài viết từ nguồn này.',
    'INVALID_SHEET_IDS':
        'Cache bài báo trong Sheet có ID trùng hoặc thiếu. Cần cập nhật backend.',
    'INVALID_SHEET_SCHEMA':
        'Cấu trúc dữ liệu Sheet chưa đúng. Cần kiểm tra backend.',
    'INVALID_ARTICLE_RESPONSE':
        'Dữ liệu bài báo trả về chưa đúng định dạng. Vui lòng thử lại.',
    'PUBLIC_NEWS_QUERY_REQUIRED':
        'Nhập từ khóa tìm kiếm để tải bài báo cho môn này.',
    'ARTICLE_CACHE_FULL': 'Cache bài báo đã đầy. Cần cập nhật backend.',
    'INVALID_INPUT': 'Thông tin chưa hợp lệ. Vui lòng kiểm tra lại.',
    'invalid-credential': 'Email hoặc mật khẩu không đúng.',
    'user-disabled': 'Tài khoản đã bị vô hiệu hóa.',
    'permission-denied':
        'Tài khoản chưa được phân quyền hoặc không có quyền đọc dữ liệu.',
    'network-request-failed': 'Không thể kết nối. Vui lòng kiểm tra mạng.',
    'unavailable': 'Không thể kết nối. Vui lòng thử lại.',
  };
  final text = error.toString();
  for (final entry in messages.entries) {
    if (text.contains(entry.key)) return entry.value;
  }
  if (text.contains('Tài khoản chưa được phân quyền')) {
    return 'Tài khoản chưa được phân quyền';
  }
  return 'Không thể hoàn tất thao tác. Vui lòng kiểm tra kết nối và thử lại.';
}
