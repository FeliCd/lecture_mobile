class AppConfig {
  static const apiUrl = String.fromEnvironment('APPS_SCRIPT_URL');
  static const serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  static const iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static const checkinUrl = String.fromEnvironment('STUDENT_CHECKIN_URL');
  static const environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static bool get configured =>
      validEndpoint(apiUrl) && serverClientId.isNotEmpty;
  static bool validEndpoint(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'script.google.com' &&
        uri.path.startsWith('/macros/s/') &&
        uri.path.endsWith('/exec') &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }
}

class AppFailure implements Exception {
  final String message;
  final bool unauthenticated;
  const AppFailure(this.message, {this.unauthenticated = false});
  @override
  String toString() => message;
}

String safeMessage(Object error) => error is AppFailure
    ? error.message
    : 'Unable to complete this request. Please try again.';
