import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/api/repository.dart';
import 'package:lecturer_companion/core/config.dart';
import 'package:lecturer_companion/models/domain.dart';
import 'fixtures.dart';

class InterruptedApi extends FixtureApi {
  bool failFinalization = true;
  bool acknowledge = true;
  @override
  Future<dynamic> call(String action, [Json payload = const {}]) async {
    if (action == 'markAbsent' && failFinalization) {
      throw const AppFailure('Offline');
    }
    if (action == 'updateAttendance' && !acknowledge) return {'saved': false};
    return super.call(action, payload);
  }
}

void main() {
  test(
    'Interrupted finalization remains CLOSED and can be recovered without duplicates',
    () async {
      final api = InterruptedApi();
      final repo = LecturerRepository(api);
      final cls = TeachingClass.fromJson(classJson);
      await expectLater(
        repo.finish(await repo.attendance(cls, 'session-1', 'lec-1')),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.message,
            'recovery instruction',
            contains('Finalize missing attendance'),
          ),
        ),
      );
      expect(api.status, 'CLOSED');
      expect(api.records, isEmpty);
      api.failFinalization = false;
      await repo.finish(await repo.attendance(cls, 'session-1', 'lec-1'));
      expect(api.records.single['status'], 'ABSENT');
    },
  );
  test('Unacknowledged manual change is never treated as success', () async {
    final api = InterruptedApi()..acknowledge = false;
    final repo = LecturerRepository(api);
    final data = await repo.attendance(
      TeachingClass.fromJson(classJson),
      'session-1',
      'lec-1',
    );
    await expectLater(
      repo.update(data, data.roster.single, 'PRESENT', ''),
      throwsA(isA<AppFailure>()),
    );
    expect(api.records, isEmpty);
  });
  test('Ambiguous class mappings never select an arbitrary class', () {
    final cls = TeachingClass.fromJson(classJson);
    final data = Overview([cls, cls], [Schedule.fromJson(scheduleJson())], []);
    expect(data.mappedClass(data.schedules.single), isNull);
  });
}
