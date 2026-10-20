import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'domain.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'lecturer_reminders.dart';
import 'package:http/http.dart' as http;
import 'desktop_sync.dart';

final sharedDesktop = DesktopSync(
  endpoint: const String.fromEnvironment('APPS_SCRIPT_URL'),
  token: () async => FirebaseAuth.instance.currentUser?.getIdToken(),
  identity: () => FirebaseAuth.instance.currentUser?.uid,
  lecturerGoogleOnly: true,
);

final authProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);
final profileProvider = StreamProvider<UserProfile?>((ref) {
  final auth = ref.watch(authProvider);
  if (auth.isLoading) return const Stream.empty();
  final user = auth.value;
  if (user == null) return Stream.value(null);
  if (useSharedDesktop) {
    if (!user.providerData.any((p) => p.providerId == 'google.com')) {
      return Stream.error(StateError('GOOGLE_ONLY'));
    }
    return sharedDesktop.watch((data) {
      final profile = Map<String, dynamic>.from(data['profile'] as Map);
      return UserProfile.fromMap(profile['uid'] as String, profile);
    });
  }
  return FirebaseFirestore.instance
      .doc('users/${user.uid}')
      .snapshots()
      .map((s) => UserProfile.fromMap(user.uid, s.data() ?? {}));
});
final repositoryProvider = Provider((ref) => CampusRepository());
final memberNamesProvider = StreamProvider.autoDispose
    .family<Map<String, Data>, String>((ref, classId) {
      final repo = ref.watch(repositoryProvider);
      return repo.memberStream(classId);
    });

