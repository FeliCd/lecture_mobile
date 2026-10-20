import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'domain.dart';
import 'desktop_sync.dart' show useSharedDesktop;
import 'repository.dart';
import 'timetable_domain.dart';
import 'timetable_card.dart';
import 'desktop_session_dialog.dart';
import 'lecturer_reminders.dart';

String? attendanceFollowUp(TeachingPeriod p, DateTime now) {
  if (p.cancelled ||
      p.completed ||
      p.classId == null ||
      now.isBefore(p.scheduledStartAt)) {
    return null;
  }
  if (p.sessionId == null) {
    return now.isBefore(p.scheduledEndAt)
        ? 'Chưa mở điểm danh'
        : 'Đã qua giờ · Chưa có phiên';
  }
  if (p.scheduledEndAt.difference(now) > const Duration(minutes: 2)) {
    return null;
  }
  return now.isBefore(p.scheduledEndAt)
      ? 'Sắp hết phiên · Kiểm tra và chốt'
      : 'Cần kiểm tra kết quả';
}

class AttendanceFollowUpPanel extends StatelessWidget {
  final List<TeachingPeriod> periods;
  final DateTime now;
  const AttendanceFollowUpPanel({
    super.key,
    required this.periods,
    required this.now,
  });
  @override
  Widget build(BuildContext context) {
    final pending =
        periods.where((p) => attendanceFollowUp(p, now) != null).toList()
          ..sort((a, b) => a.scheduledEndAt.compareTo(b.scheduledEndAt));
    if (pending.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cần xử lý · ${pending.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final p in pending)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${p.classCode} · ${p.subjectId} · Slot ${p.slot ?? '—'}',
                    ),
                    subtitle: Text(
                      '${attendanceFollowUp(p, now)}\n${p.timeRange} · ${roomLabel(p.room)}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openAttendanceForPeriod(context, p),
                  ),
                  FilledButton(
                    onPressed: () => openAttendanceForPeriod(context, p),
                    child: Text(
                      p.sessionId != null
                          ? 'Tiếp tục điểm danh'
                          : now.isBefore(p.scheduledEndAt)
                          ? 'Mở điểm danh'
                          : 'Kiểm tra buổi học',
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            const Text(
              'Trạng thái trong app · Chưa xác nhận cập nhật FAP',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kept above routes so reminders also reconcile while viewing a class/session.
/// Background delivery uses the last observed schedule, never claims live status.
class AttendanceReminderCoordinator extends ConsumerStatefulWidget {
  final UserProfile user;
  final Widget child;
  const AttendanceReminderCoordinator({
    super.key,
    required this.user,
    required this.child,
  });
  @override
  ConsumerState<AttendanceReminderCoordinator> createState() =>
      _AttendanceReminderCoordinatorState();
}

class _AttendanceReminderCoordinatorState
    extends ConsumerState<AttendanceReminderCoordinator>
    with WidgetsBindingObserver {
  final values = <String, List<Data>>{};
  final subscriptions = <StreamSubscription<List<Data>>>[];
  Timer? timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final repo = ref.read(repositoryProvider);
    void subscribe(String key, Stream<List<Data>> stream) {
      subscriptions.add(
        stream.listen(
          (rows) {
            values[key] = rows;
            sync();
          },
          onError: (Object _) {
            values.remove(key);
            LecturerReminders.instance
                .syncLessons(widget.user.uid, [])
                .catchError((Object _) {});
          },
        ),
      );
    }

    subscribe('classes', repo.classes(widget.user));
    subscribe('schedules', repo.watch('schedules'));
    subscribe('sessions', repo.watch('classSessions'));
    subscribe(
      'exceptions',
      useSharedDesktop ? repo.watch('scheduleExceptions') : Stream.value([]),
    );
    timer = Timer.periodic(const Duration(minutes: 1), (_) => sync());
  }

  void sync() {
    if (!mounted || values.length != 4) return;
    final day = campusDay(DateTime.now());
    final periods = <TeachingPeriod>[];
    for (final term in values['classes']!.map((c) => '${c['term']}').toSet()) {
      // Bound to tomorrow: no guessed semester-wide repetition.
      for (var i = -1; i <= 1; i++) {
        periods.addAll(
          teachingPeriods(
            user: widget.user,
            day: day.add(Duration(days: i)),
            term: term,
            classes: values['classes']!,
            schedules: values['schedules']!,
            sessions: values['sessions']!,
            exceptions: values['exceptions']!,
          ),
        );
      }
    }
    LecturerReminders.instance
        .syncLessons(widget.user.uid, periods)
        .catchError((Object _) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) sync();
  }

  @override
  void dispose() {
    timer?.cancel();
    for (final s in subscriptions) {
      s.cancel();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class AttendanceReminderToggle extends StatefulWidget {
  final String uid, term;
  const AttendanceReminderToggle({
    super.key,
    required this.uid,
    required this.term,
  });
  @override
  State<AttendanceReminderToggle> createState() =>
      _AttendanceReminderToggleState();
}

class _AttendanceReminderToggleState extends State<AttendanceReminderToggle> {
  bool enabled = false, busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant AttendanceReminderToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.term != widget.term || oldWidget.uid != widget.uid) load();
  }

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final key = LecturerReminders.lessonPreference(widget.uid);
      final value =
          p.getBool(key) != false &&
          (p.getString('$key-term') == null ||
              p.getString('$key-term') == widget.term);
      if (mounted) setState(() => enabled = value);
    } catch (_) {
      /* Defaults off when local preferences cannot be read. */
    }
  }

  Future<void> toggle(bool value) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (value && !await LecturerReminders.instance.enable()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chưa bật được thông báo Android')),
          );
        }
        return;
      }
      await LecturerReminders.instance.setLessonReminders(
        widget.uid,
        value,
        widget.term,
      );
      if (mounted) setState(() => enabled = value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa lưu được nhắc điểm danh. Thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    title: const Text('Nhắc điểm danh'),
    subtitle: Text('${widget.term} · Lịch trên máy · Có thể nhắc trễ'),
    secondary: IconButton(
      icon: const Icon(Icons.info_outline),
      tooltip: 'Thông tin nhắc điểm danh',
      onPressed: () => showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Nhắc điểm danh'),
          content: const SingleChildScrollView(
            child: Text(
              'Nhắc giữa buổi, trước khi kết thúc 5 phút, sau khi kết thúc 10 phút và lúc 21:00 nếu chưa hoàn tất điểm danh (tối đa 4 lần/buổi, trước 00:00 giờ Việt Nam). Có âm thanh và rung theo cài đặt thông báo Android; chế độ im lặng hoặc Không làm phiền có thể tắt tiếng/rung. Chạm thông báo để mở đúng buổi điểm danh nhanh. Dùng lịch đã tải hôm nay và ngày mai. Buổi đã chốt hoặc hủy sẽ được gỡ nhắc khi app kết nối. Android có thể nhắc trễ. Cần mở app để cập nhật lịch và trạng thái từ thiết bị khác.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      Navigator.pop(c);
                      setState(() => busy = true);
                      try {
                        final shown = await LecturerReminders.instance
                            .testAttendanceAlert(widget.uid);
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(
                              shown
                                  ? 'Đã gửi thông báo thử. Nếu không có tiếng/rung, kiểm tra cài đặt thông báo Android.'
                                  : 'Chưa gửi được. Cần cấp quyền thông báo trên Android.',
                            ),
                          ),
                        );
                      } catch (_) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Chưa gửi được thông báo thử. Thử lại.',
                            ),
                          ),
                        );
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
              child: const Text('Thử âm thanh và rung'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
    ),
    value: enabled,
    onChanged: busy ? null : toggle,
  );
}
