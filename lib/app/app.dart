import 'package:flutter/material.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../features/auth/auth.dart';
import 'shell.dart';

class CompanionApp extends StatelessWidget {
  final AuthController auth;
  const CompanionApp({super.key, required this.auth});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: auth,
    builder: (context, _) => MaterialApp(
      // Replacing the navigator removes every private detail route on logout/401.
      key: ValueKey(auth.lecturer?.lecturerId),
      title: 'FPT Lecturer Companion',
      debugShowCheckedModeBanner: false,
      theme: companionTheme(),
      home: auth.lecturer == null
          ? LoginScreen(auth: auth)
          : LecturerShell(auth: auth),
    ),
  );
}

class LoginScreen extends StatelessWidget {
  final AuthController auth;
  const LoginScreen({super.key, required this.auth});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.school_outlined, size: 44),
                ),
                const SizedBox(height: 28),
                Text(
                  'FPT LECTURER COMPANION',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 14),
                Text(
                  'Your teaching day,\nin one place.',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Classes, attendance and reports. Sign in with your registered school Google account to get started.',
                ),
                const SizedBox(height: 32),
                if (auth.repository == null)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Setup required',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'This app has not been connected to your attendance service. Ask your administrator for a configured build.',
                          ),
                        ],
                      ),
                    ),
                  ),
                if (auth.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      auth.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: auth.busy || auth.repository == null
                        ? null
                        : auth.login,
                    icon: auth.busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(
                      auth.busy
                          ? 'Checking your account…'
                          : 'Sign in with Google',
                    ),
                  ),
                ),
                if (auth.error != null)
                  TextButton(
                    onPressed: auth.busy ? null : auth.logout,
                    child: const Text('Clear saved sign-in'),
                  ),
                const SizedBox(height: 20),
                const Text(
                  'Access is verified by your institution. Only registered lecturers can continue.',
                ),
                const SizedBox(height: 28),
                Text(
                  'Online access required • ${AppConfig.environment}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
