import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auracare_mobile_app/app/theme.dart';
import 'package:auracare_mobile_app/features/sisterhood/sisterhood.dart';

void main() {
  testWidgets(
    'demo reviews and constructive feedback filter without publishing',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          theme: auracareTheme(),
          home: const Scaffold(body: SisterhoodPage()),
        ),
      );
      expect(
        find.textContaining('All names, posts, reviews and replies'),
        findsOneWidget,
      );
      final reviewFilter = find.widgetWithText(ChoiceChip, 'Reviews');
      await tester.scrollUntilVisible(reviewFilter, 200);
    await Scrollable.ensureVisible(tester.element(reviewFilter), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(reviewFilter);
      await tester.pumpAndSettle();
      final first = find.byKey(const ValueKey('community-post-1'));
      await tester.ensureVisible(first);
      await tester.pumpAndSettle();
      expect(find.text('A calmer place to check in'), findsOneWidget);
      expect(find.byKey(const ValueKey('community-post-0')), findsNothing);
      final helpful = find.descendant(
        of: first,
        matching: find.text('Helpful'),
      );
      await tester.ensureVisible(helpful);
      await tester.pumpAndSettle();
      await tester.tap(helpful);
      await tester.pumpAndSettle();
      expect(find.text('Marked helpful'), findsOneWidget);
      final reply = find.descendant(
        of: first,
        matching: find.text('View sample reply'),
      );
      await tester.ensureVisible(reply);
      await tester.pumpAndSettle();
      await tester.tap(reply);
      await tester.pumpAndSettle();
      expect(find.textContaining('Fictional reply'), findsOneWidget);
      final feedback = find.widgetWithText(ChoiceChip, 'Feedback');
      await tester.scrollUntilVisible(feedback, -200);
    await Scrollable.ensureVisible(tester.element(feedback), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(feedback);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('community-post-1')), findsNothing);
      expect(
        find.text('Make saved and temporary entries clearer'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
