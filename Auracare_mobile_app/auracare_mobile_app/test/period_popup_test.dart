import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auracare_mobile_app/app/session.dart';
import 'package:auracare_mobile_app/data/records.dart';
import 'package:auracare_mobile_app/core/calendar.dart';
import 'package:auracare_mobile_app/features/logging/period_picker.dart';
import 'package:auracare_mobile_app/features/wellbeing/ball_face.dart';

import 'widget_test.dart' as helper;

void main() {
  test('every level has a unique solid color; doubling follows the requested colors', () {
    expect(ballColors.toSet().length, 10);
    expect([1, 2, 4, 8].map(ballName), [
      'Green',
      'Turquoise',
      'Pink',
      'Purple',
    ]);
    expect(ballColors.every((c) => c.a == 1), isTrue);
  });

  testWidgets(
    'flow popup validates, retries, edits notes and opens journal for the date',
    (tester) async {
      final session = DemoSession(
        records: DemoRecordsRepository(sample: false),
      );
      addTearDown(session.dispose);
      final day = dayOnly(DateTime.now());
      final key = ValueKey('calendar-day-${dayLabel(day)}');
      await helper.show(tester, PeriodPickerPage(initialDay: day), session);
      Future<void> open() async {
        await tester.ensureVisible(find.byKey(key));
        await tester.tap(find.byKey(key));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
      }

      await open();
      await helper.tapText(tester, 'Save demo entry');
      expect(find.text('Choose the observed flow.'), findsOneWidget);
      await helper.tapText(tester, 'Spotting');
      session.records.failNextWrite = true;
      await helper.tapText(tester, 'Save demo entry');
      expect(find.text('Retry save'), findsOneWidget);
      expect(session.records.entries, isEmpty);
      await helper.tapText(tester, 'Retry save');
      expect(find.byType(Dialog), findsNothing);
      expect(
        session.records.entries.single.flowIntensity,
        FlowIntensity.spotting,
      );
      expect(session.records.entries.single.periodStart, isNot(true));
      expect(session.records.entries.single.periodEnd, isNot(true));
      final cell = find.byKey(key);
      expect(
        find
            .descendant(
              of: cell,
              matching: find.byWidgetPredicate(
                (w) =>
                    w is Ink &&
                    w.decoration is BoxDecoration &&
                    (w.decoration as BoxDecoration).gradient != null,
              ),
            )
            .evaluate()
            .length,
        1,
      );
      await open();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Spotting'))
            .selected,
        isTrue,
      );
      await helper.tapText(tester, 'Add Notes');
      await tester.ensureVisible(find.byKey(const ValueKey('entry-note')));
      await tester.enterText(
        find.byKey(const ValueKey('entry-note')),
        'A note for this date',
      );
      await helper.tapText(tester, 'Save demo entry');
      expect(session.records.entries, hasLength(1));
      expect(session.records.entries.single.note, 'A note for this date');
      await open();
      await helper.tapText(tester, 'Heavy');
      await helper.tapText(tester, 'Period start');
      await helper.tapText(tester, 'Save demo entry');
      expect(session.records.entries.single.periodStart, isTrue);
      await open();
      await helper.tapText(tester, 'Medium');
      await helper.tapText(tester, 'Neither');
      await helper.tapText(tester, 'Save demo entry');
      expect(session.records.entries, hasLength(1));
      expect(
        session.records.entries.single.flowIntensity,
        FlowIntensity.moderate,
      );
      expect(session.records.entries.single.periodStart, isFalse);
      expect(session.records.entries.single.periodEnd, isFalse);
      await open();
      await helper.tapText(tester, 'Continue in Journal');
      expect(find.text('Room for your words.'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('entry-note')));
      await tester.enterText(
        find.byKey(const ValueKey('entry-note')),
        'Journal for the selected day',
      );
      await helper.tapText(tester, 'Save demo entry');
      final journal = session.records.entries.singleWhere(
        (e) => e.type == EntryType.journal,
      );
      expect(dayLabel(journal.when), dayLabel(day));
      expect(journal.note, 'Journal for the selected day');
      expect(
        flowColor(FlowIntensity.spotting),
        isNot(flowColor(FlowIntensity.heavy)),
      );
      await open();
      await helper.tapText(tester, 'Delete entry');
      await helper.tapText(tester, 'Delete');
      expect(
        session.records.entries.where((e) => e.type == EntryType.bleeding),
        isEmpty,
      );
      expect(session.records.entries.single.type, EntryType.journal);
    },
  );
  testWidgets('flow popup scrolls at 320 pixels and doubled text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final session = DemoSession(records: DemoRecordsRepository(sample: false));
    addTearDown(session.dispose);
    final day = dayOnly(DateTime.now());
    await helper.show(tester, PeriodPickerPage(initialDay: day), session);
    final cell = find.byKey(ValueKey('calendar-day-${dayLabel(day)}'));
    await tester.ensureVisible(cell);
    await tester.pumpAndSettle();
    await tester.tap(cell);
    await tester.pumpAndSettle();
    await helper.tapText(tester, 'Light');
    await helper.tapText(tester, 'Save demo entry');
    expect(session.records.entries.single.flowIntensity, FlowIntensity.light);
    expect(tester.takeException(), isNull);
  });
}
