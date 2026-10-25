import 'dart:async';
import 'dart:convert';

import 'package:auracare_mobile_app/app/session.dart';
import 'package:auracare_mobile_app/data/api_client.dart';
import 'package:auracare_mobile_app/data/auth_service.dart';
import 'package:auracare_mobile_app/data/services.dart';
import 'package:auracare_mobile_app/features/pcos_quiz/quiz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'auth_test.dart' show FakeAuth, now, syntheticSession;

Map<String, Object> response() => {
  'assessment_id': 'synthetic-assessment',
  'prediction': 'survey_summary',
  'risk_score': 4,
  'answered_questions': 4,
  'total_questions': 4,
  'reported_symptoms': [
    'irregular_periods',
    'acne',
    'excess_hair_growth',
    'scalp_hair_thinning',
  ],
  'method_version': 'survey-count-v1',
  'limitations':
      'Unvalidated survey summary only. Missing answers are unknown.',
};
QuizAnswers example() => QuizAnswers()
  ..age = 28
  ..kg = 64
  ..cm = 160
  ..knownDiagnosis = false
  ..hairThinningRefersToScalp = true
  ..binary.addAll({
    'regular_periods': 0,
    'acne': 1,
    'excess_hair': 1,
    'hair_thinning': 1,
    'weight_gain': 1,
    'skin_darkening': 0,
  });

