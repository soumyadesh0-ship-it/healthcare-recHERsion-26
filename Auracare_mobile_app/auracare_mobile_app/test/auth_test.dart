import 'dart:async';

import 'package:auracare_mobile_app/app/auth_root.dart';
import 'package:auracare_mobile_app/app/session.dart';
import 'package:auracare_mobile_app/data/api_client.dart';
import 'package:auracare_mobile_app/data/auth_service.dart';
import 'package:auracare_mobile_app/features/auth/auth_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

final now = DateTime.utc(2026, 10, 25);
UserSession syntheticSession({bool expired = false, bool verified = true}) =>
    UserSession(
      userId: 'synthetic-user',
      token: 'synthetic-token',
      expiresAt: now.add(Duration(minutes: expired ? -1 : 60)),
      emailVerified: verified,
    );

class FakeAuth implements AuthGateway {
  @override
  UserSession? session;
  final events = StreamController<AuthUpdate>.broadcast(sync: true);
  Object? failure;
  Completer<void>? pending;
  UserSession? signupSession;
  int signups = 0;
  int refreshes = 0, signOuts = 0, resets = 0, updates = 0, resends = 0;
  @override
  Stream<AuthUpdate> get changes => events.stream;
  @override
  Future<void> signIn(String email, String password) async {
    if (pending != null) await pending!.future;
    if (failure != null) throw failure!;
    session = syntheticSession();
    events.add(AuthUpdate(AuthEvent.signedIn, session));
  }

  @override
  Future<UserSession?> signUp(String email, String password) async {
    signups++;
    if (failure != null) throw failure!;
    if (signupSession != null) session = signupSession;
    return signupSession;
  }

  @override
  Future<void> resendVerification(String email) async {
    resends++;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    resets++;
  }

  @override
  Future<void> updatePassword(String password) async {
    updates++;
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    session = null;
    events.add(const AuthUpdate(AuthEvent.signedOut, null));
  }

  @override
  Future<UserSession?> refresh() async {
    refreshes++;
    if (failure != null) throw failure!;
    session = syntheticSession();
    events.add(AuthUpdate(AuthEvent.refreshed, session));
    return session;
  }
}

