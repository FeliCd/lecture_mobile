import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'domain.dart';
import 'widgets.dart';
import 'repository.dart' show authProvider;

final articleLibraryProvider = Provider((ref) => ArticleLibrary());
final savedArticlesProvider = StreamProvider.autoDispose<List<Data>>((ref) {
  ref.watch(authProvider);
  return ref.watch(articleLibraryProvider).watch();
});

String articleKey(Data article) {
  final doi = '${article['doi'] ?? article['DOI'] ?? ''}'.trim().toLowerCase();
  return sha256
      .convert(utf8.encode(doi.isNotEmpty ? doi : '${article['url']}'.trim()))
      .toString();
}

class ArticleLibrary {
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  ArticleLibrary({FirebaseFirestore? firestore, FirebaseAuth? authentication})
    : db = firestore ?? FirebaseFirestore.instance,
      auth = authentication ?? FirebaseAuth.instance;
  CollectionReference<Data> get collection {
    final user = auth.currentUser;
    if (user == null) throw StateError('UNAUTHENTICATED');
    return db.collection('articleLibraries/${user.uid}/articles');
  }

  Stream<List<Data>> watch() => collection
      .orderBy('savedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  Stream<Data?> article(Data article) => collection
      .doc(articleKey(article))
      .snapshots()
      .map((s) => s.exists ? {...s.data()!, 'id': s.id} : null);
  Future<void> save(Data article, String summary) async {
    final url = Uri.tryParse('${article['url']}');
    if (url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        '${article['title'] ?? ''}'.trim().isEmpty ||
        summary.length > 12000) {
      throw StateError('INVALID_INPUT');
    }
    final document = collection.doc(articleKey(article));
    await db.runTransaction((t) async {
      final old = await t.get(document);
      t.set(document, {
        'title': '${article['title']}'.trim(),
        'url': url.toString(),
        'doi': '${article['doi'] ?? article['DOI'] ?? ''}',
        'source': '${article['source'] ?? ''}',
        'publisher': '${article['publisher'] ?? ''}',
        'contentType': article['contentType'] ?? 'RESEARCH',
        'authors': List<String>.from(
          article['authors'] ?? [],
        ).take(30).toList(),
        'publishedAt': '${article['publishedAt'] ?? ''}',
        'subjectIds': List<String>.from(
          article['subjectIds'] ?? [],
        ).take(30).toList(),
        'sourceSummary':
            '${article['abstractSnippet'] ?? article['sourceSummary'] ?? ''}'
                .substring(
                  0,
                  '${article['abstractSnippet'] ?? article['sourceSummary'] ?? ''}'
                      .length
                      .clamp(0, 12000),
                ),
        'summary': summary.trim(),
        'savedAt': old.data()?['savedAt'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> remove(Data article) =>
      collection.doc(articleKey(article)).delete();
}

class ArticleDetailsPage extends ConsumerStatefulWidget {
  final Data article;
  const ArticleDetailsPage({super.key, required this.article});
  @override
  ConsumerState<ArticleDetailsPage> createState() => _ArticleDetailsPageState();
}

class _ArticleDetailsPageState extends ConsumerState<ArticleDetailsPage> {
  late final summary = TextEditingController(
    text:
        '${widget.article['summary'] ?? widget.article['abstractSnippet'] ?? ''}',
  );
  late final Stream<Data?> saved = ref
      .read(articleLibraryProvider)
      .article(widget.article);
  bool busy = false, dirty = false, initialized = false;
  @override
  void dispose() {
    summary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CampusDraftGuard(
    dirty: dirty,
    busy: busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Chi tiết bài báo')),
      body: StreamBuilder<Data?>(
        stream: saved,
        builder: (context, snapshot) {
          if (!initialized &&
              snapshot.connectionState != ConnectionState.waiting) {
            initialized = true;
            if (!dirty && snapshot.data != null) {
              summary.text = snapshot.data!['summary'] ?? '';
            }
          }
          final article = widget.article;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                '${article['title']}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                '${article['source'] ?? ''} • ${article['publisher'] ?? ''}',
              ),
              Text((article['authors'] as List? ?? []).join(', ')),
              if ('${article['publishedAt'] ?? ''}'.isNotEmpty)
                Text('${article['publishedAt']}'),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text('Đọc bài gốc'),
                onPressed: () => runAction(context, () async {
                  final url = Uri.tryParse('${article['url']}');
                  if (url == null ||
                      url.scheme != 'https' ||
                      url.userInfo.isNotEmpty) {
                    throw StateError('INVALID_INPUT');
                  }
                  if (!await launchUrl(
                    url,
                    mode: LaunchMode.externalApplication,
                  )) {
                    throw StateError('unavailable');
                  }
                }),
              ),
              const SizedBox(height: 20),
              Text(
                'Tóm tắt của bạn',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Sử dụng tóm tắt từ nguồn hoặc chỉnh sửa nội dung để lưu vào thư viện riêng.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: summary,
                enabled: !busy,
                minLines: 6,
                maxLines: 18,
                maxLength: 12000,
                onChanged: (_) => setState(() => dirty = true),
                decoration: const InputDecoration(
                  hintText: 'Bài báo chưa có tóm tắt. Bạn có thể nhập tại đây.',
                ),
              ),
              if (snapshot.hasError) Text(errorMessage(snapshot.error!)),
              const SizedBox(height: 16),
              AppPrimaryButton(
                label: snapshot.data == null
                    ? 'Lưu bài báo và tóm tắt'
                    : 'Cập nhật tóm tắt',
                busy: busy,
                onPressed: snapshot.connectionState == ConnectionState.waiting
                    ? null
                    : () async {
                        setState(() => busy = true);
                        await runAction(context, () async {
                          await ref
                              .read(articleLibraryProvider)
                              .save(article, summary.text);
                          dirty = false;
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã lưu vào thư viện của bạn.'),
                              ),
                            );
                          }
                        });
                        if (mounted) setState(() => busy = false);
                      },
              ),
              if (snapshot.data != null)
                TextButton.icon(
                  icon: const Icon(Icons.bookmark_remove_outlined),
                  label: const Text('Bỏ lưu bài viết'),
                  onPressed: busy
                      ? null
                      : () async {
                          final confirmed = await campusConfirm(
                            context,
                            title: 'Bỏ lưu bài viết?',
                            message:
                                'Bài viết và ghi chú riêng sẽ được bỏ khỏi thư viện. Bạn vẫn có thể tìm và lưu lại bài gốc.',
                            confirm: 'Bỏ lưu',
                            destructive: true,
                          );
                          if (!confirmed || !context.mounted || busy) return;
                          setState(() => busy = true);
                          await runAction(context, () async {
                            await ref
                                .read(articleLibraryProvider)
                                .remove(article);
                            if (context.mounted) Navigator.pop(context);
                          });
                          if (mounted) setState(() => busy = false);
                        },
                ),
            ],
          );
        },
      ),
    ),
  );
}

