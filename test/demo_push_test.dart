import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/cloud/demo_push.dart';
import 'package:lecturer_companion/cloud/cloud_services.dart';

class FakePush implements DemoPushService {
  int calls = 0;
  bool wasDelayed = false;
  final pending = Completer<void>();
  @override
  Future<void> send({bool delayed = false}) {
    calls++;
    wasDelayed = delayed;
    return pending.future;
  }
}

void main() {
  test('background demo requests the delayed backend path', () async {
    final fake = FakePush();
    final c = ProviderContainer(
      overrides: [demoPushServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(c.dispose);
    c.listen(demoPushProvider, (_, _) {});
    final sent = c.read(demoPushProvider.notifier).send(delayed: true);
    expect(fake.wasDelayed, true);
    fake.pending.complete();
    await sent;
  });
  test(
    'repeated tap is serialized and success means accepted, not delivered',
    () async {
      final fake = FakePush();
      final c = ProviderContainer(
        overrides: [demoPushServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(c.dispose);
      c.listen(demoPushProvider, (_, _) {});
      final controller = c.read(demoPushProvider.notifier);
      final first = controller.send();
      await controller.send();
      expect(fake.calls, 1);
      expect(c.read(demoPushProvider).isLoading, true);
      fake.pending.complete();
      await first;
      expect(c.read(demoPushProvider).value, contains('FCM đã nhận yêu cầu'));
    },
  );
  test(
    'permission error restores button and gives actionable message',
    () async {
      final fake = FakePush();
      final c = ProviderContainer(
        overrides: [demoPushServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(c.dispose);
      c.listen(demoPushProvider, (_, _) {});
      final sent = c.read(demoPushProvider.notifier).send();
      fake.pending.completeError(
        const CloudServiceFailure('notification-permission'),
      );
      await sent;
      expect(c.read(demoPushProvider).isLoading, false);
      expect(c.read(demoPushProvider).error, contains('cho phép'));
    },
  );
}
