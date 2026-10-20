import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'attendance_actions.dart';
import 'domain.dart';
import 'quick_attendance_draft.dart';
import 'repository.dart';
import 'widgets.dart';

/// Route for one lesson, identified by class + date + slot (+ schedule ids).
String quickAttendanceLocation(Data selector) => Uri(
  path: '/quick',
  queryParameters: {
    for (final e in selector.entries)
      if (e.value != null && '${e.value}'.isNotEmpty) e.key: '${e.value}',
  },
).toString();

Data quickSelectorFromQuery(Map<String, String> q) => {
  'classId': q['classId'],
  'sessionDate': q['sessionDate'],
  'slot': int.tryParse(q['slot'] ?? ''),
  if (q['scheduleId'] != null) 'scheduleId': q['scheduleId'],
  'exceptionId': q['exceptionId'] ?? '',
  if (q['sessionId'] != null) 'sessionId': q['sessionId'],
};

enum _Phase { loading, ready, sending, failed }

/// F01: everyone starts as a PRESENT draft; the lecturer marks exceptions,
/// reviews, then confirms. Opening this screen never writes a result.
class QuickAttendancePage extends ConsumerStatefulWidget {
  final Data selector;
  final String uid;
  const QuickAttendancePage({
    super.key,
    required this.selector,
    required this.uid,
  });
  @override
  ConsumerState<QuickAttendancePage> createState() =>
      _QuickAttendancePageState();
}

class _QuickAttendancePageState extends ConsumerState<QuickAttendancePage> {
  Data? context_;
  QuickAttendanceDraft? draft;
  _Phase phase = _Phase.loading;
  Object? loadError, saveError;
  bool uncertain = false, restored = false, conflict = false;
  QuickFilter filter = QuickFilter.all;
  String query = '';
  String? requestId;
  final scroll = ScrollController();