class SavedArticlesPanel extends ConsumerStatefulWidget {
  const SavedArticlesPanel({super.key});
  @override
  ConsumerState<SavedArticlesPanel> createState() => _SavedArticlesPanelState();
}

class _SavedArticlesPanelState extends ConsumerState<SavedArticlesPanel> {
  String query = '';
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final articles = ref.watch(savedArticlesProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: CampusSearchField(
            controller: search,
            hint: 'Tìm trong bài báo đã lưu',
            onChanged: (v) => setState(() => query = v.toLowerCase().trim()),
          ),
        ),
        Expanded(
          child: articles.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                ErrorState(e, () => ref.invalidate(savedArticlesProvider)),
            data: (rows) {
              final filtered = rows
                  .where(
                    (r) =>
                        '${r['title']} ${r['summary']} ${(r['subjectIds'] as List? ?? []).join(' ')}'
                            .toLowerCase()
                            .contains(query),
                  )
                  .toList();
              if (filtered.isEmpty) {
                return EmptyState(
                  rows.isEmpty
                      ? 'Thư viện chưa có bài viết. Lưu bài từ Tin tức hoặc Nghiên cứu.'
                      : 'Không có bài viết khớp từ khóa.',
                  actionLabel: query.isEmpty ? null : 'Xóa tìm kiếm',
                  onAction: () => setState(() {
                    query = '';
                    search.clear();
                  }),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final article = filtered[i];
                  return CampusCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${article['title']}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${article['summary'] ?? ''}'.isEmpty
                            ? 'Chưa có tóm tắt'
                            : '${article['summary']}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ArticleDetailsPage(article: article),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
