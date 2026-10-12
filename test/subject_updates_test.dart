import 'package:lecturer_companion/lab2/article_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/repository.dart';
import 'package:lecturer_companion/lab2/subject_updates.dart';
import 'lab2_navigation_test.dart' show FixtureRepository;

class UpdatesFixture extends FixtureRepository {
  final calls = <Data>[];
  @override
  Future<Data> call(String name, Data input) async {
    calls.add({'name': name, ...input});
    return {
      'configured': true,
      'sources': ['Official'],
      'items': [
        {
          'id': 'a',
          'title': 'Android release',
          'sourceName': 'Official',
          'canonicalUrl': 'https://example.com/a',
          'publishedAt': '2026-10-10T00:00:00Z',
          'excerpt': '',
          'subjectCodes': ['PRM393'],
          'matchedTopics': ['Android'],
        },
      ],
      'stale': true,
      'lastUpdatedAt': '2026-10-11T00:00:00Z',
      'partialSourcesFailed': ['Other source'],
      'nextCursor': null,
    };
  }
}

void main() {
  testWidgets(
    'authorized subject loads without query; type/date filters call backend and show provenance/stale',
    (tester) async {
      final repo = UpdatesFixture();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedArticlesProvider.overrideWith((ref) => Stream.value([])),
            repositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SubjectUpdatesPage(
                user: UserProfile('u', 'Teacher', 'lecturer', [
                  'PRM393',
                  'PRM393',
                ]),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.calls.single['subjectCode'], 'PRM393');
      expect(repo.calls.single['query'], '');
      expect(repo.calls.single['type'], 'NEWS');
      await tester.tap(find.text('Tất cả nguồn'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Official').last);
      await tester.pumpAndSettle();
      expect(repo.calls.last['source'], 'Official');
      await tester.tap(find.text('Nghiên cứu'));
      await tester.pumpAndSettle();
      expect(repo.calls.last['type'], 'RESEARCH');
      await tester.tap(find.text('7 ngày'));
      await tester.pumpAndSettle();
      expect(repo.calls.last['days'], 7);
      expect(find.textContaining('Dữ liệu cache có thể đã cũ'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Chưa có mô tả'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Phù hợp chủ đề: Android'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
