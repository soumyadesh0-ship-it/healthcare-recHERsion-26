import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auracare_mobile_app/app/app.dart';
import 'package:auracare_mobile_app/app/session.dart';
import 'package:auracare_mobile_app/data/records.dart';
import 'package:auracare_mobile_app/data/services.dart';
import 'package:auracare_mobile_app/features/appointments/appointments.dart';
import 'package:auracare_mobile_app/features/cycle/cycle.dart';
import 'package:auracare_mobile_app/features/logging/editor.dart';
import 'package:auracare_mobile_app/features/pcos_quiz/quiz.dart';
import 'package:auracare_mobile_app/app/theme.dart';
import 'package:auracare_mobile_app/app/setup_preference.dart';

Future<void> show(WidgetTester tester, Widget page, DemoSession session) async {
  await tester.pumpWidget(
    SessionScope(
      session: session,
      child: MaterialApp(
        theme: auracareTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => page),
              ),
              child: const Text('Open test page'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open test page'));
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  final raw = find.text(text);
  final scroll = find
      .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      )
      .hitTestable();
  for (var i = 0; i < 35 && raw.evaluate().isEmpty; i++) {
    await tester.drag(scroll.first, const Offset(0, -240));
    await tester.pumpAndSettle();
  }
  if (raw.evaluate().isEmpty) {
    for (var i = 0; i < 35 && raw.evaluate().isEmpty; i++) {
      await tester.drag(scroll.first, const Offset(0, 240));
      await tester.pumpAndSettle();
    }
  }
  expect(raw, findsWidgets, reason: 'Missing control: $text');
  final finder = raw.last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SetupPreference.channel, (_) async => false);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SetupPreference.channel, null);
  });
  testWidgets(
    'onboarding skip/demo entry and five tabs preserve search state',
    (tester) async {
      await tester.pumpWidget(const AuracareApp());
      await tester.pumpAndSettle();
      await tapText(tester, 'Get started');
      expect(find.text('Your body. Your rhythm. Your space.'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Next'));
      await tester.pumpAndSettle();
      await tapText(tester, 'Back');
      await tapText(tester, 'Skip');
      await tapText(tester, 'Start empty demo');
      expect(find.text('Demo — sample data'), findsOneWidget);
      for (final tab in ['Timeline', 'Learn', 'Insights', 'Profile', 'Home']) {
        await tester.tap(find.byKey(ValueKey('tab-$tab')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const ValueKey('tab-Learn')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('resource-search')),
        'no topic matches',
      );
      await tester.pumpAndSettle();
      expect(find.text('No matching topics'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tab-Home')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab-Learn')));
      await tester.pumpAndSettle();
      expect(find.text('no topic matches'), findsOneWidget);
    },
  );
  testWidgets(
    'journal validation, failure retry preserves text and propagates save',
    (tester) async {
      final session = DemoSession(
        records: DemoRecordsRepository(sample: false),
      );
      await show(tester, const EntryEditor(type: EntryType.journal), session);
      await tapText(tester, 'Save demo entry');
      expect(
        find.text('Write some fictional text before saving.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('entry-note')),
        'Fictional reflection',
      );
      await tapText(tester, 'Demo controls: fail next write');
      await tapText(tester, 'Save demo entry');
      expect(find.text('Fictional reflection'), findsOneWidget);
      expect(session.records.entries, isEmpty);
      await tapText(tester, 'Retry save');
      expect(session.records.entries.single.note, 'Fictional reflection');
    },
  );
  testWidgets('unsaved journal back/cancel preserves words', (tester) async {
    final session = DemoSession(records: DemoRecordsRepository(sample: false));
    await show(tester, const EntryEditor(type: EntryType.journal), session);
    await tester.enterText(
      find.byKey(const ValueKey('entry-note')),
      'Keep these fictional words',
    );
    await tapText(tester, 'Cancel');
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Keep these fictional words'), findsOneWidget);
    expect(session.records.entries, isEmpty);
  });
  testWidgets('cycle opt-in does not remove records when disabled', (
    tester,
  ) async {
    final session = DemoSession(records: DemoRecordsRepository(sample: false));
    await tester.runAsync(
      () => session.records.save(
        HealthEntry(
          id: 'bleeding',
          type: EntryType.bleeding,
          title: 'Bleeding · Light',
          when: DateTime.now(),
          zone: 'Device local',
        ),
      ),
    );
    await show(tester, const CyclePage(), session);
    expect(find.text('Optional, always'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(session.cycleEnabled, isTrue);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(session.records.entries, hasLength(1));
  });
  testWidgets(
    'appointment selection updates preview and clipboard; deleted source disappears',
    (tester) async {
      final session = DemoSession();
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await show(tester, const AppointmentPage(), session);
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      await tapText(tester, 'Copy synthetic summary');
      expect(clipboard, contains('Headache'));
      expect(clipboard, isNot(contains('Fictional sample: noticed')));
      final id = session.records.entries.first.id;
      await tester.runAsync(() => session.records.delete(id));
      await tester.pumpAndSettle();
      await tapText(tester, 'Copy synthetic summary');
      expect(clipboard, contains('No records selected.'));
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    },
  );
  testWidgets(
    'quiz back/edit preserves unknown answer and insufficient state',
    (tester) async {
      final session = DemoSession();
      await show(tester, const QuizPage(), session);
      await tapText(tester, 'Load explicit synthetic example');
      await tapText(tester, 'Are periods regular?');
      await tapText(tester, 'Not sure');
      await tapText(tester, 'Back');
      await tapText(tester, 'Next');
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Not sure'))
            .selected,
        isTrue,
      );
      for (var i = 0; i < 6; i++) {
        await tapText(tester, 'Next');
      }
      await tapText(tester, 'Submit demo answers');
      expect(find.text('Insufficient inputs'), findsOneWidget);
    },
  );
  testWidgets('record changes propagate across Home, Timeline and Insights', (
    tester,
  ) async {
    final session = DemoSession(records: DemoRecordsRepository(sample: false));
    await tester.pumpWidget(
      AuracareApp(session: session, showOnboarding: false),
    );
    await tester.pumpAndSettle();
    final entry = HealthEntry(
      id: 'propagation',
      type: EntryType.symptom,
      title: 'Headache',
      when: DateTime.now(),
      zone: 'Device local',
    );
    await tester.runAsync(() => session.records.save(entry));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 records in this session'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tab-Timeline')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Headache'),
      200,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
    expect(find.text('Headache'), findsOneWidget);
    await tester.runAsync(
      () => session.records.save(
        HealthEntry(
          id: entry.id,
          type: entry.type,
          title: 'Fatigue',
          when: entry.when,
          zone: entry.zone,
          version: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fatigue'), findsOneWidget);
    expect(find.text('Headache'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('tab-Insights')));
    await tester.pumpAndSettle();
    await tapText(
      tester,
      'Fatigue recorded on 1 of 1 days with entries. Days without entries are unknown.',
    );
    await tester.runAsync(() => session.records.delete(entry.id));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tab-Timeline')));
    await tester.pumpAndSettle();
    expect(find.text('No records yet'), findsOneWidget);
  });
  testWidgets(
    'timeline filtered empty distinguishes existing journal from no records',
    (tester) async {
      final session = DemoSession();
      await tester.pumpWidget(
        AuracareApp(session: session, showOnboarding: false),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab-Timeline')));
      await tester.pumpAndSettle();
      await tapText(tester, 'bleeding');
      expect(find.text('No matching records'), findsOneWidget);
      expect(session.records.entries, isNotEmpty);
    },
  );
  testWidgets('edit/delete confirms and removes the selected record', (
    tester,
  ) async {
    final session = DemoSession();
    final entry = session.records.entries.first;
    await show(tester, EntryEditor(type: entry.type, entry: entry), session);
    await tapText(tester, 'Delete entry');
    expect(session.records.entries, hasLength(3));
    await tapText(tester, 'Delete');
    expect(session.records.entries, hasLength(2));
  });
  for (final scenario in [QuizOutcome.failure, QuizOutcome.unavailable]) {
    testWidgets(
      'quiz ${scenario.name} preserves answers and offers honest retry',
      (tester) async {
        await show(tester, const QuizPage(), DemoSession());
        await tapText(tester, 'Load explicit synthetic example');
        await tapText(tester, 'Labeled fixture (no model)');
        await tapText(
          tester,
          scenario == QuizOutcome.failure
              ? 'Fail once, then retry fixture'
              : 'Live service unavailable',
        );
        await tapText(tester, 'Submit demo answers');
        expect(
          find.text(
            scenario == QuizOutcome.failure
                ? 'Demo service failed'
                : 'Live assessment unavailable',
          ),
          findsOneWidget,
        );
        await tapText(tester, 'Retry demo service');
        expect(
          find.text(
            scenario == QuizOutcome.failure
                ? 'A summary, not a diagnosis.'
                : 'Live assessment unavailable',
          ),
          findsOneWidget,
        );
      },
    );
  }
  testWidgets(
    'quiz age scope leaves rest of app available, known diagnosis avoids scoring',
    (tester) async {
      await show(tester, const QuizPage(), DemoSession());
      await tapText(tester, 'Load explicit synthetic example');
      await tapText(tester, 'Edit context');
      await tester.enterText(find.byType(TextFormField).first, '17');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      for (var i = 0; i < 7; i++) {
        await tapText(tester, 'Next');
      }
      await tapText(tester, 'Submit demo answers');
      expect(find.text('Outside experimental age scope'), findsOneWidget);
      await tapText(tester, 'Edit answers');
      await tapText(tester, 'Edit context');
      await tapText(tester, 'Yes');
      await tapText(tester, 'Next');
      expect(find.text('Continue with your history'), findsOneWidget);
      await tapText(tester, 'Return to Auracare');
      expect(find.text('Open test page'), findsOneWidget);
    },
  );
  for (final width in [320.0, 390.0, 430.0]) {
    testWidgets('five destinations at width $width and text scale 200%', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await tester.pumpWidget(const AuracareApp(showOnboarding: false));
      await tester.pumpAndSettle();
      for (final tab in ['Home', 'Timeline', 'Learn', 'Insights', 'Profile']) {
        await tester.tap(find.byKey(ValueKey('tab-$tab')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Active tab: $tab');
      }
    });
  }
}
