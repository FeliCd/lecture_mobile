import 'package:flutter/material.dart';
import 'domain.dart';
import 'theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'repository.dart';

class CampusRefreshList extends ConsumerWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  const CampusRefreshList({super.key, required this.children, this.padding});
  @override
  Widget build(BuildContext context, WidgetRef ref) => RefreshIndicator(
    onRefresh: () async {
      try {
        await ref.read(repositoryProvider).refreshData();
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage(error))));
        }
      }
    },
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      children: children,
    ),
  );
}

class CampusActionSheet extends StatelessWidget {
  final Widget title, content;
  final List<Widget> actions;
  const CampusActionSheet({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
        maxWidth: 640,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DefaultTextStyle(
              style: Theme.of(context).textTheme.titleLarge!,
              child: title,
            ),
            const SizedBox(height: 16),
            content,
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
          ],
        ),
      ),
    ),
  );
}

class CampusOutlineAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  const CampusOutlineAction({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
  });
  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    ),
  );
}

AttendanceSummary attendanceSummary(WidgetRef ref, Iterable<String> values) =>
    AttendanceSummary(
      values,
      policy:
          ref.read(profileProvider).value?.attendancePolicy ??
          const AttendancePolicy(),
    );

class MemberLabel extends ConsumerWidget {
  final String classId, uid;
  const MemberLabel({super.key, required this.classId, required this.uid});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(profileProvider).value;
    if (user?.isLecturer != true) return Text(user?.name ?? 'Sinh viên');
    final member = ref.watch(memberNamesProvider(classId)).value?[uid];
    return Text(
      member == null
          ? uid
          : '${member['displayName']} • ${member['studentCode']}',
    );
  }
}

class AttendanceBar extends StatelessWidget {
  final AttendanceSummary counts;
  const AttendanceBar({super.key, required this.counts});
  @override
  Widget build(BuildContext context) {
    final values = {
      'present': counts.present,
      'late': counts.late,
      'absent': counts.absent,
      'excused': counts.excused,
    };
    if (values.values.every((n) => n == 0)) {
      return const Text('Chưa đủ dữ liệu');
    }
    return Semantics(
      label: values.entries
          .map((e) => '${StatusBadge.label(e.key)} ${e.value}')
          .join(', '),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 14,
          child: Row(
            children: values.entries
                .where((e) => e.value > 0)
                .map(
                  (e) => Expanded(
                    flex: e.value,
                    child: ColoredBox(
                      color: CampusColors.status(
                        e.key,
                        Theme.of(context).brightness == Brightness.dark,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class CampusCard extends StatelessWidget {
  final Widget child;
  const CampusCard({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}

class AppPrimaryButton extends StatelessWidget {
  final String label;
  final bool busy;
  final String busyLabel;
  final VoidCallback? onPressed;
  const AppPrimaryButton({
    super.key,
    required this.label,
    this.busy = false,
    this.busyLabel = 'Đang xử lý…',
    this.onPressed,
  });
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: busy
        ? Semantics(
            liveRegion: true,
            child: Wrap(
              spacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                Text(busyLabel),
              ],
            ),
          )
        : Text(label),
  );
}

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});
  static String label(String s) => switch (s) {
    'present' => 'Có mặt',
    'late' => 'Đi trễ',
    'absent' => 'Vắng',
    'excused' => 'Vắng có phép',
    'pending' => 'Chưa điểm danh',
    _ => 'Chưa chốt',
  };
  @override
  Widget build(BuildContext context) {
    final color = CampusColors.status(
      status,
      Theme.of(context).brightness == Brightness.dark,
    );
    final icon = switch (status) {
      'present' => Icons.check_circle_outline,
      'late' => Icons.schedule,
      'absent' => Icons.cancel_outlined,
      'excused' => Icons.verified_outlined,
      _ => Icons.hourglass_empty,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(label(status), style: TextStyle(color: color)),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState(this.message, {super.key, this.actionLabel, this.onAction});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.inbox_outlined, size: 40),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    ),
  );
}

class ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback retry;
  final String actionLabel;
  const ErrorState(
    this.error,
    this.retry, {
    super.key,
    this.actionLabel = 'Thử lại',
  });
  @override
  Widget build(BuildContext context) => CampusCard(
    child: Column(
      children: [
        const Icon(Icons.error_outline),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(errorMessage(error), textAlign: TextAlign.center),
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: retry, child: Text(actionLabel)),
      ],
    ),
  );
}

class LiveList extends StatefulWidget {
  final Stream<List<Data>> Function() source;
  final Widget Function(List<Data>) builder;
  final String empty;
  final bool hideEmpty;
  final bool buildEmpty;
  const LiveList({
    super.key,
    required this.source,
    required this.builder,
    this.empty = 'Chưa có dữ liệu.',
    this.hideEmpty = false,
    this.buildEmpty = false,
  });
  @override
  State<LiveList> createState() => _LiveListState();
}

class _LiveListState extends State<LiveList> {
  late Stream<List<Data>> stream;
  @override
  void initState() {
    super.initState();
    stream = widget.source();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Data>>(
    stream: stream,
    builder: (context, s) {
      if (s.hasError) {
        return ErrorState(
          s.error!,
          () => setState(() => stream = widget.source()),
        );
      }
      if (!s.hasData) {
        return const Center(child: CampusLoadingState());
      }
      if (s.data!.isEmpty && !widget.buildEmpty) {
        return widget.hideEmpty
            ? const SizedBox.shrink()
            : EmptyState(widget.empty);
      }
      return widget.builder(s.data!);
    },
  );
}

Future<void> runAction(
  BuildContext context,
  Future<void> Function() action, {
  bool mutation = false,
}) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mutation ? mutationErrorMessage(e) : errorMessage(e)),
        ),
      );
    }
  }
}

