import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'repository.dart';
import 'auth_session_service.dart';

/// View -> controller -> repository. Firebase/Google SDKs stay in the repository.
final authSessionServiceProvider = Provider<AuthSessionService>(
  (ref) => ref.watch(repositoryProvider),
);

class AuthActionState {
  final bool busy;
  final Object? error;
  const AuthActionState({this.busy = false, this.error});
}

final authActionsProvider =
    NotifierProvider<AuthActionsController, AuthActionState>(
      AuthActionsController.new,
    );

class AuthActionsController extends Notifier<AuthActionState> {
  @override
  AuthActionState build() => const AuthActionState();

  Future<bool> login() =>
      _perform(() => ref.read(authSessionServiceProvider).loginWithGoogle());

  Future<bool> logout() =>
      _perform(() => ref.read(authSessionServiceProvider).logout());

  Future<bool> _perform(Future<void> Function() operation) async {
    if (state.busy) return false;
    state = const AuthActionState(busy: true);
    try {
      await operation();
      if (ref.mounted) {
        state = const AuthActionState();
        ref.invalidate(profileProvider);
      }
      return true;
    } catch (e) {
      if (ref.mounted) state = AuthActionState(error: e);
      return false;
    }
  }
}
