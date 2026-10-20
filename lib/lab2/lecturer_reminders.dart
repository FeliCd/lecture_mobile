import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'attendance_reminders.dart';
import 'lecturer_workspace_store.dart';
import 'timetable_domain.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LessonAlarm {
  final DateTime at;
  final String key, payload, title, body;
  const LessonAlarm(this.at, this.key, this.payload, this.title, this.body);
}

List<LessonAlarm> lessonAlarms(
  List<TeachingPeriod> periods,
  DateTime now,
  bool quiet,
) => [
  for (final r in planAttendanceReminders(periods, now))
    if (!quiet ||
        (() {
          final h = r.at.toUtc().add(const Duration(hours: 7)).hour;
          return h >= 7 && h < 22;
        })())
      LessonAlarm(
        r.at,
        r.key,
        'lesson:${jsonEncode(r.selector)}',
        r.title,
        r.body,
      ),
];

/// Single serialized owner, including logout, so old saves cannot resurrect alarms.
class LecturerReminders {
  static final instance = LecturerReminders();
  final plugin = FlutterLocalNotificationsPlugin();
  // Keep the channel ID so existing Android sound/vibration preferences survive.
  static NotificationDetails attendanceDetails({bool quickAction = false}) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          'lecturer_attendance',
          'Nhắc điểm danh',
          channelDescription: 'Nhắc lịch dạy và buổi chưa hoàn tất điểm danh',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 800]),
          visibility: NotificationVisibility.private,
          actions: quickAction
              ? const [
                  AndroidNotificationAction(
                    'quick_attendance',
                    'Điểm danh nhanh',
                    showsUserInterface: true,
                  ),
                ]
              : null,
        ),
      );

  /// Uses the real attendance channel so lecturers can check device settings.
  Future<bool> testAttendanceAlert(String uid) async {
    var shown = false;
    await _queue(() async {
      if (owner != uid || !await enable() || owner != uid) return;
      await plugin.show(
        id: 0x7ffffffe,
        title: 'Thử nhắc điểm danh',
        body:
            'Nếu chưa nghe tiếng hoặc thấy rung, kiểm tra cài đặt thông báo của máy.',
        notificationDetails: attendanceDetails(),
      );
      shown = true;
    });
    return shown;
  }

  String? owner;
  bool initialized = false;
  bool launchChecked = false;
  List<TeachingPeriod> _lessons = [];
  String _lessonSignature = '';
  static String lessonPreference(String uid) =>
      'attendance-reminders-${sha256.convert(utf8.encode(uid))}';
  Future<void> _tail = Future.value();
  void Function(String)? onOpen;
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  Future<void> _initialize() async {
    if (initialized || !supported) return;
    tzdata.initializeTimeZones();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_reminder'),
      ),
      onDidReceiveNotificationResponse: (r) => _open(r.payload),
    );
    initialized = true;
  }

  void _open(String? payload) {
    if (payload == null) return;
    final d = jsonDecode(payload) as Map;
    if (owner == null || d['uid'] != owner) return;
    if (d['type'] == 'attendance') {
      onOpenAttendance?.call(Map<String, dynamic>.from(d['selector'] as Map));
    } else {
      onOpen?.call('${d['id']}');
    }
  }

  void Function(Map<String, dynamic>)? onOpenAttendance;
  String? _attendanceSignature;

  static bool _isAttendance(String? payload) {
    try {
      return payload != null &&
          (jsonDecode(payload) as Map)['type'] == 'attendance' &&
          (jsonDecode(payload) as Map)['kind'] != 'lesson';
    } catch (_) {
      return false;
    }
  }

  /// Cancels only one kind, so task and attendance reminders never erase
  /// each other.
  Future<void> _cancelKind({required bool attendance}) async {
    for (final r in await plugin.pendingNotificationRequests()) {
      if (_isAttendance(r.payload) == attendance) await plugin.cancel(id: r.id);
    }
  }

  /// F02: replaces this lecturer's attendance reminders. Skipped when the
  /// plan is unchanged so periodic rebuilds do not reschedule.
  Future<void> syncAttendance(String uid, List<AttendanceReminder> plan) {
    final signature =
        '$uid|${plan.map((r) => '${r.key}@${r.at.millisecondsSinceEpoch}').join(',')}';
    if (signature == _attendanceSignature) return Future.value();
    return _queue(() async {
      if (owner != uid || !supported) return;
      await _initialize();
      await _cancelKind(attendance: true);
      // Remember the plan only once it is really scheduled, so enabling the
      // permission later schedules it on the next refresh.
      _attendanceSignature = null;
      if (!await enabled() || owner != uid) return;
      final taken = {
        for (final r in await plugin.pendingNotificationRequests()) r.id,
      };
      for (final r in plan) {
        if (owner != uid) return;
        final bytes = sha256.convert(utf8.encode('att/$uid/${r.key}')).bytes;
        var id =
            ((bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]) &
            0x7fffffff;
        while (!taken.add(id)) {
          id = (id + 1) & 0x7fffffff;
        }
        await plugin.zonedSchedule(
          id: id,
          title: r.title,
          body: r.body,
          scheduledDate: tz.TZDateTime.from(r.at, tz.UTC),
          notificationDetails: attendanceDetails(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: jsonEncode({
            'uid': uid,
            'type': 'attendance',
            'selector': r.selector,
          }),
        );
      }
      if (owner == uid) _attendanceSignature = signature;
    });
  }

  Future<bool> enable() async {
    await _initialize();
    if (!supported) return false;
    return await plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()!
            .requestNotificationsPermission() ??
        false;
  }

  Future<bool> enabled() async {
    await _initialize();
    if (!supported) return false;
    return await plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()!
            .areNotificationsEnabled() ??
        false;
  }

  Future<void> activate(String? uid) {
    owner = uid;
    _attendanceSignature = null;
    _lessons = [];
    _lessonSignature = '';
    return _queue(() async {
      await _initialize();
      if (!supported) return;
      await plugin.cancelAll();
      if (owner != uid || uid == null) return;
      await _schedule(uid, await WorkspaceStore(uid).read());
      if (!launchChecked) {
        launchChecked = true;
        final launch = await plugin.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp == true) {
          _open(launch?.notificationResponse?.payload);
        }
      }
    });
  }

  Future<void> setLessonReminders(String uid, bool value, String term) async {
    final p = await SharedPreferences.getInstance();
    if (!await p.setString('${lessonPreference(uid)}-term', term)) {
      throw StateError('SAVE_FAILED');
    }
    if (!await p.setBool(lessonPreference(uid), value)) {
      throw StateError('SAVE_FAILED');
    }
    _lessonSignature = '';
    await sync(uid, await WorkspaceStore(uid).read());
  }

  Future<void> syncLessons(
    String uid,
    List<TeachingPeriod> periods,
  ) => _queue(() async {
    if (owner != uid || !supported) return;
    final data = await WorkspaceStore(uid).read();
    final preferences = await SharedPreferences.getInstance();
    final term = preferences.getString('${lessonPreference(uid)}-term');
    final alarms = lessonAlarms(
      periods.where((p) => term == null || p.term == term).toList(),
      DateTime.now(),
      data.quiet,
    );
    final enabled = preferences.getBool(lessonPreference(uid)) ?? true;
    final signature = jsonEncode([
      enabled,
      alarms
          .map(
            (a) => [a.key, a.at.toIso8601String(), a.payload, a.title, a.body],
          )
          .toList(),
    ]);
    _lessons = periods;
    if (signature == _lessonSignature) return;
    await _initialize();
    await _cancelKind(attendance: false);
    await _schedule(uid, data);
    _lessonSignature = owner == uid && await this.enabled() ? signature : '';
  });

  Future<void> sync(String uid, WorkspaceData data) => _queue(() async {
    if (owner != uid || !supported) return;
    await _initialize();
    await _cancelKind(attendance: false);
    await _schedule(uid, data);
  });
  Future<void> _schedule(String uid, WorkspaceData data) async {
    if (!await enabled() || owner != uid) return;
    final usedIds = {
      for (final r in await plugin.pendingNotificationRequests()) r.id,
    };
    for (final task in data.tasks) {
      if (owner != uid) return;
      final at = taskReminder(task, data.quiet, DateTime.now());
      if (at == null) continue;
      final bytes = sha256.convert(utf8.encode('$uid/${task['id']}')).bytes;
      var id =
          ((bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]) &
          0x3fffffff;
      while (!usedIds.add(id)) {
        id = (id + 1) & 0x3fffffff;
      }
      await plugin.zonedSchedule(
        id: id,
        title: 'FPT Lecturer • Nhắc việc',
        body: 'Có việc cần chuẩn bị. Chạm để xem trong ứng dụng.',
        scheduledDate: tz.TZDateTime.from(at, tz.UTC),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'lecturer_tasks',
            'Việc giảng dạy',
            channelDescription: 'Nhắc việc cá nhân theo giờ Việt Nam',
            importance: Importance.high,
            priority: Priority.high,
            visibility: NotificationVisibility.private,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: jsonEncode({'uid': uid, 'id': task['id']}),
      );
    }
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(lessonPreference(uid)) == false) return;
    final term = preferences.getString('${lessonPreference(uid)}-term');
    for (final alarm in lessonAlarms(
      _lessons.where((p) => term == null || p.term == term).toList(),
      DateTime.now(),
      data.quiet,
    )) {
      if (owner != uid) return;
      final bytes = sha256.convert(utf8.encode('$uid/${alarm.key}')).bytes;
      var id =
          (((bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]) &
              0x3fffffff) |
          0x40000000;
      while (!usedIds.add(id)) {
        id = ((id + 1) & 0x3fffffff) | 0x40000000;
      }
      await plugin.zonedSchedule(
        id: id,
        title: alarm.title,
        body: alarm.body,
        scheduledDate: tz.TZDateTime.from(alarm.at, tz.UTC),
        notificationDetails: attendanceDetails(quickAction: true),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: jsonEncode({
          'uid': uid,
          'type': 'attendance',
          'kind': 'lesson',
          'selector': jsonDecode(alarm.payload.substring(7)),
        }),
      );
    }
  }

  Future<void> _queue(Future<void> Function() work) {
    final result = _tail.then((_) => work());
    _tail = result.catchError((Object _) {});
    return result;
  }
}