class CampusRepository {
  final FirebaseFirestore db;
  final FirebaseFunctions functions;
  CampusRepository({FirebaseFirestore? firestore, FirebaseFunctions? callable})
    : db = firestore ?? FirebaseFirestore.instance,
      functions =
          callable ??
          FirebaseFunctions.instanceFor(
            region: const String.fromEnvironment(
              'FUNCTIONS_REGION',
              defaultValue: 'asia-southeast1',
            ),
          );
  Stream<List<Data>> watch(
    String collection, {
    String? field,
    Object? equals,
    String? uid,
  }) {
    if (useSharedDesktop) {
      return sharedDesktop.watch((data) {
        if (collection == 'schedules' &&
            (data['collections'] as Map?)?['schedules'] == null) {
          throw StateError('TIMETABLE_BACKEND_UPDATE_REQUIRED');
        }
        return DesktopSync.rows(data, collection)
            .where(
              (row) =>
                  (field == null || row[field] == equals) &&
                  (uid == null || row['studentUid'] == uid),
            )
            .toList();
      });
    }
    Query<Map<String, dynamic>> q = db.collection(collection);
    if (field != null) q = q.where(field, isEqualTo: equals);
    if (uid != null) q = q.where('studentUid', isEqualTo: uid);
    return q.snapshots().map(
      (s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList(),
    );
  }

  Stream<List<Data>> classes(UserProfile user) {
    if (useSharedDesktop) return watch('classes');
    return db
        .collection('classes')
        .where(
          user.isLecturer ? 'lecturerUids' : 'studentUids',
          arrayContains: user.uid,
        )
        .snapshots()
        .map((s) => s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  Stream<Data?> document(String path) {
    if (useSharedDesktop) {
      final split = path.lastIndexOf('/');
      return sharedDesktop.watch(
        (data) => DesktopSync.rows(
          data,
          path.substring(0, split),
        ).where((row) => row['id'] == path.substring(split + 1)).firstOrNull,
      );
    }
    return db
        .doc(path)
        .snapshots()
        .map((s) => s.exists ? {...s.data()!, 'id': s.id} : null);
  }

  Stream<Map<String, Data>> memberStream(String classId) => watch(
    'classes/$classId/members',
  ).map((rows) => {for (final row in rows) row['id'] as String: row});
  Future<Data> call(String name, Data input) async {
    if (useSharedDesktop) {
      try {
        return await sharedDesktop.call(name, input);
      } catch (e) {
        if (e.toString().contains('FEATURE_DISABLED') &&
            [
              'getTeachingOccurrence',
              'createClassSession',
              'importTimetable',
              'importClassStudents',
              'rotateAttendanceQr',
              'updateAttendanceRecord',
              'getQuickAttendanceContext',
              'submitQuickAttendance',
              'bulkUpdatePendingAttendance',
            ].contains(name)) {
          throw StateError('ATTENDANCE_BACKEND_UPDATE_REQUIRED');
        }
        rethrow;
      }
    }
    if (const bool.fromEnvironment('USE_EMULATORS')) {
      return _callEmulator(name, input);
    }
    final response = await functions
        .httpsCallable(
          name,
          options: HttpsCallableOptions(timeout: const Duration(seconds: 35)),
        )
        .call(input);
    return Map<String, dynamic>.from(response.data as Map);
  }

  // The Android callable SDK requests Firebase Installations even with a
  // demo project. Use the documented callable wire protocol only locally.
  Future<Data> _callEmulator(String name, Data input) async {
    const project = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const env = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    if (env == 'prod' ||
        !project.startsWith('demo-') ||
        !RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$').hasMatch(name)) {
      throw StateError('Invalid emulator configuration');
    }
    const host = String.fromEnvironment(
      'EMULATOR_HOST',
      defaultValue: '10.0.2.2',
    );
    const region = String.fromEnvironment(
      'FUNCTIONS_REGION',
      defaultValue: 'asia-southeast1',
    );
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'UNAUTHENTICATED',
      );
    }
    final response = await http
        .post(
          Uri(
            scheme: 'http',
            host: host,
            port: 5001,
            path: '/$project/$region/$name',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'data': input}),
        )
        .timeout(const Duration(seconds: 35));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final error = body['error'];
    if (error is Map) {
      throw FirebaseFunctionsException(
        code: (error['status'] as String? ?? 'INTERNAL')
            .toLowerCase()
            .replaceAll('_', '-'),
        message: error['message'] as String? ?? 'SERVER_ERROR',
        details: error['details'],
      );
    }
    if (response.statusCode != 200 || body['result'] is! Map) {
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'SERVER_ERROR',
      );
    }
    return Map<String, dynamic>.from(body['result'] as Map);
  }

  Future<Data?> serverRecord(String path) async {
    if (useSharedDesktop) {
      final split = path.lastIndexOf('/');
      final data = await sharedDesktop.snapshot(force: true);
      return DesktopSync.rows(
        data,
        path.substring(0, split),
      ).where((row) => row['id'] == path.substring(split + 1)).firstOrNull;
    }
    return (await db.doc(path).get(const GetOptions(source: Source.server)))
        .data();
  }

  Future<Map<String, Data>> members(String classId) async {
    if (useSharedDesktop) {
      final rows = DesktopSync.rows(
        await sharedDesktop.snapshot(),
        'classes/$classId/members',
      );
      return {for (final row in rows) row['id'] as String: row};
    }
    final result = await db.collection('classes/$classId/members').get();
    return {for (final d in result.docs) d.id: d.data()};
  }

  Future<void> refreshData() async {
    if (useSharedDesktop) {
      sharedDesktop.refresh();
      await sharedDesktop.snapshot(force: true);
    }
  }

  Future<void> logout() async {
    await LecturerReminders.instance.activate(null);
    sharedDesktop.reset();
    await FirebaseAuth.instance.signOut();
    if (googleInitialized) await GoogleSignIn.instance.signOut();
  }

  static bool googleInitialized = false;
  Future<void> loginWithGoogle() async {
    if (!googleInitialized) {
      await GoogleSignIn.instance.initialize(
        serverClientId: const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
      );
      googleInitialized = true;
    }
    final account = await GoogleSignIn.instance.authenticate();
    final token = account.authentication.idToken;
    if (token == null) throw StateError('UNAUTHENTICATED');
    await FirebaseAuth.instance.signInWithCredential(
      GoogleAuthProvider.credential(idToken: token),
    );
  }
}

DateTime dateValue(dynamic value) => value is Timestamp
    ? value.toDate()
    : DateTime.fromMillisecondsSinceEpoch(
        value is num ? value.toInt() : 0,
        isUtc: true,
      );
