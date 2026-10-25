import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auracare_mobile_app/app/session.dart';
import 'package:auracare_mobile_app/app/theme.dart';
import 'package:auracare_mobile_app/data/services.dart';
import 'package:auracare_mobile_app/features/pcos_quiz/flashcard.dart';
import 'package:auracare_mobile_app/features/pcos_quiz/quiz.dart';

Future<void> tap(WidgetTester tester, String text) async {
  final scroll = find.byType(Scrollable).first;
  for (var i = 0; i < 40 && find.text(text).evaluate().isEmpty; i++) {
    await tester.drag(scroll, const Offset(0, -250));
    await tester.pumpAndSettle();
  }
  if (find.text(text).evaluate().isEmpty) {
    for (var i = 0; i < 40 && find.text(text).evaluate().isEmpty; i++) {
      await tester.drag(scroll, const Offset(0, 250));
      await tester.pumpAndSettle();
    }
  }
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    testWidgets('flashcard journey at $width dp and 200% text', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 950);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final session = DemoSession();
      addTearDown(session.dispose);
      await tester.pumpWidget(
        SessionScope(
          session: session,
          child: MaterialApp(theme: auracareTheme(), home: const QuizPage()),
        ),
      );
      await tap(tester, 'Begin demo questionnaire');
      await tester.enterText(find.byType(TextFormField).first, '28');
      // Keyboard/view insets must not prevent reaching the context navigation.
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      await tap(tester, 'Next');
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.text('Question 1 of 6'), findsOneWidget);
      expect(
        tester.widget<QuizFlashcard>(find.byType(QuizFlashcard)).answered,
        isFalse,
      );
      await tap(tester, 'Next');
      expect(find.textContaining('No answer is preselected'), findsOneWidget);
      await tap(tester, 'Yes');
      await tap(tester, 'Next');
      expect(find.text('Question 2 of 6'), findsOneWidget);
      await tap(tester, 'No');
      await tap(tester, 'Back');
      expect(
        tester.widget<QuizFlashcard>(find.byType(QuizFlashcard)).selected,
        1,
      );
      await tap(tester, 'Not sure');
      await tap(tester, 'Next');
      expect(
        tester.widget<QuizFlashcard>(find.byType(QuizFlashcard)).selected,
        0,
      );
      for (var i = 1; i < quizFields.length; i++) {
        if (i != 1) await tap(tester, 'Yes');
        await tap(tester, i == quizFields.length - 1 ? 'Review' : 'Next');
        expect(tester.takeException(), isNull);
      }
      await tap(tester, 'Are periods regular?');
      final edited = tester.widget<QuizFlashcard>(find.byType(QuizFlashcard));
      expect(edited.answered, isTrue);
      expect(edited.selected, isNull);
      for (var i = 0; i < quizFields.length; i++) {
        await tap(tester, i == quizFields.length - 1 ? 'Review' : 'Next');
      }
      await tap(tester, 'Submit demo answers');
      expect(find.text('Insufficient inputs'), findsOneWidget);
      expect(find.textContaining('No model was run.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('transitions respect reduced motion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const QuizCardTransition(child: Text('Question')),
        ),
      ),
    );
    expect(
      tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
      Duration.zero,
    );
  });

  testWidgets('submission shows loading before demonstration result', (
    tester,
  ) async {
    final session = DemoSession();
    addTearDown(session.dispose);
    await tester.pumpWidget(
      SessionScope(
        session: session,
        child: MaterialApp(theme: auracareTheme(), home: const QuizPage()),
      ),
    );
    await tap(tester, 'Load explicit synthetic example');
    final submit = find.text('Submit demo answers');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Submitting demo answers'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('A summary, not a diagnosis.'), findsOneWidget);
    expect(find.textContaining('No model was run'), findsWidgets);
  });
}
