import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'attendance_reminders.dart';
import 'lecturer_workspace_store.dart';

/// Single serialized owner, including logout, so old saves cannot resurrect alarms.
class LecturerReminders {
  static final instance = LecturerReminders();
  final plugin = FlutterLocalNotificationsPlugin();
  String? owner;
  bool initialized = false;
  bool launchChecked = false;
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
          (jsonDecode(payload) as Map)['type'] == 'attendance';
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
      _attendanceSignature = signature;
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
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'lecturer_attendance',
              'Nhắc điểm danh',
              channelDescription:
                  'Nhắc lịch dạy và buổi chưa hoàn tất điểm danh',
              importance: Importance.high,
              priority: Priority.high,
              visibility: NotificationVisibility.private,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: jsonEncode({
            'uid': uid,
            'type': 'attendance',
            'selector': r.selector,
          }),
        );
      }
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

  Future<void> sync(String uid, WorkspaceData data) => _queue(() async {
    if (owner != uid || !supported) return;
    await _initialize();
    await _cancelKind(attendance: false);
    await _schedule(uid, data);
  });
  Future<void> _schedule(String uid, WorkspaceData data) async {
    if (!await enabled() || owner != uid) return;
    final usedIds = <int>{};
    for (final task in data.tasks) {
      if (owner != uid) return;
      final at = taskReminder(task, data.quiet, DateTime.now());
      if (at == null) continue;
      final bytes = sha256.convert(utf8.encode('$uid/${task['id']}')).bytes;
      var id =
          ((bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]) &
          0x7fffffff;
      while (!usedIds.add(id)) {
        id = (id + 1) & 0x7fffffff;
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
  }

  Future<void> _queue(Future<void> Function() work) {
    final result = _tail.then((_) => work());
    _tail = result.catchError((Object _) {});
    return result;
  }
}
