import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/widgets.dart';
import '../../data/model_quiz_service.dart';
import '../../data/services.dart';

class PcosModelResult extends StatelessWidget {
  const PcosModelResult({
    super.key,
    required this.answers,
    required this.result,
  });
  final QuizAnswers answers;
  final ModelQuizResult result;

  static const reportedChanges = <String, String>{
    'weight_gain': 'Recent weight gain',
    'excess_hair': 'Excess body or facial hair growth',
    'skin_darkening': 'Skin darkening',
    'hair_thinning': 'Scalp hair loss or thinning',
    'acne': 'Pimples or acne',
  };

  @override
  Widget build(BuildContext context) {
    final changes = <String>[
      if (answers.binary['regular_periods'] == 0) 'Irregular periods',
      for (final entry in reportedChanges.entries)
        if (answers.binary[entry.key] == 1) entry.value,
    ];
    final score = result.scoreOutOf100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaced([
        Panel(
          color: Palette.lavender,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: spaced([
              Text(
                'Experimental model score',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Semantics(
                label: score == null
                    ? 'Score unavailable'
                    : 'Experimental model score ${score.toStringAsFixed(1)} out of 100. Not a clinical risk score.',
                child: ExcludeSemantics(
                  child: Text(
                    score == null
                        ? 'Score unavailable'
                        : '${score.toStringAsFixed(1)} / 100',
                    key: const ValueKey('experimental-model-score'),
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ),
              ),
              const Text('Not a PCOS risk percentage or diagnosis.'),
              const Text(
                'Higher scores mean a stronger association with self-reported prior diagnosis in the training data. They do not measure your personal likelihood of PCOS.',
              ),
            ]),
          ),
        ),
        Panel(
          color: Palette.blush,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: spaced([
              Text(
                'Your reported pattern',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (answers.binary['regular_periods'] == 1)
                const Text('Periods reported as regular.'),
              if (changes.isEmpty)
                const Text(
                  'No listed changes reported. This does not rule out PCOS.',
                )
              else
                for (final change in changes) Text('• $change'),
              if (answers.binary.values.any((value) => value == null))
                const Text(
                  'Some answers are unknown; unknown does not mean No.',
                ),
            ], gap: 10),
          ),
        ),
        Text(
          result.bmiImputed
              ? 'BMI not supplied. The model used its development-trained imputation.'
              : 'BMI supplied: ${answers.bmi?.toStringAsFixed(1) ?? 'Not available'}.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const Text(
          'This experiment cannot confirm or rule out PCOS. Discuss concerns with a qualified healthcare professional.',
        ),
        ExpansionTile(
          title: const Text('About this score'),
          childrenPadding: const EdgeInsets.all(16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'The existing trained Random Forest produced this output. It is multiplied by 100 for display; no new risk formula or clinical thresholds are applied. Training labels were self-reported prior PCOS diagnoses, not clinically verified diagnoses. The model has not been clinically validated. A low score does not rule out PCOS, and a high score does not confirm it.',
            ),
          ],
        ),
      ]),
    );
  }
}
