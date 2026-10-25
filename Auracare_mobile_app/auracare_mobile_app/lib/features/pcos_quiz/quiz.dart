import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets.dart';
import '../../data/services.dart';
import '../appointments/doctor.dart';

const quizSources = <String, String>{
  'WHO: PCOS': 'https://www.who.int/news-room/fact-sheets/detail/polycystic-ovary-syndrome',
  'FDA: PCOS': 'https://www.fda.gov/consumers/womens-health-topics/polycystic-ovary-syndrome-pcos',
  'Monash: international guideline':
      'https://www.monash.edu/medicine/mchri/pcos/guideline',
};

class QuizPage extends StatefulWidget {
  const QuizPage({
    super.key,
    this.embedded = false,
    this.service,
    this.active = true,
    this.onDoctor,
    this.onExit,
  });
  final bool embedded, active;
  final VoidCallback? onDoctor, onExit;
  final QuizService? service;
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
  final fields = quizFields.entries.toList();
  int step = -1, attempt = 0;
  bool busy = false, diagnosisAnswered = false;
  QuizOutcome? outcome;
  String? validation;
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
        step = 9;
      } else if (step >= 0) {
        step--;
      }
      validation = null;
    });
  }

  void next() {
    if (step == 0 && !diagnosisAnswered) {
      setState(() => validation = 'Choose Yes, No or Not sure.');
      return;
    }
    if (step == 0 && answers.knownDiagnosis == true) {
      setState(() => outcome = QuizOutcome.tracking);
      return;
    }
    if (step == 1) {
      if (!form.currentState!.validate()) return;
      answers.age = int.tryParse(age.text);
      if (answers.age! < 18 || answers.age! > 45) {
        setState(() => outcome = QuizOutcome.outsideScope);
        return;
      }
    }
    if (step == 2) {
      if (!form.currentState!.validate()) return;
      answers.kg = double.tryParse(kg.text);
      answers.cm = double.tryParse(cm.text);
      final bmi = answers.bmi;
      if (bmi != null && (bmi < 10 || bmi > 70)) {
        setState(
          () => validation = 'This experiment accepts BMI from 10 to 70. Check the values, or leave both optional fields empty.',
        );
        return;
      }
    }
    if (step >= 3 && step <= 8 && !answered.contains(fields[step - 3].key)) {
      setState(() => validation = 'Choose Yes, No or Not sure.');
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
      attempt++;
      validation = null;
    });
    QuizOutcome result;
    try {
      if (answers.knownDiagnosis == true) {
        result = QuizOutcome.tracking;
      } else if (answers.age == null ||
          answers.binary.values.any((v) => v == null)) {
        result = QuizOutcome.insufficient;
      } else if (answers.age! < 18 || answers.age! > 45) {
        result = QuizOutcome.outsideScope;
      } else {
        result = await (widget.service ?? LiveUnavailableQuizService()).assess(
          answers,
        );
      }
    } catch (_) {
      result = QuizOutcome.failure;
    }
    if (!mounted) return;
    setState(() {
      busy = false;
      outcome = result;
    });
  }

  String? number(String? value, {required bool weight}) {
    if (value == null || value.trim().isEmpty) return null;
    final n = double.tryParse(value);
    return n == null || !n.isFinite || n <= 0 || n > (weight ? 500 : 250)
        ? 'Enter a valid ${weight ? 'weight in kg' : 'height in cm'}.'
        : null;
  }

  List<Widget> choices(String key, String label) => [
    Heading(label),
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
    const Text('Not sure stays unknown. It is never changed to No.'),
  ];
  String get resultTitle => switch (outcome!) {
    QuizOutcome.tracking => 'Continue with your history',
    QuizOutcome.outsideScope => 'Outside experimental age scope',
    QuizOutcome.insufficient => 'Insufficient inputs',
    QuizOutcome.failure => 'Assessment could not be reached',
    QuizOutcome.unavailable => 'Live assessment unavailable',
    QuizOutcome.fixture => 'Demonstration summary only',
  };
  String get resultMessage => switch (outcome!) {
    QuizOutcome.tracking => 'A previous clinician diagnosis routes to tracking without another score. You can use Timeline to record your observations.',
    QuizOutcome.outsideScope => 'This experiment covers ages 18–45. The rest of Auracare remains available. No assessment was run.',
    QuizOutcome.insufficient => 'The experimental contract requires age and all six symptom answers. Unknown answers stay null; BMI can be omitted. No assessment was run.',
    QuizOutcome.failure => 'The service failed. Your answers are still here. You can retry or edit them.',
    QuizOutcome.unavailable => 'The eight-feature experimental model has no verified mobile endpoint or authentication connection. No model was run. Your answers are available to edit or copy.',
    QuizOutcome.fixture => 'An explicitly injected demonstration service returned a fixture. No model was run; this is not a personal prediction.',
  };
  Future<void> openSource(String url) async {
    try {
      final opened = await const MethodChannel('org.auracare/links')
          .invokeMethod<bool>('open', url);
      if (opened != true && mounted) {
        tell(context, 'Browser unavailable. Use Copy link.');
      }
    } on PlatformException {
      if (mounted) tell(context, 'Browser unavailable. Use Copy link.');
    } on MissingPluginException {
      if (mounted) tell(context, 'Browser unavailable. Use Copy link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = <Widget>[];
    if (busy) {
      body.addAll([
        const Heading('Checking availability'),
        const LinearProgressIndicator(),
        const Text('Your answers remain in this session.'),
      ]);
    } else if (outcome != null) {
      body.addAll([
        Heading(resultTitle),
        ErrorNotice(resultMessage),
        const Text(
          'Experimental, not diagnostic. A clinical assessment is needed to understand symptoms. This questionnaire cannot diagnose or rule out PCOS.',
        ),
        Panel(child: SelectableText(answers.summary)),
        FilledButton(
          onPressed:
              widget.onDoctor ??
              () => pushPage(
                context,
                Scaffold(
                  appBar: AppBar(title: const Text('Doctor')),
                  body: const SafeArea(child: DoctorPage()),
                ),
              ),
          child: const Text('Open Doctor'),
        ),
        OutlinedButton(
          onPressed: () => setState(() {
            outcome = null;
            step = 9;
          }),
          child: const Text('Edit answers'),
        ),
        if (outcome == QuizOutcome.failure ||
            outcome == QuizOutcome.unavailable)
          OutlinedButton(
            onPressed: submit,
            child: const Text('Retry assessment'),
          ),
        TextButton(
          onPressed: () => copyText(context, answers.summary),
          child: const Text('Copy reported-answer summary'),
        ),
      ]);
    } else if (step < 0) {
      body.addAll([
        const Heading('Make room for your questions.'),
        const Text(
          'A short experimental PCOS questionnaire. Nine questions, one step at a time. This is not a validated questionnaire or a diagnosis.',
        ),
        const Panel(
          child: Text(
            'This app is a demo. Use fictional answers. No verified model endpoint is connected, and your answers are not uploaded.',
          ),
        ),
        FilledButton(
          onPressed: () => setState(() => step = 0),
          child: const Text('Begin questionnaire'),
        ),
      ]);
    } else if (step == 9) {
      body.addAll([
        const Heading('Review your answers'),
        Panel(
          child: Text(
            'Age: ${answers.age ?? 'Unknown'}\nBMI: ${answers.bmi?.toStringAsFixed(1) ?? 'Not supplied'}\nPrevious diagnosis: ${answers.knownDiagnosis == null
                ? 'Not sure'
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
            onTap: () => setState(() => step = i + 3),
          ),
        FilledButton(onPressed: submit, child: const Text('Submit answers')),
        OutlinedButton(onPressed: back, child: const Text('Back')),
      ]);
    } else {
      body.addAll([
        Text('Question ${step + 1} of 9'),
        LinearProgressIndicator(value: (step + 1) / 9),
      ]);
      if (step == 0) {
        body.addAll([
          const Heading('Has a clinician previously diagnosed you with PCOS?'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in <bool?>[true, false, null])
                ChoiceChip(
                  label: Text(
                    value == null
                        ? 'Not sure'
                        : value
                        ? 'Yes'
                        : 'No',
                  ),
                  selected:
                      diagnosisAnswered && answers.knownDiagnosis == value,
                  onSelected: (_) => setState(() {
                    diagnosisAnswered = true;
                    answers.knownDiagnosis = value;
                    validation = null;
                  }),
                ),
            ],
          ),
        ]);
      } else if (step == 1) {
        body.add(
          Form(
            key: form,
            child: TextFormField(
              controller: age,
              decoration: const InputDecoration(labelText: 'Age (years)'),
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return n == null || n < 1 || n > 120
                    ? 'Enter an age from 1 to 120.'
                    : null;
              },
            ),
          ),
        );
      } else if (step == 2) {
        body.addAll([
          const Heading('Height and weight (optional)'),
          const Text(
            'BMI is calculated only when both values are supplied. Weight/BMI alone cannot diagnose PCOS.',
          ),
          Form(
            key: form,
            child: Column(
              children: spaced([
                TextFormField(
                  controller: kg,
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg, optional)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) => (v ?? '').isEmpty && cm.text.isNotEmpty
                      ? 'Enter both values, or leave both empty.'
                      : number(v, weight: true),
                ),
                TextFormField(
                  controller: cm,
                  decoration: const InputDecoration(
                    labelText: 'Height (cm, optional)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) => (v ?? '').isEmpty && kg.text.isNotEmpty
                      ? 'Enter both values, or leave both empty.'
                      : number(v, weight: false),
                ),
              ]),
            ),
          ),
        ]);
      } else {
        final field = fields[step - 3];
        body.addAll(choices(field.key, field.value));
        if (field.key == 'skin_darkening') {
          body.add(
            const Text(
              'This question serves the experimental model; it is not a diagnostic criterion on its own.',
            ),
          );
        }
      }
      if (validation != null) body.add(ErrorNotice(validation!));
      body.addAll([
        FilledButton(onPressed: next, child: const Text('Continue')),
        OutlinedButton(onPressed: back, child: const Text('Back')),
      ]);
    }
    body.add(
      ExpansionTile(
        key: const PageStorageKey('pcos-sources'),
        title: const Text('About these questions & sources'),
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Topics are informed by WHO, FDA and the Monash guideline. These sources do not provide a validated nine-question questionnaire or a ranking of common questions. Wording follows the experimental eight-feature training contract. Clinical editorial review is still needed.',
            ),
          ),
          for (final source in quizSources.entries)
            ListTile(
              title: Text(source.key),
              subtitle: SelectableText(source.value),
              trailing: IconButton(
                tooltip: 'Copy link',
                onPressed: () => copyText(context, source.value),
                icon: const Icon(Icons.copy),
              ),
              onTap: () => openSource(source.value),
            ),
        ],
      ),
    );
    return PopScope(
      canPop: !widget.active || !widget.embedded && step < 0 && !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.active) {
          if (widget.embedded && step < 0 && !busy) {
            widget.onExit?.call();
          } else {
            back();
          }
        }
      },
      child: PageFrame(
        key: ValueKey('quiz-$attempt-$step-${outcome?.name}-$busy'),
        embedded: widget.embedded,
        title: 'Experimental PCOS quiz',
        children: body,
      ),
    );
  }
}
