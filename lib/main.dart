import 'package:flutter/material.dart';
import 'api/client.dart';
import 'api/repository.dart';
import 'app/app.dart';
import 'core/config.dart';
import 'features/auth/auth.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = AuthController(GoogleIdentity(), SecureTokenVault());
  if (AppConfig.configured) {
    auth.repository = LecturerRepository(
      AppsScriptApi(
        url: AppConfig.apiUrl,
        tokenProvider: auth.token,
        onUnauthorized: auth.logout,
      ),
    );
  }
  runApp(CompanionApp(auth: auth));
  auth.restore();
}
