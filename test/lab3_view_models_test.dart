import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/lab2/auth_session_service.dart';
import 'package:lecturer_companion/lab2/auth_view_model.dart';
import 'package:lecturer_companion/lab2/domain.dart';
import 'package:lecturer_companion/lab2/notebook_view_model.dart';
import 'package:lecturer_companion/lab2/lecturer_workspace_store.dart';
import 'package:lecturer_companion/cloud/push_permission_service.dart';
import 'package:lecturer_companion/cloud/push_view_model.dart';

class TestAuth implements AuthSessionService {
  int calls = 0;
  Completer<void>? next;
  bool fail = false;
  @override
  Future<void> loginWithGoogle() async {
    calls++;
    if (next != null) await next!.future;
    if (fail) throw StateError('cancelled-or-offline');
  }

  @override
  Future<void> logout() => loginWithGoogle();
}

class TestNotes extends WorkspaceStore {
  TestNotes() : super('test');
  bool loadFailed = false;
  final saves = <Completer<void>>[];
  final inputs = <Data>[];
  @override
  Future<WorkspaceData> read() async {
    if (loadFailed) throw StateError('disk-unavailable');
    return const WorkspaceData(
      notes: {
        'lesson': {'goals': 'saved'},
      },
    );
  }

  @override
  Future<void> saveNote(String id, Data note) {
    inputs.add(note);
    final result = Completer<void>();
    saves.add(result);
    return result.future;
  }
}

class TestPermission implements PushPermissionService {
  PushPermission current = PushPermission.denied;
  int requests = 0;
  bool fail = false;
  Completer<void>? next;
  @override
  Future<PushPermission> permissionStatus() async {
    if (fail) throw StateError('sdk-unavailable');
    return current;
  }

  @override
  Future<PushPermission> enableNotifications() async {
    requests++;
    if (next != null) await next!.future;
    return permissionStatus();
  }
}

void main() {
  test(
    'auth serializes login/logout; failure resets busy and retry clears error',
    () async {
      final auth = TestAuth()..next = Completer<void>();
      final c = ProviderContainer(
        overrides: [authSessionServiceProvider.overrideWithValue(auth)],
      );
      addTearDown(c.dispose);
      final vm = c.read(authActionsProvider.notifier);
      final first = vm.login();
      expect(c.read(authActionsProvider).busy, true);
      expect(await vm.logout(), false);
      expect(auth.calls, 1);
      auth.fail = true;
      auth.next!.complete();
      expect(await first, false);
      expect(c.read(authActionsProvider).busy, false);
      expect(c.read(authActionsProvider).error, isNotNull);
      auth
        ..next = null
        ..fail = false;
      expect(await vm.login(), true);
      expect(c.read(authActionsProvider).error, null);
    },
  );

  test(
    'notebook load failure can retry without overwriting durable notes',
    () async {
      final notes = TestNotes()..loadFailed = true;
      final c = ProviderContainer(
        overrides: [workspaceStoreProvider('test').overrideWithValue(notes)],
      );
      addTearDown(c.dispose);
      addTearDown(notes.dispose);
      const key = (uid: 'test', noteId: 'lesson');
      final sub = c.listen(notebookProvider(key), (_, _) {});
      addTearDown(sub.close);
      final vm = c.read(notebookProvider(key).notifier);
      expect(await vm.load(), null);
      await vm.save({'goals': 'do-not-overwrite'});
      expect(notes.inputs, isEmpty);
      expect(c.read(notebookProvider(key)).loadFailed, true);
      notes.loadFailed = false;
      expect((await vm.load())!['goals'], 'saved');
      expect(c.read(notebookProvider(key)).loadFailed, false);
    },
  );

  test(
    'latest notebook write determines failure; retry and checkbox snapshots are stable',
    () async {
      final notes = TestNotes();
      final c = ProviderContainer(
        overrides: [workspaceStoreProvider('test').overrideWithValue(notes)],
      );
      addTearDown(c.dispose);
      addTearDown(notes.dispose);
      const key = (uid: 'test', noteId: 'lesson');
      final sub = c.listen(notebookProvider(key), (_, _) {});
      addTearDown(sub.close);
      final vm = c.read(notebookProvider(key).notifier);
      await vm.load();
      final checked = ['a'];
      final old = vm.save({'goals': 'old', 'checkedPrep': checked});
      checked.add('b');
      final latest = vm.save({'goals': 'latest'});
      expect(notes.inputs.first['checkedPrep'], ['a']);
      notes.saves[1].completeError(StateError('disk-full'));
      await latest;
      notes.saves[0].complete();
      await old;
      expect(c.read(notebookProvider(key)).saveFailed, true);
      expect(c.read(notebookProvider(key)).pending, 0);
      final retry = vm.save({'goals': 'latest'});
      notes.saves.last.complete();
      await retry;
      expect(c.read(notebookProvider(key)).saveFailed, false);
    },
  );

  test(
    'push permission reflects OS changes, deduplicates prompts, and can retry SDK failure',
    () async {
      final service = TestPermission();
      final c = ProviderContainer(
        overrides: [pushPermissionServiceProvider.overrideWithValue(service)],
      );
      addTearDown(c.dispose);
      final sub = c.listen(pushPermissionProvider, (_, _) {});
      addTearDown(sub.close);
      expect(
        await c.read(pushPermissionProvider.future),
        PushPermission.denied,
      );
      final vm = c.read(pushPermissionProvider.notifier);
      service
        ..current = PushPermission.authorized
        ..next = Completer<void>();
      final first = vm.request();
      await vm.request();
      expect(service.requests, 1);
      service.next!.complete();
      await first;
      expect(c.read(pushPermissionProvider).value, PushPermission.authorized);
      service.fail = true;
      await vm.refresh();
      expect(c.read(pushPermissionProvider).hasError, true);
      service
        ..fail = false
        ..current = PushPermission.denied;
      await vm.refresh();
      expect(c.read(pushPermissionProvider).value, PushPermission.denied);
    },
  );
}
