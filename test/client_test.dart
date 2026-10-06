import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lecturer_companion/api/client.dart';
import 'package:lecturer_companion/core/config.dart';

void main() {
  test(
    'Unregistered lecturer rejection remains distinct from resource permissions',
    () {
      final error = mapBackendError(
        'Email chưa có trong Lecturers hoặc hồ sơ bị trùng. Liên hệ trưởng nhóm.',
      );
      expect(error.message, contains('not registered as a lecturer'));
      expect(error.unauthenticated, false);
    },
  );
  const url = 'https://script.google.com/macros/s/test/exec';
  AppsScriptApi api(
    http.Client client, {
    Future<void> Function()? unauthorized,
    Duration timeout = const Duration(seconds: 1),
  }) => AppsScriptApi(
    url: url,
    tokenProvider: () async => 'private-id-token',
    onUnauthorized: unauthorized ?? () async {},
    client: client,
    timeout: timeout,
  );
  test(
    'Token and action go in POST body; redirect GET has no credentials',
    () async {
      var count = 0;
      final client = MockClient((request) async {
        count++;
        if (count == 1) {
          expect(request.method, 'POST');
          expect(request.followRedirects, false);
          expect(jsonDecode(request.body)['idToken'], 'private-id-token');
          expect(request.url.query, isEmpty);
          return http.Response(
            '',
            303,
            headers: {
              'location': 'https://script.googleusercontent.com/result?id=x',
            },
          );
        }
        expect(request.method, 'GET');
        expect(request.body, isEmpty);
        expect(request.headers.containsKey('authorization'), false);
        expect(request.followRedirects, false);
        return http.Response('{"ok":true,"data":[]}', 200);
      });
      expect(await api(client).call('profile'), isEmpty);
      expect(count, 2);
    },
  );
  test('Untrusted redirects fail without forwarding token', () async {
    var count = 0;
    final service = api(
      MockClient((_) async {
        count++;
        return http.Response(
          '',
          302,
          headers: {'location': 'https://attacker.invalid/'},
        );
      }),
    );
    await expectLater(service.call('profile'), throwsA(isA<AppFailure>()));
    expect(count, 1);
  });
  test('401 invalidates authentication', () async {
    var invalidated = false;
    await expectLater(
      api(
        MockClient((_) async => http.Response('', 401)),
        unauthorized: () async {
          invalidated = true;
        },
      ).call('profile'),
      throwsA(isA<AppFailure>()),
    );
    expect(invalidated, true);
  });
  test('HTTP 200 expired Google envelope invalidates authentication', () async {
    var invalidated = false;
    await expectLater(
      api(
        MockClient(
          (_) async => http.Response(
            jsonEncode({'ok': false, 'error': 'Phiên Google không hợp lệ.'}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
        unauthorized: () async {
          invalidated = true;
        },
      ).call('profile'),
      throwsA(isA<AppFailure>()),
    );
    expect(invalidated, true);
  });
  for (final code in [403, 404, 409, 500]) {
    test('HTTP $code is a safe error, never a backend trace', () async {
      await expectLater(
        api(
          MockClient((_) async => http.Response('SECRET STACK TRACE', code)),
        ).call('getRows'),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.message,
            'safe message',
            isNot(contains('SECRET')),
          ),
        ),
      );
    });
  }
  test('Timeout is actionable', () async {
    await expectLater(
      api(
        MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return http.Response('{}', 200);
        }),
        timeout: const Duration(milliseconds: 1),
      ).call('profile'),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.message,
          'message',
          contains('timed out'),
        ),
      ),
    );
  });
  test('Offline client errors are mapped', () async {
    await expectLater(
      api(
        MockClient((_) async => throw http.ClientException('private URL')),
      ).call('profile'),
      throwsA(isA<AppFailure>()),
    );
  });
  test('Malformed JSON and unknown backend errors are sanitized', () async {
    for (final body in [
      '<html>secret</html>',
      jsonEncode({'ok': false, 'error': 'stack trace private'}),
    ]) {
      await expectLater(
        api(MockClient((_) async => http.Response(body, 200))).call('profile'),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.message,
            'message',
            isNot(contains('private')),
          ),
        ),
      );
    }
  });
  test('Localhost, arbitrary hosts and query-bearing API URLs rejected', () {
    for (final url in [
      'http://127.0.0.1:8765',
      'https://other.invalid/exec',
      'https://script.google.com/macros/s/x/exec?token=secret',
    ]) {
      expect(AppConfig.validEndpoint(url), false);
    }
  });
}
