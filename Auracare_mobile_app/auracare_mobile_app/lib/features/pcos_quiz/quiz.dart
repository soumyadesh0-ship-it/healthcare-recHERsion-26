import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/widgets.dart';
import '../../data/services.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});
  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final answers = QuizAnswers();
  final answered = <String>{};
  final age = TextEditingController(),
      kg = TextEditingController(),
      cm = TextEditingController();
  final form = GlobalKey<FormState>();
  int step = -1; // intro, then age/context, six binary questions, then review
  bool busy = false;
  int attempt = 0;
  QuizOutcome? outcome;
  QuizOutcome scenario = QuizOutcome.fixture;
  String? validation;
  final fields = quizFields.entries.toList();
  @override
  void dispose() {
    age.dispose();
    kg.dispose();
    cm.dispose();
    super.dispose();
  }

  void back() {
    if (busy) return;
    setState(() {
      if (outcome != null) {
        outcome = null;
        step = 7;
      } else if (step >= 0) {
        step--;
      }
      validation = null;
    });
  }

  bool readContext() {
    if (!form.currentState!.validate()) return false;
    answers.age = int.tryParse(age.text);
    answers.kg = double.tryParse(kg.text);
    answers.cm = double.tryParse(cm.text);
    return true;
  }

  void next() {
    if (step == 0) {
      if (!readContext()) return;
      if (answers.knownDiagnosis == true) {
        setState(() => outcome = QuizOutcome.tracking);
        return;
      }
    }
    if (step >= 1 && step <= 6 && !answered.contains(fields[step - 1].key)) {
      setState(
        () => validation =
            'Choose Yes, No or Not sure. No answer is preselected.',
      );
      return;
    }
    setState(() {
      step++;
      validation = null;
    });
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() {
      busy = true;
      outcome = null;
      attempt++;
    });
    final QuizService service = scenario == QuizOutcome.unavailable
        ? LiveUnavailableQuizService()
        : DemoQuizService(scenario: scenario);
    try {
      final result = await service.assess(answers);
      if (!mounted) return;
      setState(() {
        outcome = result;
        busy = false;
        if (scenario == QuizOutcome.failure) scenario = QuizOutcome.fixture;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          outcome = QuizOutcome.failure;
          busy = false;
        });
      }
    }
  }

  void synthetic() {
    setState(() {
      age.text = '28';
      kg.text = '';
      cm.text = '';
      answers.age = 28;
      answers.kg = null;
      answers.cm = null;
      answers.knownDiagnosis = false;
      for (final field in fields) {
        answers.binary[field.key] = field.key == 'regular_periods' ? 0 : 1;
        answered.add(field.key);
      }
      outcome = null;
      step = 7;
      validation = null;
    });
    tell(
      context,
      'Explicit fictional example loaded — not your health history',
    );
  }

  List<Widget> choices(String key, String label) => [
    Text(label, style: Theme.of(context).textTheme.titleLarge),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in <(int?, String)>[
          (1, 'Yes'),
          (0, 'No'),
          (null, 'Not sure'),
        ])
          ChoiceChip(
            label: Text(option.$2),
            selected:
                answered.contains(key) && answers.binary[key] == option.$1,
            onSelected: (_) => setState(() {
              answers.binary[key] = option.$1;
              answered.add(key);
              validation = null;
            }),
          ),
      ],
    ),
  ];
  String get resultTitle => switch (outcome!) {
    QuizOutcome.fixture => 'A summary, not a diagnosis.',
    QuizOutcome.unavailable => 'Live assessment unavailable',
    QuizOutcome.failure => 'Demo service failed',
    QuizOutcome.insufficient => 'Insufficient inputs',
    QuizOutcome.outsideScope => 'Outside experimental age scope',
    QuizOutcome.tracking => 'Continue with your history',
  };
  String get resultMessage => switch (outcome!) {
    QuizOutcome.fixture => 'Labeled demonstration fixture. No model was run and this is not a personal result. No risk band or probability is displayed.',
    QuizOutcome.unavailable => 'No verified model service or endpoint is connected. Your answers remain available to edit or copy.',
    QuizOutcome.failure => 'Simulated failure. Your answers are preserved. Retry uses the demonstration fixture, not a model.',
    QuizOutcome.insufficient => 'Unknown answers remain unknown. This prototype requires age and all core answers to be known before showing the fixture; this is not a verified model minimum-input rule. You can still copy the descriptive summary.',
    QuizOutcome.outsideScope => 'The experiment is limited to ages 18–45. This does not limit access to the rest of Auracare. No assessment was run.',
    QuizOutcome.tracking => 'A reported known diagnosis routes to tracking and consultation preparation, without another diagnostic score. The app does not verify that diagnosis.',
  };
  @override
  Widget build(BuildContext context) {
    final body = <Widget>[];
    if (busy) {
      body.addAll([
        const Heading('Submitting demo answers'),
        Semantics(
          label: 'Demo service loading',
          child: const LinearProgressIndicator(),
        ),
        const Text(
          'Only a demonstration service is being used. No model or remote endpoint is running.',
        ),
      ]);
    } else if (step < 0 && outcome == null) {
      body.addAll([
        const Heading('Make room for\nyour questions.'),
        const Text(
          'Experimental PCOS questionnaire · synthetic demo. It cannot diagnose or rule out PCOS and does not estimate your chance of having it.',
        ),
        const Panel(
          child: Text(
            'No model or backend exists in this checkout. Use fictional answers only. This flow demonstrates questions, review and service states; nothing is uploaded or saved after restart.',
          ),
        ),
        const Text(
          'Question wording/time windows are not verified against a local model contract. No adaptive AI, clinical validation or medical review is claimed.',
        ),
        FilledButton(
          onPressed: () => setState(() => step = 0),
          child: const Text('Begin demo questionnaire'),
        ),
        OutlinedButton(
          onPressed: synthetic,
          child: const Text('Load explicit synthetic example'),
        ),
      ]);
    } else if (outcome != null) {
      body.addAll([
        Heading(resultTitle),
        ErrorNotice(resultMessage),
        const Text(
          'Experimental, not diagnostic. Missing or absent symptoms cannot rule out PCOS. Discuss concerns with a qualified healthcare professional.',
        ),
        Panel(child: SelectableText(answers.summary)),
        FilledButton(
          onPressed: () => copyText(context, answers.summary),
          child: const Text('Copy reported-answer summary'),
        ),
        OutlinedButton(
          onPressed: () => setState(() {
            outcome = null;
            step = 7;
          }),
          child: const Text('Edit answers'),
        ),
        if (outcome == QuizOutcome.failure ||
            outcome == QuizOutcome.unavailable)
          OutlinedButton(
            onPressed: submit,
            child: const Text('Retry demo service'),
          ),
        if (outcome == QuizOutcome.tracking)
          OutlinedButton(
            onPressed: () {
              SessionScope.of(context).addQuestion(
                'What should I discuss about my reported PCOS history?',
              );
              tell(context, 'Question added to appointment preparation');
            },
            child: const Text('Add tracking question'),
          ),
        OutlinedButton(
          onPressed: () {
            setState(() {
              step = -1;
              outcome = null;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.pop(context);
            });
          },
          child: const Text('Return to Auracare'),
        ),
      ]);
    } else {
      body.addAll([
        Text(
          step == 7 ? 'Review before submitting' : 'Step ${step + 1} of 7',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        LinearProgressIndicator(value: (step + 1) / 8),
      ]);
      if (step == 0) {
        body.add(
          Form(
            key: form,
            child: Column(
              children: spaced([
                const Heading('A little context.'),
                TextFormField(
                  controller: age,
                  decoration: const InputDecoration(labelText: 'Age (years)'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return n == null || n < 1 || n > 120
                        ? 'Enter an age from 1 to 120. Experimental scope is 18–45.'
                        : null;
                  },
                ),
                const Text(
                  'Weight and height are optional. BMI is derived only if both are explicitly entered; it is not interpreted as a diagnosis.',
                ),
                TextFormField(
                  controller: kg,
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg, optional)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return cm.text.isEmpty
                          ? null
                          : 'Enter both weight and height, or leave both empty.';
                    }
                    final n = double.tryParse(v);
                    return n == null || !n.isFinite || n <= 0 || n > 500
                        ? 'Enter a positive weight up to 500 kg.'
                        : null;
                  },
                ),
                TextFormField(
                  controller: cm,
                  decoration: const InputDecoration(
                    labelText: 'Height (cm, optional)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return kg.text.isEmpty
                          ? null
                          : 'Enter both weight and height, or leave both empty.';
                    }
                    final n = double.tryParse(v);
                    return n == null || !n.isFinite || n < 30 || n > 250
                        ? 'Enter height from 30 to 250 cm.'
                        : null;
                  },
                ),
                const Text(
                  'Previously diagnosed with PCOS by a clinician? (optional routing flag)',
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final value in [true, false])
                      ChoiceChip(
                        label: Text(value ? 'Yes' : 'No'),
                        selected: answers.knownDiagnosis == value,
                        onSelected: (_) =>
                            setState(() => answers.knownDiagnosis = value),
                      ),
                    ActionChip(
                      label: const Text('Not sure / clear'),
                      onPressed: () =>
                          setState(() => answers.knownDiagnosis = null),
                    ),
                  ],
                ),
              ]),
            ),
          ),
        );
      } else if (step <= 6) {
        final field = fields[step - 1];
        body.addAll(choices(field.key, field.value));
        if (field.key == 'regular_periods' &&
            answers.binary[field.key] == 0 &&
            answered.contains(field.key)) {
          body.add(
            const Panel(
              child: Text(
                'You can record the dates you remember in Cycle records. No extra duration or severity answer is sent as a model feature.',
              ),
            ),
          );
        }
        body.add(
          const Text(
            'Choose a fictional response. Not sure stays null; it is never converted to No.',
          ),
        );
      } else {
        body.addAll([
          const Heading('Check your answers.'),
          Panel(
            child: Text(
              'Age: ${answers.age ?? 'Unknown'}\nBMI: ${answers.bmi?.toStringAsFixed(1) ?? 'Not supplied'}\nKnown diagnosis: ${answers.knownDiagnosis == null
                  ? 'Unknown'
                  : answers.knownDiagnosis!
                  ? 'Yes'
                  : 'No'}',
            ),
          ),
          OutlinedButton(
            onPressed: () => setState(() => step = 0),
            child: const Text('Edit context'),
          ),
          for (var i = 0; i < fields.length; i++)
            ActionCard(
              title: fields[i].value,
              subtitle: answers.binary[fields[i].key] == null
                  ? 'Not sure'
                  : answers.binary[fields[i].key] == 1
                  ? 'Yes'
                  : 'No',
              icon: Icons.edit_outlined,
              onTap: () => setState(() => step = i + 1),
            ),
          DropdownButtonFormField<QuizOutcome>(
            itemHeight: null,
            initialValue: scenario,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Demo service scenario',
            ),
            items: const [
              DropdownMenuItem(
                value: QuizOutcome.fixture,
                child: Text('Labeled fixture (no model)'),
              ),
              DropdownMenuItem(
                value: QuizOutcome.failure,
                child: Text('Fail once, then retry fixture'),
              ),
              DropdownMenuItem(
                value: QuizOutcome.unavailable,
                child: Text('Live service unavailable'),
              ),
            ],
            onChanged: busy ? null : (v) => setState(() => scenario = v!),
          ),
          const Text(
            'Unknown core inputs show insufficient inputs. Ages outside 18–45 show scope limits. Known diagnosis goes to tracking. No scores are calculated.',
          ),
        ]);
      }
      if (validation != null) body.add(ErrorNotice(validation!));
      if (busy) {
        body.add(
          Semantics(
            label: 'Submitting demo answers',
            child: LinearProgressIndicator(),
          ),
        );
      }
      body.add(
        FilledButton(
          onPressed: busy
              ? null
              : step == 7
              ? submit
              : next,
          child: Text(
            busy
                ? 'Submitting demo…'
                : step == 7
                ? 'Submit demo answers'
                : 'Next',
          ),
        ),
      );
      body.add(
        OutlinedButton(
          onPressed: busy ? null : back,
          child: const Text('Back'),
        ),
      );
    }
    return PopScope(
      canPop: step < 0 && !busy,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) back();
      },
      child: PageFrame(
        key: ValueKey(
          '$attempt-${busy ? 'submitting' : step}-${outcome?.name}',
        ),
        title: 'Experimental PCOS quiz',
        children: body,
      ),
    );
  }
}
