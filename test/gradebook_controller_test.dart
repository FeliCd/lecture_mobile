import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecturer_companion/grades/gradebook_controller.dart';

GradeRow book() => {
  'version': 0,
  'activePublicationId': '',
  'components': <GradeRow>[
    {'id': 'quiz', 'name': 'Quiz', 'maxScore': 10},
  ],
  'students': <GradeRow>[
    {
      'studentId': 's1',
      'studentCode': 'SE1',
      'fullName': 'Student',
      'grades': {'quiz': 5},
      'comment': '',
    },
  ],
};
void main() {
  test(
    'save zero/comma numeric drafts; publication is explicit and retries use frozen identity',
    () async {
      final writes = <GradeRow>[], initial = book();
      var attempts = 0;
      final model = GradebookController(
        classId: 'c1',
        call: (method, data) async {
          if (method == 'getGradebook') {
            return attempts < 2
                ? initial
                : {...initial, 'activePublicationId': 'p1', 'version': 2};
          }
          writes.add({'method': method, ...data});
          if (method == 'saveGradebook') return {'saved': true, 'version': 1};
          if (method == 'publishGrades') {
            if (++attempts == 1) throw StateError('timeout');
            return {'publicationId': 'p1'};
          }
          return {'saved': true};
        },
      );
      addTearDown(model.dispose);
      await model.load();
      model.setGrade(model.students.single, 'quiz', '0');
      await model.save();
      expect(writes.single['students'][0]['grades']['quiz'], 0);
      expect(initial['students'][0]['grades']['quiz'], 5);
      expect(model.book!['activePublicationId'], '');
      expect(await model.publish(), false);
      expect(model.editable, false);
      model.setGrade(model.students.single, 'quiz', '9');
      expect(model.students.single['grades']['quiz'], 0);
      expect(await model.publish(), true);
      expect(writes[1], writes[2]);
      expect(model.book!['activePublicationId'], 'p1');
      model.setGrade(model.students.single, 'quiz', '8,5');
      expect(await model.publish(), false);
      await model.save();
      expect(writes.last['students'][0]['grades']['quiz'], 8.5);
    },
  );
  test(
    'invalid score prevents API writes, version conflict preserves the draft',
    () async {
      var writes = 0;
      final model = GradebookController(
        classId: 'c1',
        call: (method, data) async {
          if (method == 'getGradebook') return book();
          writes++;
          throw StateError('VERSION_CONFLICT');
        },
      );
      addTearDown(model.dispose);
      await model.load();
      for (final score in ['-1', '10.1', 'NaN', 'Infinity']) {
        model.setGrade(model.students.single, 'quiz', score);
        expect(await model.save(), false);
      }
      expect(writes, 0);
      model.setGrade(model.students.single, 'quiz', '7');
      expect(await model.save(), false);
      expect(model.dirty, true);
      expect(model.students.single['grades']['quiz'], '7');
      expect(model.error, contains('thiết bị khác'));
    },
  );
  test(
    'closing during a read ignores late data and duplicate operations do not write twice',
    () async {
      final pending = Completer<dynamic>();
      var calls = 0;
      final model = GradebookController(
        classId: 'c1',
        call: (_, _) {
          calls++;
          return pending.future;
        },
      );
      final first = model.load();
      expect(await model.load(), false);
      expect(calls, 1);
      model.dispose();
      pending.complete(book());
      expect(await first, false);
      expect(model.book, isNull);
    },
  );
  test('component edits keep other scores and enforce names/scales', () async {
    final model = GradebookController(
      classId: 'c1',
      call: (_, _) async => book(),
    );
    addTearDown(model.dispose);
    await model.load();
    expect(() => model.upsertComponent('Quiz', 10), throwsFormatException);
    expect(
      () => model.upsertComponent('Lab', double.nan),
      throwsFormatException,
    );
    model.upsertComponent('Lab', 100);
    expect(model.components.length, 2);
    expect(model.students.single['grades']['quiz'], 5);
    model.removeComponent(model.components.first);
    expect(model.students.single['grades'].containsKey('quiz'), false);
  });
}
