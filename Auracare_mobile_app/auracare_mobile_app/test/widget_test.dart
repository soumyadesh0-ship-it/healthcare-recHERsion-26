import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auracare_mobile_app/app/app.dart';
import 'package:auracare_mobile_app/app/session.dart';
import 'package:auracare_mobile_app/data/records.dart';
import 'package:auracare_mobile_app/data/appointments.dart';
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

Future<void> tapTab(WidgetTester tester, String label) async {
  final target = find.byKey(ValueKey('tab-$label'));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> drawerPage(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey('open-drawer')));
  await tester.pumpAndSettle();
  await tapText(tester, label);
}

Future<void> fillQuiz(WidgetTester tester, {bool unknown = false}) async {
  await tapText(tester, 'Begin questionnaire');
  await tapText(tester, 'No');
  await tapText(tester, 'Continue');
  await tester.enterText(find.byType(TextFormField), '28');
  tester.testTextInput.hide();
  FocusManager.instance.primaryFocus?.unfocus();
  await tapText(tester, 'Continue');
  await tapText(tester, 'Continue'); // optional BMI remains null
  for (var i = 0; i < 6; i++) {
    await tapText(tester, unknown && i == 0 ? 'Not sure' : 'No');
    await tapText(tester, 'Continue');
  }
}

class FailingQuizService implements QuizService {
  int calls = 0;
  @override
  Future<QuizOutcome> assess(QuizAnswers answers) async {
    calls++;
    throw StateError('offline');
  }
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SetupPreference.channel, (_) async => false);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          AndroidAppointmentStore.channel,
          (_) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SetupPreference.channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidAppointmentStore.channel, null);
  });
  testWidgets('onboarding and five destinations preserve tab state', (
    tester,
  ) async {
    await tester.pumpWidget(const AuracareApp());
    await tester.pumpAndSettle();
    await tapText(tester, 'Get started');
    expect(find.text('Your body. Your rhythm. Your space.'), findsOneWidget);
    await tapText(tester, 'Skip');
    await tapText(tester, 'Start empty demo');
    for (final tab in [
      'Home',
      'Wellbeing',
      'Doctor',
      'Timeline',
      'PCOS Quiz',
    ]) {
      await tapTab(tester, tab);
    }
    await tapText(tester, 'Begin questionnaire');
    await tapTab(tester, 'Home');
    await tapTab(tester, 'PCOS Quiz');
    expect(find.text('Question 1 of 9'), findsOneWidget);
    await tapTab(tester, 'Home');
    await drawerPage(tester, 'Learn');
    await tester.enterText(
      find.byKey(const ValueKey('resource-search')),
      'no topic matches',
    );
    await tester.pumpAndSettle();
    expect(find.text('No matching topics'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tab-Home')), findsOneWidget);
  });
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
    expect(
      find.text('Keep tracking your cycle to see patterns over time.'),
      findsOneWidget,
    );
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
    'quiz back/edit preserves unknown answers and insufficient result',
    (tester) async {
      await show(tester, const QuizPage(), DemoSession());
      await fillQuiz(tester, unknown: true);
      await tapText(tester, 'Are your periods regular?');
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Not sure'))
            .selected,
        isTrue,
      );
      await tapText(tester, 'Back');
      await tapText(tester, 'Continue');
      for (var i = 0; i < 6; i++) {
        await tapText(tester, 'Continue');
      }
      await tapText(tester, 'Submit answers');
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
    await drawerPage(tester, 'Insights');
    await tester.pumpAndSettle();
    await tapText(
      tester,
      'Fatigue recorded on 1 of 1 days with entries. Days without entries are unknown.',
    );
    await tester.runAsync(() => session.records.delete(entry.id));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapTab(tester, 'Timeline');
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
  for (final failure in [true, false]) {
    testWidgets(
      'quiz service ${failure ? 'failure' : 'unavailable'} preserves answers and retries',
      (tester) async {
        final service = FailingQuizService();
        await show(
          tester,
          QuizPage(service: failure ? service : null),
          DemoSession(),
        );
        await fillQuiz(tester);
        await tapText(tester, 'Submit answers');
        expect(
          find.text(
            failure
                ? 'Assessment could not be reached'
                : 'Live assessment unavailable',
          ),
          findsOneWidget,
        );
        await tapText(tester, 'Retry assessment');
        expect(
          find.text(
            failure
                ? 'Assessment could not be reached'
                : 'Live assessment unavailable',
          ),
          findsOneWidget,
        );
        if (failure) expect(service.calls, 2);
      },
    );
  }
  testWidgets(
    'quiz known diagnosis skips service; age scope remains enforced',
    (tester) async {
      final service = FailingQuizService();
      await show(tester, QuizPage(service: service), DemoSession());
      await tapText(tester, 'Begin questionnaire');
      await tapText(tester, 'Yes');
      await tapText(tester, 'Continue');
      expect(find.text('Continue with your history'), findsOneWidget);
      expect(service.calls, 0);
      await tapText(tester, 'Edit answers');
      await tapText(tester, 'Edit context');
      await tapText(tester, 'No');
      await tapText(tester, 'Continue');
      await tester.enterText(find.byType(TextFormField), '17');
      tester.testTextInput.hide();
      await tapText(tester, 'Continue');
      expect(find.text('Outside experimental age scope'), findsOneWidget);
      expect(service.calls, 0);
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
      for (final tab in [
        'Home',
        'Timeline',
        'Wellbeing',
        'Doctor',
        'PCOS Quiz',
      ]) {
        await tapTab(tester, tab);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Active tab: $tab');
      }
    });
  }
}