  String get draftKey => quickDraftKey(widget.uid, widget.selector);
  bool get editable => context_?['editable'] == true;
  bool get completed => context_?['status'] == 'CLOSED';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> load({Map<String, String> reapply = const {}}) async {
    setState(() {
      phase = _Phase.loading;
      loadError = null;
    });
    try {
      final value = await ref
          .read(repositoryProvider)
          .call('getQuickAttendanceContext', widget.selector);
      final students = [
        for (final s in value['students'] as List? ?? const [])
          QuickStudent.fromMap(Map<String, dynamic>.from(s as Map)),
      ];
      final next = QuickAttendanceDraft(
        students,
        revision: '${value['revision'] ?? ''}',
      );
      var wasRestored = false;
      if (value['editable'] == true) {
        final prefs = await SharedPreferences.getInstance();
        wasRestored = next.restore(prefs.getString(draftKey));
        // After a conflict the lecturer's explicit choices are re-applied
        // on the fresh data, and must be reviewed again before saving.
        for (final e in reapply.entries) {
          next.set(e.key, e.value);
        }
      }
      if (!mounted) return;
      setState(() {
        context_ = value;
        draft = next;
        restored = wasRestored;
        phase = _Phase.ready;
        // Fresh server data replaces any previous conflict; an uncertain
        // send stays flagged so the next save checks the server first.
        conflict = false;
        if (!uncertain) saveError = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loadError = e;
          phase = _Phase.failed;
        });
      }
    }
  }

  Future<void> persist() async {
    final d = draft;
    if (d == null || !editable) return;
    final prefs = await SharedPreferences.getInstance();
    if (d.dirty) {
      await prefs.setString(draftKey, d.encode());
    } else {
      await prefs.remove(draftKey);
    }
  }

  Future<void> discardDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(draftKey);
  }

  void change(QuickStudent s, String status) {
    final d = draft;
    if (d == null || phase == _Phase.sending || !d.set(s.id, status)) return;
    setState(() {
      saveError = null;
      conflict = false;
    });
    persist();
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: Text(
          '${s.name.isEmpty ? s.code : s.name}: ${quickStatusLabel(status)}',
        ),
        action: SnackBarAction(
          label: 'Hoàn tác',
          onPressed: () {
            if (!mounted || draft?.undo() == null) return;
            setState(() {});
            persist();
          },
        ),
      ),
    );
  }

  Future<void> review() async {
    final d = draft;
    if (d == null || phase == _Phase.sending) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (c) => _ReviewSheet(
        title: _lessonTitle(context_!),
        draft: d,
        retry: uncertain,
      ),
    );
    if (ok == true) await submit();
  }

  Future<void> submit() async {
    final d = draft;
    if (d == null || phase == _Phase.sending) return;
    setState(() {
      phase = _Phase.sending;
      saveError = null;
      conflict = false;
    });
    try {
      // After an uncertain send the same payload is sent again: the server
      // compares it with what is stored and answers alreadySaved, or refuses
      // with ATTENDANCE_ALREADY_FINALIZED (the draft is then kept). A lesson
      // closed by someone else is never mistaken for this lecturer's save.
      requestId ??=
          '${widget.uid}-${DateTime.now().microsecondsSinceEpoch}-${d.hashCode}';
      final result = await ref
          .read(repositoryProvider)
          .call(
            'submitQuickAttendance',
            d.payload(widget.selector, requestId!),
          );
      await finish(result, alreadySaved: result['alreadySaved'] == true);
    } catch (e) {
      if (!mounted) return;
      final text = e.toString();
      final isConflict =
          text.contains('ATTENDANCE_CONFLICT') ||
          text.contains('ROSTER_CHANGED');
      setState(() {
        saveError = e;
        conflict = isConflict;
        uncertain = !isConflict && mutationErrorMessage(e) != errorMessage(e);
        phase = _Phase.ready;
      });
      persist();
      showStatus();
    }
  }

  /// The status banner sits above the list; bring it into view after a save
  /// so an error or the completion time is never hidden below the fold.
  void showStatus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) {
        scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> finish(Data result, {required bool alreadySaved}) async {
    await discardDraft();
    requestId = null;
    uncertain = false;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          alreadySaved
              ? 'Kết quả đã được lưu trước đó. Đang hiển thị kết quả chính thức.'
              : 'Đã hoàn tất điểm danh.',
        ),
      ),
    );
    await ref.read(repositoryProvider).refreshData().catchError((Object _) {});
    await load();
    showStatus();
  }

  Future<void> reloadAfterConflict() async {
    final d = draft;
    final mine = <String, String>{
      if (d != null)
        for (final s in d.students)
          if (d.statusOf(s.id) != s.baseline) s.id: d.statusOf(s.id),
    };
    await discardDraft();
    await load(reapply: mine);
    await persist();
    if (mounted && mine.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã tải dữ liệu mới và áp dụng lại lựa chọn của bạn. Hãy xem lại trước khi lưu.',
          ),
        ),
      );
    }
  }

  Future<void> leave() async {
    final d = draft;
    if (phase == _Phase.sending) return;
    if (d == null || !editable || !d.dirty) {
      Navigator.of(context).pop();
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Điểm danh chưa được lưu'),
        content: const Text(
          'Bản nháp chưa phải kết quả chính thức. Bạn muốn làm gì?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, 'discard'),
            child: const Text('Bỏ bản nháp'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, 'keep'),
            child: const Text('Giữ bản nháp'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, 'stay'),
            child: const Text('Tiếp tục chỉnh'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null || choice == 'stay') return;
    if (choice == 'discard') await discardDraft();
    if (choice == 'keep') await persist();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final d = draft, c = context_;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Điểm danh nhanh'),
          actions: [
            IconButton(
              tooltip: 'Tải lại',
              onPressed: phase == _Phase.sending ? null : () => load(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: switch (phase) {
            _Phase.loading when c == null => const Center(
              child: CampusLoadingState(message: 'Đang tải buổi học…'),
            ),
            _Phase.failed => ListView(
              padding: const EdgeInsets.all(20),
              children: [ErrorState(loadError!, () => load())],
            ),
            _ when c == null || d == null => const SizedBox.shrink(),
            _ => _body(context, c, d),
          },
        ),
        bottomNavigationBar: c != null && d != null && editable
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Totals stay visible while the list scrolls.
                      _Counts(counts: d.counts),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed:
                            phase == _Phase.sending || phase == _Phase.loading
                            ? null
                            : conflict
                            ? reloadAfterConflict
                            : review,
                        icon: phase == _Phase.sending
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                conflict
                                    ? Icons.sync
                                    : Icons.fact_check_outlined,
                              ),
                        label: Text(
                          phase == _Phase.sending
                              ? 'Đang gửi…'
                              : conflict
                              ? 'Tải lại và đối soát'
                              : uncertain
                              ? 'Kiểm tra và thử lại'
                              : 'Xem lại',
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _body(BuildContext context, Data c, QuickAttendanceDraft d) {
    final theme = Theme.of(context);
    final rows = d.visible(filter, query);
    // One scroll view: with large text the header must scroll too instead of
    // squeezing the list.
    return CustomScrollView(
      key: PageStorageKey('quick:$draftKey'),
      controller: scroll,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          sliver: SliverList.list(
            children: [
              Text(_lessonTitle(c), style: theme.textTheme.titleMedium),
              Text(
                '${c['room'] != null && '${c['room']}'.isNotEmpty ? 'Phòng ${c['room']} · ' : ''}Sĩ số ${d.students.length}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              _StatusBanner(
                text: _statusText(c, d),
                tone: saveError != null
                    ? theme.colorScheme.errorContainer
                    : completed
                    ? theme.colorScheme.secondaryContainer
                    : theme.colorScheme.primaryContainer,
              ),
              if (saveError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      conflict
                          ? 'Dữ liệu buổi học vừa thay đổi (có người cập nhật hoặc danh sách lớp đổi). Bấm "Tải lại và đối soát" trước khi lưu.'
                          : '${mutationErrorMessage(saveError!)}\nBản nháp vẫn được giữ.',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ),
              if (!editable && !completed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_notEditableText('${c['state']}')),
                ),
              if (!editable) ...[
                const SizedBox(height: 8),
                _Counts(counts: d.counts),
              ],
              const SizedBox(height: 8),
              CampusSearchField(
                hint: 'Tìm tên hoặc MSSV',
                onChanged: (v) => setState(() => query = v),
              ),
              const SizedBox(height: 8),
              SegmentedButton<QuickFilter>(
                segments: [
                  ButtonSegment(
                    value: QuickFilter.all,
                    label: Text('Tất cả (${d.students.length})'),
                  ),
                  ButtonSegment(
                    value: QuickFilter.exceptions,
                    label: Text('Ngoại lệ (${d.exceptions.length})'),
                  ),
                ],
                selected: {filter},
                onSelectionChanged: (v) => setState(() => filter = v.first),
              ),
            ],
          ),
        ),
        if (rows.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              d.students.isEmpty
                  ? 'Lớp chưa có sinh viên hợp lệ cho buổi này.'
                  : filter == QuickFilter.exceptions && query.isEmpty
                  ? 'Chưa có ngoại lệ. Toàn bộ lớp đang Có mặt.'
                  : 'Không có sinh viên khớp tìm kiếm.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            sliver: SliverList.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) => _StudentTile(
                student: rows[i],
                status: d.statusOf(rows[i].id),
                changed: d.statusOf(rows[i].id) != rows[i].baseline,
                enabled: editable && phase != _Phase.sending,
                onChanged: (status) => change(rows[i], status),
                onAdjust: completed && c['sessionId'] != null
                    ? () => adjust(rows[i], c)
                    : null,
              ),
            ),
          ),
      ],
    );
  }

  /// Late arrival after saving: per-student correction with a reason,
  /// never re-initialising the whole class.
  Future<void> adjust(QuickStudent s, Data c) async {
    await editAttendance(
      context,
      ref,
      sessionId: '${c['sessionId']}',
      studentUid: 'student-${s.id}',
      status: s.existing ?? 'present',
      studentName: s.name,
      studentCode: s.code,
      contextLabel: _lessonTitle(c),
    );
    if (mounted) await load();
  }

  String _statusText(Data c, QuickAttendanceDraft d) {
    if (phase == _Phase.sending) return 'Đang gửi kết quả điểm danh…';
    if (completed) {
      final at = c['savedAt'] is num && (c['savedAt'] as num) > 0
          ? ' lúc ${localDate(DateTime.fromMillisecondsSinceEpoch((c['savedAt'] as num).toInt(), isUtc: true))}'
          : '';
      return 'Đã hoàn tất$at. Chạm một sinh viên để điều chỉnh có lý do.';
    }
    if (saveError != null) return 'Lưu chưa thành công — chưa hoàn tất';
    if (!editable) return 'Chưa điểm danh';
    if (restored) return 'Bản nháp đã khôi phục — chưa lưu';
    if (d.hasExistingResults) {
      return 'Đang hiển thị kết quả đã ghi nhận; người chưa có kết quả được chọn Có mặt — chưa lưu';
    }
    return d.dirty
        ? 'Bản nháp — chưa lưu'
        : 'Đang chọn Có mặt cho toàn bộ lớp — chưa lưu';
  }
}

