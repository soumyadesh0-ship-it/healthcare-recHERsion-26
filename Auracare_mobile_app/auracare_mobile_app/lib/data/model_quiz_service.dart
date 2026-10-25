import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app/auth_service.dart';
import 'services.dart';

enum ModelQuizStatus {
  experimental,
  insufficient,
  outsideScope,
  tracking,
  authenticationRequired,
  unavailable,
  invalidInputs,
}

class ModelQuizResult {
  const ModelQuizResult(this.status, {this.bmiImputed = false});
  final ModelQuizStatus status;
  final bool bmiImputed;
}

/// Only the model's exact eight features and optional routing flag are sent.
/// `regular_periods` is not inverted or renamed to `irregular_periods`.
Map<String, Object?> modelQuizPayload(QuizAnswers answers) => {
  'age': answers.age,
  'bmi': answers.bmi,
  for (final key in quizFields.keys) key: answers.binary[key],
  'known_pcos_diagnosis': answers.knownDiagnosis ?? false,
};

abstract interface class ModelQuizService {
  Future<ModelQuizResult> assess(QuizAnswers answers);
}

class AuthenticatedModelQuizService implements ModelQuizService {
  AuthenticatedModelQuizService({
    required Uri baseUrl,
    required this.tokens,
    required this.client,
    this.timeout = const Duration(seconds: 20),
    bool allowLocalHttp = false,
  }) : endpoint = modelQuizEndpoint(baseUrl, allowLocalHttp: allowLocalHttp);

  final Uri endpoint;
  final AccessTokenProvider tokens;
  final http.Client client;
  final Duration timeout;

  @override
  Future<ModelQuizResult> assess(QuizAnswers answers) async {
    // Take the snapshot before async token refresh; navigation cannot change it.
    final payload = modelQuizPayload(answers);
    try {
      final token = await tokens.accessToken().timeout(timeout);
      if (token == null || token.isEmpty) {
        return const ModelQuizResult(ModelQuizStatus.authenticationRequired);
      }
      final request = http.Request('POST', endpoint)
        ..followRedirects = false
        ..headers.addAll({
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        })
        ..body = jsonEncode(payload);
      final response = await (() async {
        final stream = await client.send(request);
        return http.Response.fromStream(stream);
      })().timeout(timeout);
      if (response.statusCode == 401 || response.statusCode == 403) {
        return const ModelQuizResult(ModelQuizStatus.authenticationRequired);
      }
      if (response.statusCode == 422) {
        return const ModelQuizResult(ModelQuizStatus.invalidInputs);
      }
      if (response.statusCode != 200) {
        return const ModelQuizResult(ModelQuizStatus.unavailable);
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic> ||
          body['method_version'] != 'trained-random-forest-v1') {
        return const ModelQuizResult(ModelQuizStatus.unavailable);
      }
      switch (body['status']) {
        case 'experimental_result':
          final score = body['experimental_model_score'];
          if (body['model'] != 'random_forest' ||
              body['score_target'] !=
                  'self_reported_prior_pcos_diagnosis_in_training_sample' ||
              score is! num ||
              !score.isFinite ||
              score < 0 ||
              score > 1 ||
              body['bmi_imputed'] is! bool) {
            return const ModelQuizResult(ModelQuizStatus.unavailable);
          }
          // The numeric developer output is deliberately not retained in UI state.
          return ModelQuizResult(
            ModelQuizStatus.experimental,
            bmiImputed: body['bmi_imputed'] as bool,
          );
        case 'insufficient_inputs':
          return const ModelQuizResult(ModelQuizStatus.insufficient);
        case 'outside_experimental_scope':
          return const ModelQuizResult(ModelQuizStatus.outsideScope);
        case 'tracking_journey':
          return const ModelQuizResult(ModelQuizStatus.tracking);
        default:
          return const ModelQuizResult(ModelQuizStatus.unavailable);
      }
    } on AuthException catch (error) {
      return ModelQuizResult(
        error.failure == AuthFailure.network
            ? ModelQuizStatus.unavailable
            : ModelQuizStatus.authenticationRequired,
      );
    } catch (_) {
      // No tokens, answers, or raw backend exception messages enter logs/UI.
      return const ModelQuizResult(ModelQuizStatus.unavailable);
    }
  }
}

Uri modelQuizEndpoint(Uri base, {bool allowLocalHttp = false}) {
  final local =
      base.scheme == 'http' &&
      allowLocalHttp &&
      {'localhost', '127.0.0.1', '::1', '10.0.2.2'}.contains(base.host);
  if ((!local && base.scheme != 'https') ||
      base.host.isEmpty ||
      base.userInfo.isNotEmpty ||
      base.hasQuery ||
      base.hasFragment) {
    throw ArgumentError('The shared API requires an HTTPS base URL.');
  }
  final path = base.path.endsWith('/') ? base.path : '${base.path}/';
  return base.replace(path: '${path}pcos/model-assessment');
}

String reportedModelQuizSummary(QuizAnswers answers) =>
    'Reported questionnaire answers\n'
    'Age: ${answers.age ?? 'Not supplied'}\n'
    'BMI: ${answers.bmi?.toStringAsFixed(1) ?? 'Not supplied'}\n'
    '${quizFields.entries.map((field) => '${field.value} ${answers.binary[field.key] == null
        ? 'Not sure'
        : answers.binary[field.key] == 1
        ? 'Yes'
        : 'No'}').join('\n')}\n'
    'These are self-reported answers, not confirmed clinical findings. '
    'This experiment cannot confirm or rule out PCOS.';
