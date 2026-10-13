import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain.dart';
import 'repository.dart';
import 'widgets.dart';
import 'news.dart' show openSource;
import 'article_library.dart';

class SubjectUpdatesPage extends ConsumerStatefulWidget {
  final UserProfile user;
  const SubjectUpdatesPage({super.key, required this.user});
  @override
  ConsumerState<SubjectUpdatesPage> createState() => _SubjectUpdatesPageState();
}

class _SubjectUpdatesPageState extends ConsumerState<SubjectUpdatesPage> {
  String? subject, cursor;
  String type = 'NEWS', sort = 'LATEST';
  String source = '';
  Set<String> sources = {};
  final query = TextEditingController();
  int days = 30, generation = 0;
  bool busy = false;
  Data? feed;
  List<Data> items = [];
  Object? error;
  @override
  void initState() {
    super.initState();
    subject = widget.user.subjectIds.firstOrNull;
    load();
  }

  @override
  void dispose() {
    generation++;
    query.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SubjectUpdatesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid ||
        !widget.user.subjectIds.contains(subject)) {
      subject = widget.user.subjectIds.firstOrNull;
      source = '';
      sources = {};
      load();
    }
  }

  Future<void> load({bool more = false}) async {
    if (subject == null || type == 'SAVED') return;
    final current = ++generation;
    setState(() {
      busy = true;
      error = null;
      if (!more) {
        items = [];
        feed = null;
        cursor = null;
      }
    });
    try {
      final data = await ref
          .read(repositoryProvider)
          .call('getSubjectUpdates', {
            'subjectCode': subject,
            'type': type,
            'sort': sort,
            'days': days,
            'query': query.text.trim(),
            'source': source,
            'limit': 20,
            if (more && cursor != null) 'cursor': cursor,
          });
      if (!mounted || generation != current) return;
      if (data['items'] is! List) {
        throw StateError('ATTENDANCE_BACKEND_UPDATE_REQUIRED');
      }
      setState(() {
        feed = data;
        sources = (data['sources'] as List? ?? []).map((s) => '$s').toSet();
        cursor = data['nextCursor'] as String?;
        final fetched = (data['items'] as List).map(
          (r) => Map<String, dynamic>.from(r as Map),
        );
        items = {
          for (final r in [...items, ...fetched]) r['id']: r,
        }.values.toList();
      });
    } catch (e) {
      if (mounted && generation == current) setState(() => error = e);
    } finally {
      if (mounted && generation == current) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedArticlesProvider);
    final subjects = widget.user.subjectIds.toSet().toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 8,
            children: [
              for (final entry in {
                'NEWS': 'Tin tức',
                'RESEARCH': 'Nghiên cứu',
                'SAVED': 'Đã lưu',
              }.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: type == entry.key,
                  onSelected: (_) {
                    generation++;
                    setState(() {
                      type = entry.key;
                      source = '';
                      sources = {};
                      busy = false;
                    });
                    load();
                  },
                ),
            ],
          ),
        ),
        Expanded(
          child: type == 'SAVED'
              ? const SavedArticlesPanel()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const CampusSectionHeader(
                      title: 'Cập nhật kiến thức',
                      action: CampusHelpButton(
                        title: 'Hướng dẫn Cập nhật',
                        message:
                            'Chọn môn đang giảng dạy, loại nội dung và bộ lọc. '
                            'Bài viết giữ nguồn và ngày cập nhật để bạn đối chiếu. '
                            'Lưu bài và ghi chú vào thư viện riêng qua Lưu / ghi chú. '
                            'Nếu không có kết quả, thử xóa bộ lọc; nếu nguồn chưa cấu hình, liên hệ quản trị viên.',
                      ),
                    ),
                    if (subjects.isEmpty)
                      const EmptyState('Chưa có môn được phân công.'),
                    if (subjects.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: subject,
                        decoration: const InputDecoration(
                          labelText: 'Môn đang giảng dạy',
                        ),
                        items: subjects
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            subject = v;
                            source = '';
                            sources = {};
                          });
                          load();
                        },
                      ),
                      TextField(
                        controller: query,
                        decoration: InputDecoration(
                          labelText: 'Lọc từ khóa (tùy chọn)',
                          suffixIcon: IconButton(
                            tooltip: 'Tìm theo từ khóa',
                            onPressed: () => load(),
                            icon: const Icon(Icons.search),
                          ),
                        ),
                        onSubmitted: (_) => load(),
                      ),
                      if (sources.isNotEmpty)
                        DropdownButtonFormField<String>(
                          key: ValueKey('source-$source'),
                          isExpanded: true,
                          initialValue: source,
                          decoration: const InputDecoration(labelText: 'Nguồn'),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Tất cả nguồn'),
                            ),
                            ...sources.map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() => source = v ?? '');
                            load();
                          },
                        ),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final d in [0, 7, 30, 90])
                            ChoiceChip(
                              label: Text(d == 0 ? 'Mọi thời gian' : '$d ngày'),
                              selected: days == d,
                              onSelected: (_) {
                                setState(() => days = d);
                                load();
                              },
                            ),
                        ],
                      ),
                      DropdownButtonFormField<String>(
                        key: ValueKey('sort-$sort'),
                        isExpanded: true,
                        initialValue: sort,
                        decoration: const InputDecoration(labelText: 'Sắp xếp'),
                        items: const [
                          DropdownMenuItem(
                            value: 'LATEST',
                            child: Text('Mới nhất'),
                          ),
                          DropdownMenuItem(
                            value: 'RELEVANCE',
                            child: Text('Phù hợp'),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() => sort = v!);
                          load();
                        },
                      ),
                      OutlinedButton.icon(
                        onPressed: busy ? null : () => load(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Làm mới'),
                      ),
                      TextButton.icon(
                        onPressed: busy
                            ? null
                            : () {
                                query.clear();
                                setState(() {
                                  source = '';
                                  days = 30;
                                  sort = 'LATEST';
                                });
                                load();
                              },
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Đặt lại bộ lọc'),
                      ),
                      if (busy) const LinearProgressIndicator(),
                      if (error != null) ErrorState(error!, () => load()),
                      if (feed != null) ...[
                        Text(
                          feed!['lastUpdatedAt'] == null
                              ? 'Chưa cập nhật được từ nguồn'
                              : 'Cập nhật nguồn: ${localDate(DateTime.parse(feed!['lastUpdatedAt']))}',
                        ),
                        if (feed!['stale'] == true)
                          const Text(
                            'Dữ liệu cache có thể đã cũ. Một số nguồn chưa cập nhật được.',
                          ),
                        if ((feed!['partialSourcesFailed'] as List? ?? [])
                            .isNotEmpty)
                          Text(
                            'Nguồn chưa sẵn sàng: ${(feed!['partialSourcesFailed'] as List).join(', ')}',
                          ),
                        if (feed!['configured'] == false)
                          const EmptyState(
                            'Chưa có chủ đề hoặc nguồn cho môn này. Liên hệ người quản trị để cấu hình.',
                          ),
                        if (feed!['configured'] != false && items.isEmpty)
                          const EmptyState(
                            'Chưa có nội dung phù hợp với bộ lọc.',
                          ),
                      ],
                      ...items.map(
                        (item) => CampusCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item['title']}',
                                style: Theme.of(
                                  context,
                                ).textTheme.titleMedium?.copyWith(height: 1.35),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  '${item['sourceName']} • ${item['publishedAt'] == null ? 'Chưa có ngày đăng' : localDate(DateTime.parse(item['publishedAt']))}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              Text(
                                'Môn: ${(item['subjectCodes'] as List? ?? []).join(', ')}',
                              ),
                              Text(
                                'Phù hợp chủ đề: ${(item['matchedTopics'] as List? ?? []).join(', ')}',
                              ),
                              Text(
                                '${item['excerpt'] ?? ''}'.isEmpty
                                    ? 'Chưa có mô tả'
                                    : 'Mô tả từ nguồn: ${item['excerpt']}',
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(height: 1.5),
                              ),
                              Wrap(
                                spacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: () => openSource(
                                      context,
                                      '${item['canonicalUrl']}',
                                    ),
                                    child: const Text('Đọc bài gốc'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) => ArticleDetailsPage(
                                          article: normalizedUpdate({
                                            ...item,
                                            'contentType': type,
                                          }),
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      saved.value?.any(
                                                (r) =>
                                                    r['id'] ==
                                                    articleKey(
                                                      normalizedUpdate({
                                                        ...item,
                                                        'contentType': type,
                                                      }),
                                                    ),
                                              ) ==
                                              true
                                          ? 'Đã lưu / ghi chú'
                                          : 'Lưu / ghi chú',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (cursor != null)
                        OutlinedButton(
                          onPressed: busy ? null : () => load(more: true),
                          child: const Text('Tải thêm'),
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

Data normalizedUpdate(Data item) => {
  ...item,
  'url': item['canonicalUrl'] ?? item['url'],
  'source': item['sourceName'] ?? item['source'],
  'abstractSnippet': item['excerpt'] ?? '',
  'subjectIds': item['subjectCodes'] ?? [],
  'contentType': item['contentType'] ?? 'NEWS',
};
