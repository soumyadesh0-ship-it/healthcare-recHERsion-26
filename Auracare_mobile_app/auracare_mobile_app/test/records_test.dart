import 'package:flutter_test/flutter_test.dart';
import 'package:auracare_mobile_app/data/records.dart';
import 'package:auracare_mobile_app/data/services.dart';

void main() {
  HealthEntry entry({int version = 1, String title = 'Headache'}) =>
      HealthEntry(
        id: 'fixture',
        type: EntryType.symptom,
        title: title,
        when: DateTime(2026, 10, 20, 9),
        zone: 'UTC',
        version: version,
      );
  test(
    'CRUD notifies and derived coverage/summary use current versions',
    () async {
      final repo = DemoRecordsRepository(sample: false);
      var changes = 0;
      repo.addListener(() => changes++);
      final from = DateTime(2026, 10, 19), to = DateTime(2026, 10, 21);
      await repo.save(entry());
      var coverage = Coverage(repo.entries, from, to);
      expect(coverage.recordedDays, 1);
      expect(coverage.unknownDays, 2);
      expect(coverage.symptomDays, {'Headache': 1});
      await repo.save(entry(version: 2, title: 'Fatigue'));
      coverage = Coverage(repo.entries, from, to);
      expect(coverage.symptomDays, {'Fatigue': 1});
      final summary = appointmentSummary(
        repo.entries,
        [],
        includeNotes: false,
        includeObservations: true,
        from: from,
        to: to,
      );
      expect(summary, contains('Fatigue'));
      expect(summary, contains('v2'));
      expect(summary, isNot(contains('Headache')));
      await repo.delete('fixture');
      expect(Coverage(repo.entries, from, to).recordedDays, 0);
      expect(changes, 3);
      repo.dispose();
    },
  );
  test(
    'failure is atomic, retry succeeds and stale edits cannot overwrite',
    () async {
      final repo = DemoRecordsRepository(sample: false)..failNextWrite = true;
      await expectLater(repo.save(entry()), throwsStateError);
      expect(repo.entries, isEmpty);
      await repo.save(entry());
      await expectLater(
        repo.save(entry(version: 1, title: 'Other')),
        throwsStateError,
      );
      expect(repo.entries.single.title, 'Headache');
      repo.dispose();
    },
  );
  test(
    'symptom counts deduplicate days and mixed zones retain labels',
    () async {
      final repo = DemoRecordsRepository(sample: false);
      await repo.save(entry());
      await repo.save(
        HealthEntry(
          id: 'other',
          type: EntryType.symptom,
          title: 'Headache',
          when: DateTime(2026, 10, 20, 19),
          zone: 'Device local',
        ),
      );
      final coverage = Coverage(
        repo.entries,
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 20),
      );
      expect(coverage.symptomDays['Headache'], 1);
      expect(coverage.totalDays, 1);
      expect(repo.entries.first.zone, 'Device local');
      repo.dispose();
    },
  );
  test(
    'selected summary omits notes/observations by default and deleted records',
    () {
      final e = HealthEntry(
        id: 'journal',
        type: EntryType.journal,
        title: 'Journal',
        when: DateTime(2026, 10, 20),
        zone: 'UTC',
        note: 'private fictional text',
      );
      final summary = appointmentSummary(
        [e],
        ['Question'],
        includeNotes: false,
        includeObservations: false,
        from: DateTime(2026, 10, 20),
        to: DateTime(2026, 10, 21),
      );
      expect(summary, isNot(contains(e.note)));
      expect(summary, isNot(contains('prototype-count-v1')));
      expect(summary, contains('Question'));
    },
  );
  test(
    'quiz nulls, scope, known diagnosis, failure and unavailable boundaries',
    () async {
      final answers = QuizAnswers()..age = 28;
      expect(answers.toJson()['acne'], isNull);
      expect(await DemoQuizService().assess(answers), QuizOutcome.insufficient);
      for (final key in quizFields.keys) {
        answers.binary[key] = 0;
      }
      expect(await DemoQuizService().assess(answers), QuizOutcome.fixture);
      expect(
        await DemoQuizService(scenario: QuizOutcome.failure).assess(answers),
        QuizOutcome.failure,
      );
      expect(
        await LiveUnavailableQuizService().assess(answers),
        QuizOutcome.unavailable,
      );
      answers.age = 17;
      expect(await DemoQuizService().assess(answers), QuizOutcome.outsideScope);
      answers.knownDiagnosis = true;
      expect(await DemoQuizService().assess(answers), QuizOutcome.tracking);
      answers.kg = 64;
      answers.cm = 160;
      expect(answers.bmi, closeTo(25, .001));
      expect(answers.summary, contains('No model was run'));
      expect(answers.summary, isNot(contains('%')));
    },
  );
}
