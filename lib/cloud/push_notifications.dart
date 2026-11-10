import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud_services.dart';
import 'push_permission_service.dart';
import '../lab2/logout_cleanup.dart';

String pushDestination(Map<String, dynamic> data) {
  final screen = data['screen'];
  final classId = '${data['classId'] ?? ''}';
  final groupId = '${data['groupId'] ?? ''}';
  final safeId = RegExp(r'^[A-Za-z0-9_-]{1,100}$');
  if (screen == 'group-chat' &&
      safeId.hasMatch(classId) &&
      safeId.hasMatch(groupId)) {
    return '/chat/$classId/$groupId';
  }
  if (screen == 'class' && safeId.hasMatch(classId)) {
    return '/class/$classId';
  }
  if (screen == 'settings') return '/settings';
  return '/';
}

FirebaseOptions pushFirebaseOptions() => const FirebaseOptions(
  apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
  appId: String.fromEnvironment('FIREBASE_APP_ID'),
  messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
  projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
  storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
);

class PushHistory {
  SharedPreferencesAsync? _preferences;
  SharedPreferencesAsync get preferences =>
      _preferences ??= SharedPreferencesAsync();
  PushHistory({SharedPreferencesAsync? store}) : _preferences = store;
  Future<void> record(RemoteMessage message, String uid) async {
    // Console notification messages are scoped to the current signed-in account.
    // Automated senders should additionally set recipientUid; discard mismatches.
    final recipient = message.data['recipientUid'];
    if (recipient != null && recipient != uid) return;
    final id =
        message.messageId ??
        '${message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}';
    final key = 'push:$uid:${Uri.encodeComponent(id)}';
    await preferences.setString(
      key,
      jsonEncode({
        'id': id,
        'title': message.notification?.title ?? 'Thông báo học tập',
        'body': message.notification?.body ?? '',
        'route': pushDestination(message.data),
        'at': (message.sentTime ?? DateTime.now()).toIso8601String(),
      }),
    );
    final all = await read(uid);
    for (final old in all.skip(100)) {
      await preferences.remove('push:$uid:${Uri.encodeComponent(old['id'])}');
    }
  }

  Future<List<Map<String, dynamic>>> read(String uid) async {
    final keys = (await preferences.getKeys()).where(
      (k) => k.startsWith('push:$uid:'),
    );
    final rows = <Map<String, dynamic>>[];
    for (final key in keys) {
      try {
        final raw = await preferences.getString(key);
        if (raw != null) {
          rows.add(Map<String, dynamic>.from(jsonDecode(raw) as Map));
        }
      } catch (_) {}
    }
    return rows..sort((a, b) => '${b['at']}'.compareTo('${a['at']}'));
  }

  Future<void> clear(String uid) async {
    for (final key in (await preferences.getKeys()).where(
      (k) => k.startsWith('push:$uid:'),
    )) {
      await preferences.remove(key);
    }
  }
}

@pragma('vm:entry-point')
Future<void> firebasePushBackground(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: pushFirebaseOptions());
  }
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid != null) await PushHistory().record(message, uid);
}

