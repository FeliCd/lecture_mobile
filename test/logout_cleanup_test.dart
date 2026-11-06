import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/lab2/logout_cleanup.dart';

void main() {
  const names = [
    'reminders',
    'shared_cache',
    'firebase',
    'google',
    'push',
    'logout_event',
    'telemetry_identity',
  ];
  for (final failed in names) {
    test('failure in $failed does not skip any other logout step', () async {
      final calls = <String>[];
      final operation = runLogoutCleanup({
        for (final name in names)
          name: () async {
            calls.add(name);
            if (name == failed) throw StateError('private SDK error');
          },
      });
      await expectLater(
        operation,
        throwsA(
          isA<LogoutCleanupFailure>().having(
            (e) => e.failedSteps,
            'failed steps',
            [failed],
          ),
        ),
      );
      expect(calls, names);
    });
  }
  test(
    'synchronous and multiple push cleanup failures still try token deletion and identity reset',
    () async {
      final calls = <String>[];
      final action = runLogoutCleanup({
        'push': () => runLogoutCleanup({
          'history': () {
            calls.add('history');
            throw StateError('store failed');
          },
          'auto_init': () async {
            calls.add('auto_init');
            throw StateError('SDK failed');
          },
          'token': () async {
            calls.add('token');
          },
          'listeners': () async {
            calls.add('listeners');
          },
        }),
        'identity': () async {
          calls.add('identity');
        },
      });
      await expectLater(action, throwsA(isA<LogoutCleanupFailure>()));
      expect(calls, ['history', 'auto_init', 'token', 'listeners', 'identity']);
    },
  );
  test('success completes without a cleanup failure', () async {
    await runLogoutCleanup({'one': () async {}, 'two': () async {}});
  });
}
