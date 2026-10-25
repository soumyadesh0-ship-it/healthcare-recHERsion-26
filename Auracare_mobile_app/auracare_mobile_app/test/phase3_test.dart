import 'widget_test.dart' as helper;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auracare_mobile_app/app/app.dart';
import 'package:auracare_mobile_app/app/session.dart';
import 'package:auracare_mobile_app/app/setup_preference.dart';
import 'package:auracare_mobile_app/app/theme.dart';
import 'package:auracare_mobile_app/core/calendar.dart';
import 'package:auracare_mobile_app/data/appointments.dart';
import 'package:auracare_mobile_app/data/articles.dart';
import 'package:auracare_mobile_app/data/cycles.dart';
import 'package:auracare_mobile_app/data/records.dart';
import 'package:auracare_mobile_app/data/services.dart';
import 'package:auracare_mobile_app/features/appointments/doctor.dart';
import 'package:auracare_mobile_app/features/cycle/cycle.dart';
import 'package:auracare_mobile_app/features/learn/learn.dart';

class TestAppointmentStore implements AppointmentStore {
  String? json;
  bool fail = false;
  @override
  Future<String?> read() async => json;
  @override
  Future<void> write(String value) async {
    if (fail) throw StateError('test failure');
    json = value;
  }
}

List<HealthEntry> cycleRecords({List<int> offsets = const [0, 30, 60, 90]}) => [
  for (var i = 0; i < offsets.length; i++) ...[
    HealthEntry(
      id: 'start-$i',
      type: EntryType.bleeding,
      title: 'Bleeding · Heavy',
      when: addDays(DateTime(2026, 1, 1), offsets[i]),
      zone: 'Device local',
      periodStart: true,
    ),
    HealthEntry(
      id: 'end-$i',
      type: EntryType.bleeding,
      title: 'Bleeding · Light',
      when: addDays(DateTime(2026, 1, 1), offsets[i] + 4),
      zone: 'Device local',
      periodEnd: true,
    ),
  ],
];
Future<void> reveal(
  WidgetTester tester,
  Finder target, {
  double delta = 220,
}) async {
  final scroll = find
      .byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      )
      .hitTestable()
      .last;
  await tester.scrollUntilVisible(target, delta, scrollable: scroll);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'cycle summaries use explicit starts and ends and preserve missing days',
    () {
      final records = cycleRecords();
      final history = CycleHistory(records);
      expect(history.lengths, [30, 30, 30]);
      expect(history.averageLength, 30);
      expect(history.averageDuration, 5);
      expect(history.shortest, 30);
      expect(history.longest, 30);
      expect(history.periods.first.records, hasLength(2));
      final legacy = HealthEntry(
        id: 'legacy',
        type: EntryType.bleeding,
        title: 'Bleeding · Light',
        when: DateTime(2026, 5, 1),
        zone: 'UTC',
      );
      expect(CycleHistory([legacy]).periods, isEmpty);
      expect(legacy.periodStart, isNull);
    },
  );
  test('basic phases are optional, history-based, bounded and withheld for irregular or insufficient history', () {
    final history = CycleHistory(cycleRecords());
    final estimates = CycleEstimates(history, today: DateTime(2026, 4, 10));
    final start = history.periods.last.start;
    expect(estimates.available, isTrue);
    expect(estimates.nextPeriod, addDays(start, 30));
    expect(estimates.on(addDays(start, 5))!.phase, CyclePhase.follicular);
    expect(estimates.on(addDays(start, 9))!.phase, CyclePhase.fertile);
    expect(estimates.on(addDays(start, 17))!.phase, CyclePhase.ovulation);
    expect(estimates.on(addDays(start, 23))!.phase, CyclePhase.luteal);
    expect(estimates.on(addDays(start, 27))!.step, 0);
    expect(estimates.on(addDays(start, 29))!.step, 2);
    expect(estimates.on(addDays(start, 30))!.phase, CyclePhase.predictedPeriod);
    expect(estimates.on(addDays(start, 35)), isNull);
    expect(CycleEstimates(history, unsuitable: true).available, isFalse);
    expect(
      CycleEstimates(CycleHistory(cycleRecords(offsets: [0, 30]))).available,
      isFalse,
    );
    expect(
      CycleEstimates(CycleHistory(cycleRecords(offsets: [0, 23, 58, 90])))
          .available,
      isFalse,
    );
    expect(CycleEstimates(history, today: DateTime(2025)).available, isFalse);
    final varied = CycleEstimates(
      CycleHistory(cycleRecords(offsets: [0, 32, 64, 96])),
      today: DateTime(2026, 8),
    );
    expect(varied.nextPeriod, addDays(varied.history.periods.last.start, 32));
    expect(
      CycleEstimates.warning,
      contains('Do not use these estimates as contraception'),
    );
  });
  test('appointments create edit delete survive repository recreation and failed writes are atomic', () async {
    final store = TestAppointmentStore();
    final repo = AppointmentsRepository(store: store);
    await repo.load();
    final date = DateTime(2027, 2, 3, 10, 30);
    await repo.save(
      DoctorAppointment(
        id: 'one',
        doctor: 'Test clinician',
        when: date,
        notes: 'Questions',
      ),
    );
    final reopened = AppointmentsRepository(store: store);
    await reopened.load();
    expect(reopened.entries.single.doctor, 'Test clinician');
    expect(reopened.entries.single.when, date);
    store.fail = true;
    await expectLater(reopened.delete('one'), throwsStateError);
    expect(reopened.entries, hasLength(1));
    store.fail = false;
    await reopened.save(
      DoctorAppointment(
        id: 'one',
        doctor: 'Updated clinician',
        when: date,
        location: 'Test clinic',
      ),
    );
    final edited = AppointmentsRepository(store: store);
    await edited.load();
    expect(edited.entries.single.location, 'Test clinic');
    await edited.delete('one');
    final empty = AppointmentsRepository(store: store);
    await empty.load();
    expect(empty.entries, isEmpty);
    repo.dispose();
    reopened.dispose();
    edited.dispose();
    empty.dispose();
  });
  test('unreadable persisted appointments block overwrites instead of silently replacing data', () async {
    final store = TestAppointmentStore()..json = 'broken json';
    final repo = AppointmentsRepository(store: store);
    await repo.load();
    expect(repo.loaded, isFalse);
    expect(repo.error, isNotNull);
    await expectLater(
      repo.save(DoctorAppointment(id: 'x', doctor: 'X', when: DateTime(2027))),
      throwsStateError,
    );
    expect(store.json, 'broken json');
    repo.dispose();
  });
  test(
    'all existing topics have complete referenced drafts with unique topics',
    () {
      final topics = PreviewResourcesRepository().resources;
      expect(ArticleCatalog.articles.length, topics.length);
      for (final topic in topics) {
        final article = topic.article!;
        expect(article.sections, hasLength(5));
        expect(article.introduction, isNotEmpty);
        expect(article.question, isNotEmpty);
        expect(article.answer, isNotEmpty);
        expect(article.sources, isNotEmpty);
        for (final source in article.sources) {
          expect(Uri.parse(source.url).scheme, 'https');
          expect([
            'www.nhs.uk',
            'www.cdc.gov',
            'www.who.int',
            'health.nih.gov',
          ], contains(Uri.parse(source.url).host));
        }
      }
    },
  );
  testWidgets(
    'recorded flow and mood take priority while estimates retain a separate marker',
    (tester) async {
      final records = cycleRecords();
      final history = CycleHistory(records);
      final day = addDays(history.periods.last.start, 17);
      records.addAll([
        HealthEntry(
          id: 'flow',
          type: EntryType.bleeding,
          title: 'Bleeding · Heavy',
          when: day,
          zone: 'Device local',
        ),
        HealthEntry(
          id: 'mood',
          type: EntryType.wellness,
          title: 'Mood',
          mood: RecordedMood.happy,
          when: day,
          zone: 'Device local',
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          theme: auracareTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecordCalendar(
                entries: records,
                selected: day,
                onSelect: (_) {},
                estimates: CycleEstimates(history, today: DateTime(2026, 5)),
              ),
            ),
          ),
        ),
      );
      final cell = tester.widget<Material>(
        find.byKey(ValueKey('calendar-day-${dayLabel(day)}')),
      );
      expect(cell.color, Palette.heavyFlow);
      expect(
        (cell.shape! as RoundedRectangleBorder).side.color,
        Palette.happyMood,
      );
      expect(find.byKey(ValueKey('estimate-${dayLabel(day)}')), findsOneWidget);
      await reveal(
        tester,
        find.text('Calendar estimate: Estimated ovulation midpoint'),
      );
      expect(find.text('Recorded mood: Happy'), findsOneWidget);
    },
  );
  testWidgets('Cycle Summary contains history but no second calendar', (
    tester,
  ) async {
    final session = DemoSession(records: DemoRecordsRepository(sample: false));
    await tester.pumpWidget(
      SessionScope(
        session: session,
        child: MaterialApp(theme: auracareTheme(), home: const CyclePage()),
      ),
    );
    expect(find.byType(RecordCalendar), findsNothing);
    expect(
      find.text('Keep tracking your cycle to see patterns over time.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });
  testWidgets(
    'five tabs preserve Doctor preparation; Profile is available in drawer',
    (tester) async {
      final repo = AppointmentsRepository(store: TestAppointmentStore());
      final session = DemoSession(appointments: repo);
      await tester.pumpWidget(
        AuracareApp(session: session, showOnboarding: false),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Open profile'), findsNothing);
      for (final tab in [
        'Home',
        'Timeline',
        'Wellbeing',
        'Doctor',
        'PCOS Quiz',
      ]) {
        expect(find.byKey(ValueKey('tab-$tab')), findsOneWidget);
        await helper.tapTab(tester, tab);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byKey(const ValueKey('tab-Doctor')));
      await tester.pumpAndSettle();
      expect(find.text('No upcoming appointments'), findsOneWidget);
      await reveal(tester, find.text('Appointment preparation'));
      expect(find.text('Appointment preparation'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    },
  );
  testWidgets('article navigation and content search retain Learn state', (
    tester,
  ) async {
    final session = DemoSession();
    await tester.pumpWidget(
      AuracareApp(session: session, showOnboarding: false),
    );
    await tester.pumpAndSettle();
    await helper.drawerPage(tester, 'Learn');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('resource-search')),
      'lochia',
    );
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Postpartum'));
    await tester.tap(find.text('Postpartum'));
    await tester.pumpAndSettle();
    expect(find.byType(ResourcePage), findsOneWidget);
    expect(find.textContaining('Postpartum means'), findsOneWidget);
    expect(find.text('Preview · article not available'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('lochia'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });
  testWidgets(
    'debug onboarding preview preserves existing records and completion flag',
    (tester) async {
      bool completed = true;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SetupPreference.channel,
        (call) async => completed,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SetupPreference.channel,
          null,
        ),
      );
      final session = DemoSession();
      final ids = session.records.entries.map((e) => e.id).toList();
      await tester.pumpWidget(
        AuracareApp(session: session, showOnboarding: false),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byKey(const ValueKey('tab-Home')));
      Navigator.of(context).pushNamed('/debug/onboarding');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Start empty demo'));
      await tester.tap(find.text('Start empty demo'));
      await tester.pumpAndSettle();
      expect(session.records.entries.map((e) => e.id), ids);
      expect(completed, isTrue);
      expect(find.byKey(const ValueKey('tab-Home')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    },
  );
  testWidgets(
    'appointment editor saves through durable repository and confirms deletion',
    (tester) async {
      final store = TestAppointmentStore();
      final repo = AppointmentsRepository(store: store);
      await repo.load();
      final session = DemoSession(appointments: repo);
      await tester.pumpWidget(
        AuracareApp(session: session, showOnboarding: false),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab-Doctor')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add appointment'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('appointment-doctor')),
        'Test clinician',
      );
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Save appointment'));
      await tester.tap(find.text('Save appointment'));
      await tester.pumpAndSettle();
      expect(find.byType(DoctorAppointmentEditor), findsNothing);
      expect(repo.entries.single.doctor, 'Test clinician');
      await reveal(tester, find.text('Test clinician'));
      await tester.tap(find.text('Test clinician'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Delete appointment'));
      await tester.tap(find.text('Delete appointment'));
      await tester.pumpAndSettle();
      expect(repo.entries, hasLength(1));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(repo.entries, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
    },
  );
}
