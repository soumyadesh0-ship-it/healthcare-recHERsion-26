import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auracare_mobile_app/app/app.dart';
import 'package:auracare_mobile_app/app/navigation.dart';
import 'package:auracare_mobile_app/app/session.dart';
import 'package:auracare_mobile_app/app/theme.dart';
import 'package:auracare_mobile_app/core/widgets.dart';
import 'package:auracare_mobile_app/data/records.dart';
import 'package:auracare_mobile_app/data/services.dart';
import 'package:auracare_mobile_app/data/cycles.dart';
import 'package:auracare_mobile_app/data/demo_doctors.dart';
import 'package:auracare_mobile_app/features/appointments/demo_directory.dart';
import 'package:auracare_mobile_app/features/logging/editor.dart';
import 'package:auracare_mobile_app/features/wellbeing/merge_game.dart';

import 'widget_test.dart' as helper;

void main() {
  test('approved screenshot palette is exact', () {
    expect(Palette.white, const Color(0xFFFFFFFF));
    expect(Palette.input, const Color(0xFFFAF8FB));
    expect(Palette.blush, const Color(0xFFF9DFEA));
    expect(Palette.blue, const Color(0xFFA6BCE1));
    expect(Palette.lavender, const Color(0xFFE7DEF1));
    expect(Palette.ink, const Color(0xFF34283C));
  });
  for (final type in [EntryType.spotting, EntryType.discharge]) {
    testWidgets(
      '${type.name} validates amount and supports create edit delete without changing cycle dates',
      (tester) async {
        final session = DemoSession(
          records: DemoRecordsRepository(sample: false),
        );
        await helper.show(tester, EntryEditor(type: type), session);
        await helper.tapText(tester, 'Save demo entry');
        expect(find.text('Choose an amount.'), findsOneWidget);
        expect(session.records.entries, isEmpty);

        await tester.ensureVisible(
          find.byKey(const ValueKey('tracking-amount')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('tracking-amount')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Light').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('tracking-color')),
          'Brown',
        );
        if (type == EntryType.discharge) {
          await tester.enterText(
            find.byKey(const ValueKey('tracking-consistency')),
            'Creamy',
          );
          tester.testTextInput.hide();
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byKey(const ValueKey('odor-change')));
          await tester.tap(find.byKey(const ValueKey('odor-change')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Unsure').last);
          await tester.pumpAndSettle();
        }
        tester.testTextInput.hide();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await helper.tapText(tester, 'Save demo entry');
        final entry = session.records.entries.single;
        expect(entry.type, type);
        expect(entry.tracking!.amount, TrackingAmount.light);
        expect(entry.tracking!.color, 'Brown');
        expect(entry.periodStart, isNull);
        expect(CycleHistory(session.records.entries).periods, isEmpty);
        if (type == EntryType.discharge) {
          expect(entry.tracking!.consistency, 'Creamy');
          expect(entry.tracking!.odorChange, ObservationAnswer.unsure);
          expect(entry.tracking!.irritation, isNull);
        }
        await helper.show(
          tester,
          EntryEditor(type: type, entry: entry),
          session,
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('tracking-amount')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('tracking-amount')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Heavy').last);
        await tester.pumpAndSettle();
        await helper.tapText(tester, 'Save demo entry');
        final edited = session.records.entries.single;
        expect(edited.version, 2);
        expect(edited.tracking!.amount, TrackingAmount.heavy);
        expect(edited.tracking!.color, 'Brown');
        expect(edited.toJson()['tracking'], isA<Map<String, Object?>>());
        await helper.show(
          tester,
          EntryEditor(type: type, entry: edited),
          session,
        );
        await helper.tapText(tester, 'Delete entry');
        expect(session.records.entries, hasLength(1));
        await helper.tapText(tester, 'Delete');
        expect(session.records.entries, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        session.dispose();
      },
    );
  }
  test('existing records remain compatible and selected observations enter appointment summaries', () {
    final date = DateTime(2026, 10, 25, 10, 30);
    final old = HealthEntry(
      id: 'old',
      type: EntryType.symptom,
      title: 'Cramps',
      when: date,
      zone: 'UTC',
    );
    expect(old.tracking, isNull);
    expect(old.toJson().containsKey('tracking'), isFalse);
    final spotting = HealthEntry(
      id: 'spot',
      type: EntryType.spotting,
      title: 'Spotting',
      when: date,
      zone: 'UTC',
      tracking: const TrackingDetails(
        amount: TrackingAmount.light,
        color: 'Pink',
      ),
      note: 'optional words',
    );
    final discharge = HealthEntry(
      id: 'discharge',
      type: EntryType.discharge,
      title: 'Discharge',
      when: date,
      zone: 'UTC',
      tracking: const TrackingDetails(
        amount: TrackingAmount.moderate,
        consistency: 'Sticky',
        odorChange: ObservationAnswer.unsure,
        irritation: ObservationAnswer.no,
      ),
    );
    final summary = appointmentSummary(
      [spotting, discharge],
      [],
      includeNotes: false,
      includeObservations: false,
      from: date,
      to: date,
    );
    expect(summary, contains('Spotting'));
    expect(summary, contains('Amount: Light'));
    expect(summary, contains('Consistency: Sticky'));
    expect(summary, contains('Odor change: Unsure'));
    expect(summary, isNot(contains('optional words')));
    expect(summary, isNot(contains('Cramps')));
    expect(
      Coverage([old, spotting, discharge], date, date).records,
      hasLength(3),
    );
    expect(CycleHistory([spotting, discharge]).periods, isEmpty);
  });
  testWidgets('new record types render distinct timeline icons and filters', (
    tester,
  ) async {
    final session = DemoSession(records: DemoRecordsRepository(sample: false));
    for (final type in [EntryType.spotting, EntryType.discharge]) {
      await tester.runAsync(
        () => session.records.save(
          HealthEntry(
            id: type.name,
            type: type,
            title: observationLabel(type),
            when: DateTime.now(),
            zone: 'Device local',
            tracking: const TrackingDetails(amount: TrackingAmount.light),
          ),
        ),
      );
    }
    await tester.pumpWidget(
      AuracareApp(session: session, showOnboarding: false),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tab-Timeline')));
    await tester.pumpAndSettle();
    await helper.tapText(tester, 'spotting');
    await helper.tapText(tester, 'Spotting');
    expect(find.text('Entry details'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await helper.tapText(tester, 'discharge');
    await helper.tapText(tester, 'Discharge');
    expect(find.text('Entry details'), findsOneWidget);
    expect(
      entryIcon(EntryType.spotting),
      isNot(entryIcon(EntryType.discharge)),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });
  test(
    'directory search/filter only returns visibly fictional inert contacts',
    () {
      expect(DemoDoctorDirectory.doctors, hasLength(6));
      for (final d in DemoDoctorDirectory.doctors) {
        expect(d.name, contains('Demo'));
        expect(d.clinic, startsWith('Example '));
        expect(d.phone, '+91 XXXXX XXXXX');
        expect(d.email, endsWith('@example.com'));
      }
      expect(DemoDoctorDirectory.search(specialty: 'Gynecology'), hasLength(2));
      expect(
        DemoDoctorDirectory.search(name: 'ASTER').single.name,
        'Dr. Aster Demo',
      );
      expect(
        DemoDoctorDirectory.search(name: 'Aster', specialty: 'Endocrinology'),
        isEmpty,
      );
    },
  );
  testWidgets(
    'demo contacts have no call email map or booking actions and a useful empty state',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: auracareTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: DemoDirectory(),
            ),
          ),
        ),
      );
      expect(find.text(DemoDoctorDirectory.notice), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('doctor-directory-search')),
        'Nobody',
      );
      await tester.pumpAndSettle();
      expect(find.text('No fictional doctors match'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('doctor-directory-search')),
        '',
      );
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('doctor-specialty-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('General practice').last);
      await tester.pumpAndSettle();
      expect(find.text('Dr. Clover Demo'), findsOneWidget);
      expect(find.text('Dr. Aster Demo'), findsNothing);
    },
  );
  testWidgets(
    'game route pauses when covered, backgrounded or left, and exposes resume/restart',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [auraRouteObserver],
          theme: auracareTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => pushPage(context, const MergeGamePage()),
                child: const Text('Open game'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open game'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(MergeGamePage), findsOneWidget);
      final context = tester.element(find.byType(MergeGamePage));
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Covered')),
        ),
      );
      await tester.pumpAndSettle();
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('merge-status')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Paused'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Resume'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Resume'));
      await tester.pump(const Duration(milliseconds: 80));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(find.text('Paused'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Paused'), findsOneWidget);
      await tester.ensureVisible(find.text('Restart'));
      await tester.tap(find.text('Restart'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Paused'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Open game'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
