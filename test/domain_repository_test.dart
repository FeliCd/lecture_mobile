import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/api/repository.dart';
import 'package:lecturer_companion/core/config.dart';
import 'package:lecturer_companion/features/auth/auth.dart';
import 'package:lecturer_companion/models/domain.dart';
import 'fixtures.dart';

void main() {
  final cls = TeachingClass.fromJson(classJson);
  test('Campus midnight and date-only normalization do not shift dates', () {
    expect(
      CampusClock.date(CampusClock.now(DateTime.utc(2026, 10, 4, 18))),
      '2026-10-05',
    );
    expect(TeachingSession.normalizeDate('5/10/2026'), '2026-10-05');
    expect(
      CampusClock.current(
        '2026-10-05',
        '07:00',
        '08:00',
        DateTime.utc(2026, 10, 5, 0),
      ),
      true,
    );
    expect(
      CampusClock.current(
        '2026-10-05',
        '07:00',
        '08:00',
        DateTime.utc(2026, 10, 5, 1),
      ),
      false,
    );
  });
  test('Overview, roster and session load real contract actions', () async {
    final api = FixtureApi(), repo = LecturerRepository(FixtureApi());
    final overview = await repo.overview('lec-1');
    expect(overview.classes.single.classId, 'class-1');
    expect(overview.schedules.length, 1);
    expect(overview.sessions.length, 1);
    final data = await LecturerRepository(
      api,
    ).attendance(cls, 'session-1', 'lec-1');
    expect(data.roster.single.studentCode, 'SE123456');
    expect(data.unrecorded, 1);
    expect(data.reportAbsent, 1);
    expect(
      await repo.overview('different-owner').then((v) => v.sessions),
      isEmpty,
    );
  });
  test('Manual correction persists through API and report reload', () async {
    final api = FixtureApi(), student = Student.fromJson(studentJson);
    final repo = LecturerRepository(api);
    for (final status in ['PRESENT', 'ABSENT', 'LATE']) {
      final data = await repo.attendance(cls, 'session-1', 'lec-1');
      await repo.update(data, student, status, 'Corrected');
      expect(
        (await repo.attendance(
          cls,
          'session-1',
          'lec-1',
        )).recordFor(student)?.status,
        status,
      );
      expect((await repo.history(cls)).single.status, status);
      expect(api.records.length, 1);
    }
    final mutation = api.calls.lastWhere((c) => c.$1 == 'updateAttendance').$2;
    expect(mutation.containsKey('updatedBy'), false);
    expect(mutation['sessionId'], 'session-1');
  });
  test(
    'Closed-session corrections allowed, EXCUSED and RESET rejected',
    () async {
      final api = FixtureApi()..status = 'CLOSED';
      final repo = LecturerRepository(api);
      final data = await repo.attendance(cls, 'session-1', 'lec-1');
      await repo.update(data, data.roster.single, 'PRESENT', '');
      await expectLater(
        repo.update(data, data.roster.single, 'EXCUSED', ''),
        throwsA(isA<AppFailure>()),
      );
      api.status = 'RESET';
      await expectLater(
        repo.attendance(cls, 'session-1', 'lec-1'),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test('Duplicate attendance fails closed', () {
    final api = FixtureApi();
    final record = AttendanceRecord.fromJson(api.record('PRESENT'));
    expect(
      () => SessionAttendance(
        TeachingSession.fromJson(sessionJson()),
        [Student.fromJson(studentJson)],
        [record, record],
      ),
      throwsA(isA<AppFailure>()),
    );
  });
  test(
    'Finish closes before marking absent and retry does not duplicate',
    () async {
      final api = FixtureApi();
      final repo = LecturerRepository(api);
      await repo.finish(await repo.attendance(cls, 'session-1', 'lec-1'));
      final close = api.calls.indexWhere((c) => c.$1 == 'closeSession'),
          absent = api.calls.indexWhere((c) => c.$1 == 'markAbsent');
      expect(close, lessThan(absent));
      await repo.finish(await repo.attendance(cls, 'session-1', 'lec-1'));
      expect(api.records.length, 1);
      expect(api.calls.where((c) => c.$1 == 'closeSession').length, 1);
    },
  );
  test(
    'QR payload preserves token, mode, version without embedding secret',
    () {
      final session = TeachingSession.fromJson({
        ...sessionJson(),
        'currentToken': 'token#123456',
      });
      final uri = checkinUri('https://example.edu/checkin', session);
      expect(uri.queryParameters, {
        'sessionId': 'session-1',
        'token': 'token',
        'mode': 'secret',
        'v': '2',
      });
      expect(uri.toString(), isNot(contains('123456')));
      final credentials = LecturerRepository.newQrCredentials(secret: true);
      expect((credentials['currentToken'] as String).length, 48);
      expect((credentials['currentSecretCode'] as String).length, 6);
      expect(
        DateTime.parse(
          credentials['tokenExpiredAt'] as String,
        ).difference(DateTime.now().toUtc()).inSeconds,
        inInclusiveRange(118, 120),
      );
    },
  );
  test(
    'Native login verifies profile before restoring auth and logout clears vault',
    () async {
      final vault = MemoryVault(), identity = TestIdentity();
      final auth = AuthController(identity, vault)
        ..repository = LecturerRepository(FixtureApi());
      await auth.login();
      expect(auth.lecturer?.lecturerId, 'lec-1');
      expect(vault.value, isNotNull);
      final restored = AuthController(identity, vault)
        ..repository = auth.repository;
      await restored.restore();
      expect(restored.lecturer?.lecturerId, 'lec-1');
      await restored.logout();
      expect(vault.value, isNull);
      expect(restored.lecturer, isNull);
      expect(identity.signedOut, true);
    },
  );
  test('Unauthorized profile never grants local lecturer access', () async {
    final vault = MemoryVault();
    final auth = AuthController(TestIdentity(), vault)
      ..repository = LecturerRepository(FixtureApi()..deny = true);
    await auth.login();
    expect(auth.lecturer, isNull);
    expect(vault.value, isNull);
    expect(auth.error, isNot(contains('Private')));
  });
}