void main() {
  late FakeAuth gateway;
  late AuraAuthController auth;
  setUp(() {
    gateway = FakeAuth();
    auth = AuraAuthController(gateway: gateway, clock: () => now);
  });
  tearDown(() async {
    auth.dispose();
    await gateway.events.close();
  });

  test('successful sign in supplies current user bearer token', () async {
    await auth.signIn('synthetic@example.com', 'password');
    expect(auth.mode, AccessMode.authenticated);
    expect(await auth.accessToken(), 'synthetic-token');
  });
  test('signup confirmation never reuses an unrelated SDK session', () async {
    gateway.session = syntheticSession();
    await auth.signUp('new-synthetic@example.com', 'password');
    expect(gateway.signups, 1);
    expect(auth.mode, AccessMode.signedOut);
    expect(await auth.accessToken(), isNull);
    expect(auth.message, contains('verification email'));
  });
  test('signup can accept its own verified session', () async {
    gateway.signupSession = syntheticSession();
    await auth.signUp('synthetic@example.com', 'password');
    expect(auth.mode, AccessMode.authenticated);
    expect(await auth.accessToken(), 'synthetic-token');
  });
  test('signup failure is sanitized and grants no access', () async {
    gateway.failure = StateError('internal signup secret');
    await auth.signUp('synthetic@example.com', 'password');
    expect(auth.mode, AccessMode.signedOut);
    expect(auth.error, const AuthFailure(AuthProblem.unavailable).message);
    expect(await auth.accessToken(), isNull);
  });
  test('empty initial session still accepts later confirmation', () async {
    gateway.events.add(const AuthUpdate(AuthEvent.restored, null));
    expect(auth.error, isNull);
    gateway.session = syntheticSession();
    gateway.events.add(AuthUpdate(AuthEvent.signedIn, gateway.session));
    expect(auth.mode, AccessMode.authenticated);
  });
  test(
    'API uses refreshed controller token and stops sending after logout',
    () async {
      await auth.signIn('synthetic@example.com', 'password');
      gateway.session = syntheticSession(expired: true);
      var sends = 0;
      final transport = MockClient((request) async {
        sends++;
        expect(request.headers['Authorization'], 'Bearer synthetic-token');
        return http.Response('{"response":"Synthetic response"}', 200);
      });
      final api = AuraApiClient(
        config: ApiConfig(baseUrl: 'https://example.com'),
        tokenProvider: auth,
        httpClient: transport,
      );
      addTearDown(() {
        api.close();
        transport.close();
      });
      expect(
        await api.chat(prompt: 'synthetic', aiProcessingConfirmed: true),
        'Synthetic response',
      );
      expect(gateway.refreshes, 1);
      await auth.signOut();
      await expectLater(
        api.chat(prompt: 'synthetic', aiProcessingConfirmed: true),
        throwsA(
          isA<ApiException>().having(
            (e) => e.failure,
            'failure',
            ApiFailure.unauthenticated,
          ),
        ),
      );
      expect(sends, 1);
    },
  );
  test('invalid credentials show fixed safe message', () async {
    gateway.failure = const AuthFailure(AuthProblem.invalidCredentials);
    await auth.signIn('synthetic@example.com', 'wrong');
    expect(auth.mode, AccessMode.signedOut);
    expect(auth.error, contains('Check your email and password'));
    expect(await auth.accessToken(), isNull);
  });
  test('sign out revokes access immediately', () async {
    await auth.signIn('synthetic@example.com', 'password');
    await auth.signOut();
    expect(gateway.signOuts, 1);
    expect(auth.mode, AccessMode.signedOut);
    expect(await auth.accessToken(), isNull);
  });
  test('expired session refresh is coalesced for concurrent callers', () async {
    await auth.signIn('synthetic@example.com', 'password');
    gateway.session = syntheticSession(expired: true);
    expect(await Future.wait([auth.accessToken(), auth.accessToken()]), [
      'synthetic-token',
      'synthetic-token',
    ]);
    expect(gateway.refreshes, 1);
  });
  test('failed refresh expires access without exposing SDK error', () async {
    await auth.signIn('synthetic@example.com', 'password');
    gateway.session = syntheticSession(expired: true);
    gateway.failure = StateError('secret-internal-token');
    expect(await auth.accessToken(), isNull);
    expect(auth.mode, AccessMode.signedOut);
    expect(auth.error, isNot(contains('secret')));
  });
  test('restored session refreshes before protected access', () async {
    auth.dispose();
    gateway.session = syntheticSession(expired: true);
    auth = AuraAuthController(gateway: gateway, clock: () => now);
    expect(auth.mode, AccessMode.authenticated);
    expect(await auth.accessToken(), 'synthetic-token');
    expect(gateway.refreshes, 1);
  });
  test('unverified restoration grants no access', () async {
    gateway.events.add(
      AuthUpdate(AuthEvent.restored, syntheticSession(verified: false)),
    );
    expect(auth.mode, AccessMode.signedOut);
    expect(await auth.accessToken(), isNull);
  });
  test('demo ignores restored, refreshed and recovery sessions', () async {
    auth.enterDemo();
    gateway.session = syntheticSession();
    for (final event in AuthEvent.values) {
      gateway.events.add(AuthUpdate(event, gateway.session));
      expect(auth.mode, AccessMode.demo);
      expect(await auth.accessToken(), isNull);
    }
    auth.leaveDemo();
    expect(await auth.accessToken(), isNull);
  });
  test(
    'unauthenticated and demo protected requests never reach transport',
    () async {
      var sent = 0;
      final http = MockClient((request) async {
        sent++;
        throw StateError('sent');
      });
      final api = AuraApiClient(
        config: ApiConfig(baseUrl: 'https://example.com'),
        tokenProvider: auth,
        httpClient: http,
      );
      addTearDown(() {
        api.close();
        http.close();
      });
      for (final demo in [false, true]) {
        if (demo) auth.enterDemo();
        await expectLater(
          api.chat(prompt: 'synthetic', aiProcessingConfirmed: true),
          throwsA(
            isA<ApiException>().having(
              (e) => e.failure,
              'failure',
              ApiFailure.unauthenticated,
            ),
          ),
        );
      }
      expect(sent, 0);
    },
  );
  test(
    'signup waits for verification and reset uses recovery with no token',
    () async {
      await auth.signUp('synthetic@example.com', 'password');
      expect(auth.mode, AccessMode.signedOut);
      expect(auth.message, contains('verification email'));
      await auth.requestPasswordReset('synthetic@example.com');
      expect(gateway.resets, 1);
      gateway.session = syntheticSession();
      gateway.events.add(AuthUpdate(AuthEvent.recovery, gateway.session));
      expect(auth.mode, AccessMode.recovery);
      expect(await auth.accessToken(), isNull);
      await auth.updatePassword('new-password');
      expect(gateway.updates, 1);
      expect(auth.mode, AccessMode.signedOut);
    },
  );
  test('timed out sign in cannot grant late access', () async {
    auth.dispose();
    auth = AuraAuthController(
      gateway: gateway,
      clock: () => now,
      operationTimeout: const Duration(milliseconds: 1),
    );
    gateway.pending = Completer<void>();
    await auth.signIn('synthetic@example.com', 'password');
    gateway.pending!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(auth.mode, AccessMode.signedOut);
    expect(await auth.accessToken(), isNull);
  });
  test('configuration rejects privileged and missing keys', () {
    for (final key in ['', 'sb_secret_synthetic', 'service_role']) {
      expect(
        () => SupabaseConfiguration(
          url: 'https://example.supabase.co',
          anonKey: key,
        ),
        throwsA(isA<AuthFailure>()),
      );
    }
  });
  testWidgets('login validates, shows loading and sanitized failure', (
    tester,
  ) async {
    gateway.pending = Completer<void>();
    gateway.failure = StateError('internal secret');
    await tester.pumpWidget(MaterialApp(home: AuthPage(auth: auth)));
    await tester.ensureVisible(find.byKey(const ValueKey('auth-submit')));
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pump();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'synthetic@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'password',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('auth-submit')));
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('auth-submit')))
          .onPressed,
      isNull,
    );
    gateway.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('auth-error')), findsOneWidget);
    expect(find.textContaining('internal secret'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('demo records are discarded at the account entry boundary', (
    tester,
  ) async {
    await tester.pumpWidget(AuthenticationRoot(auth: auth));
    auth.enterDemo();
    await tester.pumpAndSettle();
    final demo = tester
        .widget<SessionScope>(find.byType(SessionScope))
        .notifier!;
    demo.addQuestion('Synthetic demo-only question');
    auth.leaveDemo();
    await tester.pumpAndSettle();
    await auth.signIn('synthetic@example.com', 'password');
    await tester.pumpAndSettle();
    final account = tester
        .widget<SessionScope>(find.byType(SessionScope))
        .notifier!;
    expect(identical(demo, account), isFalse);
    expect(account.questions, isEmpty);
    expect(account.records.entries, isEmpty);
    expect(find.text('Sign out'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
