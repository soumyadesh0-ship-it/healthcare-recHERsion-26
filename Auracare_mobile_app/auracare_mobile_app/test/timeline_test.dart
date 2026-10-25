import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auracare_mobile_app/app/session.dart';
import 'package:auracare_mobile_app/data/records.dart';
import 'package:auracare_mobile_app/features/timeline/timeline.dart';

void main() {
  for (final sample in [true, false]) {
    testWidgets(
      'Timeline storage and day details with ${sample ? 'demo' : 'saved'} records',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final records = DemoRecordsRepository(sample: sample);
        final today = dayOnly(DateTime.now());
        if (!sample) {
          await tester.runAsync(
            () => records.save(
              HealthEntry(
                id: 'saved-period',
                type: EntryType.bleeding,
                title: 'Bleeding',
                when: today,
                zone: 'UTC',
                periodStart: true,
              ),
            ),
          );
          expect(records.entries.single.periodEnd, isNull);
          expect(records.entries.single.toJson()['periodStart'], isTrue);
          expect(
            records.entries.single.toJson().containsKey('periodEnd'),
            isFalse,
          );
        }
        final session = DemoSession(records: records);
        addTearDown(session.dispose);
        final bucket = PageStorageBucket();
        Future<void> showTimeline() async {
          await tester.pumpWidget(
            SessionScope(
              session: session,
              child: MaterialApp(
                home: Scaffold(
                  body: PageStorage(
                    bucket: bucket,
                    child: const TimelinePage(),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        Finder outerScroll() => find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first;
        await showTimeline();
        await tester.drag(outerScroll(), const Offset(0, -300));
        await tester.pumpAndSettle();
        final offset = tester
            .state<ScrollableState>(outerScroll())
            .position
            .pixels;
        expect(offset, greaterThan(0));
        // Reuse the real numeric offset after destroying the widgets, as on remount.
        await tester.pumpWidget(const SizedBox.shrink());
        await showTimeline();
        expect(
          tester.state<ScrollableState>(outerScroll()).position.pixels,
          offset,
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byType(ExpansionTile));
        await tester.tap(find.text('Mood borders & other records'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Expansible>(find.byType(Expansible))
              .controller
              .isExpanded,
          isTrue,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await showTimeline();
        expect(
          tester
              .widget<Expansible>(find.byType(Expansible))
              .controller
              .isExpanded,
          isTrue,
        );
        final day = find.byKey(ValueKey('calendar-day-${dayLabel(today)}'));
        await tester.ensureVisible(day);
        await tester.pumpAndSettle();
        await tester.tap(day);
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        final cancel = find.text('Cancel');
        await tester.ensureVisible(cancel);
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('No recorded mood'));
        expect(
          find.text(
            sample ? 'No period record' : 'Recorded flow: Unspecified period',
          ),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.text('Clear date filter'),
          150,
          scrollable: outerScroll(),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Clear date filter'));
        await tester.pumpAndSettle();
        await tester.drag(outerScroll(), const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(
          tester.state<ScrollableState>(outerScroll()).position.pixels,
          greaterThan(0),
        );
        expect(find.byType(ErrorWidget), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
