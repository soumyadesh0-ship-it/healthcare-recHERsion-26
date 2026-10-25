import 'package:auracare_mobile_app/data/records.dart';
import 'package:flutter_test/flutter_test.dart';

HealthEntry journal({int version = 1, DateTime? when}) => HealthEntry(
  id: 'synthetic-journal',
  type: EntryType.journal,
  title: 'Synthetic journal',
  note: 'Fictional reflection',
  when: when ?? DateTime.utc(2026, 10, 20, 9, 15, 12, 345, 678),
  zone: 'UTC',
  version: version,
);
Matcher problem(RecordProblem value) =>
    isA<RecordFailure>().having((e) => e.problem, 'problem', value);

void main() {
  for (final utc in [true, false]) {
    test(
      'export retains timestamp precision and declared representation ($utc)',
      () {
        final when = utc
            ? DateTime.utc(2026, 10, 20, 9, 15, 12, 345, 678)
            : DateTime(2026, 10, 20, 9, 15, 12, 345, 678);
        final encoded = journal(when: when).toJson()['wallClock'] as String;
        final restored = DateTime.parse(encoded);
        expect(restored, when);
        expect(restored.isUtc, utc);
        expect(encoded, contains('12.345678'));
      },
    );
  }
  test(
    'editing a deleted entry is not an insert and sends no notification',
    () async {
      final repo = DemoRecordsRepository(sample: false);
      addTearDown(repo.dispose);
      var notifications = 0;
      repo.addListener(() => notifications++);
      await repo.save(journal());
      await repo.delete(journal().id, expectedVersion: 1);
      await expectLater(
        repo.save(journal(version: 2)),
        throwsA(problem(RecordProblem.notFound)),
      );
      expect(repo.entries, isEmpty);
      expect(notifications, 2);
    },
  );
  test('stale deletion cannot remove a newer entry; current-version deletion works', () async {
    final repo = DemoRecordsRepository(sample: false);
    addTearDown(repo.dispose);
    await repo.save(journal());
    await repo.save(journal(version: 2));
    await expectLater(
      repo.delete(journal().id, expectedVersion: 1),
      throwsA(problem(RecordProblem.conflict)),
    );
    expect(repo.entries.single.version, 2);
    await repo.delete(journal().id, expectedVersion: 2);
    await expectLater(
      repo.delete(journal().id, expectedVersion: 2),
      throwsA(problem(RecordProblem.notFound)),
    );
  });
  test(
    'duplicate create and stale update preserve the confirmed record',
    () async {
      final repo = DemoRecordsRepository(sample: false);
      addTearDown(repo.dispose);
      await repo.save(journal());
      await expectLater(
        repo.save(journal()),
        throwsA(problem(RecordProblem.conflict)),
      );
      await repo.save(journal(version: 2));
      await expectLater(
        repo.save(journal(version: 2)),
        throwsA(problem(RecordProblem.conflict)),
      );
      expect(repo.entries.single.version, 2);
    },
  );
  for (final operation in ['create', 'update', 'delete']) {
    test('pending $operation cannot mutate or notify after disposal', () async {
      final repo = DemoRecordsRepository(sample: false);
      if (operation != 'create') await repo.save(journal());
      var notifications = 0;
      repo.addListener(() => notifications++);
      final pending = operation == 'delete'
          ? repo.delete(journal().id, expectedVersion: 1)
          : repo.save(journal(version: operation == 'update' ? 2 : 1));
      final checked = expectLater(
        pending,
        throwsA(problem(RecordProblem.closed)),
      );
      repo.dispose();
      await checked;
      expect(repo.entries, isEmpty);
      expect(notifications, 0);
    });
  }
  test('reset cancels a pending create at the session boundary', () async {
    final repo = DemoRecordsRepository(sample: false);
    addTearDown(repo.dispose);
    final pending = repo.save(journal());
    final checked = expectLater(
      pending,
      throwsA(problem(RecordProblem.cancelled)),
    );
    repo.reset();
    await checked;
    expect(repo.entries, isEmpty);
    await repo.save(journal());
    expect(repo.entries, hasLength(1));
  });
  test('all repository operations reject use after disposal', () async {
    final repo = DemoRecordsRepository(sample: false)..dispose();
    expect(repo.newId, throwsA(problem(RecordProblem.closed)));
    expect(() => repo.reset(), throwsA(problem(RecordProblem.closed)));
    await expectLater(
      repo.save(journal()),
      throwsA(problem(RecordProblem.closed)),
    );
    await expectLater(
      repo.delete(journal().id, expectedVersion: 1),
      throwsA(problem(RecordProblem.closed)),
    );
    expect(repo.entries, isEmpty);
  });
  test(
    'save preserves the full observation timestamp and separates save time',
    () async {
      final repo = DemoRecordsRepository(sample: false);
      addTearDown(repo.dispose);
      final entry = journal();
      await repo.save(entry);
      await repo.save(journal(version: 2, when: entry.when));
      expect(repo.entries.single.when, entry.when);
      expect(repo.entries.single.when.isUtc, isTrue);
      expect(repo.entries.single.savedAt!.isUtc, isTrue);
      expect(repo.entries.single.zone, 'UTC');
    },
  );
  for (final utc in [true, false]) {
    test(
      'date/time edits retain precision and ${utc ? 'UTC' : 'local'} representation',
      () {
        final before = utc
            ? DateTime.utc(2026, 10, 20, 9, 15, 12, 345, 678)
            : DateTime(2026, 10, 20, 9, 15, 12, 345, 678);
        expect(
          identical(
            withWallClockComponents(
              before,
              date: DateTime(2026, 10, 20),
              hour: 9,
              minute: 15,
            ),
            before,
          ),
          isTrue,
        );
        final changed = withWallClockComponents(
          before,
          date: DateTime(2026, 10, 21),
          hour: 11,
          minute: 30,
        );
        expect(
          [
            changed.year,
            changed.month,
            changed.day,
            changed.hour,
            changed.minute,
            changed.second,
            changed.millisecond,
            changed.microsecond,
          ],
          [2026, 10, 21, 11, 30, 12, 345, 678],
        );
        expect(changed.isUtc, utc);
      },
    );
  }
}
