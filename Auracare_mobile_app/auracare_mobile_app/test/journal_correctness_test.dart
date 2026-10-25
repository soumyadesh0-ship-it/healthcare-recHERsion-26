import 'package:auracare_mobile_app/app/session.dart';
import 'package:auracare_mobile_app/data/records.dart';
import 'package:auracare_mobile_app/features/logging/editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'local_records_correctness_test.dart' show journal;
import 'widget_test.dart' show show, tapText;

class FailingRecords extends DemoRecordsRepository {
  FailingRecords() : super(sample: false);
  bool fail = false;
  @override
  Future<void> save(HealthEntry entry) async {
    if (fail) {
      throw StateError('Bearer synthetic-secret-token internal SDK details');
    }
    await super.save(entry);
  }

  @override
  Future<void> delete(String id, {required int expectedVersion}) async {
    if (fail) {
      throw StateError('Bearer synthetic-secret-token internal SDK details');
    }
    await super.delete(id, expectedVersion: expectedVersion);
  }
}

void main() {
  for (final deleting in [false, true]) {
    testWidgets(
      '${deleting ? 'delete' : 'save'} failure hides raw errors and preserves journal draft',
      (tester) async {
        final repo = FailingRecords();
        if (deleting) await tester.runAsync(() => repo.save(journal()));
        repo.fail = true;
        final session = DemoSession(records: repo);
        await show(
          tester,
          EntryEditor(
            type: EntryType.journal,
            entry: deleting ? repo.entries.single : null,
          ),
          session,
        );
        await tester.enterText(
          find.byKey(const ValueKey('entry-note')),
          'Fictional unsaved words',
        );
        if (deleting) {
          await tapText(tester, 'Delete entry');
          await tapText(tester, 'Delete');
        } else {
          await tapText(tester, 'Save demo entry');
        }
        expect(find.textContaining('synthetic-secret-token'), findsNothing);
        expect(find.textContaining('internal SDK'), findsNothing);
        expect(find.text('Fictional unsaved words'), findsOneWidget);
        expect(
          find.textContaining(
            deleting ? 'could not be deleted' : 'could not be saved',
          ),
          findsOneWidget,
        );
        repo.fail = false;
        await tapText(tester, deleting ? 'Delete entry' : 'Retry save');
        if (deleting) await tapText(tester, 'Delete');
        expect(
          deleting
              ? repo.entries.isEmpty
              : repo.entries.single.note == 'Fictional unsaved words',
          isTrue,
        );
        await tester.pumpWidget(const SizedBox());
        session.dispose();
      },
    );
  }
  testWidgets(
    'deleted journal update shows safe conflict and retains unsaved text',
    (tester) async {
      final session = DemoSession(
        records: DemoRecordsRepository(sample: false),
      );
      final entry = journal();
      await tester.runAsync(() => session.records.save(entry));
      await show(
        tester,
        EntryEditor(type: EntryType.journal, entry: entry),
        session,
      );
      await tester.enterText(
        find.byKey(const ValueKey('entry-note')),
        'Fictional pending edit',
      );
      await tester.runAsync(
        () => session.records.delete(entry.id, expectedVersion: 1),
      );
      await tapText(tester, 'Save demo entry');
      expect(session.records.entries, isEmpty);
      expect(find.textContaining('no longer exists'), findsOneWidget);
      expect(find.text('Fictional pending edit'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets('stale editor deletion leaves the newer record intact', (
    tester,
  ) async {
    final session = DemoSession(records: DemoRecordsRepository(sample: false));
    final entry = journal();
    await tester.runAsync(() => session.records.save(entry));
    await show(
      tester,
      EntryEditor(type: EntryType.journal, entry: entry),
      session,
    );
    await tester.runAsync(() => session.records.save(journal(version: 2)));
    await tapText(tester, 'Delete entry');
    await tapText(tester, 'Delete');
    expect(session.records.entries.single.version, 2);
    expect(find.textContaining('This entry changed'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
  for (final changeDate in [false, true]) {
    testWidgets(
      'journal ${changeDate ? 'date picker edit' : 'unchanged timestamp'} preserves UTC and microseconds',
      (tester) async {
        final session = DemoSession(
          records: DemoRecordsRepository(sample: false),
        );
        final entry = journal();
        await tester.runAsync(() => session.records.save(entry));
        await show(
          tester,
          EntryEditor(type: EntryType.journal, entry: entry),
          session,
        );
        if (changeDate) {
          await tapText(tester, 'Date: 2026-10-20');
          await tester.tap(find.text('21').last);
          await tester.pumpAndSettle();
          await tapText(tester, 'OK');
        }
        await tapText(tester, 'Save demo entry');
        final saved = session.records.entries.single;
        expect(
          saved.when,
          changeDate
              ? DateTime.utc(2026, 10, 21, 9, 15, 12, 345, 678)
              : entry.when,
        );
        expect(saved.when.isUtc, isTrue);
        expect(saved.zone, 'UTC');
        await tester.pumpWidget(const SizedBox());
        session.dispose();
      },
    );
  }
}
