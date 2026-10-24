import 'records.dart';

class ResourcePreview {
  const ResourcePreview(this.topic);
  final String topic;
  String get question =>
      'What should I ask a healthcare professional about $topic?';
}

abstract interface class ResourcesRepository {
  List<ResourcePreview> get resources;
}

class PreviewResourcesRepository implements ResourcesRepository {
  @override
  List<ResourcePreview> get resources => const [
    ResourcePreview('Puberty & adolescence'),
    ResourcePreview('First periods & menstrual health'),
    ResourcePreview('Hormonal & reproductive health'),
    ResourcePreview('Fertility & preconception'),
    ResourcePreview('Pregnancy'),
    ResourcePreview('Postpartum'),
    ResourcePreview('Perimenopause'),
    ResourcePreview('Menopause'),
    ResourcePreview('Later-life wellbeing'),
    ResourcePreview('PCOS'),
    ResourcePreview('Symptoms & terminology'),
    ResourcePreview('Appointment preparation'),
  ];
}

const quizFields = <String, String>{
  'regular_periods': 'Are periods regular?',
  'weight_gain': 'Weight gain?',
  'excess_hair': 'Excess hair growth?',
  'skin_darkening': 'Skin darkening?',
  'hair_thinning': 'Hair thinning?',
  'acne': 'Acne?',
};

class QuizAnswers {
  int? age;
  double? kg, cm;
  bool? knownDiagnosis;
  final Map<String, int?> binary = {
    for (final key in quizFields.keys) key: null,
  };
  double? get bmi => kg != null && cm != null && cm! > 0
      ? kg! / ((cm! / 100) * (cm! / 100))
      : null;
  Map<String, Object?> toJson() => {
    'age': age,
    'bmi': bmi,
    ...binary,
    'known_pcos_diagnosis': knownDiagnosis,
  };
  String get summary =>
      'Experimental questionnaire — synthetic demo\n'
      'No model was run. Cannot diagnose or rule out PCOS.\n'
      'Reported answers (not confirmed clinical findings):\n'
      'Age: ${age ?? 'Not supplied'}\nBMI: ${bmi?.toStringAsFixed(1) ?? 'Not supplied'}\n'
      '${quizFields.entries.map((e) => '${e.value} ${binary[e.key] == null
          ? 'Not sure'
          : binary[e.key] == 1
          ? 'Yes'
          : 'No'}').join('\n')}\n'
      'Discuss concerns with a qualified healthcare professional.';
}

enum QuizOutcome {
  fixture,
  unavailable,
  failure,
  insufficient,
  outsideScope,
  tracking,
}

abstract interface class QuizService {
  Future<QuizOutcome> assess(QuizAnswers answers);
}

class DemoQuizService implements QuizService {
  DemoQuizService({this.scenario = QuizOutcome.fixture});
  final QuizOutcome scenario;
  @override
  Future<QuizOutcome> assess(QuizAnswers answers) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (answers.knownDiagnosis == true) return QuizOutcome.tracking;
    if (answers.age == null) return QuizOutcome.insufficient;
    if (answers.age! < 18 || answers.age! > 45) return QuizOutcome.outsideScope;
    // Prototype gate, not a verified model minimum-input rule. Null stays null.
    if (answers.binary.values.any((v) => v == null)) {
      return QuizOutcome.insufficient;
    }
    return scenario;
  }
}

class LiveUnavailableQuizService implements QuizService {
  @override
  Future<QuizOutcome> assess(QuizAnswers answers) async =>
      QuizOutcome.unavailable;
}

String appointmentSummary(
  List<HealthEntry> selected,
  List<String> questions, {
  required bool includeNotes,
  required bool includeObservations,
  required DateTime from,
  required DateTime to,
}) {
  final facts = selected
      .map(
        (e) =>
            '${dayLabel(e.when)} ${timeLabel(e.when)} (${e.zone}) — ${e.title} [${e.type.name}, v${e.version}]'
            '${includeNotes && e.note.isNotEmpty ? '\n${e.note}' : ''}',
      )
      .join('\n\n');
  final coverage = Coverage(selected, from, to);
  return 'Auracare — synthetic consultation preparation\n${dayLabel(from)} to ${dayLabel(to)}\n'
      'Reported facts — not confirmed clinical findings\n${facts.isEmpty ? 'No records selected.' : facts}\n\n'
      '${includeObservations ? 'Descriptive observations — prototype-count-v1\n${coverage.recordedDays} days with selected entries of ${coverage.totalDays}; other days unknown. No diagnosis or causal conclusions.\n\n' : ''}'
      'Questions\n${questions.isEmpty ? 'No questions added.' : questions.map((q) => '• $q').join('\n')}\n'
      'Review this synthetic text before copying. Nothing is sent to a clinician.';
}
