import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import '../models/domain.dart';

abstract interface class ApplicationApi {
  Future<dynamic> call(String action, [Json payload = const {}]);
}

class AppsScriptApi implements ApplicationApi {
  final Uri endpoint;
  final Future<String> Function() tokenProvider;
  final Future<void> Function() onUnauthorized;
  final http.Client client;
  final Duration timeout;
  AppsScriptApi({
    required String url,
    required this.tokenProvider,
    required this.onUnauthorized,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  }) : endpoint = Uri.parse(url),
       client = client ?? http.Client() {
    if (!AppConfig.validEndpoint(url)) {
      throw const AppFailure(
        'Configure a valid HTTPS Apps Script deployment URL.',
      );
    }
  }
  @override
  Future<dynamic> call(String action, [Json payload = const {}]) async {
    try {
      final token = await tokenProvider();
      final request = http.Request('POST', endpoint)
        ..followRedirects = false
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode({...payload, 'action': action, 'idToken': token});
      var response = await _send(request);
      if ([302, 303].contains(response.statusCode)) {
        final target = Uri.tryParse(response.headers['location'] ?? '');
        if (target == null ||
            target.scheme != 'https' ||
            target.host != 'script.googleusercontent.com' ||
            target.userInfo.isNotEmpty) {
          throw const AppFailure('The server returned an unexpected redirect.');
        }
        response = await _send(
          http.Request('GET', target)..followRedirects = false,
        );
      }
      if (response.statusCode == 401) {
        throw const AppFailure(
          'Your session expired. Sign in again.',
          unauthenticated: true,
        );
      }
      if (response.statusCode == 403) {
        throw const AppFailure(
          'You do not have permission to access this information.',
        );
      }
      if (response.statusCode == 404) {
        throw const AppFailure(
          'The requested resource is unavailable. Refresh and try again.',
        );
      }
      if (response.statusCode == 409) {
        throw const AppFailure(
          'This record changed. Refresh before trying again.',
        );
      }
      if (response.statusCode != 200) {
        throw const AppFailure(
          'The service is unavailable. Please try again later.',
        );
      }
      final dynamic envelope;
      try {
        envelope = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        throw const AppFailure(
          'The server returned an invalid response. Check the deployment.',
        );
      }
      if (envelope is! Map) {
        throw const AppFailure('The server returned an invalid response.');
      }
      if (envelope['ok'] != true) {
        throw mapBackendError('${envelope['error'] ?? ''}');
      }
      return envelope['data'];
    } on AppFailure catch (error) {
      if (error.unauthenticated) await onUnauthorized();
      rethrow;
    } on TimeoutException {
      throw const AppFailure(
        'The request timed out. Refresh to check whether it completed before retrying.',
      );
    } on http.ClientException {
      throw const AppFailure(
        'Unable to connect. Check your internet connection and retry.',
      );
    }
  }

  Future<http.Response> _send(http.Request request) async =>
      http.Response.fromStream(
        await client.send(request).timeout(timeout),
      ).timeout(timeout);
  void close() => client.close();
}

AppFailure mapBackendError(String raw) {
  if (raw.contains('Phiên Google') || raw.contains('Cần đăng nhập')) {
    return const AppFailure(
      'Your session expired. Sign in again.',
      unauthenticated: true,
    );
  }
  if (raw.contains('không được phép') ||
      raw.contains('Không có quyền') ||
      raw.contains('Lecturers') ||
      raw.contains('không thuộc')) {
    return const AppFailure(
      'Access denied. Check your lecturer registration and resource permissions.',
    );
  }
  if (raw.contains('Trùng') ||
      raw.contains('trùng') ||
      raw.contains('đã điểm danh') ||
      raw.contains('nhiều phiên')) {
    return const AppFailure(
      'Duplicate or conflicting data was found. Refresh and contact your administrator if it persists.',
    );
  }
  if (raw.contains('RESET') ||
      raw.contains('reset') ||
      raw.contains('không còn mở') ||
      raw.contains('đã kết thúc') ||
      raw.contains('được thay thế')) {
    return const AppFailure(
      'This session has changed or closed. Refresh to continue.',
    );
  }
  if (raw.contains('chưa được hỗ trợ') || raw.contains('chưa cấu hình')) {
    return const AppFailure(
      'This capability requires backend configuration or an updated deployment.',
    );
  }
  return const AppFailure(
    'The server could not complete the request. Refresh and try again.',
  );
}
