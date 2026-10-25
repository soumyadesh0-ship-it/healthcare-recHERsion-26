import 'dart:async';
import 'dart:convert';

import 'package:auracare_mobile_app/app/theme.dart';
import 'package:auracare_mobile_app/data/chat_service.dart';
import 'package:auracare_mobile_app/features/assistant/assistant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('chat sends only prompt and reads the response string', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), 'http://127.0.0.1:8000/chat');
      expect(jsonDecode(request.body), {'prompt': 'Hello'});
      return http.Response(
        jsonEncode({'response': 'Hello from AuraCare'}),
        200,
      );
    });
    addTearDown(client.close);
    expect(
      await ChatService(
        client: client,
        baseUrl: 'http://127.0.0.1:8000/',
      ).send(' Hello '),
      'Hello from AuraCare',
    );
  });

  test('missing config, backend errors, malformed replies and network errors are handled', () async {
    for (final base in ['', 'invalid', 'ftp://localhost']) {
      final client = MockClient((_) async => throw StateError('must not send'));
      addTearDown(client.close);
      await expectLater(
        ChatService(client: client, baseUrl: base).send('Hi'),
        throwsA(isA<ChatException>()),
      );
    }
    for (final result in [
      http.Response('provider error', 500),
      http.Response('{}', 200),
      http.Response('not json', 200),
    ]) {
      final client = MockClient((_) async => result);
      addTearDown(client.close);
      await expectLater(
        ChatService(
          client: client,
          baseUrl: 'http://localhost:8000',
        ).send('Hi'),
        throwsA(isA<ChatException>()),
      );
    }
    final client = MockClient(
      (_) async => throw http.ClientException('offline'),
    );
    addTearDown(client.close);
    await expectLater(
      ChatService(client: client, baseUrl: 'http://localhost:8000').send('Hi'),
      throwsA(isA<ChatException>()),
    );
  });

  test(
    'provider status messages distinguish busy, rate limited and timeout',
    () async {
      for (final status in [429, 503, 504]) {
        final client = MockClient(
          (_) async => http.Response('private provider details', status),
        );
        addTearDown(client.close);
        final expected = switch (status) {
          429 => 'request limit',
          503 => 'temporarily unavailable',
          _ => 'too long',
        };
        await expectLater(
          ChatService(
            client: client,
            baseUrl: 'http://localhost:8000',
          ).send('Hi'),
          throwsA(
            isA<ChatException>().having(
              (e) => e.message,
              'message',
              contains(expected),
            ),
          ),
        );
      }
    },
  );

  testWidgets('send displays user message, loading, then assistant response', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    final client = MockClient((_) => response.future);
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: auracareTheme(),
        home: Scaffold(
          body: AssistantPage(
            service: ChatService(
              client: client,
              baseUrl: 'http://localhost:8000',
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('chat-input')), 'Hello');
    await tester.tap(find.byKey(const ValueKey('chat-send')));
    await tester.pump();
    expect(find.text('Hello'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('chat-send')))
          .onPressed,
      isNull,
    );
    response.complete(http.Response('{"response":"Hello from AuraCare"}', 200));
    await tester.pumpAndSettle();
    expect(find.text('Hello from AuraCare'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failure preserves the prompt for retry', (tester) async {
    final client = MockClient((_) async => http.Response('{}', 500));
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssistantPage(
            service: ChatService(
              client: client,
              baseUrl: 'http://localhost:8000',
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('chat-input')), 'Hello');
    await tester.tap(find.byKey(const ValueKey('chat-send')));
    await tester.pumpAndSettle();
    expect(find.textContaining('assistant is unavailable'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('chat-input')))
          .controller!
          .text,
      'Hello',
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