class CampusSectionHeader extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? action;
  const CampusSectionHeader({
    super.key,
    required this.title,
    this.description,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (description != null)
                Text(
                  description!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}

class CampusStatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  const CampusStatusChip(
    this.label, {
    super.key,
    this.icon = Icons.circle_outlined,
    this.color,
  });
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme,
        accent = color ?? scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(CampusRadius.control),
      ),
      child: Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(icon, size: 16, color: accent),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: accent),
          ),
        ],
      ),
    );
  }
}

class CampusSearchField extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  const CampusSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
  });
  @override
  State<CampusSearchField> createState() => _CampusSearchFieldState();
}

class _CampusSearchFieldState extends State<CampusSearchField> {
  late final owned = TextEditingController();
  TextEditingController get controller => widget.controller ?? owned;
  @override
  void dispose() {
    owned.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: widget.hint,
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Xóa tìm kiếm',
                    onPressed: () {
                      controller.clear();
                      widget.onChanged('');
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
          onChanged: widget.onChanged,
        ),
      );
}

class CampusHelpButton extends StatelessWidget {
  final String title, message;
  const CampusHelpButton({
    super.key,
    required this.title,
    required this.message,
  });
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: title,
    icon: const Icon(Icons.help_outline),
    onPressed: () => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => CampusActionSheet(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    ),
  );
}

/// Protects local drafts; never implies that a server mutation can be undone.
class CampusDraftGuard extends StatefulWidget {
  final bool dirty, busy;
  final Widget child;
  const CampusDraftGuard({
    super.key,
    required this.dirty,
    required this.busy,
    required this.child,
  });
  @override
  State<CampusDraftGuard> createState() => _CampusDraftGuardState();
}

class _CampusDraftGuardState extends State<CampusDraftGuard> {
  bool leaving = false, asking = false;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.busy && (!widget.dirty || leaving),
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || widget.busy || asking) return;
      asking = true;
      final discard = await campusConfirm(
        context,
        title: 'Bỏ thay đổi chưa lưu?',
        message:
            'Dữ liệu bạn đang nhập sẽ bị bỏ. Chọn Hủy để tiếp tục chỉnh sửa.',
        confirm: 'Bỏ thay đổi',
        destructive: true,
      );
      asking = false;
      if (!discard || !mounted) return;
      setState(() => leaving = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(result);
      });
    },
    child: widget.child,
  );
}

class CampusLoadingState extends StatelessWidget {
  final String message;
  const CampusLoadingState({super.key, this.message = 'Đang tải dữ liệu…'});
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class CampusStudentRow extends StatelessWidget {
  final String name, code;
  final Widget? detail, action;
  final VoidCallback? onTap;
  const CampusStudentRow({
    super.key,
    required this.name,
    required this.code,
    this.detail,
    this.action,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
    onTap: onTap,
    title: Text(name, style: Theme.of(context).textTheme.titleSmall),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(code), ?detail],
    ),
    trailing: action,
  );
}

Future<bool> campusConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  bool destructive = false,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (c) => CampusActionSheet(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(c).colorScheme.error,
                    foregroundColor: Theme.of(c).colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(c, true),
            child: Text(confirm),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Hủy'),
          ),
        ],
      ),
    ) ??
    false;
