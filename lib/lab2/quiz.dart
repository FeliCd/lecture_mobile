import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'domain.dart';
import 'repository.dart';
import 'widgets.dart';

class QuizList extends ConsumerWidget {
  final UserProfile user;
  const QuizList({super.key, required this.user});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (user.isLecturer)
          AppPrimaryButton(
            label: 'Tạo Quiz hoặc Poll',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CreateQuizPage(user: user),
              ),
            ),
          ),
        const SizedBox(height: 16),
        LiveList(
          source: () => repo.classes(user),
          builder: (classes) => Column(
            children: classes
                .map(
                  (c) => LiveList(
                    key: ValueKey(c['id']),
                    source: () => repo.watch(
                      'quizzes',
                      field: 'classId',
                      equals: c['id'],
                    ),
                    empty: '${c['classCode']}: chưa có hoạt động.',
                    builder: (quizzes) {
                      quizzes.sort(
                        (a, b) => dateValue(
                          b['createdAt'],
                        ).compareTo(dateValue(a['createdAt'])),
                      );
                      return Column(
                        children: quizzes
                            .map(
                              (q) => CampusCard(
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    q['type'] == 'quiz'
                                        ? Icons.quiz_outlined
                                        : Icons.poll_outlined,
                                  ),
                                  title: Text(q['question']),
                                  subtitle: Text(
                                    '${c['classCode']} • ${q['type'] == 'quiz' ? 'Quiz' : 'Poll'} • ${activityStatus(q['status'])}',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => context.push('/quiz/${q['id']}'),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

String activityStatus(String value) => switch (value) {
  'scheduled' => 'Chưa mở',
  'open' => 'Đang mở',
  'published' => 'Đã công bố',
  _ => 'Đã đóng',
};

class QuizOptionTile extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback? onTap;
  const QuizOptionTile({
    super.key,
    required this.text,
    required this.selected,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? colors.primaryContainer : colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: selected ? colors.primary : colors.outline,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(text)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CreateQuizPage extends ConsumerStatefulWidget {
  final UserProfile user;
  const CreateQuizPage({super.key, required this.user});
  @override
  ConsumerState<CreateQuizPage> createState() => _CreateQuizPageState();
}

class _CreateQuizPageState extends ConsumerState<CreateQuizPage> {
  final question = TextEditingController();
  final answers = List.generate(5, (_) => TextEditingController());
  String? classId;
  String type = 'quiz';
  int correct = 0, count = 2, duration = 180;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    question.dispose();
    for (final a in answers) {
      a.dispose();
    }
    super.dispose();
  }

  Future<void> create() async {
    if (classId == null ||
        question.text.trim().isEmpty ||
        answers.take(count).any((a) => a.text.trim().isEmpty)) {
      setState(() => error = 'Chọn lớp và nhập đủ câu hỏi, đáp án.');
      return;
    }
    setState(() => busy = true);
    try {
      final d = <String, dynamic>{
        'classId': classId,
        'type': type,
        'question': question.text.trim(),
        'options': List.generate(
          count,
          (i) => {'id': 'option_$i', 'text': answers[i].text.trim()},
        ),
        'durationSeconds': duration,
      };
      if (type == 'quiz') d['correctOptionId'] = 'option_$correct';
      final result = await ref.read(repositoryProvider).call('createQuiz', d);
      if (mounted) {
        final router = GoRouter.of(context);
        Navigator.pop(context);
        router.push('/quiz/${result['quizId']}');
      }
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tạo hoạt động')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LiveList(
          source: () => ref.read(repositoryProvider).classes(widget.user),
          builder: (classes) => DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: classId,
            decoration: const InputDecoration(labelText: 'Lớp'),
            items: classes
                .map(
                  (c) => DropdownMenuItem<String>(
                    value: c['id'],
                    child: Text('${c['classCode']} / ${c['subjectId']}'),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => classId = v),
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'quiz', label: Text('Quiz')),
            ButtonSegment(value: 'poll', label: Text('Poll')),
          ],
          selected: {type},
          onSelectionChanged: (v) => setState(() => type = v.first),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: question,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Câu hỏi'),
        ),
        DropdownButtonFormField<int>(
          isExpanded: true,
          initialValue: count,
          decoration: const InputDecoration(labelText: 'Số lựa chọn'),
          items: [2, 3, 4, 5]
              .map(
                (n) => DropdownMenuItem(value: n, child: Text('$n lựa chọn')),
              )
              .toList(),
          onChanged: (v) => setState(() {
            count = v!;
            if (correct >= count) correct = 0;
          }),
        ),
        const SizedBox(height: 16),
        ...List.generate(
          count,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: answers[i],
              maxLength: 200,
              decoration: InputDecoration(labelText: 'Lựa chọn ${i + 1}'),
            ),
          ),
        ),
        if (type == 'quiz')
          DropdownButtonFormField<int>(
            isExpanded: true,
            key: ValueKey(count),
            initialValue: correct,
            decoration: const InputDecoration(
              labelText: 'Đáp án đúng (chỉ backend lưu)',
            ),
            items: List.generate(
              count,
              (i) =>
                  DropdownMenuItem(value: i, child: Text('Lựa chọn ${i + 1}')),
            ),
            onChanged: (v) => setState(() => correct = v!),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          isExpanded: true,
          initialValue: duration,
          decoration: const InputDecoration(labelText: 'Thời lượng'),
          items: [60, 180, 300, 600, 900]
              .map(
                (n) =>
                    DropdownMenuItem(value: n, child: Text('${n ~/ 60} phút')),
              )
              .toList(),
          onChanged: (v) => setState(() => duration = v!),
        ),
        const SizedBox(height: 16),
        if (error != null) Text(error!),
        AppPrimaryButton(label: 'Lưu hoạt động', busy: busy, onPressed: create),
      ],
    ),
  );
}

class QuizPage extends ConsumerStatefulWidget {
  final String quizId;
  const QuizPage({super.key, required this.quizId});
  @override
  ConsumerState<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends ConsumerState<QuizPage> {
  String? selected;
  bool busy = false;
  String? message;
  Timer? timer;
  late Stream<Data?> stream;
  final Map<String, Stream<Data?>> documents = {};
  Stream<Data?> watchDocument(String path) => documents.putIfAbsent(
    path,
    () => ref.read(repositoryProvider).document(path),
  );
  @override
  void initState() {
    super.initState();
    stream = ref.read(repositoryProvider).document('quizzes/${widget.quizId}');
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> action(String name, Data input) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await ref.read(repositoryProvider).call(name, input);
      if (mounted) {
        setState(
          () => message = name == 'submitQuiz'
              ? 'Đã gửi câu trả lời. Kết quả công bố sau khi đóng.'
              : null,
        );
      }
    } catch (e) {
      if (name == 'submitQuiz') {
        try {
          final uid = ref.read(profileProvider).value!.uid;
          final existing = await ref
              .read(repositoryProvider)
              .serverRecord('quizResponses/${widget.quizId}_$uid');
          if (existing != null) {
            if (mounted) {
              setState(() => message = 'Câu trả lời đã được ghi nhận.');
            }
            return;
          }
        } catch (_) {}
      }
      if (mounted) setState(() => message = errorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(profileProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz và Poll')),
      body: StreamBuilder<Data?>(
        stream: stream,
        builder: (context, s) {
          if (s.hasError) {
            return ErrorState(
              s.error!,
              () => setState(
                () => stream = ref
                    .read(repositoryProvider)
                    .document('quizzes/${widget.quizId}'),
              ),
            );
          }
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.data == null || user == null) {
            return const EmptyState('Không tìm thấy hoạt động.');
          }
          final q = s.data!,
              options = (s.data!['options'] as List)
                  .map((o) => Map<String, dynamic>.from(o))
                  .toList();
          final remaining = q['closesAt'] == null
              ? 0
              : dateValue(q['closesAt']).difference(DateTime.now()).inSeconds;
          final open = q['status'] == 'open' && remaining > 0;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              CampusCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q['type'] == 'quiz' ? 'Quiz' : 'Poll'),
                    Text(
                      q['question'],
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(activityStatus(q['status'])),
                    if (q['status'] == 'open')
                      Text('Còn ${remaining.clamp(0, 900)} giây'),
                  ],
                ),
              ),
              if (user.isLecturer && q['status'] == 'scheduled')
                AppPrimaryButton(
                  label: 'Mở hoạt động',
                  busy: busy,
                  onPressed: () =>
                      action('openQuiz', {'quizId': widget.quizId}),
                ),
              if (user.isLecturer && q['status'] == 'open')
                AppPrimaryButton(
                  label: 'Đóng và công bố kết quả',
                  busy: busy,
                  onPressed: () =>
                      action('closeQuiz', {'quizId': widget.quizId}),
                ),
              if (!user.isLecturer)
                StreamBuilder<Data?>(
                  stream: watchDocument(
                    'quizResponses/${widget.quizId}_${user.uid}',
                  ),
                  builder: (context, response) {
                    if (response.hasError) {
                      return ErrorState(response.error!, () => setState(() {}));
                    }
                    if (response.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    final submitted = response.data != null;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (submitted)
                          const CampusCard(
                            child: Text('Bạn đã gửi câu trả lời.'),
                          ),
                        ...options.map(
                          (o) => QuizOptionTile(
                            text: o['text'],
                            selected: submitted
                                ? response.data!['selectedOptionId'] == o['id']
                                : selected == o['id'],
                            onTap: open && !submitted && !busy
                                ? () => setState(() => selected = o['id'])
                                : null,
                          ),
                        ),
                        if (open && !submitted)
                          AppPrimaryButton(
                            label: 'Gửi câu trả lời',
                            busy: busy,
                            onPressed: selected == null
                                ? null
                                : () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: const Text('Gửi câu trả lời?'),
                                        content: const Text(
                                          'Bạn chỉ được gửi một lần.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, false),
                                            child: const Text('Quay lại'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(c, true),
                                            child: const Text('Gửi'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      action('submitQuiz', {
                                        'quizId': widget.quizId,
                                        'selectedOptionId': selected,
                                      });
                                    }
                                  },
                          ),
                      ],
                    );
                  },
                ),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(message!),
                ),
              if (user.isLecturer || q['status'] == 'published')
                StreamBuilder<Data?>(
                  stream: watchDocument(
                    '${q['status'] == 'published' ? 'quizResults' : 'quizStats'}/${widget.quizId}',
                  ),
                  builder: (context, stats) {
                    if (stats.hasError) {
                      return ErrorState(stats.error!, () => setState(() {}));
                    }
                    if (!stats.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final total = (stats.data!['totalResponses'] as num)
                            .toInt(),
                        counts = Map<String, dynamic>.from(
                          stats.data!['optionCounts'],
                        );
                    return CampusCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Phản hồi: $total',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (total == 0) const Text('Chưa có phản hồi'),
                          ...options.map((o) {
                            final count = (counts[o['id']] as num? ?? 0)
                                .toInt();
                            final correct =
                                stats.data!['correctOptionId'] == o['id'];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${o['text']}${correct ? ' • Đáp án đúng' : ''}',
                                  ),
                                  LinearProgressIndicator(
                                    value: total == 0 ? 0 : count / total,
                                    minHeight: 10,
                                  ),
                                  Text(
                                    '$count • ${total == 0 ? '0' : (count / total * 100).toStringAsFixed(1)}%',
                                  ),
                                ],
                              ),
                            );
                          }),
                          if (stats.data!['correctCount'] != null && total > 0)
                            Text(
                              'Tỷ lệ đúng: ${((stats.data!['correctCount'] as num) / total * 100).toStringAsFixed(1)}%',
                            ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
