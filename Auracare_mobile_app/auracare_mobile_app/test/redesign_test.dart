import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auracare_mobile_app/app/app.dart';
import 'package:auracare_mobile_app/app/session.dart';
import 'package:auracare_mobile_app/app/setup_preference.dart';
import 'package:auracare_mobile_app/app/theme.dart';
import 'package:auracare_mobile_app/core/calendar.dart';
import 'package:auracare_mobile_app/data/records.dart';
import 'package:auracare_mobile_app/features/logging/editor.dart';

void main() {
  testWidgets(
    'Android setup flag skips onboarding on a fresh app instance without loading samples',
    (tester) async {
      bool completed = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SetupPreference.channel,
        (call) async {
          if (call.method == 'completed') return completed;
          if (call.method == 'complete') {
            completed = true;
            return true;
          }
          throw PlatformException(code: 'unsupported');
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SetupPreference.channel,
          null,
        ),
      );
      await tester.pumpWidget(const AuracareApp());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Get started'));
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Start empty demo'),
        240,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Start empty demo'));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const AuracareApp());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tab-Home')), findsOneWidget);
      expect(find.text('Get started'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('No records yet'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('No records yet'), findsOneWidget);
    },
  );

  testWidgets(
    'chosen mood reaches existing editor and saves through the record repository',
    (tester) async {
      final session = DemoSession(
        records: DemoRecordsRepository(sample: false),
      );
      addTearDown(session.dispose);
      await tester.pumpWidget(
        SessionScope(
          session: session,
          child: MaterialApp(
            theme: auracareTheme(),
            home: const MoodCheckInPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Continue'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
            .onPressed,
        isNull,
      );
      await tester.scrollUntilVisible(
        find.text('Calm'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Calm'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Continue'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Feeling: Calm. '), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('save-entry')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byKey(const ValueKey('save-entry')));
      await tester.pumpAndSettle();
      expect(session.records.entries.single.type, EntryType.wellness);
      expect(session.records.entries.single.title, 'Mood');
      expect(session.records.entries.single.note, 'Feeling: Calm.');
    },
  );

  testWidgets(
    'calendar marks recorded days, selects dates, and navigates months',
    (tester) async {
      DateTime? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: auracareTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecordCalendar(
                selected: DateTime(2026, 10, 1),
                entries: [
                  HealthEntry(
                    id: 'period',
                    type: EntryType.bleeding,
                    title: 'Bleeding',
                    when: DateTime(2026, 10, 12),
                    zone: 'Device local',
                  ),
                ],
                onSelect: (day) => selected = day,
              ),
            ),
          ),
        ),
      );
      expect(find.text('October 2026'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(RegExp('2026-10-12, bleeding')));
      expect(selected, DateTime(2026, 10, 12));
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      expect(find.text('November 2026'), findsOneWidget);
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);
    },
  );
}
