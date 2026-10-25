import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:auracare_mobile_app/app/auth_service.dart';
import 'package:auracare_mobile_app/data/model_quiz_service.dart';
import 'package:auracare_mobile_app/data/services.dart';

class Tokens implements AccessTokenProvider {
  String? value = 'current-user-token';
  int calls = 0;
  @override
  Future<String?> accessToken() async {
    calls++;
    return value;
  }
}

Map<String, Object?> result([String status = 'experimental_result']) => {
  'status': status,
  'method_version': 'trained-random-forest-v1',
  if (status == 'experimental_result') ...{
    'model': 'random_forest',
    'experimental_model_score': 0.314159,
    'score_target': 'self_reported_prior_pcos_diagnosis_in_training_sample',
    'bmi_imputed': true,
  },
};

void main() {
  test('Flutter payload matches the actual eight-field model contract', () {
    final contract = jsonDecode(
      File('../../auracare_pcos/quiz_contract.json').readAsStringSync(),
    ) as Map;
    final keys = (contract['questions'] as List).map((entry) => entry['key']);
    final answers = QuizAnswers()
      ..age = 28
      ..kg = 64
      ..cm = 160;
    answers.binary['regular_periods'] = 1;
    answers.binary['acne'] = null;
    final payload = modelQuizPayload(answers);
    expect(payload.keys.toSet(), {...keys, 'known_pcos_diagnosis'});
    expect(payload['regular_periods'], 1);
    expect(payload.containsKey('irregular_periods'), isFalse);
    expect(payload['acne'], isNull);
    expect(payload['bmi'], closeTo(25, .000001));
    expect(payload['known_pcos_diagnosis'], isFalse);
    expect(payload.containsKey('kg'), isFalse);
    expect(payload.containsKey('cm'), isFalse);
  });

  test('POST uses the current token each time and refuses redirects', () async {
    final tokens = Tokens();
    final seen = <String?>[];
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'https://api.example/team/pcos/model-assessment',
      );
      expect(request.followRedirects, isFalse);
      seen.add(request.headers['Authorization']);
      expect(jsonDecode(request.body)['regular_periods'], 0);
      return http.Response(jsonEncode(result()), 200);
    });
    addTearDown(client.close);
    final service = AuthenticatedModelQuizService(
      baseUrl: Uri.parse('https://api.example/team'),
      tokens: tokens,
      client: client,
    );
    final answers = QuizAnswers()..age = 28;
    answers.binary['regular_periods'] = 0;
    final first = await service.assess(answers);
    expect(first.status, ModelQuizStatus.experimental);
    expect(first.bmiImputed, isTrue);
    expect(first.scoreOutOf100, closeTo(31.4159, .00001));
    tokens.value = 'refreshed-current-token';
    await service.assess(answers);
    expect(seen, [
      'Bearer current-user-token',
      'Bearer refreshed-current-token',
    ]);
    expect(tokens.calls, 2);
  });

  test('no session never sends an HTTP request', () async {
    final tokens = Tokens()..value = null;
    final client = MockClient((_) async => throw StateError('Should not send'));
    addTearDown(client.close);
    final service = AuthenticatedModelQuizService(
      baseUrl: Uri.parse('https://api.example'),
      tokens: tokens,
      client: client,
    );
    expect(
      (await service.assess(QuizAnswers())).status,
      ModelQuizStatus.authenticationRequired,
    );
  });

  test(
    'abstentions map explicitly and legacy summary responses are rejected',
    () async {
      for (final entry in {
        'insufficient_inputs': ModelQuizStatus.insufficient,
        'outside_experimental_scope': ModelQuizStatus.outsideScope,
        'tracking_journey': ModelQuizStatus.tracking,
        'unknown': ModelQuizStatus.unavailable,
      }.entries) {
        final client = MockClient(
          (_) async => http.Response(jsonEncode(result(entry.key)), 200),
        );
        addTearDown(client.close);
        final service = AuthenticatedModelQuizService(
          baseUrl: Uri.parse('https://api.example'),
          tokens: Tokens(),
          client: client,
        );
        expect((await service.assess(QuizAnswers())).status, entry.value);
      }
      for (final response in [
        {'method_version': 'survey-count-v1', 'risk_score': 3},
        {...result(), 'model': 'replacement'},
        {...result(), 'experimental_model_score': 5},
        {...result(), 'experimental_model_score': '0.2'},
        {...result(), 'score_target': 'pcos_probability'},
      ]) {
        final client = MockClient(
          (_) async => http.Response(jsonEncode(response), 200),
        );
        addTearDown(client.close);
        expect(
          (await AuthenticatedModelQuizService(
            baseUrl: Uri.parse('https://api.example'),
            tokens: Tokens(),
            client: client,
          ).assess(QuizAnswers())).status,
          ModelQuizStatus.unavailable,
        );
      }
    },
  );

  test(
    'HTTP errors, malformed JSON, timeout and network failures stay honest',
    () async {
      for (final entry in {
        401: ModelQuizStatus.authenticationRequired,
        403: ModelQuizStatus.authenticationRequired,
        422: ModelQuizStatus.invalidInputs,
        503: ModelQuizStatus.unavailable,
        500: ModelQuizStatus.unavailable,
        302: ModelQuizStatus.unavailable,
        200: ModelQuizStatus.unavailable,
      }.entries) {
        final client = MockClient(
          (_) async => http.Response('invalid response', entry.key),
        );
        addTearDown(client.close);
        final service = AuthenticatedModelQuizService(
          baseUrl: Uri.parse('https://api.example'),
          tokens: Tokens(),
          client: client,
        );
        expect((await service.assess(QuizAnswers())).status, entry.value);
      }
      for (final error in [
        TimeoutException('timeout'),
        http.ClientException('offline'),
      ]) {
        final client = MockClient((_) async => throw error);
        addTearDown(client.close);
        expect(
          (await AuthenticatedModelQuizService(
            baseUrl: Uri.parse('https://api.example'),
            tokens: Tokens(),
            client: client,
          ).assess(QuizAnswers())).status,
          ModelQuizStatus.unavailable,
        );
      }
    },
  );

  test(
    'base URL requires HTTPS except explicitly enabled local development',
    () {
      for (final base in [
        'http://api.example',
        'https://user:pass@api.example',
        'https://api.example?secret=x',
        'file:///tmp/api',
      ]) {
        expect(() => modelQuizEndpoint(Uri.parse(base)), throwsArgumentError);
      }
      expect(
        () => modelQuizEndpoint(Uri.parse('http://127.0.0.1:8000')),
        throwsArgumentError,
      );
      expect(
        modelQuizEndpoint(
          Uri.parse('http://127.0.0.1:8000'),
          allowLocalHttp: true,
        ).path,
        '/pcos/model-assessment',
      );
      expect(
        () => modelQuizEndpoint(
          Uri.parse('http://api.example'),
          allowLocalHttp: true,
        ),
        throwsArgumentError,
      );
    },
  );
}