class PushNotifications implements PushPermissionService {
  String? get uid => FirebaseAuth.instance.currentUser?.uid;
  static final instance = PushNotifications();
  final history = PushHistory();
  final changes = StreamController<void>.broadcast();
  final groupChanges = StreamController<Map<String, dynamic>>.broadcast();
  StreamSubscription<RemoteMessage>? foreground, opened;
  StreamSubscription<String>? tokenChanges;
  Future<Object?> Function(String, Map<String, dynamic>)? groupPushApi;
  String? _groupPushUid, _registeredGroupToken;
  Future<void> _groupRegistration = Future.value();
  void Function(String)? onOpen;
  String? pendingRoute;
  bool initialized = false;
  bool get supported => androidCloudSupported && Firebase.apps.isNotEmpty;
  Future<void> initialize() async {
    if (initialized || !supported) return;
    FirebaseMessaging.onBackgroundMessage(firebasePushBackground);
    foreground = FirebaseMessaging.onMessage.listen((m) {
      unawaited(remember(m));
    });
    opened = FirebaseMessaging.onMessageOpenedApp.listen((m) {
      unawaited(open(m));
    });
    tokenChanges = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      unawaited(_registerGroupPush(token));
    });
    initialized = true;
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) await open(initial);
  }

  Future<void> remember(RemoteMessage m) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (m.data['recipientUid'] != null && m.data['recipientUid'] != uid) return;
    if (m.data['screen'] == 'group-chat' && m.data['recipientUid'] == uid) {
      groupChanges.add(m.data);
    }
    try {
      await history.record(m, uid);
      changes.add(null);
    } catch (e) {
      await CloudTelemetry.handled('push_history', e);
    }
  }

  Future<void> activateGroupPush() async {
    if (groupPushApi == null || !supported) return;
    final account = uid;
    if (_groupPushUid != account) _registeredGroupToken = null;
    _groupPushUid = account;
    await _registerGroupPush();
  }

  Future<void> _registerGroupPush([String? refreshedToken]) {
    final account = _groupPushUid;
    final api = groupPushApi;
    if (account == null || api == null) return Future.value();
    _groupRegistration = _groupRegistration.then((_) async {
      try {
        if (_groupPushUid != account || uid != account) return;
        final permission = await permissionStatus();
        if (permission != PushPermission.authorized &&
            permission != PushPermission.provisional) {
          return;
        }
        final token =
            refreshedToken ?? await FirebaseMessaging.instance.getToken();
        if (token == null || _groupPushUid != account || uid != account) return;
        if (token == _registeredGroupToken) return;
        await api('registerGroupPushDevice', {
          'platform': 'android',
          'token': token,
        }).timeout(const Duration(seconds: 6));
        if (_groupPushUid == account && uid == account) {
          _registeredGroupToken = token;
        }
      } catch (_) {
        // The shared deployment can support chat before push is configured.
      }
    });
    return _groupRegistration;
  }

  Future<void> open(RemoteMessage m) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null ||
        m.data['recipientUid'] != null && m.data['recipientUid'] != uid) {
      return;
    }
    await remember(m);
    final route = pushDestination(m.data);
    if (onOpen != null) {
      onOpen!(route);
    } else {
      pendingRoute = route;
    }
    await CloudTelemetry.event('notification_opened', {
      'destination': route.startsWith('/class/')
          ? 'class'
          : route == '/settings'
          ? 'settings'
          : 'home',
    });
  }

  Future<String> requestPermission() async {
    final result = await enableNotifications();
    if (result == PushPermission.unsupported) {
      return 'Chức năng push cần chạy bản Android kết nối Firebase thật.';
    }
    return result == PushPermission.denied
        ? 'Bạn đã từ chối nhận thông báo. Có thể bật lại trong cài đặt Android.'
        : 'Đã cho phép nhận thông báo.';
  }

  PushPermission _permission(AuthorizationStatus status) => switch (status) {
    AuthorizationStatus.authorized => PushPermission.authorized,
    AuthorizationStatus.provisional => PushPermission.provisional,
    AuthorizationStatus.denied ||
    AuthorizationStatus.deniedPermanently => PushPermission.denied,
    AuthorizationStatus.notDetermined => PushPermission.notDetermined,
  };

  @override
  Future<PushPermission> permissionStatus() async => !supported
      ? PushPermission.unsupported
      : _permission(
          (await FirebaseMessaging.instance.getNotificationSettings())
              .authorizationStatus,
        );

  @override
  Future<PushPermission> enableNotifications() async {
    if (!supported) return PushPermission.unsupported;
    final result = _permission(
      (await FirebaseMessaging.instance.requestPermission())
          .authorizationStatus,
    );
    if (result == PushPermission.authorized ||
        result == PushPermission.provisional) {
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      unawaited(_registerGroupPush());
    }
    return result;
  }

  Future<String?> testToken() async {
    if (!supported) throw const CloudServiceFailure('unsupported');
    final permission = await permissionStatus();
    if (permission != PushPermission.authorized &&
        permission != PushPermission.provisional) {
      throw const CloudServiceFailure('notification-permission');
    }
    return FirebaseMessaging.instance.getToken();
  }

  Future<void> logout(String? uid) async {
    pendingRoute = null;
    _groupPushUid = null;
    final registered = _registeredGroupToken;
    _registeredGroupToken = null;
    await runLogoutCleanup({
      'group_push': () async {
        final api = groupPushApi;
        if (api == null || registered == null) return;
        try {
          await api('unregisterGroupPushDevice', {
            'platform': 'android',
            'token': registered,
          }).timeout(const Duration(seconds: 4));
        } catch (_) {
          // The SDK deletes the device token in the next cleanup step.
        }
      },
      'push_history': () async {
        if (uid != null) await history.clear(uid);
      },
      'push_auto_init': () async {
        if (supported) {
          await FirebaseMessaging.instance.setAutoInitEnabled(false);
        }
      },
      'push_token': () async {
        if (supported) await FirebaseMessaging.instance.deleteToken();
      },
      'push_listeners': () async => changes.add(null),
    });
  }
}
