import 'dart:convert';

/// Metadata is only a UI hint; the server verifies the token and Secret Code.
Map<String, dynamic> attendanceQrMetadata(String token) {
  try {
    final uri = Uri.tryParse(token);
    if (uri != null && uri.queryParameters.containsKey('sessionId')) {
      return {
        'sessionId': uri.queryParameters['sessionId'],
        'secretRequired': (uri.queryParameters['mode'] ?? '').contains(
          'secret',
        ),
      };
    }
    return Map<String, dynamic>.from(
      jsonDecode(
            utf8.decode(
              base64Url.decode(base64Url.normalize(token.split('.').first)),
            ),
          )
          as Map,
    );
  } catch (_) {
    return {};
  }
}