void main() {
  for (final value in <int?>[0, 1, null]) {
    test('all supported integer mappings preserve $value', () {
      final answers = example();
      for (final key in answers.binary.keys) {
        answers.binary[key] = value;
      }
      final mapped = PcosQuestionnaireAdapter.map(answers).toJson();
      final expected = value == null ? null : value == 1;
      expect(mapped, {
        'irregular_periods': expected == null ? null : !expected,
        'acne': expected,
        'excess_hair_growth': expected,
        'scalp_hair_thinning': expected,
      });
      expect(jsonDecode(jsonEncode(mapped)), mapped);
    });
  }
  test('unsupported state remains intact and never enters request', () {
    final answers = example();
    final before = answers.toJson();
    expect(PcosQuestionnaireAdapter.map(answers).toJson().keys.toSet(), {
      'irregular_periods',
      'acne',
      'excess_hair_growth',
      'scalp_hair_thinning',
    });
    expect(answers.toJson(), before);
    expect(answers.bmi, closeTo(25, 0.0001));
  });
  test('general hair thinning is unknown without scalp clarification', () {
    final answers = example()..hairThinningRefersToScalp = false;
    expect(PcosQuestionnaireAdapter.map(answers).scalpHairThinning, isNull);
    expect(answers.binary['hair_thinning'], 1);
  });
  test('non-binary encodings fail instead of coercing', () {
    final answers = example()..binary['acne'] = 2;
    expect(
      () => PcosQuestionnaireAdapter.map(answers),
      throwsA(isA<ApiException>()),
    );
  });

  late FakeAuth gateway;
  late AuraAuthController auth;
  late MockClient transport;
  late AuthenticatedQuizService service;
  int sends = 0;
  Future<http.Response> Function(http.Request) handler = (_) async =>
      http.Response(jsonEncode(response()), 201);
  setUp(() {
    gateway = FakeAuth()..session = syntheticSession();
    auth = AuraAuthController(gateway: gateway, clock: () => now);
    sends = 0;
    handler = (request) async {
      expect(request.url.path, '/predict-pcos');
      expect(request.headers['Authorization'], 'Bearer synthetic-token');
      expect(
        jsonDecode(request.body),
        PcosQuestionnaireAdapter.map(example()).toJson(),
      );
      return http.Response(jsonEncode(response()), 201);
    };
    transport = MockClient((request) {
      sends++;
      return handler(request);
    });
    service = AuthenticatedQuizService(
      auth: auth,
      createClient: () => AuraApiClient(
        config: ApiConfig(baseUrl: 'https://example.com'),
        tokenProvider: auth,
        httpClient: transport,
        requestTimeout: const Duration(milliseconds: 100),
      ),
    );
  });
  tearDown(() async {
    service.dispose();
    transport.close();
    auth.dispose();
    await gateway.events.close();
  });

  test(
    'confirmed authenticated submission parses structured response',
    () async {
      expect(
        await service.assessConfirmed(example(), confirmed: true),
        QuizOutcome.summary,
      );
      final result = service.assessment!;
      expect(result.assessmentId, 'synthetic-assessment');
      expect(result.riskScore, 4);
      expect(result.answeredQuestions, 4);
      expect(result.totalQuestions, 4);
      expect(result.reportedSymptoms.length, 4);
      expect(result.methodVersion, 'survey-count-v1');
      expect(result.limitations, contains('Missing answers'));
      expect(sends, 1);
    },
  );
  test(
    'confirmation is required even when directly calling the service',
    () async {
      await expectLater(
        service.assess(example()),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        service.assessConfirmed(example(), confirmed: false),
        throwsA(isA<ApiException>()),
      );
      expect(sends, 0);
    },
  );
  for (final mode in [
    AccessMode.demo,
    AccessMode.signedOut,
    AccessMode.recovery,
  ]) {
    test('$mode cannot submit', () async {
      auth.mode = mode;
      await expectLater(
        service.assessConfirmed(example(), confirmed: true),
        throwsA(isA<ApiException>()),
      );
      expect(sends, 0);
    });
  }
  for (final status in [401, 403, 422, 503]) {
    test('HTTP $status is safe and preserves all answers', () async {
      handler = (_) async =>
          http.Response('{"detail":"secret raw error"}', status);
      final answers = example();
      final before = answers.toJson();
      await expectLater(
        service.assessConfirmed(answers, confirmed: true),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'safe message',
            isNot(contains('secret')),
          ),
        ),
      );
      expect(answers.toJson(), before);
      expect(service.assessment, isNull);
      expect(sends, 1);
    });
  }
  test('missing session denies transport', () async {
    gateway.session = null;
    await expectLater(
      service.assessConfirmed(example(), confirmed: true),
      throwsA(isA<ApiException>()),
    );
    expect(sends, 0);
  });
  test('invalid token is blocked before transport', () async {
    gateway.session = UserSession(
      userId: 'synthetic-user',
      token: 'invalid whitespace',
      expiresAt: now.add(const Duration(hours: 1)),
      emailVerified: true,
    );
    await expectLater(
      service.assessConfirmed(example(), confirmed: true),
      throwsA(
        isA<ApiException>().having(
          (e) => e.failure,
          'failure',
          ApiFailure.unauthenticated,
        ),
      ),
    );
    expect(sends, 0);
  });
  test('expired token refresh failure denies transport', () async {
    gateway.session = syntheticSession(expired: true);
    gateway.failure = StateError('internal refresh detail');
    await expectLater(
      service.assessConfirmed(example(), confirmed: true),
      throwsA(isA<ApiException>()),
    );
    expect(gateway.refreshes, 1);
    expect(sends, 0);
  });
  test('logout during submission discards its late result', () async {
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    handler = (_) {
      started.complete();
      return pending.future;
    };
    final result = service.assessConfirmed(example(), confirmed: true);
    await started.future;
    await auth.signOut();
    pending.complete(http.Response(jsonEncode(response()), 201));
    await expectLater(result, throwsA(isA<ApiException>()));
    expect(service.assessment, isNull);
  });
  test('all-unknown supported inputs fail locally', () async {
    await expectLater(
      service.assessConfirmed(QuizAnswers(), confirmed: true),
      throwsA(isA<ApiException>()),
    );
    expect(sends, 0);
  });
  test('network failure and malformed responses are safe', () async {
    for (final fail in [true, false]) {
      handler = (_) async {
        if (fail) throw StateError('internal network details');
        return http.Response('{}', 201);
      };
      await expectLater(
        service.assessConfirmed(example(), confirmed: true),
        throwsA(isA<ApiException>()),
      );
      expect(service.assessment, isNull);
    }
  });
  test('timeout never retries an ambiguous write', () async {
    final pending = Completer<http.Response>();
    handler = (_) => pending.future;
    await expectLater(
      service.assessConfirmed(example(), confirmed: true),
      throwsA(
        isA<ApiException>().having(
          (e) => e.failure,
          'timeout',
          ApiFailure.timeout,
        ),
      ),
    );
    expect(sends, 1);
    pending.complete(http.Response(jsonEncode(response()), 201));
  });
  test('overlapping submissions are rejected without a second send', () async {
    final pending = Completer<http.Response>();
    handler = (_) => pending.future;
    final first = service.assessConfirmed(example(), confirmed: true);
    await expectLater(
      service.assessConfirmed(example(), confirmed: true),
      throwsA(isA<ApiException>()),
    );
    pending.complete(http.Response(jsonEncode(response()), 201));
    await first;
    expect(sends, 1);
  });

  for (final failure in [false, true]) {
    testWidgets(
      'live quiz confirmation, ${failure ? 'failure preservation' : 'non-diagnostic result'}',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        handler = (_) async => failure
            ? http.Response('{}', 503)
            : http.Response(jsonEncode(response()), 201);
        final session = DemoSession(quizService: service);
        await tester.pumpWidget(
          SessionScope(
            session: session,
            child: const MaterialApp(home: QuizPage()),
          ),
        );
        await tester.tap(find.text('Load explicit synthetic example'));
        await tester.pumpAndSettle();
        final submit = find.byKey(const ValueKey('pcos-submit'));
        await tester.scrollUntilVisible(submit, 400);
        expect(tester.widget<FilledButton>(submit).onPressed, isNull);
        expect(sends, 0);
        await tester.ensureVisible(find.byKey(const ValueKey('pcos-confirm')));
        await tester.tap(find.byKey(const ValueKey('pcos-confirm')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(sends, 1);
        if (failure) {
          await tester.scrollUntilVisible(
            find.textContaining('Your answers are preserved.'),
            300,
          );
          expect(
            find.textContaining('Your answers are preserved.'),
            findsOneWidget,
          );
          await tester.scrollUntilVisible(
            find.text('Check your answers.'),
            -400,
          );
          expect(find.textContaining('Age: 28'), findsOneWidget);
        } else {
          expect(find.text('Reported symptom summary'), findsOneWidget);
          expect(find.textContaining('Reported symptoms: 4'), findsOneWidget);
          expect(
            find.textContaining('clinical risk classification'),
            findsOneWidget,
          );
          expect(
            find.textContaining('Unvalidated survey summary only'),
            findsOneWidget,
          );
        }
        await tester.pumpWidget(const SizedBox());
        session.dispose();
      },
    );
  }
}