String _lessonTitle(Data c) =>
    '${c['subjectName'] ?? c['subjectId'] ?? ''} · Lớp ${c['classCode'] ?? ''} · ${_displayDate('${c['sessionDate'] ?? ''}')} · Slot ${c['slot'] ?? ''}';

/// 2026-10-19 → 19/10/2026; anything else is shown unchanged.
String _displayDate(String iso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso);
  return m == null ? iso : '${m[3]}/${m[2]}/${m[1]}';
}

String _notEditableText(String state) => switch (state) {
  'NOT_YET' => 'Chưa đến thời gian điểm danh của buổi này.',
  'ENDED' =>
    'Buổi học đã kết thúc và chưa có kết quả. Xử lý theo quy định điểm danh muộn của nhà trường.',
  'TOO_SHORT' => 'Còn dưới 1 phút giờ học, không thể lưu điểm danh mới.',
  'RESET' => 'Phiên đã reset. Xử lý từ Desktop.',
  _ => 'Không thể điểm danh buổi này lúc này.',
};

class _Counts extends StatelessWidget {
  final Map<String, int> counts;
  const _Counts({required this.counts});
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 4,
    children: [
      for (final s in quickStatuses)
        Text(
          '${quickStatusLabel(s)}: ${counts[s]}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
    ],
  );
}

