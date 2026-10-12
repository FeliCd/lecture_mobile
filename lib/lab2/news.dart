import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'domain.dart';
import 'repository.dart';
import 'widgets.dart';
import 'article_library.dart';
import 'public_news.dart';

Future<void> openSource(BuildContext context, String url) =>
    runAction(context, () async {
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
        throw StateError('INVALID_INPUT');
      }
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('unavailable');
      }
    });

class ArticleCard extends StatelessWidget {
  final Data article;
  final VoidCallback onTap;
  const ArticleCard({super.key, required this.article, required this.onTap});
  @override
  Widget build(BuildContext context) => CampusCard(
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            article['title'] ?? '',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text('${article['source']} • ${article['publisher']}'),
          Text(article['publishedAt'] ?? 'Chưa có ngày xuất bản'),
          const SizedBox(height: 8),
          Text(
            (article['authors'] as List? ?? []).join(', '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          const Text('Xem thông tin bài viết →'),
        ],
      ),
    ),
  );
}

Future<void> articleDetails(
  BuildContext context,
  CampusRepository repo,
  Data article,
  UserProfile user,
) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ArticleDetailsPage(article: article),
    ),
  );
}

class ArticlesWorkspace extends StatefulWidget {
  final UserProfile user;
  const ArticlesWorkspace({super.key, required this.user});
  @override
  State<ArticlesWorkspace> createState() => _ArticlesWorkspaceState();
}

class _ArticlesWorkspaceState extends State<ArticlesWorkspace> {
  int selected = 0;
  bool libraryOpened = false;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              label: Text('Khám phá'),
              icon: Icon(Icons.travel_explore),
            ),
            ButtonSegment(
              value: 1,
              label: Text('Đã lưu'),
              icon: Icon(Icons.bookmark_outline),
            ),
          ],
          selected: {selected},
          onSelectionChanged: (s) => setState(() {
            selected = s.first;
            libraryOpened |= selected == 1;
          }),
        ),
      ),
      Expanded(
        child: IndexedStack(
          index: selected,
          children: [
            NewsPanel(user: widget.user),
            libraryOpened
                ? const SavedArticlesPanel()
                : const SizedBox.shrink(),
          ],
        ),
      ),
    ],
  );
}

class NewsPanel extends ConsumerStatefulWidget {
  final UserProfile user;
  const NewsPanel({super.key, required this.user});
  @override
  ConsumerState<NewsPanel> createState() => _NewsPanelState();
}

