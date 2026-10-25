import 'dart:async';

import 'package:auracare_mobile_app/app/app.dart';
import 'package:auracare_mobile_app/app/session.dart';
import 'package:auracare_mobile_app/core/widgets.dart';
import 'package:auracare_mobile_app/data/appointments.dart';
import 'package:auracare_mobile_app/data/records.dart';
import 'package:auracare_mobile_app/features/logging/editor.dart';
import 'package:auracare_mobile_app/features/wellbeing/breath_haptics.dart';
import 'package:auracare_mobile_app/features/wellbeing/merge_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryAppointments implements AppointmentStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String json) async {}
}

Future<DemoSession> home(WidgetTester tester) async {
  final session = DemoSession(
    records: DemoRecordsRepository(sample: false),
    appointments: AppointmentsRepository(store: _MemoryAppointments()),
  );
  addTearDown(session.dispose);
  await tester.pumpWidget(AuracareApp(session: session, showOnboarding: false));
  await tester.pumpAndSettle();
  return session;
}

Future<void> expand(WidgetTester tester, EntryType type) async {
  final tile = find.byKey(PageStorageKey('inline-category-${type.name}'));
  final header = find
      .descendant(of: tile, matching: find.byType(ListTile))
      .first;
  await tester.ensureVisible(header);
  await tester.pumpAndSettle();
  await tester.tap(header);
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  } else {
    await tester.ensureVisible(target);
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Home has inline categories and only the retained shortcuts', (
    tester,
  ) async {
    await home(tester);
    expect(find.text('Log Entry'), findsOneWidget);
    for (final type in EntryType.values) {
      expect(
        find.byKey(PageStorageKey('inline-category-${type.name}')),
        findsOneWidget,
      );
    }
    expect(find.widgetWithText(FilledButton, 'Log entry'), findsNothing);
    await reveal(tester, find.widgetWithText(ActionCard, 'AI Assistant'));
    final shortcuts = tester
        .widgetList<ActionCard>(find.byType(ActionCard))
        .map((card) => card.title)
        .toList();
    expect(shortcuts, ['AI Assistant', 'Journal']);
    await reveal(tester, find.text('Recent records'));
    expect(find.text('Appointment preparation'), findsNothing);
    for (final tab in ['Wellbeing', 'PCOS Quiz', 'Doctor']) {
      expect(find.byKey(ValueKey('tab-$tab')), findsOneWidget);
    }
  });

  testWidgets(
    'inline symptom save stays on Home and repeated taps create one entry',
    (tester) async {
      final session = await home(tester);
      await expand(tester, EntryType.symptom);
      await tapVisible(tester, find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.text('Headache').last);
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('save-entry'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.tap(save);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(session.records.entries, hasLength(1));
      expect(session.records.entries.single.title, 'Headache');
      expect(find.byType(LogEntryPage), findsNothing);
      expect(find.text('Added to demo session'), findsOneWidget);
      await reveal(tester, find.text('Recent records'));
      expect(find.widgetWithText(EntryCard, 'Headache'), findsOneWidget);
      await tapVisible(tester, find.widgetWithText(EntryCard, 'Headache'));
      await tapVisible(tester, find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.text('Fatigue').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const ValueKey('save-entry')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(session.records.entries, hasLength(1));
      expect(session.records.entries.single.version, 2);
      expect(session.records.entries.single.title, 'Fatigue');
    },
  );

  testWidgets(
    'inline spotting validates, retains collapsed drafts and retries a failed save',
    (tester) async {
      final session = await home(tester);
      await expand(tester, EntryType.spotting);
      await tapVisible(tester, find.byKey(const ValueKey('save-entry')));
      expect(find.text('Choose an amount.'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('tracking-amount')));
      await tester.tap(find.text('Light').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('tracking-color')),
        'Fictional pink',
      );
      await expand(tester, EntryType.spotting);
      await expand(tester, EntryType.spotting);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('tracking-color')))
            .controller!
            .text,
        'Fictional pink',
      );
      session.records.failNextWrite = true;
      await tapVisible(tester, find.byKey(const ValueKey('save-entry')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(session.records.entries, isEmpty);
      expect(find.textContaining('Simulated demo failure'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('tracking-color')))
            .controller!
            .text,
        'Fictional pink',
      );
      await tapVisible(tester, find.text('Retry save'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(session.records.entries.single.tracking?.color, 'Fictional pink');
    },
  );

  testWidgets('inline discharge retains its existing validation and fields', (
    tester,
  ) async {
    final session = await home(tester);
    await expand(tester, EntryType.discharge);
    await tapVisible(tester, find.byKey(const ValueKey('tracking-amount')));
    await tester.tap(find.text('Moderate').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('tracking-consistency')),
      'Fictional thin',
    );
    await tapVisible(tester, find.byKey(const ValueKey('odor-change')));
    await tester.tap(find.text('Unsure').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('save-entry')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(session.records.entries.single.type, EntryType.discharge);
    expect(
      session.records.entries.single.tracking?.consistency,
      'Fictional thin',
    );
    expect(
      session.records.entries.single.tracking?.odorChange,
      ObservationAnswer.unsure,
    );
  });

  testWidgets('Merge instruction is short and bold', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MergeGamePage()));
    final label = find.text('Match colors. Merge bubbles. Unwind!');
    expect(label, findsOneWidget);
    expect(tester.widget<Text>(label).style?.fontWeight, FontWeight.w700);
    await tester.pumpWidget(const SizedBox());
  });

  test(
    'queued haptics never overlap and cancellation drops pending transitions',
    () async {
      final blocked = Completer<void>();
      final sent = <BreathCue>[];
      final haptics = BreathHaptics(
        pulse: (cue) async {
          sent.add(cue);
          if (sent.length == 1) await blocked.future;
        },
      );
      final inhale = haptics.cue(BreathCue.inhale);
      final exhale = haptics.cue(BreathCue.exhale);
      final finish = haptics.cue(BreathCue.finish);
      expect(sent, [BreathCue.inhale]);
      haptics.cancel();
      blocked.complete();
      await Future.wait([inhale, exhale, finish]);
      expect(sent, [BreathCue.inhale]);
    },
  );

  test(
    'temporary haptic failure does not disable subsequent phase cues',
    () async {
      var calls = 0;
      final haptics = BreathHaptics(
        pulse: (_) async {
          if (++calls == 1) throw PlatformException(code: 'temporary');
        },
      );
      await haptics.cue(BreathCue.inhale);
      await haptics.cue(BreathCue.exhale);
      expect(calls, 2);
      expect(haptics.supported, isTrue);
    },
  );
}
