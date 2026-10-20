import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'domain.dart';
import 'quick_attendance.dart';
import 'repository.dart';
import 'timetable_domain.dart';
import 'timetable_card.dart' show roomLabel;
import 'widgets.dart';

/// All three schedule entry points use the same server-validated flow.
Future<void> openAttendanceForPeriod(
  BuildContext context,
  TeachingPeriod period,
) async {
  final result = await showModalBottomSheet<Data>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => DesktopSessionDialog(period: period),
  );
  if (result == null || !context.mounted) return;
  if (result['quick'] == true) {
    context.push(quickAttendanceLocation(period.selector));
    return;
  }
  if (result['status'] == 'OPEN' && result['effectiveDurationMinutes'] is num) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Phiên có hiệu lực ${(result['effectiveDurationMinutes'] as num).toStringAsFixed(1)} phút.',
        ),
      ),
    );
  }
  context.push('/host/${result['sessionId'] ?? result['classSessionId']}');
}

/// Name retained for callers; manual slot/time inputs have been removed.
class DesktopSessionDialog extends ConsumerStatefulWidget {
  final TeachingPeriod period;
  const DesktopSessionDialog({super.key, required this.period});
  @override
  ConsumerState<DesktopSessionDialog> createState() =>
      _DesktopSessionDialogState();
}

class _DesktopSessionDialogState extends ConsumerState<DesktopSessionDialog>
    with WidgetsBindingObserver {
  Data? occurrence;
  Object? error;
  bool loading = false, submitting = false;
  int duration = 10;
  Timer? timer;
  bool foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
    timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (occurrence?['state'] == 'NOT_YET' ||
          occurrence?['state'] == 'AVAILABLE') {
        load();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) load();
  }

  Future<void> load() async {
    if (loading || submitting || !foreground) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await ref
          .read(repositoryProvider)
          .call('getTeachingOccurrence', widget.period.selector);
      if (mounted) setState(() => occurrence = value);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          occurrence = null;
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> submit() async {
    if (submitting || loading || occurrence?['state'] != 'AVAILABLE') return;
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      final result = await ref
          .read(repositoryProvider)
          .call('createClassSession', {
            ...widget.period.selector,
            'occurrenceId': occurrence!['occurrenceId'],
            'durationMinutes': duration,
          });
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.period, state = occurrence?['state'];
    final remaining = (occurrence?['remainingMinutes'] as num?)?.toDouble();
    return PopScope(
      canPop: !submitting,
      child: CampusActionSheet(
        title: const Text('Điểm danh buổi học'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${occurrence?['subjectName'] ?? p.subjectName} (${occurrence?['subjectId'] ?? p.subjectId})',
              ),
              Text('Lớp ${occurrence?['classCode'] ?? p.classCode}'),
              Text(
                'Ngày ${occurrence?['sessionDate'] ?? p.sessionDate} • Slot ${occurrence?['slot'] ?? p.slot}',
              ),
              Text(
                '${occurrence?['scheduledStartTime'] ?? teachingTime(p.start)} – ${occurrence?['scheduledEndTime'] ?? teachingTime(p.end)}',
              ),
              Text(roomLabel(occurrence?['room'] as String? ?? p.room)),
              if (loading)
                const CampusLoadingState(
                  message: 'Đang kiểm tra buổi học với máy chủ…',
                ),
              const Text(
                'Giờ học và thời hạn được kiểm tra theo máy chủ (UTC+7). Phiên không kéo dài quá giờ kết thúc buổi học.',
              ),
              if (state == 'AVAILABLE') ...[
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: duration,
                  decoration: const InputDecoration(
                    labelText: 'Thời lượng điểm danh',
                  ),
                  items: [5, 10, 15, 20, 30]
                      .map(
                        (v) =>
                            DropdownMenuItem(value: v, child: Text('$v phút')),
                      )
                      .toList(),
                  onChanged: submitting || loading
                      ? null
                      : (v) => setState(() => duration = v!),
                ),
                if (remaining != null && remaining < duration)
                  Text(
                    'Còn ${remaining.toStringAsFixed(1)} phút giờ học. Phiên sẽ kết thúc chậm nhất khi hết giờ học.',
                  ),
              ],
              if (state == 'NOT_YET')
                Text(
                  'Chưa đến giờ. Có thể mở từ ${localDate(DateTime.fromMillisecondsSinceEpoch((occurrence!['earliestOpenAt'] as num).toInt(), isUtc: true))}. Buổi tương lai chỉ được xem thông tin.',
                ),
              if (state == 'ENDED')
                const Text('Đã qua giờ học. Không thể mở phiên mới.'),
              if (state == 'TOO_SHORT')
                const Text('Còn dưới 1 phút giờ học. Không thể mở phiên mới.'),
              if (state == 'RESET')
                const Text(
                  'Phiên đã reset. Tải lại dữ liệu hoặc xử lý reset từ Desktop; không tự tạo phiên khác.',
                ),
              if (state == 'OPEN')
                const Text(
                  'Phiên đang mở. Tiếp tục sẽ giữ nguyên thời điểm mở và hạn kết thúc.',
                ),
              if (state == 'CLOSED')
                const Text(
                  'Phiên đã chốt. Bạn có thể xem kết quả và sửa điểm danh có lý do.',
                ),
              if (error != null)
                Text(
                  errorMessage(error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: submitting ? null : () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          if (error != null)
            TextButton(
              onPressed: loading || submitting ? null : load,
              child: const Text('Kiểm tra lại'),
            ),
          if (state == 'AVAILABLE' || state == 'OPEN')
            OutlinedButton.icon(
              onPressed: loading || submitting
                  ? null
                  : () => Navigator.pop(context, {'quick': true}),
              icon: const Icon(Icons.checklist_rtl),
              label: const Text('Điểm danh nhanh'),
            ),
          if (state == 'AVAILABLE')
            FilledButton(
              onPressed: loading || submitting ? null : submit,
              child: Text(submitting ? 'Đang mở…' : 'Mở phiên điểm danh'),
            ),
          if (state == 'OPEN' || state == 'CLOSED')
            FilledButton(
              onPressed: loading || submitting
                  ? null
                  : () => Navigator.pop(context, occurrence),
              child: Text(
                state == 'OPEN'
                    ? 'Tiếp tục điểm danh'
                    : 'Xem kết quả điểm danh',
              ),
            ),
        ],
      ),
    );
  }
}
