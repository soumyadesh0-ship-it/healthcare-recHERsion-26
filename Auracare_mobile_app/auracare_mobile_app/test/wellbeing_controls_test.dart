import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auracare_mobile_app/app/theme.dart';
import 'package:auracare_mobile_app/app/navigation.dart';
import 'package:auracare_mobile_app/features/wellbeing/breathing.dart';
import 'package:auracare_mobile_app/features/wellbeing/merge_game.dart';
import 'package:auracare_mobile_app/features/logging/editor.dart';

void main() {
  test(
    'breathing clock uses elapsed time and supports pause reset and completion',
    () {
      final clock = BreathingClock();
      clock.start(Duration.zero);
      clock.update(const Duration(seconds: 17));
      expect(clock.elapsed.inSeconds, 17);
      clock.pause(const Duration(seconds: 20));
      clock.update(const Duration(seconds: 80));
      expect(clock.elapsed.inSeconds, 20);
      clock.start(const Duration(seconds: 80));
      clock.update(const Duration(seconds: 125));
      expect(clock.complete, isTrue);
      expect(clock.running, isFalse);
      expect(clock.elapsed.inSeconds, 60);
      clock.reset();
      expect(clock.elapsed, Duration.zero);
    },
  );

  testWidgets(
    'slider release and board gestures each spawn once; pause blocks input',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(theme: auracareTheme(), home: const MergeGamePage()),
      );
      await tester.pump();
      final sliderFinder = find.byType(Slider);
      await tester.ensureVisible(sliderFinder);
      await tester.pump();
      var slider = tester.widget<Slider>(sliderFinder);
      slider.onChanged!(25); // Accessibility/programmatic adjustment: aim only.
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp('Game container. 0 balls')),
        findsOneWidget,
      );
      await tester.drag(sliderFinder, const Offset(35, 0));
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp('Game container. 1 balls')),
        findsOneWidget,
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final board = find.byKey(const ValueKey('merge-board'));
      await tester.ensureVisible(board);
      await tester.pump();
      await tester.tapAt(tester.getTopLeft(board) + const Offset(20, 20));
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp('Game container. 2 balls')),
        findsOneWidget,
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.dragFrom(
        tester.getTopLeft(board) + const Offset(50, 30),
        const Offset(70, 0),
      );
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp('Game container. 3 balls')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Pause game'));
      await tester.pump();
      await tester.tapAt(tester.getTopLeft(board) + const Offset(20, 20));
      await tester.pump();
      expect(
        find.bySemanticsLabel(RegExp('Game container. 3 balls')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'breathing phases, pause resume reset completion and covering route',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [auraRouteObserver],
          theme: auracareTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(child: BreathingSection()),
          ),
        ),
      );
      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Breathe out'), findsOneWidget);
      await tester.tap(find.text('Pause breathing'));
      await tester.pump(const Duration(seconds: 20));
      expect(find.text('0:56'), findsOneWidget);
      await tester.tap(find.text('Resume breathing'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Breathe in'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('Resume breathing'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.tap(find.text('Reset'));
      await tester.pump();
      expect(find.text('1:00'), findsOneWidget);
      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final context = tester.element(find.byType(BreathingSection));
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Cover')),
        ),
      );
      await tester.pumpAndSettle();
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      expect(find.text('Resume breathing'), findsOneWidget);
      await tester.tap(find.text('Resume breathing'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 60));
      expect(
        find.text('Your pause is complete. Take your time.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'narrow large text moods retain three columns and replace feedback',
    (tester) async {
      tester.view.physicalSize = const Size(320, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: auracareTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: const MoodCheckInPage(),
        ),
      );
      await tester.pumpAndSettle();
      final positions = [
        for (var i = 0; i < 6; i++)
          tester.getTopLeft(find.byKey(ValueKey('mood-$i'))),
      ];
      expect(positions[0].dy, positions[2].dy);
      expect(positions[3].dy, positions[5].dy);
      expect(positions[0].dx, positions[3].dx);
      expect(find.text('Happy'), findsOneWidget);
      for (final i in [0, 4, 1]) {
        final tile = find.byKey(ValueKey('mood-$i'));
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        await tester.tap(tile);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('mood-feedback')), findsOneWidget);
        expect(find.byType(EntryEditor), findsNothing);
      }
      expect(find.text('Try breathing'), findsNothing);
      await tester.scrollUntilVisible(find.text('Start'), 180);
      await tester.ensureVisible(find.text('Start'));
      await tester.pumpAndSettle();
      final circle = find
          .descendant(
            of: find.byType(BreathingSection),
            matching: find.byType(Transform),
          )
          .first;
      final before = tester.widget<Transform>(circle).transform.entry(0, 0);
      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Breathe out'), findsOneWidget);
      expect(tester.widget<Transform>(circle).transform.entry(0, 0), before);
      await tester.ensureVisible(find.text('Reset'));
      await tester.pump();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
