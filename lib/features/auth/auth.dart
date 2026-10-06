import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../api/repository.dart';
import '../../core/config.dart';
import '../../models/domain.dart';

String signInErrorMessage(Object error) {
  if (error is! GoogleSignInException) return safeMessage(error);
  return switch (error.code) {
    GoogleSignInExceptionCode.clientConfigurationError =>
      'Google sign-in is not configured for this Android app. Ask the administrator to register its package name and signing SHA-1, and verify the server client ID.',
    GoogleSignInExceptionCode.providerConfigurationError =>
      'Google sign-in services are unavailable or misconfigured on this device. Check Google Play services and try again.',
    GoogleSignInExceptionCode.canceled =>
      'Google sign-in did not complete. If you did not cancel, ask the administrator to check the Android package, signing SHA-1 and OAuth client configuration.',
    GoogleSignInExceptionCode.interrupted ||
    GoogleSignInExceptionCode.uiUnavailable =>
      'Google sign-in was interrupted. Keep the app open and try again.',
    _ => 'Unable to sign in with Google. Check your connection and try again.',
  };
}

abstract interface class IdentityProvider {
  Future<String?> signIn({bool silently = false});
  Future<void> signOut();
}

class GoogleIdentity implements IdentityProvider {
  Future<void>? _initialization;
  Future<void> _initialize() =>
      _initialization ??= GoogleSignIn.instance.initialize(
        serverClientId: AppConfig.serverClientId,
        clientId:
            defaultTargetPlatform == TargetPlatform.iOS &&
                AppConfig.iosClientId.isNotEmpty
            ? AppConfig.iosClientId
            : null,
      );
  @override
  Future<String?> signIn({bool silently = false}) async {
    await _initialize();
    if (kDebugMode) debugPrint('[GoogleAuth] Sign-in started');
    final account = silently
        ? await GoogleSignIn.instance.attemptLightweightAuthentication()
        : await GoogleSignIn.instance.authenticate();
    if (account == null) return null;
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AppFailure(
        'Google did not return an identity token. Check the Web/server client ID configuration.',
      );
    }
    if (kDebugMode) debugPrint('[GoogleAuth] Google credential received');
    return idToken;
  }

  @override
  Future<void> signOut() async {
    await _initialize();
    await GoogleSignIn.instance.signOut();
  }
}

abstract interface class TokenVault {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class SecureTokenVault implements TokenVault {
  final FlutterSecureStorage storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  static const key = 'lecturer_companion.google_id_token';
  @override
  Future<String?> read() => storage.read(key: key);
  @override
  Future<void> write(String token) => storage.write(key: key, value: token);
  @override
  Future<void> clear() => storage.delete(key: key);
}

class AuthController extends ChangeNotifier {
  final IdentityProvider identity;
  final TokenVault vault;
  LecturerRepository? repository;
  Lecturer? lecturer;
  bool busy = false;
  String? error;
  String? _token;
  int _generation = 0;
  AuthController(this.identity, this.vault);
  static bool unexpired(String token) {
    try {
      final claims =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(token.split('.')[1])),
                ),
              )
              as Map;
      return (claims['exp'] as num) * 1000 >
          DateTime.now().millisecondsSinceEpoch + 60000;
    } catch (_) {
      return false;
    }
  }

  // Local expiry is only an optimization. The backend validates every identity.
  Future<String> token() async {
    if (_token != null && unexpired(_token!)) return _token!;
    throw const AppFailure(
      'Your session expired. Sign in again.',
      unauthenticated: true,
    );
  }

  Future<void> restore() => _authenticate(restore: true);
  Future<void> login() => _authenticate(restore: false);
  Future<void> _authenticate({required bool restore}) async {
    if (busy || repository == null) return;
    busy = true;
    error = null;
    notifyListeners();
    final generation = _generation;
    try {
      var candidate = restore ? await vault.read() : null;
      if (candidate == null || !unexpired(candidate)) {
        if (restore) {
          await vault.clear();
          return;
        }
        candidate = await identity.signIn();
      }
      if (candidate == null) throw const AppFailure('Sign-in was cancelled.');
      _token = candidate;
      if (kDebugMode) debugPrint('[GoogleAuth] Backend verification requested');
      final verified = await repository!.profile();
      if (generation != _generation) return;
      await vault.write(candidate);
      lecturer = verified;
      if (kDebugMode) debugPrint('[Auth] Verified lecturer session created');
    } catch (e) {
      _token = null;
      lecturer = null;
      error = signInErrorMessage(e);
      try {
        await vault.clear();
      } catch (_) {
        error = 'Secure storage is unavailable. Sign-in could not be saved.';
      }
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _generation++;
    lecturer = null;
    _token = null;
    error = null;
    busy = true;
    notifyListeners();
    try {
      await vault.clear();
    } catch (_) {
      error =
          'Unable to clear secure credentials. Retry logout before leaving this device.';
    }
    try {
      await identity.signOut();
    } catch (_) {
      error ??= 'Google sign-out could not finish. Retry logout.';
    }
    busy = false;
    notifyListeners();
  }
}
