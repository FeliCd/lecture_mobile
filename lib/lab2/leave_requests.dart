import 'package:flutter/material.dart';

import 'domain.dart';
import 'theme.dart';
import 'widgets.dart';

class LeaveRequestsPanel extends StatefulWidget {
  final String classId;
  final Future<Data> Function(String method, Data data) call;
  final String? sessionDate, closedSessionId;
  final int? slot;

  const LeaveRequestsPanel({
    super.key,
    required this.classId,
    required this.call,
    this.sessionDate,
    this.slot,
    this.closedSessionId,
  });

  @override
  State<LeaveRequestsPanel> createState() => _LeaveRequestsPanelState();
}

class _LeaveRequestsPanelState extends State<LeaveRequestsPanel> {
  static const labels = {
    'PENDING': 'Chờ duyệt',
    'APPROVED': 'Đã duyệt',
    'REJECTED': 'Đã từ chối',
    'CANCELLED': 'Đã hủy',
  };

  List<Data> _rows = [];
  final _applied = <Object?>{};
  String _filter = 'ALL';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh([Future<void> Function()? change]) async {
    if (!mounted || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (change != null) await change();
      if (!mounted) return;
      final result = await widget.call('listClassLeaveRequests', {
        'classId': widget.classId,
        if (widget.sessionDate != null) 'sessionDate': widget.sessionDate,
        if (widget.slot != null) 'slot': widget.slot,
      });
      if (!mounted) return;
      _rows = [
        for (final row in result['requests'] as List)
          Map<String, dynamic>.from(row as Map),
      ]..sort((a, b) => '${b['submittedAt']}'.compareTo('${a['submittedAt']}'));
    } catch (error) {
      if (mounted) {
        final code = error.toString();
        if (code.contains('PERMISSION_DENIED') ||
            code.contains('UNAUTHENTICATED')) {
          _rows = [];
        }
        _error = switch (code) {
          _
              when code.contains('VERSION_CONFLICT') ||
                  code.contains('INVALID_LEAVE_TRANSITION') =>
            'Đơn đã thay đổi. Tải lại để xem trạng thái mới nhất.',
          _ when code.contains('OCCURRENCE_CHANGED') =>
            'Lịch của buổi học đã thay đổi. Tải lại và kiểm tra đơn.',
          _ when code.contains('MANUAL_CORRECTION_REQUIRED') =>
            'Buổi này đã ghi nhận có mặt hoặc đã sửa điểm danh. Kiểm tra bản ghi của sinh viên trước khi điều chỉnh.',
          _
              when code.contains('UNKNOWN_PORTAL_METHOD') ||
                  code.contains('FEATURE_DISABLED') =>
            'Cần cập nhật backend chung để quản lý đơn xin nghỉ trên điện thoại.',
          _ =>
            change == null ? errorMessage(error) : mutationErrorMessage(error),
        };
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(Data row, {required bool approve}) async {
    final form = GlobalKey<FormState>();
    var note = '';
    final reviewNote = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(approve ? 'Duyệt đơn xin nghỉ?' : 'Từ chối đơn xin nghỉ?'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_lesson(row)),
                const SizedBox(height: 12),
                TextFormField(
                  maxLength: 500,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: approve
                        ? 'Phản hồi cho sinh viên (tùy chọn)'
                        : 'Lý do từ chối',
                  ),
                  onChanged: (value) => note = value,
                  validator: (value) =>
                      !approve && (value?.trim().isEmpty ?? true)
                      ? 'Nhập lý do từ chối.'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialogContext, note.trim());
              }
            },
            child: Text(approve ? 'Duyệt đơn' : 'Từ chối đơn'),
          ),
        ],
      ),
    );
    if (reviewNote == null || !mounted) return;
    await _refresh(() async {
      await widget.call('reviewLeaveRequest', {
        'classId': widget.classId,
        'id': row['id'],
        'version': row['version'],
        'status': approve ? 'APPROVED' : 'REJECTED',
        'reviewNote': reviewNote,
      });
    });
  }

  Future<void> _apply(Data row) async {
    final confirmed = await campusConfirm(
      context,
      title: 'Cập nhật nghỉ có phép?',
      message: _lesson(row),
      confirm: 'Cập nhật',
    );
    if (!confirmed || !mounted) return;
    await _refresh(() async {
      await widget.call('applyApprovedLeave', {
        'sessionId': widget.closedSessionId,
        'studentId': row['studentId'],
      });
      _applied.add(row['id']);
    });
  }

  String _lesson(Data row) =>
      '${row['fullName']} · ${row['sessionDate']} · Slot ${row['slot']}';

  @override
  Widget build(BuildContext context) {
    final visible = _rows.where(
      (row) => _filter == 'ALL' || row['status'] == _filter,
    );
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: CampusSpace.pageInsets,
        children: [
          const CampusSectionHeader(
            title: 'Lọc đơn xin nghỉ',
            description: 'Xem lý do và phản hồi cho từng yêu cầu.',
          ),
          Wrap(
            spacing: CampusSpace.md,
            runSpacing: CampusSpace.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<String>(
                value: _filter,
                items: {'ALL': 'Tất cả', ...labels}.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _filter = value!),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Tải lại đơn'),
              ),
            ],
          ),
          const SizedBox(height: CampusSpace.md),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (!_busy && _error == null && visible.isEmpty)
            const EmptyState('Chưa có đơn xin nghỉ phù hợp.'),
          for (final row in visible) _requestCard(row),
        ],
      ),
    );
  }

  Widget _requestCard(Data row) {
    final status = row['status'];
    final scheduleChanged = row['scheduleChanged'] == true;
    final actionable = !_busy && _error == null;
    final theme = Theme.of(context);
    final (icon, color) = switch (status) {
      'PENDING' => (Icons.schedule, theme.colorScheme.primary),
      'APPROVED' => (
        Icons.check_circle_outline,
        CampusColors.status('present', theme.brightness == Brightness.dark),
      ),
      'REJECTED' => (Icons.cancel_outlined, theme.colorScheme.error),
      _ => (Icons.remove_circle_outline, theme.colorScheme.onSurfaceVariant),
    };
    return CampusCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_lesson(row), style: Theme.of(context).textTheme.titleSmall),
          Text('${row['studentCode']}'),
          const SizedBox(height: CampusSpace.sm),
          CampusStatusChip(
            '${labels[status] ?? status}',
            icon: icon,
            color: color,
          ),
          const SizedBox(height: CampusSpace.md),
          Text('${row['reason']}'),
          if ('${row['reviewNote'] ?? ''}'.isNotEmpty)
            Text('Phản hồi: ${row['reviewNote']}'),
          if (scheduleChanged)
            const Text('Lịch buổi học đã thay đổi. Kiểm tra lại đơn.'),
          if (status == 'PENDING')
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: actionable && !scheduleChanged
                      ? () => _review(row, approve: true)
                      : null,
                  child: const Text('Duyệt'),
                ),
                TextButton(
                  onPressed: actionable
                      ? () => _review(row, approve: false)
                      : null,
                  child: const Text('Từ chối'),
                ),
              ],
            ),
          if (status == 'APPROVED' &&
              widget.closedSessionId != null &&
              !scheduleChanged)
            if (_applied.contains(row['id']))
              const Text('Đã cập nhật nghỉ có phép.')
            else
              TextButton(
                onPressed: actionable ? () => _apply(row) : null,
                child: const Text('Cập nhật nghỉ có phép'),
              ),
        ],
      ),
    );
  }
}
