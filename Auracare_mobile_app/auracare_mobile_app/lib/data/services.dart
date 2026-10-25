import 'records.dart';
import 'articles.dart';
import 'api_client.dart';
import 'auth_service.dart';

class ResourcePreview {
  const ResourcePreview(this.topic);
  final String topic;
  EducationalArticle? get article => ArticleCatalog.articles[topic];
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
  'regular_periods': 'Are your periods regular?',
  'weight_gain': 'Have you gained weight recently?',
  'excess_hair': 'Do you have excessive body or facial hair growth?',
  'skin_darkening': 'Are you noticing skin darkening recently?',
  'hair_thinning': 'Do you have scalp hair loss or thinning?',
  'acne': 'Do you have pimples or acne on your face or jawline?',
};

class QuizAnswers {
  int? age;
  double? kg, cm;
  bool? knownDiagnosis;
  bool hairThinningRefersToScalp = false;
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

  /// predict.py accepts an omitted routing flag but rejects an explicit null.
  /// Unknown stays null in the UI/export; omission never asserts a diagnosis.
  Map<String, Object?> toModelJson() {
    final payload = toJson();
    if (knownDiagnosis == null) payload.remove('known_pcos_diagnosis');
    return payload;
  }

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
  summary,
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
    // experimental-1 contract: all six binary features required; BMI nullable.
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

/// Only these four fields cross the API boundary. Local answers are never mutated.
class PcosQuestionnaireAdapter {
  static bool? _boolean(int? value) => switch (value) {
    1 => true,
    0 => false,
    null => null,
    _ => throw const ApiException(ApiFailure.validation),
  };

  static PcosSurveyAnswers map(QuizAnswers answers) {
    final regular = _boolean(answers.binary['regular_periods']);
    return PcosSurveyAnswers(
      irregularPeriods: regular == null ? null : !regular,
      acne: _boolean(answers.binary['acne']),
      excessHairGrowth: _boolean(answers.binary['excess_hair']),
      // The legacy question includes general hair loss; scalp scope must be explicit.
      scalpHairThinning: answers.hairThinningRefersToScalp
          ? _boolean(answers.binary['hair_thinning'])
          : null,
    );
  }
}

class AuthenticatedQuizService implements QuizService {
  AuthenticatedQuizService({required this.auth, required this.createClient})
    : _userId = auth.userId;
  final AuraAuthController auth;
  final String? _userId;
  final AuraApiClient Function() createClient;
  AuraApiClient? _client;
  PcosAssessment? assessment;
  bool _busy = false, _disposed = false;

  @override
  Future<QuizOutcome> assess(QuizAnswers answers) async =>
      throw const ApiException(ApiFailure.forbidden);

  Future<QuizOutcome> assessConfirmed(
    QuizAnswers answers, {
    required bool confirmed,
  }) async {
    if (!confirmed || _busy) throw const ApiException(ApiFailure.forbidden);
    if (_disposed ||
        auth.mode != AccessMode.authenticated ||
        auth.userId != _userId ||
        _userId == null) {
      throw const ApiException(ApiFailure.unauthenticated);
    }
    _busy = true;
    assessment = null;
    try {
      final survey = PcosQuestionnaireAdapter.map(answers);
      final result = await (_client ??= createClient()).predictPcos(survey);
      if (_disposed ||
          auth.mode != AccessMode.authenticated ||
          auth.userId != _userId) {
        throw const ApiException(ApiFailure.unauthenticated);
      }
      assessment = result;
      return QuizOutcome.summary;
    } finally {
      _busy = false;
    }
  }

  void dispose() {
    _disposed = true;
    _client?.close();
  }
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
            '${dayLabel(e.when)} ${e.observationTimeKnown ? timeLabel(e.when) : 'Time not recorded'} (${e.zone}) — ${e.title} [${e.type.name}, v${e.version}]'
            '${e.tracking == null ? '' : '\n${e.tracking!.summary}'}'
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
