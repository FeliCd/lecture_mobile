import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'academic_term.dart';
import 'domain.dart';
import 'repository.dart';
import 'widgets.dart';

class ProfileAcademicTermSelector extends ConsumerStatefulWidget {
  final UserProfile user;
  const ProfileAcademicTermSelector({super.key, required this.user});
  @override
  ConsumerState<ProfileAcademicTermSelector> createState() =>
      _ProfileAcademicTermSelectorState();
}

class _ProfileAcademicTermSelectorState
    extends ConsumerState<ProfileAcademicTermSelector> {
  bool saving = false;
  Future<void> select(String term) async {
    setState(() => saving = true);
    try {
      await ref
          .read(selectedAcademicTermProvider(widget.user.uid).notifier)
          .select(term);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa lưu được học kỳ. Thử lại.')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(selectedAcademicTermProvider(widget.user.uid));
    final repo = ref.watch(repositoryProvider);
    return LiveList(
      key: ValueKey('term-options:${widget.user.uid}'),
      source: () => repo.classes(widget.user),
      buildEmpty: true,
      builder: (classes) => LiveList(
        source: () => repo.watch(
          'schedules',
          field: 'lecturerUid',
          equals: widget.user.uid,
        ),
        buildEmpty: true,
        builder: (schedules) {
          final terms = academicTerms([...classes, ...schedules]);
          final selected = resolveAcademicTerm(terms, selection.value);
          final options = [
            ...terms,
            if (selected != null && !terms.contains(selected)) selected,
          ];
          return CampusCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Học kỳ sử dụng',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                if (options.isEmpty)
                  const Text('Chưa có học kỳ trong dữ liệu được phân công.')
                else
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      '${widget.user.uid}:$selected:${terms.join('|')}',
                    ),
                    initialValue: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Học kỳ',
                      prefixIcon: Icon(Icons.school_outlined),
                    ),
                    items: [
                      for (final term in options)
                        DropdownMenuItem(
                          value: term,
                          child: Text(
                            terms.contains(term)
                                ? term
                                : '$term · Không còn lịch',
                          ),
                        ),
                    ],
                    onChanged: saving || selection.isLoading
                        ? null
                        : (value) {
                            if (value != null) select(value);
                          },
                  ),
                const SizedBox(height: 8),
                Text(
                  'Áp dụng cho Hôm nay, Lịch dạy và Lớp học. Lựa chọn được lưu trên thiết bị cho tài khoản này. Khi chưa chọn, dùng kỳ mới nhất trong dữ liệu.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
