import 'dart:async';
import 'dart:convert';

import 'package:auracare_mobile_app/data/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeTokens implements AccessTokenProvider {
  FakeTokens([this.token = 'synthetic-user-token']);
  String? token;
  int calls = 0;
  Object? error;
  Completer<String?>? pending;

  @override
  Future<String?> accessToken() async {
    calls++;
    if (error != null) throw error!;
    return pending == null ? token : pending!.future;
  }
}

class AbortAwareClient extends http.BaseClient {
  bool closed = false;
  final started = Completer<void>();
  final aborted = Completer<void>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    started.complete();
    await (request as http.AbortableRequest).abortTrigger;
    aborted.complete();
    throw http.RequestAbortedException();
  }

  @override
  void close() => closed = true;
}

Matcher failure(ApiFailure kind, {int? status}) => isA<ApiException>()
    .having((e) => e.failure, 'failure', kind)
    .having((e) => e.statusCode, 'status', status);

Map<String, Object> assessment() => {
  'assessment_id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'prediction': 'insufficient_data',
  'risk_score': 1,
  'answered_questions': 2,
  'total_questions': 4,
  'reported_symptoms': ['irregular_periods'],
  'method_version': 'survey-count-v1',
  'limitations': 'Synthetic unvalidated summary; not a diagnosis.',
};

