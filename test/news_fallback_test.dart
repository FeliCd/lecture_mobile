import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/news.dart';
import 'package:lecturer_companion/lab2/public_news.dart';
import 'package:lecturer_companion/lab2/repository.dart';
import 'lab2_navigation_test.dart' show FixtureRepository;

http.Response publicResponse() => http.Response(
  jsonEncode({
    'message': {
      'items': [
        {
          'DOI': '10.1000/TEST',
          'title': ['Mobile learning'],
          'publisher': 'Publisher',
          'author': [
            {'given': 'An', 'family': 'Tran'},
          ],
          'published': {
            'date-parts': [
              [2026, 10, 9],
            ],
          },
        },
        {
          'DOI': '10.1000/test',
          'title': ['Mobile learning'],
          'publisher': 'Publisher',
        },
        {
          'title': ['Unsafe URL'],
          'URL': 'https://secret@evil.example',
        },
      ],
    },
  }),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class BrokenNewsRepository extends FixtureRepository {
  final String error;
  BrokenNewsRepository(this.error);
  @override
  Future<Data> call(String name, Data input) async => throw StateError(error);
}

void main() {
  test(
    'public Crossref request preserves filters and sends no credentials',
    () async {
      final news = PublicNews(
        MockClient((request) async {
          expect(request.url.host, 'api.crossref.org');
          expect(request.url.queryParameters['query'], 'mobile learning');
          expect(request.url.queryParameters['offset'], '20');
          expect(
            request.url.queryParameters['filter'],
            'from-pub-date:2026-01-01',
          );
          expect(request.headers['Authorization'], isNull);
          expect(request.body, isEmpty);
          return publicResponse();
        }),
      );
      final result = await news.fetch({
        'subjectId': 'PRM393',
        'query': ' mobile learning ',
        'page': 2,
        'fromDate': '2026-01-01',
      });
      final articles = result['articles'] as List;
      expect(articles.length, 1);
      expect(articles.single['source'], 'Crossref');
      expect(articles.single['canShare'], false);
      expect(articles.single['url'], 'https://doi.org/10.1000/test');
    },
  );
  test(
    'authentication, permissions and rate limiting never use public fallback',
    () {
      for (final error in [
        'UNAUTHENTICATED',
        'PERMISSION_DENIED',
        'EMAIL_NOT_VERIFIED',
        'RATE_LIMITED',
      ]) {
        expect(canUsePublicNews(StateError(error)), false);
      }
      expect(canUsePublicNews(StateError('INVALID_SHEET_IDS')), true);
    },
  );
  for (final error in ['INVALID_SHEET_IDS', 'PERMISSION_DENIED']) {
    testWidgets('news handles $error without hiding the actual source', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(BrokenNewsRepository(error)),
            publicNewsProvider.overrideWithValue(
              PublicNews(
                MockClient((_) async {
                  calls++;
                  return publicResponse();
                }),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: NewsPanel(
                user: UserProfile('teacher', 'Giảng viên', 'lecturer', [
                  'PRM393',
                ]),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (error == 'INVALID_SHEET_IDS') {
        expect(calls, 1);
        expect(find.text('Mobile learning'), findsOneWidget);
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Crossref'))
              .selected,
          true,
        );
        expect(
          find.textContaining('Đang tải trực tiếp từ Crossref'),
          findsOneWidget,
        );
      } else {
        expect(calls, 0);
        expect(find.text('Mobile learning'), findsNothing);
        expect(
          find.text('Bạn không có quyền thao tác với lớp này.'),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
