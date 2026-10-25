import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auracare_mobile_app/app/app.dart';
import 'package:auracare_mobile_app/app/session.dart';
import 'package:auracare_mobile_app/app/theme.dart';
import 'package:auracare_mobile_app/core/calendar.dart';
import 'package:auracare_mobile_app/core/topic_illustration.dart';
import 'package:auracare_mobile_app/data/records.dart';
import 'package:auracare_mobile_app/data/services.dart';
import 'package:auracare_mobile_app/features/logging/editor.dart';

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
    'legacy flow and explicit mood notes remain readable without guessing',
    () {
      HealthEntry legacy(String title, String note, EntryType type) =>
          HealthEntry(
            id: title,
            type: type,
            title: title,
            note: note,
            when: DateTime(2026, 10, 25),
            zone: 'Device local',
          );
      for (final flow in FlowIntensity.values) {
        final label = flow.name[0].toUpperCase() + flow.name.substring(1);
        expect(
          legacy('Bleeding · $label', '', EntryType.bleeding).flowIntensity,
          flow,
        );
      }
      expect(
        legacy('Bleeding', '', EntryType.bleeding).flowIntensity,
        FlowIntensity.unspecified,
      );
      expect(
        legacy(
          'Mood',
          'Feeling: Calm. A quiet morning.',
          EntryType.wellness,
        ).recordedMood,
        RecordedMood.calm,
      );
      expect(
        legacy(
          'Mood',
          'I felt happy yesterday.',
          EntryType.wellness,
        ).recordedMood,
        isNull,
      );
      expect(
        legacy('Energy', 'Feeling: Calm.', EntryType.wellness).recordedMood,
        isNull,
      );
      expect(
        legacy('Journal', 'Feeling: Calm.', EntryType.journal).recordedMood,
        isNull,
      );
    },
  );

  test('latest save wins even when the observation time is earlier, and failures preserve history', () async {
    final repo = DemoRecordsRepository(sample: false);
    addTearDown(repo.dispose);
    HealthEntry mood(
      String id,
      int hour,
      RecordedMood value, {
      int version = 1,
    }) => HealthEntry(
      id: id,
      type: EntryType.wellness,
      title: 'Mood',
      when: DateTime(2026, 10, 25, hour),
      zone: 'Device local',
      mood: value,
      version: version,
    );
    await repo.save(mood('late-observation', 20, RecordedMood.sad));
    await repo.save(mood('latest-save', 8, RecordedMood.happy));
    expect(
      RecordedDay(repo.entries, DateTime(2026, 10, 25)).moodEntry!.recordedMood,
      RecordedMood.happy,
    );
    expect(repo.entries, hasLength(2));
    repo.failNextWrite = true;
    await expectLater(
      repo.save(mood('latest-save', 8, RecordedMood.tired, version: 2)),
      throwsStateError,
    );
    expect(
      RecordedDay(repo.entries, DateTime(2026, 10, 25)).moodEntry!.recordedMood,
      RecordedMood.happy,
    );
    await repo.save(
      mood('late-observation', 20, RecordedMood.calm, version: 2),
    );
    final latest = RecordedDay(repo.entries, DateTime(2026, 10, 25)).moodEntry!;
    expect(latest.recordedMood, RecordedMood.calm);
    expect(latest.toJson()['mood'], 'calm');
    expect(latest.savedAt, isNotNull);
    expect(repo.entries, hasLength(2));
  });

  testWidgets(
    'actual period records use three fills and mood borders coexist with selection',
    (tester) async {
      final repo = DemoRecordsRepository(sample: false);
      addTearDown(repo.dispose);
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => repo.save(
            HealthEntry(
              id: 'flow-$i',
              type: EntryType.bleeding,
              title: [
                'Bleeding · Light',
                'Bleeding · Moderate',
                'Bleeding · Heavy',
              ][i],
              when: DateTime(2026, 10, 12 + i),
              zone: 'Device local',
            ),
          ),
        );
      }
      await tester.runAsync(
        () => repo.save(
          HealthEntry(
            id: 'mood',
            type: EntryType.wellness,
            title: 'Mood',
            mood: RecordedMood.happy,
            when: DateTime(2026, 10, 14, 8),
            zone: 'Device local',
          ),
        ),
      );
      await tester.runAsync(
        () => repo.save(
          HealthEntry(
            id: 'old-period',
            type: EntryType.bleeding,
            title: 'Bleeding',
            when: DateTime(2026, 10, 15),
            zone: 'Device local',
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: auracareTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecordCalendar(
                entries: repo.entries,
                selected: DateTime(2026, 10, 14),
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      );
      Material cell(int day) => tester.widget<Material>(
        find.byKey(ValueKey('calendar-day-2026-10-$day')),
      );
      expect(cell(12).color, Palette.lightFlow);
      expect(cell(13).color, Palette.moderateFlow);
      expect(cell(14).color, Palette.heavyFlow);
      expect(
        (cell(14).shape! as RoundedRectangleBorder).side.color,
        Palette.happyMood,
      );
      expect(cell(15).color, Palette.lavender);
      await reveal(tester, find.text('Recorded mood: Happy'));
      expect(find.text('Recorded flow: Heavy flow'), findsOneWidget);
      expect(find.text('Recorded mood: Happy'), findsOneWidget);
    },
  );

  testWidgets(
    'Home omits cycle card and Timeline retains cycle and period entry controls',
    (tester) async {
      final session = DemoSession(
        records: DemoRecordsRepository(sample: false),
      );
      addTearDown(session.dispose);
      await tester.pumpWidget(
        AuracareApp(session: session, showOnboarding: false),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Appointment preparation'));
      expect(find.text('Cycle Summary'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('tab-Timeline')));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Log period'));
      expect(find.text('Cycle Summary'), findsOneWidget);
      await tester.tap(find.text('Log period'));
      await tester.pumpAndSettle();
      expect(find.text('New bleeding'), findsOneWidget);
    },
  );

  testWidgets(
    'mood failure stays in editor; retry removes intermediate routes and selects Home',
    (tester) async {
      final session = DemoSession(
        records: DemoRecordsRepository(sample: false),
      );
      addTearDown(session.dispose);
      await tester.pumpWidget(
        AuracareApp(session: session, showOnboarding: false),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Log entry'));
      await tester.tap(find.text('Log entry'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Mood'));
      await tester.tap(find.text('Mood'));
      await tester.pumpAndSettle();
      final metric = find.byType(DropdownButtonFormField<String>);
      await reveal(tester, metric);
      await tester.tap(metric);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mood').last);
      await tester.pumpAndSettle();
      final feeling = find.byType(DropdownButtonFormField<RecordedMood>);
      await reveal(tester, feeling);
      await tester.tap(feeling);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Happy').last);
      await tester.pumpAndSettle();
      session.records.failNextWrite = true;
      await reveal(tester, find.byKey(const ValueKey('save-entry')));
      await tester.tap(find.byKey(const ValueKey('save-entry')));
      await tester.pumpAndSettle();
      expect(find.byType(EntryEditor), findsOneWidget);
      expect(session.records.entries, isEmpty);
      await reveal(tester, find.text('Retry save'));
      await tester.tap(find.text('Retry save'));
      await tester.pumpAndSettle();
      expect(find.byType(EntryEditor), findsNothing);
      expect(find.byType(MoodCheckInPage), findsNothing);
      expect(session.records.entries.single.recordedMood, RecordedMood.happy);
      final homeContext = tester.element(
        find.byKey(const ValueKey('tab-Home')),
      );
      expect(Navigator.of(homeContext).canPop(), isFalse);
      expect(find.byKey(const ValueKey('tab-Home')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tab-Timeline')));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Mood'));
      await tester.tap(find.text('Mood').last);
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('save-entry')));
      await tester.tap(find.byKey(const ValueKey('save-entry')));
      await tester.pumpAndSettle();
      expect(find.byType(EntryEditor), findsNothing);
      await reveal(tester, find.text('A little space\nfor you.'), delta: -220);
      expect(find.text('A little space\nfor you.'), findsOneWidget);
      expect(
        Navigator.of(tester.element(find.byKey(const ValueKey('tab-Home'))))
            .canPop(),
        isFalse,
      );
    },
  );

  test('existing Learn categories have distinct local illustrations', () {
    final topics = PreviewResourcesRepository().resources;
    final motifs = topics
        .map((r) => TopicIllustration(topic: r.topic).motif)
        .toSet();
    expect(motifs.length, topics.length);
  });

  test(
    'primary button and body text retain readable contrast on pastel surfaces',
    () {
      double contrast(Color a, Color b) {
        final x = a.computeLuminance(), y = b.computeLuminance();
        return ((x > y ? x : y) + .05) / ((x < y ? x : y) + .05);
      }

      expect(
        contrast(Palette.ink, Palette.lavender),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(Palette.action, Palette.white),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(Palette.flowInk, Palette.heavyFlow),
        greaterThanOrEqualTo(4.5),
      );
    },
  );
}
