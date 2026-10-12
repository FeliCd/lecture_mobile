import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain.dart';

final publicNewsProvider = Provider<PublicNews>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return PublicNews(client);
});

// Crossref's public API requires no credentials. Used only when the shared
// scholarly feed is unavailable; no roster or authentication data is sent.
class PublicNews {
  final http.Client client;
  PublicNews(this.client);
  Future<Data> fetch(Data input) async {
    const keywords = {
      'PRM393': 'Flutter Dart mobile development',
      'PRN212': 'ASP.NET Core',
      'SWE201c': 'software engineering',
    };
    final query = '${input['query'] ?? ''}'.trim();
    final search = query.isNotEmpty ? query : keywords[input['subjectId']];
    if (search == null || search.isEmpty || search.length > 150) {
      throw StateError('PUBLIC_NEWS_QUERY_REQUIRED');
    }
    final page = (input['page'] as num? ?? 1).toInt();
    final uri = Uri.https('api.crossref.org', '/works', {
      'query': search,
      'rows': '20',
      'offset': '${(page - 1) * 20}',
      'sort': input['sort'] == 'relevance' ? 'relevance' : 'published',
      'order': 'desc',
      'select': 'DOI,title,publisher,author,published,URL,abstract',
      if (input['fromDate'] != null)
        'filter': 'from-pub-date:${input['fromDate']}',
    });
    final response = await client
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'FAP-Smart-Lecturer/1.0',
          },
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw StateError('ARTICLE_SOURCE_UNAVAILABLE');
    }
    final payload = jsonDecode(utf8.decode(response.bodyBytes));
    final message = payload is Map ? payload['message'] : null;
    final items = message is Map ? message['items'] : null;
    if (items is! List) throw StateError('INVALID_ARTICLE_RESPONSE');
    final articles = <String, Data>{};
    for (final item in items.whereType<Map>()) {
      final titles = item['title'];
      final title = titles is List && titles.isNotEmpty
          ? '${titles.first}'.trim()
          : '';
      final doi = '${item['DOI'] ?? ''}'.trim().toLowerCase();
      final url = doi.isNotEmpty
          ? 'https://doi.org/$doi'
          : '${item['URL'] ?? ''}';
      final parsed = Uri.tryParse(url);
      if (title.isEmpty ||
          parsed == null ||
          parsed.scheme != 'https' ||
          parsed.host.isEmpty ||
          parsed.userInfo.isNotEmpty) {
        continue;
      }
      final published = item['published'];
      final dateParts = published is Map ? published['date-parts'] : null;
      final parts =
          dateParts is List && dateParts.isNotEmpty && dateParts.first is List
          ? dateParts.first as List
          : <dynamic>[];
      final id = doi.isNotEmpty ? doi : url;
      articles[id] = {
        'id': id,
        'doi': doi.isEmpty ? null : doi,
        'title': title,
        'url': url,
        'source': 'Crossref',
        'publisher': '${item['publisher'] ?? ''}',
        'authors': item['author'] is List
            ? (item['author'] as List)
                  .whereType<Map>()
                  .map(
                    (a) => [
                      a['given'],
                      a['family'],
                    ].where((v) => v != null).join(' '),
                  )
                  .where((v) => v.isNotEmpty)
                  .take(12)
                  .toList()
            : <String>[],
        'publishedAt': parts.isEmpty
            ? null
            : parts
                  .asMap()
                  .entries
                  .map(
                    (p) => p.key == 0
                        ? '${p.value}'
                        : '${p.value}'.padLeft(2, '0'),
                  )
                  .join('-'),
        'abstractSnippet': item['abstract'] is String
            ? (item['abstract'] as String)
                  .replaceAll(RegExp(r'<[^>]*>'), ' ')
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .trim()
            : null,
        'subjectIds': [input['subjectId']],
        'canShare': false,
      };
    }
    return {
      'articles': articles.values.toList(),
      'nextPage': items.length == 20 ? page + 1 : null,
      'source': 'Crossref',
      'fetchedAt': DateTime.now().millisecondsSinceEpoch,
      'cached': false,
      'publicFallback': true,
    };
  }
}

bool canUsePublicNews(Object error) => [
  'INVALID_SHEET_IDS',
  'INVALID_SHEET_SCHEMA',
  'ARTICLE_SOURCE_UNAVAILABLE',
  'ARTICLE_CACHE_FULL',
  'OPENALEX_SETUP_REQUIRED',
  'SHARED_BACKEND_SETUP_REQUIRED',
].any((code) => error.toString().contains(code));