void main() {
  late FakeTokens tokens;
  late AuraApiClient api;
  late int requests;

  void setup(
    Future<http.Response> Function(http.Request) handler, {
    Duration timeout = const Duration(seconds: 1),
    String url = 'https://synthetic-backend.invalid',
  }) {
    api = AuraApiClient(
      config: ApiConfig(baseUrl: url),
      tokenProvider: tokens,
      requestTimeout: timeout,
      httpClient: MockClient((request) {
        requests++;
        return handler(request);
      }),
    );
    addTearDown(api.close);
  }

  setUp(() {
    tokens = FakeTokens();
    requests = 0;
  });

  group('configuration', () {
    test('missing dart-define fails closed', () {
      // The suite is run without a backend URL define.
      expect(
        ApiConfig.fromEnvironment,
        throwsA(failure(ApiFailure.configuration)),
      );
    });

    for (final url in [
      '',
      'not a URL',
      '/relative',
      'ftp://example.invalid',
      'https://user:password@example.invalid',
      'https://example.invalid?token=fake',
      'https://example.invalid#fake',
      'https://example.invalid/../escape',
      'http://example.invalid',
      'http://8.8.8.8',
    ]) {
      test('rejects unsafe URL $url', () {
        expect(
          () => ApiConfig(baseUrl: url, allowDevelopmentHttp: true),
          throwsA(failure(ApiFailure.configuration)),
        );
      });
    }

    for (final host in [
      'localhost',
      '127.0.0.1',
      '10.0.2.2',
      '192.168.1.20',
      '172.16.0.2',
    ]) {
      test('permits explicitly opted-in debug local HTTP for $host', () {
        expect(
          ApiConfig(
            baseUrl: 'http://$host:8000',
            allowDevelopmentHttp: true,
          ).baseUri.host,
          host,
        );
        expect(
          () => ApiConfig(baseUrl: 'http://$host:8000'),
          throwsA(failure(ApiFailure.configuration)),
        );
      });
    }

    test('normalizes base URL without dropping proxy path prefix', () {
      expect(
        ApiConfig(baseUrl: ' https://example.invalid/aura/// ').baseUri
            .toString(),
        'https://example.invalid/aura/',
      );
    });
  });

  test('chat matches contract and sends only supplied text', () async {
    setup((request) async {
      expect(
        request.url.toString(),
        'https://synthetic-backend.invalid/proxy/chat',
      );
      expect(request.method, 'POST');
      expect(request.followRedirects, isFalse);
      expect(request.headers['Authorization'], 'Bearer synthetic-user-token');
      expect(request.headers['Content-Type'], contains('application/json'));
      expect(jsonDecode(request.body), {
        'prompt': 'Synthetic health question',
        'ai_processing_confirmed': true,
      });
      return http.Response(
        jsonEncode({'response': 'Synthetic information.'}),
        200,
      );
    }, url: 'https://synthetic-backend.invalid/proxy');
    expect(
      await api.chat(
        prompt: '  Synthetic health question  ',
        aiProcessingConfirmed: true,
      ),
      'Synthetic information.',
    );
    expect(tokens.calls, 1);
  });

  test('survey preserves false/null and decodes all response fields', () async {
    setup((request) async {
      expect(request.url.path, '/predict-pcos');
      expect(jsonDecode(request.body), {
        'irregular_periods': true,
        'acne': false,
        'excess_hair_growth': null,
        'scalp_hair_thinning': null,
      });
      return http.Response(jsonEncode(assessment()), 201);
    });
    final result = await api.predictPcos(
      const PcosSurveyAnswers(irregularPeriods: true, acne: false),
    );
    expect(result.assessmentId, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
    expect(result.prediction, 'insufficient_data');
    expect(result.riskScore, 1);
    expect(result.answeredQuestions, 2);
    expect(result.totalQuestions, 4);
    expect(result.reportedSymptoms, ['irregular_periods']);
    expect(result.methodVersion, 'survey-count-v1');
    expect(result.limitations, contains('not a diagnosis'));
    expect(result.toString(), 'PcosAssessment');
  });

  test(
    'refusal, invalid prompt and all-null survey do not acquire tokens',
    () async {
      setup((_) async => throw StateError('Must not send'));
      await expectLater(
        api.chat(prompt: 'Synthetic', aiProcessingConfirmed: false),
        throwsA(failure(ApiFailure.forbidden)),
      );
      for (final prompt in ['', '   ', 'x' * 10001]) {
        await expectLater(
          api.chat(prompt: prompt, aiProcessingConfirmed: true),
          throwsA(failure(ApiFailure.validation)),
        );
      }
      await expectLater(
        api.predictPcos(const PcosSurveyAnswers()),
        throwsA(failure(ApiFailure.validation)),
      );
      expect(tokens.calls, 0);
      expect(requests, 0);
    },
  );

  for (final token in [null, '', ' ', 'Bearer fake', 'fake\r\ninjected']) {
    test(
      'missing/invalid token never sends request: ${token == null ? 'null' : token.length}',
      () async {
        tokens.token = token;
        setup((_) async => throw StateError('Must not send'));
        await expectLater(
          api.predictPcos(const PcosSurveyAnswers(acne: true)),
          throwsA(failure(ApiFailure.unauthenticated)),
        );
        expect(requests, 0);
      },
    );
  }

  test('token-provider exceptions do not leak details', () async {
    tokens.error = StateError('SYNTHETIC_PRIVATE_TOKEN');
    setup((_) async => throw StateError('Must not send'));
    await expectLater(
      api.predictPcos(const PcosSurveyAnswers(acne: true)),
      throwsA(failure(ApiFailure.unauthenticated)),
    );
    expect(requests, 0);
  });

  test('token is fetched afresh after rotation', () async {
    final seen = <String?>[];
    setup((request) async {
      seen.add(request.headers['Authorization']);
      return http.Response('{"response":"Synthetic"}', 200);
    });
    await api.chat(prompt: 'Synthetic', aiProcessingConfirmed: true);
    tokens.token = 'synthetic-rotated-token';
    await api.chat(prompt: 'Synthetic', aiProcessingConfirmed: true);
    expect(seen, [
      'Bearer synthetic-user-token',
      'Bearer synthetic-rotated-token',
    ]);
    expect(tokens.calls, 2);
  });

  test('overlapping token lookups keep authorization request-local', () async {
    final seen = <String, String?>{};
    setup((request) async {
      seen[jsonDecode(request.body)['prompt'] as String] =
          request.headers['Authorization'];
      return http.Response('{"response":"Synthetic"}', 200);
    });
    final firstToken = Completer<String?>();
    final secondToken = Completer<String?>();
    tokens.pending = firstToken;
    final first = api.chat(prompt: 'Synthetic A', aiProcessingConfirmed: true);
    tokens.pending = secondToken;
    final second = api.chat(prompt: 'Synthetic B', aiProcessingConfirmed: true);
    secondToken.complete('synthetic-token-b');
    firstToken.complete('synthetic-token-a');
    await Future.wait([first, second]);
    expect(seen, {
      'Synthetic A': 'Bearer synthetic-token-a',
      'Synthetic B': 'Bearer synthetic-token-b',
    });
  });

  for (final value in ['-1', 'invalid-private-marker', '']) {
    test('invalid Retry-After is omitted: ${value.length}', () async {
      setup(
        (_) async => http.Response('', 429, headers: {'retry-after': value}),
      );
      try {
        await api.chat(prompt: 'Synthetic', aiProcessingConfirmed: true);
        fail('Expected rate limit');
      } on ApiException catch (error) {
        expect(error.retryAfter, isNull);
        expect(
          error.message,
          isNot(contains(value.isEmpty ? 'marker' : value)),
        );
      }
    });
  }

  const errors = {
    401: ApiFailure.unauthenticated,
    403: ApiFailure.forbidden,
    400: ApiFailure.validation,
    422: ApiFailure.validation,
    429: ApiFailure.rateLimited,
    500: ApiFailure.unavailable,
    502: ApiFailure.unavailable,
    503: ApiFailure.unavailable,
    404: ApiFailure.rejected,
    307: ApiFailure.rejected,
  };
  for (final entry in errors.entries) {
    test(
      'safe HTTP ${entry.key} handling without retries or body disclosure',
      () async {
        setup(
          (_) async => http.Response(
            'SYNTHETIC_PRIVATE_BODY_AND_TOKEN',
            entry.key,
            headers: {'retry-after': '60'},
          ),
        );
        try {
          await api.chat(prompt: 'Synthetic', aiProcessingConfirmed: true);
          fail('Expected failure');
        } on ApiException catch (error) {
          expect(error, failure(entry.value, status: entry.key));
          expect(error.retryAfter, const Duration(seconds: 60));
          expect(
            '${error.message} $error',
            isNot(contains('SYNTHETIC_PRIVATE')),
          );
        }
        expect(requests, 1);
      },
    );
  }

  for (final body in [
    'not JSON: SYNTHETIC_PRIVATE',
    '[]',
    'null',
    '{}',
    '{"response":42}',
    '{"response":" "}',
  ]) {
    test('rejects malformed chat response ${body.length}', () async {
      setup((_) async => http.Response(body, 200));
      await expectLater(
        api.chat(prompt: 'Synthetic', aiProcessingConfirmed: true),
        throwsA(failure(ApiFailure.invalidResponse)),
      );
    });
  }

  for (final field in assessment().keys) {
    test('rejects missing assessment field $field', () async {
      final json = assessment()..remove(field);
      setup((_) async => http.Response(jsonEncode(json), 201));
      await expectLater(
        api.predictPcos(const PcosSurveyAnswers(acne: true)),
        throwsA(failure(ApiFailure.invalidResponse)),
      );
    });
  }

  test('network exception is sanitized and not retried', () async {
    setup((_) async => throw http.ClientException('SYNTHETIC_PRIVATE'));
    await expectLater(
      api.chat(prompt: 'Synthetic', aiProcessingConfirmed: true),
      throwsA(failure(ApiFailure.network)),
    );
    expect(requests, 1);
  });

  test('deadline aborts transport, not only the caller Future', () async {
    final transport = AbortAwareClient();
    api = AuraApiClient(
      config: ApiConfig(baseUrl: 'https://example.invalid'),
      tokenProvider: tokens,
      httpClient: transport,
      requestTimeout: const Duration(milliseconds: 30),
    );
    addTearDown(api.close);
    await expectLater(
      api.chat(prompt: 'Synthetic', aiProcessingConfirmed: true),
      throwsA(failure(ApiFailure.timeout)),
    );
    await transport.aborted.future;
  });

  test('token resolving after deadline cannot send a late request', () async {
    tokens.pending = Completer<String?>();
    setup(
      (_) async => throw StateError('Must not send'),
      timeout: const Duration(milliseconds: 30),
    );
    await expectLater(
      api.chat(prompt: 'Synthetic', aiProcessingConfirmed: true),
      throwsA(failure(ApiFailure.timeout)),
    );
    tokens.pending!.complete('synthetic-late-token');
    await Future<void>.delayed(Duration.zero);
    expect(requests, 0);
  });

  test(
    'close aborts in-flight work without closing caller-owned HTTP client',
    () async {
      final transport = AbortAwareClient();
      api = AuraApiClient(
        config: ApiConfig(baseUrl: 'https://example.invalid'),
        tokenProvider: tokens,
        httpClient: transport,
      );
      final future = api.chat(prompt: 'Synthetic', aiProcessingConfirmed: true);
      final assertion = expectLater(
        future,
        throwsA(failure(ApiFailure.closed)),
      );
      await transport.started.future;
      api.close();
      await assertion;
      expect(transport.closed, isFalse);
      api.close();
      await expectLater(
        api.checkConnection(),
        throwsA(failure(ApiFailure.closed)),
      );
    },
  );

  test(
    'diagnostics request no token and only inspect public contract',
    () async {
      tokens.error = StateError('Provider must not be consulted');
      setup((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/openapi.json');
        expect(request.headers.containsKey('Authorization'), isFalse);
        expect(request.body, isEmpty);
        return http.Response(
          jsonEncode({
            'paths': {
              '/chat': {'post': {}},
              '/predict-pcos': {'post': {}},
            },
          }),
          200,
        );
      });
      expect(await api.checkConnection(), isTrue);
      expect(tokens.calls, 0);
      expect(requests, 1);
    },
  );

  test('diagnostics report a mismatched contract', () async {
    setup((_) async => http.Response('{"paths":{}}', 200));
    expect(await api.checkConnection(), isFalse);
  });
}
