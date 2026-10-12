import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lecturer_companion/lab2/desktop_sync.dart';

const endpoint = 'https://script.google.com/macros/s/test-deployment/exec';
http.Response response(String marker) => http.Response(
  jsonEncode({
    'ok': true,
    'data': {'marker': marker, 'collections': {}},
  }),
  200,
);
void main() {
  test('Google redirect receives no Firebase token or POST body', () async {
    var count = 0;
    final sync = DesktopSync(
      endpoint: endpoint,
      token: () async => 'private-token',
      identity: () => 'a',
      client: MockClient((r) async {
        count++;
        if (count == 1) {
          expect(jsonDecode(r.body)['idToken'], 'private-token');
          return http.Response(
            '',
            302,
            headers: {
              'location':
                  'https://script.googleusercontent.com/macros/echo?user_content_key=result',
            },
          );
        }
        expect(r.method, 'GET');
        expect(r.body, isEmpty);
        expect(r.headers['Authorization'], isNull);
        return response('a');
      }),
    );
    expect((await sync.snapshot())['marker'], 'a');
    await sync.dispose();
  });
  test('rejects redirect to another host', () async {
    var count = 0;
    final sync = DesktopSync(
      endpoint: endpoint,
      token: () async => 'token',
      identity: () => 'a',
      client: MockClient((r) async {
        count++;
        return http.Response(
          '',
          302,
          headers: {'location': 'https://attacker.example/'},
        );
      }),
    );
    await expectLater(sync.snapshot(), throwsStateError);
    expect(count, 1);
    await sync.dispose();
  });
  test(
    'coalesces snapshots and prevents old account data from entering cache',
    () async {
      String? user = 'a';
      var calls = 0;
      final first = Completer<http.Response>();
      final sync = DesktopSync(
        endpoint: endpoint,
        token: () async => 'token',
        identity: () => user,
        client: MockClient((r) async {
          calls++;
          if (calls == 1) return first.future;
          return response('b');
        }),
      );
      final old = sync.snapshot();
      final stale = expectLater(old, throwsStateError);
      expect(identical(old, sync.snapshot()), isTrue);
      await Future<void>.delayed(Duration.zero);
      user = 'b';
      expect((await sync.snapshot())['marker'], 'b');
      first.complete(response('a'));
      await stale;
      expect((await sync.snapshot())['marker'], 'b');
      expect(calls, 2);
      await sync.dispose();
    },
  );
}
