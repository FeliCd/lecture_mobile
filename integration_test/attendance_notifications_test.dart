import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lecturer_companion/lab2/lecturer_reminders.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android delivers test alert and persists a scheduled reminder', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    // Do not activate/logout or reconcile the real lecturer's existing alarms.
    final reminders = LecturerReminders()..owner = 'notification-device-test';
    const scheduledId = 0x7ffffffd;
    addTearDown(() async {
      await reminders.plugin.cancel(id: 0x7ffffffe);
      await reminders.plugin.cancel(id: scheduledId);
    });
    expect(
      await reminders.testAttendanceAlert('notification-device-test'),
      true,
    );
    final active = await reminders.plugin.getActiveNotifications();
    expect(active.any((n) => n.id == 0x7ffffffe), true);
    final android = reminders.plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()!;
    final channels = await android.getNotificationChannels();
    final channel = channels!.singleWhere((c) => c.id == 'lecturer_attendance');
    expect(channel.importance, Importance.high);
    expect(channel.playSound, true);
    expect(channel.enableVibration, true);

    await reminders.plugin.zonedSchedule(
      id: scheduledId,
      title: 'Kiểm tra lịch nhắc',
      body: 'Thông báo thử tự động',
      scheduledDate: tz.TZDateTime.now(tz.UTC).add(const Duration(minutes: 5)),
      notificationDetails: LecturerReminders.attendanceDetails(
        quickAction: true,
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'notification-device-test',
    );
    expect(
      (await reminders.plugin.pendingNotificationRequests()).any(
        (n) => n.id == scheduledId,
      ),
      true,
    );
    await reminders.plugin.cancel(id: scheduledId);
    expect(
      (await reminders.plugin.pendingNotificationRequests()).any(
        (n) => n.id == scheduledId,
      ),
      false,
    );
  });
}
