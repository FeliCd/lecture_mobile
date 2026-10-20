import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'domain.dart';

const useSharedDesktop = bool.fromEnvironment('USE_SHARED_DESKTOP');
const quizEnabled = false;

/// Account-scoped shared snapshot. Sheets remains authoritative.
class DesktopSync {
  final String endpoint;
  final Future<String?> Function() token;
  final String? Function() identity;
  final http.Client client;
  final bool lecturerGoogleOnly;
  Data? _cached;
  DateTime? _fetched;
  String? _account;
  Future<Data>? _pending;
  int _generation = 0;
  final _changes = StreamController<void>.broadcast();
  DesktopSync({
    required this.endpoint,
    required this.token,
    required this.identity,
    http.Client? client,
    this.lecturerGoogleOnly = false,
  }) : client = client ?? http.Client();
  static bool validEndpoint(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'script.google.com' &&
        uri.userInfo.isEmpty &&
        uri.query.isEmpty &&
        uri.fragment.isEmpty &&
        RegExp(r'^/macros/s/[\w-]+/exec$').hasMatch(uri.path);
  }

  Future<Data> request(String action, [Data input = const {}]) async {
    if (!validEndpoint(endpoint)) {
      throw StateError('SHARED_BACKEND_SETUP_REQUIRED');
    }
    final idToken = await token();
    if (idToken == null) throw StateError('UNAUTHENTICATED');
    final req = http.Request('POST', Uri.parse(endpoint))
      ..followRedirects = false
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({...input, 'action': action, 'idToken': idToken});
    Future<http.Response> send(http.Request r) async =>
        http.Response.fromStream(
          await client.send(r).timeout(const Duration(seconds: 35)),
        ).timeout(const Duration(seconds: 35));
    var response = await send(req);
    if ([302, 303].contains(response.statusCode)) {
      final redirect = Uri.tryParse(response.headers['location'] ?? '');
      if (redirect == null ||
          redirect.scheme != 'https' ||
          redirect.host != 'script.googleusercontent.com' ||
          redirect.userInfo.isNotEmpty) {
        throw StateError('INVALID_BACKEND_REDIRECT');
      }
      response = await send(
        http.Request('GET', redirect)..followRedirects = false,
      );
    }
    if (response.statusCode != 200) throw StateError('unavailable');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) throw StateError('INVALID_BACKEND_RESPONSE');
    if (decoded['ok'] != true) {
      throw StateError('${decoded['error'] ?? 'SERVER_ERROR'}');
    }
    if (decoded['data'] is! Map) throw StateError('INVALID_BACKEND_RESPONSE');
    return Map<String, dynamic>.from(decoded['data'] as Map);
  }

  Future<Data> snapshot({bool force = false}) {
    final account = identity();
    if (account == null) {
      reset();
      return Future.error(StateError('UNAUTHENTICATED'));
    }
    if (_account != account) {
      reset();
      _account = account;
    }
    if (!force &&
        _cached != null &&
        DateTime.now().difference(_fetched!) < const Duration(seconds: 30)) {
      return Future.value(_cached!);
    }
    if (_pending != null) return _pending!;
    final generation = _generation;
    final pending =
        request(
          'lab2Snapshot',
          lecturerGoogleOnly ? {'googleLecturerOnly': true} : {},
        ).then<Data>((data) {
          if (identity() != account) {
            throw StateError('UNAUTHENTICATED');
          }
          if (generation != _generation) return snapshot(force: true);
          _cached = data;
          _fetched = DateTime.now();
          return data;
        });
    _pending = pending;
    pending.then(
      (_) {
        if (generation == _generation) _pending = null;
      },
      onError: (Object _, StackTrace stack) {
        if (generation == _generation) _pending = null;
      },
    );
    return pending;
  }

  void reset() {
    _generation++;
    _cached = null;
    _fetched = null;
    _pending = null;
    _account = null;
  }

  void refresh() {
    reset();
    _changes.add(null);
  }

  Future<void> dispose() async {
    client.close();
    await _changes.close();
  }

  Future<Data> call(String name, Data input) async {
    final result = await request('lab2Call', {'name': name, 'input': input});
    if (![
      'getTeachingOccurrence',
      'getQuickAttendanceContext',
      'getQrToken',
      'discoverArticles',
      'getAttendanceSessionLive',
      'getSubjectUpdates',
      'getSubjectTopics',
    ].contains(name)) {
      refresh();
    }
    return result;
  }

  Stream<T> watch<T>(T Function(Data) select) => Stream<T>.multi((out) {
    bool active = true, loading = false;
    Future<void> load() async {
      if (!active || loading) return;
      loading = true;
      try {
        final data = await snapshot();
        if (active) out.add(select(data));
      } catch (e, s) {
        if (active) out.addError(e, s);
      } finally {
        loading = false;
      }
    }

    final timer = Timer.periodic(const Duration(seconds: 30), (_) => load());
    final changes = _changes.stream.listen((_) => load());
    out.onCancel = () {
      active = false;
      timer.cancel();
      changes.cancel();
    };
    load();
  });
  static List<Data> rows(Data snapshot, String collection) {
    final collections = snapshot['collections'] as Map? ?? {};
    return (collections[collection] as List? ?? []).map((raw) {
      final row = Map<String, dynamic>.from(raw as Map);
      if ([
        'classSessions',
        'attendanceSessions',
        'attendanceRecords',
      ].contains(collection)) {
        final cls = (collections['classes'] as List? ?? [])
            .whereType<Map>()
            .where((c) => c['id'] == row['classId'])
            .firstOrNull;
        final lesson = (collections['classSessions'] as List? ?? [])
            .whereType<Map>()
            .where((s) => s['id'] == (row['classSessionId'] ?? row['id']))
            .firstOrNull;
        row['subjectId'] ??= cls?['subjectId'];
        row['subjectName'] ??= cls?['subjectName'];
        row['classCode'] ??= cls?['classCode'];
        row['slot'] ??= lesson?['slot'];
        if (collection == 'attendanceRecords') {
          row['status'] = attendanceStatus('${row['status']}');
        }
      }
      return row;
    }).toList();
  }
}