class _StatusBanner extends StatelessWidget {
  final String text;
  final Color tone;
  const _StatusBanner({required this.text, required this.tone});
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(text),
      ),
    ),
  );
}

class _StudentTile extends StatelessWidget {
  final QuickStudent student;
  final String status;
  final bool changed, enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback? onAdjust;
  const _StudentTile({
    required this.student,
    required this.status,
    required this.changed,
    required this.enabled,
    required this.onChanged,
    this.onAdjust,
  });
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: changed ? scheme.primaryContainer.withValues(alpha: .35) : null,
      child: ListTile(
        minVerticalPadding: 10,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        title: Text(student.name.isEmpty ? student.code : student.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(student.code),
            const SizedBox(height: 2),
            StatusBadge(status),
          ],
        ),
        // Tap toggles Có mặt ↔ Vắng: the common case is one tap per exception.
        onTap:
            onAdjust ??
            (enabled
                ? () => onChanged(status == 'present' ? 'absent' : 'present')
                : null),
        trailing: onAdjust != null
            ? const Icon(Icons.edit_outlined)
            : PopupMenuButton<String>(
                enabled: enabled,
                tooltip: 'Chọn trạng thái',
                icon: const Icon(Icons.more_vert),
                onSelected: onChanged,
                itemBuilder: (_) => [
                  for (final s in quickStatuses)
                    CheckedPopupMenuItem(
                      value: s,
                      checked: s == status,
                      child: Text(quickStatusLabel(s)),
                    ),
                ],
              ),
      ),
    );
  }
}

class _ReviewSheet extends StatelessWidget {
  final String title;
  final QuickAttendanceDraft draft;
  final bool retry;
  const _ReviewSheet({
    required this.title,
    required this.draft,
    required this.retry,
  });
  @override
  Widget build(BuildContext context) {
    final exceptions = draft.exceptions;
    return CampusActionSheet(
      title: const Text('Xem lại trước khi lưu'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              draft.summary(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (exceptions.isEmpty)
              const Text('Không có ngoại lệ: toàn bộ lớp Có mặt.')
            else ...[
              const Text('Ngoại lệ:'),
              for (final s in exceptions)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.name.isEmpty ? s.code : s.name),
                  subtitle: Text(s.code),
                  trailing: StatusBadge(draft.statusOf(s.id)),
                ),
            ],
            if (retry)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Lần gửi trước chưa rõ kết quả. Máy chủ sẽ đối chiếu nên không ghi trùng.',
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Quay lại sửa'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Xác nhận và lưu'),
        ),
      ],
    );
  }
}
