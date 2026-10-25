import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auracare_mobile_app/app/quiz_integration.dart';
import 'package:auracare_mobile_app/app/session.dart';
import 'package:auracare_mobile_app/app/theme.dart';
import 'package:auracare_mobile_app/data/model_quiz_service.dart';
import 'package:auracare_mobile_app/data/services.dart';
import 'package:auracare_mobile_app/features/pcos_quiz/quiz.dart';

class ModelService implements ModelQuizService {
  final pending = Completer<ModelQuizResult>();
  final requests = <Map<String, Object?>>[];
  bool retry = false;
  @override
  Future<ModelQuizResult> assess(QuizAnswers answers) {
    requests.add(modelQuizPayload(answers));
    return retry
        ? Future.value(
            const ModelQuizResult(
              ModelQuizStatus.experimental,
              bmiImputed: true,
            ),
          )
        : pending.future;
  }
}

Future<void> tap(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> completeQuestions(WidgetTester tester) async {
  await tap(tester, 'Begin questionnaire');
  await tester.enterText(find.byType(TextFormField).first, '28');
  await tap(tester, 'Next');
  for (var i = 0; i < quizFields.length; i++) {
    await tap(tester, i == 0 ? 'Not sure' : 'No');
    await tap(tester, i == quizFields.length - 1 ? 'Review' : 'Next');
  }
}

Widget app(
  DemoSession session,
  ModelQuizService? service, {
  String userId = 'user-a',
}) => QuizIntegrationScope(
  signedIn: true,
  service: service,
  userId: userId,
  child: SessionScope(
    session: session,
    child: MaterialApp(theme: auracareTheme(), home: const QuizPage()),
  ),
);

void main() {
  testWidgets(
    'live loading, error, preserved answers and retry never use a demo',
    (tester) async {
      final session = DemoSession();
      addTearDown(session.dispose);
      final service = ModelService();
      await tester.pumpWidget(app(session, service));
      expect(find.text('Load explicit synthetic example'), findsNothing);
      await completeQuestions(tester);
      expect(find.text('Demo service scenario'), findsNothing);
      expect(find.text('Not sure'), findsOneWidget);
      await tester.ensureVisible(find.text('Submit questionnaire'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit questionnaire'));
      await tester.pump();
      expect(find.text('Submitting questionnaire'), findsOneWidget);
      expect(service.requests.single['regular_periods'], isNull);
      expect(service.requests.single['bmi'], isNull);
      service.pending.complete(
        const ModelQuizResult(ModelQuizStatus.unavailable),
      );
      await tester.pumpAndSettle();
      expect(find.text('Live assessment unavailable'), findsOneWidget);
      expect(
        find.textContaining('No demonstration result has been substituted'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Reported questionnaire answers'),
        findsOneWidget,
      );
      service.retry = true;
      await tap(tester, 'Retry model service');
      expect(find.text('Experimental model summary'), findsOneWidget);
      expect(
        find.textContaining('development-trained imputation'),
        findsOneWidget,
      );
      expect(find.textContaining('No model was run'), findsNothing);
      expect(find.textContaining('0.314159'), findsNothing);
      expect(service.requests[0], service.requests[1]);
      await tap(tester, 'Edit answers');
      expect(find.text('Not sure'), findsOneWidget);
      await tap(tester, 'Submit questionnaire');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Review before submitting'), findsOneWidget);
      await tap(tester, 'Edit context');
      await tap(tester, 'Yes');
      await tap(tester, 'Next');
      expect(find.text('Continue with your history'), findsOneWidget);
      expect(find.text('Experimental model summary'), findsNothing);
    },
  );

  testWidgets(
    'unconfigured signed-in service shows unavailable, never fixture',
    (tester) async {
      final session = DemoSession();
      addTearDown(session.dispose);
      await tester.pumpWidget(app(session, null));
      await completeQuestions(tester);
      await tap(tester, 'Submit questionnaire');
      expect(find.text('Live assessment unavailable'), findsOneWidget);
      expect(find.text('A summary, not a diagnosis.'), findsNothing);
    },
  );

  testWidgets('known diagnosis routes locally without sending model answers', (
    tester,
  ) async {
    final session = DemoSession();
    addTearDown(session.dispose);
    final service = ModelService();
    await tester.pumpWidget(app(session, service));
    await tap(tester, 'Begin questionnaire');
    await tester.enterText(find.byType(TextFormField).first, '28');
    await tap(tester, 'Yes');
    await tap(tester, 'Next');
    expect(find.text('Continue with your history'), findsOneWidget);
    expect(service.requests, isEmpty);
  });

  testWidgets('changing account clears quiz and discards pending response', (
    tester,
  ) async {
    final session = DemoSession();
    addTearDown(session.dispose);
    final service = ModelService();
    await tester.pumpWidget(app(session, service));
    await completeQuestions(tester);
    await tester.ensureVisible(find.text('Submit questionnaire'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit questionnaire'));
    await tester.pump();
    await tester.pumpWidget(app(session, service, userId: 'user-b'));
    service.pending.complete(
      const ModelQuizResult(ModelQuizStatus.experimental),
    );
    await tester.pumpAndSettle();
    expect(find.text('Begin questionnaire'), findsOneWidget);
    expect(find.text('Experimental model summary'), findsNothing);
    await tap(tester, 'Begin questionnaire');
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      isEmpty,
    );
  });
}
