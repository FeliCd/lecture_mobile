abstract interface class AuthSessionService {
  Future<void> loginWithGoogle();
  Future<void> logout();
}
