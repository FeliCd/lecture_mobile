typedef LogoutAction = Future<void> Function();

class LogoutCleanupFailure implements Exception {
  final List<String> failedSteps;
  const LogoutCleanupFailure(this.failedSteps);
  @override
  String toString() =>
      'Chưa hoàn tất mọi bước đăng xuất (${failedSteps.join(', ')}). Vui lòng thử đăng xuất lại.';
}

/// Attempt every step, including synchronous failures. Never report full success
/// when Firebase sign-out or another required cleanup failed.
Future<void> runLogoutCleanup(Map<String, LogoutAction> actions) async {
  final failed = <String>[];
  for (final entry in actions.entries) {
    try {
      await Future<void>.sync(entry.value);
    } catch (_) {
      failed.add(entry.key);
    }
  }
  if (failed.isNotEmpty) throw LogoutCleanupFailure(List.unmodifiable(failed));
}
