import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../app/theme.dart';
import '../../app/quiz_integration.dart';
import 'flashcard.dart';
import 'model_result.dart';
import 'survey_quiz.dart';
import '../../core/widgets.dart';
import '../../data/services.dart';
import '../../data/model_quiz_service.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({
    super.key,
    this.embedded = false,
    this.active = true,
    this.onDoctor,
    this.onExit,
    this.service,
  });
  final bool embedded, active;
  final VoidCallback? onDoctor, onExit;
  final QuizService? service;
  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  var answers = QuizAnswers();
  final answered = <String>{};
  final age = TextEditingController(),
      kg = TextEditingController(),
      cm = TextEditingController();
  final form = GlobalKey<FormState>();
  final scroll = ScrollController();
  String? visibleScreen;
  int get reviewStep => fields.length + 1;
  int step = -1; // intro, then age/context, six binary questions, then review
  bool busy = false;
  QuizOutcome? outcome;
  ModelQuizResult? modelResult;
  bool get live => QuizIntegrationScope.maybeOf(context)?.signedIn ?? false;
  String get summary => live
      ? reportedModelQuizSummary(answers, result: modelResult)
      : answers.summary;
  QuizOutcome scenario = QuizOutcome.fixture;
  String? validation;
  final fields = quizFields.entries.toList();
  String? identity;
  int generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final integration = QuizIntegrationScope.maybeOf(context);
    final nextIdentity =
        '${integration?.signedIn ?? false}-${integration?.userId}';
    if (identity != null && identity != nextIdentity) {
      // Never carry questionnaire contents/results into another account/demo.
      generation++;
      answers = QuizAnswers();
      answered.clear();
      age.clear();
      kg.clear();
      cm.clear();
      step = -1;
      busy = false;
      outcome = null;
      modelResult = null;
      validation = null;
    }
    identity = nextIdentity;
  }

  @override
  void dispose() {
    scroll.dispose();
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
        modelResult = null;
        step = reviewStep;
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
        setState(() {
          modelResult = null;
          outcome = QuizOutcome.tracking;
        });
        return;
      }
    }
    if (step >= 1 &&
        step <= fields.length &&
        !answered.contains(fields[step - 1].key)) {
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
    if (answers.age == null ||
        fields.any((field) => !answered.contains(field.key))) {
      setState(
        () => validation = 'Complete context and choose an answer for every question. Not sure is allowed.',
      );
      return;
    }
    final requestGeneration = ++generation;
    setState(() {
      busy = true;
      outcome = null;
      modelResult = null;
    });
    if (live) {
      final service = QuizIntegrationScope.maybeOf(context)?.service;
      ModelQuizResult result;
      try {
        result = service == null
            ? const ModelQuizResult(ModelQuizStatus.unavailable)
            : await service.assess(answers);
      } catch (_) {
        result = const ModelQuizResult(ModelQuizStatus.unavailable);
      }
      if (!mounted || requestGeneration != generation) return;
      setState(() {
        modelResult = result;
        outcome = switch (result.status) {
          ModelQuizStatus.experimental => QuizOutcome.fixture,
          ModelQuizStatus.insufficient => QuizOutcome.insufficient,
          ModelQuizStatus.outsideScope => QuizOutcome.outsideScope,
          ModelQuizStatus.tracking => QuizOutcome.tracking,
          _ => QuizOutcome.unavailable,
        };
        busy = false;
      });
      return;
    }
    final QuizService service =
        widget.service ??
        (scenario == QuizOutcome.unavailable
            ? LiveUnavailableQuizService()
            : DemoQuizService(scenario: scenario));
    try {
      final result = await service.assess(answers);
      if (!mounted || requestGeneration != generation) return;
      setState(() {
        outcome = result;
        busy = false;
        if (scenario == QuizOutcome.failure) scenario = QuizOutcome.fixture;
      });
    } catch (_) {
      if (mounted && requestGeneration == generation) {
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
      step = reviewStep;
      modelResult = null;
      validation = null;
    });
  }

  Widget questionCard() {
    final field = fields[step - 1];
    return QuizCardTransition(
      child: QuizFlashcard(
        key: ValueKey(field.key),
        field: field.key,
        question: field.value,
        index: step - 1,
        selected: answers.binary[field.key],
        answered: answered.contains(field.key),
        onAnswer: (value) => setState(() {
          answers.binary[field.key] = value;
          answered.add(field.key);
          validation = null;
        }),
      ),
    );
  }

  String get resultTitle => live && modelResult != null
      ? switch (modelResult!.status) {
          ModelQuizStatus.experimental => 'Experimental model summary',
          ModelQuizStatus.authenticationRequired => 'Sign in again to submit',
          ModelQuizStatus.invalidInputs => 'Check your questionnaire inputs',
          ModelQuizStatus.unavailable => 'Live assessment unavailable',
          ModelQuizStatus.insufficient => 'Insufficient inputs',
          ModelQuizStatus.outsideScope => 'Outside experimental age scope',
          ModelQuizStatus.tracking => 'Continue with your history',
        }
      : switch (outcome!) {
          QuizOutcome.summary => 'Reported symptom summary',
          QuizOutcome.fixture => 'A summary, not a diagnosis.',
          QuizOutcome.unavailable => 'Live assessment unavailable',
          QuizOutcome.failure => 'Demo service failed',
          QuizOutcome.insufficient => 'Insufficient inputs',
          QuizOutcome.outsideScope => 'Outside experimental age scope',
          QuizOutcome.tracking => 'Continue with your history',
        };
  String get resultMessage => live && modelResult != null
      ? switch (modelResult!.status) {
          ModelQuizStatus.experimental =>
            'The trained Random Forest processed your questionnaire answers. It was developed using self-reported prior diagnoses, not clinically verified diagnoses. This experiment cannot confirm or rule out PCOS and does not estimate your personal probability of PCOS.${modelResult!.bmiImputed ? ' BMI was not supplied; the model used its development-trained imputation.' : ''}',
          ModelQuizStatus.authenticationRequired => 'Your session could not be verified. Your answers remain here. Sign in again before retrying.',
          ModelQuizStatus.invalidInputs => 'The service rejected these inputs. Review your age, optional measurements and answers. Supplied BMI must be between 10 and 70 for this experiment.',
          ModelQuizStatus.unavailable => 'The shared model service is not configured or could not be reached. Your answers remain available to edit or retry. No demonstration result has been substituted.',
          ModelQuizStatus.insufficient => 'No score was produced. Age and all six answers must be known for this model. Not sure stays unknown; optional BMI may be omitted.',
          ModelQuizStatus.outsideScope => 'The experiment is limited to ages 18–45. No model result was produced. You can still use the rest of AuraCare.',
          ModelQuizStatus.tracking => 'A reported known diagnosis routes to tracking and consultation preparation without rescoring.',
        }
      : switch (outcome!) {
          QuizOutcome.summary =>
            'A descriptive count of reported symptoms, not a diagnosis.',
          QuizOutcome.fixture => 'Labeled demonstration fixture. No model was run and this is not a personal result. No risk band or probability is displayed.',
          QuizOutcome.unavailable => 'No verified model service or endpoint is connected. Your answers remain available to edit or copy.',
          QuizOutcome.failure => 'Simulated failure. Your answers are preserved. Retry uses the demonstration fixture, not a model.',
          QuizOutcome.insufficient => 'Unknown answers remain unknown. This prototype requires age and all core answers to be known before showing the fixture; this is not a verified model minimum-input rule. You can still copy the descriptive summary.',
          QuizOutcome.outsideScope => 'The experiment is limited to ages 18–45. This does not limit access to the rest of Auracare. No assessment was run.',
          QuizOutcome.tracking => 'A reported known diagnosis routes to tracking and consultation preparation, without another diagnostic score. The app does not verify that diagnosis.',
        };
  @override
  Widget build(BuildContext context) {
    if (SessionScope.of(context).quizService != null &&
        QuizIntegrationScope.maybeOf(context)?.service == null) {
      return SurveyQuizPage(embedded: widget.embedded);
    }
    final screen = '$step-$busy-${outcome?.name}';
    if (visibleScreen != screen) {
      visibleScreen = screen;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scroll.hasClients) scroll.jumpTo(0);
      });
    }
    final body = <Widget>[];
    if (busy) {
      body.addAll([
        Heading(live ? 'Submitting questionnaire' : 'Submitting demo answers'),
        Semantics(
          label: live ? 'Model service loading' : 'Demo service loading',
          child: const LinearProgressIndicator(),
        ),
        Text(
          live
              ? 'Sending only the reviewed questionnaire to the shared authenticated service.'
              : 'Only a demonstration service is being used. No model or remote endpoint is running.',
        ),
      ]);
    } else if (step < 0 && outcome == null) {
      body.addAll([
        const Heading('Make room for\nyour questions.'),
        Text(
          live
              ? 'Experimental PCOS questionnaire. It cannot diagnose or rule out PCOS and does not estimate your chance of having it.'
              : 'Experimental PCOS questionnaire · synthetic demo. It cannot diagnose or rule out PCOS and does not estimate your chance of having it.',
        ),
        Panel(
          child: Text(
            live
                ? 'On submission, only these questionnaire answers are sent to the team’s shared backend using your signed-in session. The backend runs the existing experimental model without storing this questionnaire. Journal and daily records are not included.'
                : 'This screen uses a demonstration service. Use fictional answers only; nothing is uploaded or saved after restart. Sign in to use the shared experimental model service.',
          ),
        ),
        const Text(
          'The six questions follow the existing PCOS field contract. No clinical validation or medical review is claimed.',
        ),
        FilledButton(
          onPressed: () => setState(() => step = 0),
          child: Text(
            live ? 'Begin questionnaire' : 'Begin demo questionnaire',
          ),
        ),
        if (!live)
          OutlinedButton(
            onPressed: synthetic,
            child: const Text('Load explicit synthetic example'),
          ),
      ]);
    } else if (outcome != null) {
      body.addAll([
        Heading(resultTitle),
        if (live && modelResult?.status == ModelQuizStatus.experimental)
          PcosModelResult(answers: answers, result: modelResult!)
        else ...[
          Panel(color: Palette.lavender, child: Text(resultMessage)),
          const Text(
            'Experimental, not diagnostic. Missing or absent symptoms cannot rule out PCOS. Discuss concerns with a qualified healthcare professional.',
          ),
        ],
        Panel(child: SelectableText(summary)),
        FilledButton(
          onPressed: () => copyText(context, summary),
          child: const Text('Copy reported-answer summary'),
        ),
        OutlinedButton(
          onPressed: () => setState(() {
            outcome = null;
            modelResult = null;
            step = reviewStep;
          }),
          child: const Text('Edit answers'),
        ),
        if (outcome == QuizOutcome.failure ||
            outcome == QuizOutcome.unavailable)
          OutlinedButton(
            onPressed: submit,
            child: Text(live ? 'Retry model service' : 'Retry demo service'),
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
              if (!mounted) return;
              if (widget.embedded) {
                widget.onExit?.call();
              } else {
                Navigator.pop(context);
              }
            });
          },
          child: const Text('Return to Auracare'),
        ),
      ]);
    } else {
      body.addAll([
        Text(
          step == reviewStep
              ? 'Review before submitting'
              : step == 0
              ? 'Before we begin'
              : 'Question $step of ${fields.length}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (step > 0 && step < reviewStep)
          Semantics(
            label: 'Question $step of ${fields.length}',
            child: Row(
              children: [
                for (var i = 0; i < fields.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: i < step ? Palette.purple : Palette.lavender,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ]);
      if (step == 0) {
        body.add(
          Panel(
            color: Palette.lavender,
            child: Form(
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
          ),
        );
      } else if (step <= fields.length) {
        final field = fields[step - 1];
        body.add(questionCard());
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
          Text(
            live
                ? 'Not sure stays unknown.'
                : 'Demonstration only. Not sure stays unknown.',
          ),
        );
      } else {
        body.addAll([
          const Heading('Check your answers.'),
          Panel(
            child: Text(
              'Age: ${answers.age ?? 'Unknown'}\nWeight: ${answers.kg == null ? 'Not supplied' : '${answers.kg} kg'}\nHeight: ${answers.cm == null ? 'Not supplied' : '${answers.cm} cm'}\nBMI: ${answers.bmi?.toStringAsFixed(1) ?? 'Not supplied'}\nKnown diagnosis: ${answers.knownDiagnosis == null
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
              subtitle: !answered.contains(fields[i].key)
                  ? 'Unanswered'
                  : answers.binary[fields[i].key] == null
                  ? 'Not sure'
                  : answers.binary[fields[i].key] == 1
                  ? 'Yes'
                  : 'No',
              icon: Icons.edit_outlined,
              onTap: () => setState(() => step = i + 1),
            ),
          if (!live)
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
          Text(
            live
                ? 'Submit only after reviewing your answers. Unknown core inputs produce no model result. Ages outside 18–45 show scope limits; known diagnosis routes to tracking. The experimental model score is shown out of 100, not as a clinical risk percentage.'
                : 'Unknown core inputs show insufficient inputs. Ages outside 18–45 show scope limits. Known diagnosis goes to tracking. No scores are calculated.',
          ),
        ]);
      }
      if (validation != null) body.add(ErrorNotice(validation!));
      body.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: OutlinedButton(
                onPressed: busy ? null : back,
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: busy
                    ? null
                    : step == reviewStep
                    ? submit
                    : next,
                child: Text(
                  step == reviewStep
                      ? live
                            ? 'Submit questionnaire'
                            : 'Submit demo answers'
                      : step == fields.length
                      ? 'Review'
                      : 'Next',
                ),
              ),
            ),
          ],
        ),
      );
    }
    return PopScope(
      canPop: !widget.active || (!widget.embedded && step < 0 && !busy),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && widget.active) {
          if (widget.embedded && step < 0 && !busy) {
            widget.onExit?.call();
          } else {
            back();
          }
        }
      },
      child: widget.embedded
          ? quizContent(body)
          : Scaffold(
              appBar: AppBar(title: const Text('Experimental PCOS quiz')),
              body: quizContent(body),
            ),
    );
  }

  Widget quizContent(List<Widget> body) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: spaced(body),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
