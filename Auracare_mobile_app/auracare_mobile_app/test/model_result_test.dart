import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auracare_mobile_app/app/theme.dart';
import 'package:auracare_mobile_app/data/model_quiz_service.dart';
import 'package:auracare_mobile_app/data/services.dart';
import 'package:auracare_mobile_app/features/pcos_quiz/model_result.dart';

void main() {
  test(
    'research score is rescaled without thresholds or invented risk bands',
    () {
      for (final value in [0.0, .314159, 1.0]) {
        final result = ModelQuizResult(
          ModelQuizStatus.experimental,
          experimentalScore: value,
        );
        expect(result.scoreOutOf100, value * 100);
      }
      expect(
        const ModelQuizResult(ModelQuizStatus.insufficient).scoreOutOf100,
        isNull,
      );
    },
  );

  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    testWidgets(
      'specific reported pattern and research score fit $width dp at 200%',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final answers = QuizAnswers()..age = 28;
        for (final key in quizFields.keys) {
          answers.binary[key] = 0;
        }
        answers.binary['acne'] = 1;
        const result = ModelQuizResult(
          ModelQuizStatus.experimental,
          experimentalScore: .822687,
          bmiImputed: true,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: auracareTheme(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: PcosModelResult(answers: answers, result: result),
              ),
            ),
          ),
        );
        expect(find.text('82.3 / 100'), findsOneWidget);
        expect(find.text('• Irregular periods'), findsOneWidget);
        expect(find.text('• Pimples or acne'), findsOneWidget);
        expect(find.text('• Recent weight gain'), findsNothing);
        expect(find.text('Periods reported as regular.'), findsNothing);
        expect(
          find.textContaining('development-trained imputation'),
          findsOneWidget,
        );
        expect(find.textContaining('Low risk'), findsNothing);
        expect(find.textContaining('High risk'), findsNothing);
        expect(
          reportedModelQuizSummary(answers, result: result),
          contains('82.3 / 100'),
        );
        final about = find.text('About this score');
        await tester.ensureVisible(about);
        await tester.tap(about);
        await tester.pumpAndSettle();
        expect(find.textContaining('multiplied by 100'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