class _NewsPanelState extends ConsumerState<NewsPanel> {
  String? subject;
  String source = 'OpenAlex', query = '', sort = 'recent';
  int days = 0, page = 1;
  Data? feed;
  List<Data> articles = [];
  bool busy = false;
  bool publicFallback = false, retryMore = false;
  Object? error;
  Timer? debounce;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    subject = widget.user.subjectIds.firstOrNull;
    load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    generation++;
    super.dispose();
  }

  Future<void> load({bool more = false}) async {
    if (subject == null) return;
    final request = ++generation;
    setState(() {
      busy = true;
      retryMore = more;
      error = null;
      if (!more) {
        page = 1;
        articles = [];
        feed = null;
      }
    });
    try {
      final input = <String, dynamic>{
        'subjectId': subject,
        'source': source,
        'query': query.trim(),
        'page': page,
        'sort': sort,
      };
      if (days > 0) {
        input['fromDate'] = DateTime.now()
            .toUtc()
            .subtract(Duration(days: days))
            .toIso8601String()
            .split('T')
            .first;
      }
      Data data;
      if (more && publicFallback) {
        data = await ref.read(publicNewsProvider).fetch(input);
      } else {
        try {
          data = await ref
              .read(repositoryProvider)
              .call('discoverArticles', input);
        } catch (e) {
          if (!canUsePublicNews(e) || more) rethrow;
          if (!mounted || request != generation) return;
          data = await ref.read(publicNewsProvider).fetch(input);
        }
      }
      if (data['articles'] is! List) {
        throw StateError('INVALID_ARTICLE_RESPONSE');
      }
      if (mounted && request == generation) {
        setState(() {
          feed = data;
          publicFallback = data['publicFallback'] == true;
          if (publicFallback) source = 'Crossref';
          final fetched = (data['articles'] as List)
              .map(
                (a) => {
                  ...Map<String, dynamic>.from(a as Map),
                  'subjectIds': [input['subjectId']],
                },
              )
              .toList();
          final unique = {
            for (final a in [...articles, ...fetched]) a['id']: a,
          };
          articles = unique.values.toList();
          if (const bool.fromEnvironment('NEWS_DIAGNOSTICS')) {
            debugPrint(
              'News loaded [$source]: ${articles.length} articles, publicFallback=$publicFallback',
            );
          }
        });
      }
    } catch (e) {
      if (const bool.fromEnvironment('NEWS_DIAGNOSTICS')) {
        // Request bodies, URLs and authentication credentials are never logged.
        final message = e is StateError ? e.message : e.runtimeType.toString();
        final safe = !RegExp(
          r'https?:|token|key|bearer',
          caseSensitive: false,
        ).hasMatch(message);
        debugPrint(
          'News failure [$source]: ${safe ? message.substring(0, message.length.clamp(0, 240)) : e.runtimeType}',
        );
      }
      if (mounted && request == generation) setState(() => error = e);
    } finally {
      if (mounted && request == generation) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      if (subject == null) const EmptyState('Chưa có môn được phân công.'),
      if (subject != null)
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: subject,
          decoration: const InputDecoration(labelText: 'Môn học'),
          items: widget.user.subjectIds
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (s) {
            setState(() => subject = s);
            load();
          },
        ),
      const SizedBox(height: 12),
      TextField(
        decoration: const InputDecoration(
          labelText: 'Tìm bài báo',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (v) {
          query = v;
          debounce?.cancel();
          debounce = Timer(const Duration(milliseconds: 600), () => load());
        },
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: ['OpenAlex', 'Crossref']
            .map(
              (s) => ChoiceChip(
                label: Text(s),
                selected: source == s,
                onSelected: (_) {
                  setState(() => source = s);
                  load();
                },
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: sort,
        decoration: const InputDecoration(labelText: 'Sắp xếp'),
        items: const [
          DropdownMenuItem(value: 'recent', child: Text('Mới nhất')),
          DropdownMenuItem(value: 'relevance', child: Text('Liên quan')),
        ],
        onChanged: (v) {
          setState(() => sort = v!);
          load();
        },
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: [0, 30, 365]
            .map(
              (d) => ChoiceChip(
                label: Text(d == 0 ? 'Mọi thời gian' : '$d ngày'),
                selected: days == d,
                onSelected: (_) {
                  setState(() => days = d);
                  load();
                },
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 16),
      if (feed != null)
        Text(
          '${feed!['cached'] == true ? 'Dữ liệu cache' : 'Đã tải từ nguồn'} • ${localDate(dateValue(feed!['fetchedAt']))}${feed!['stale'] == true ? ' • Nguồn lỗi, đang dùng dữ liệu cũ' : ''}',
        ),
      if (feed?['publicFallback'] == true)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Đang tải trực tiếp từ Crossref vì nguồn qua backend chưa sẵn sàng.',
          ),
        ),
      if (error != null) ErrorState(error!, () => load(more: retryMore)),
      if (!busy && error == null && articles.isEmpty)
        const EmptyState('Không tìm thấy bài phù hợp.'),
      ...articles.map(
        (a) => ArticleCard(
          article: a,
          onTap: () => articleDetails(
            context,
            ref.read(repositoryProvider),
            a,
            widget.user,
          ),
        ),
      ),
      if (busy) const Center(child: CircularProgressIndicator()),
      if (!busy && feed?['nextPage'] != null)
        OutlinedButton(
          onPressed: () {
            page = (feed!['nextPage'] as num).toInt();
            load(more: true);
          },
          child: const Text('Tải thêm'),
        ),
    ],
  );
}
