import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthClientOptions, AuthFlowType, SupabaseClient;
import 'package:auracare_mobile_app/app/auth_service.dart';
import 'package:auracare_mobile_app/app/supabase_auth_service.dart';

SupabaseClient _client(MockClient mockClient) => SupabaseClient(
  'https://auth-test.supabase.co',
  'public-test-key',
  authOptions: const AuthClientOptions(
    autoRefreshToken: false,
    authFlowType: AuthFlowType.implicit,
  ),
  httpClient: mockClient,
);

http.Response _jsonResponse(int status, Map<String, Object?> body) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, Object?> _user() => {
  'id': 'test-user',
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': 'alex@example.com',
  'email_confirmed_at': '2026-10-25T00:00:00Z',
  'user_metadata': {'display_name': 'Alex'},
  'app_metadata': {
    'provider': 'email',
    'providers': ['email'],
  },
  'created_at': '2026-10-25T00:00:00Z',
};

String _accessToken() {
  final expiry =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000;
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': 'test-user', 'exp': expiry})))
      .replaceAll('=', '');
  return 'eyJhbGciOiJub25lIn0.$payload.signature';
}

void main() {
  test('client configuration rejects secret and service-role key formats', () {
    String legacyKey(String role) {
      final payload = base64Url
          .encode(utf8.encode(jsonEncode({'role': role})))
          .replaceAll('=', '');
      return 'header.$payload.signature';
    }

    expect(isSupabasePublishableKey('sb_publishable_public-value'), isTrue);
    expect(isSupabasePublishableKey('sb_secret_server-value'), isFalse);
    expect(isSupabasePublishableKey(legacyKey('anon')), isTrue);
    expect(isSupabasePublishableKey(legacyKey('service_role')), isFalse);
    expect(isSupabasePublishableKey('not-a-supabase-key'), isFalse);
  });

  test(
    'registration submits schema-compatible display metadata and redirect',
    () async {
      late Map<String, dynamic> submitted;
      late Uri requestUri;
      final client = _client(
        MockClient((request) async {
          requestUri = request.url;
          submitted = jsonDecode(request.body) as Map<String, dynamic>;
          return _jsonResponse(200, {
            'id': 'new-user',
            'aud': 'authenticated',
            'email': 'alex@example.com',
            'user_metadata': {'display_name': 'Alex'},
            'app_metadata': {
              'provider': 'email',
              'providers': ['email'],
            },
            'created_at': '2026-10-25T00:00:00Z',
            'identities': [],
          });
        }),
      );
      addTearDown(client.dispose);
      final service = SupabaseAuthService(client);

      final result = await service.createAccount(
        fullName: 'Alex',
        email: 'alex@example.com',
        password: 'a-private-test-password',
      );

      expect(submitted['data'], {'display_name': 'Alex'});
      expect(requestUri.queryParameters['redirect_to'], supabaseRedirectUrl);
      expect(result.accountCreated, isTrue);
      expect(result.emailVerificationRequired, isTrue);
      expect(result.user, isNull);
    },
  );

  test(
    'login maps invalid credentials to a safe user-facing failure',
    () async {
      final client = _client(
        MockClient(
          (_) async => _jsonResponse(400, {
            'error_code': 'invalid_credentials',
            'msg': 'private provider error',
          }),
        ),
      );
      addTearDown(client.dispose);
      final service = SupabaseAuthService(client);

      await expectLater(
        service.signInWithPassword(
          email: 'alex@example.com',
          password: 'a-private-test-password',
        ),
        throwsA(
          isA<AuthException>().having(
            (exception) => exception.failure,
            'failure',
            AuthFailure.invalidCredentials,
          ),
        ),
      );
    },
  );

  test('sign-in restores the Supabase session and profile metadata', () async {
    final accessToken = _accessToken();
    final client = _client(
      MockClient((request) async {
        expect(request.url.path, '/auth/v1/token');
        return _jsonResponse(200, {
          'access_token': accessToken,
          'token_type': 'bearer',
          'expires_in': 3600,
          'refresh_token': 'refresh-test-token',
          'user': _user(),
        });
      }),
    );
    addTearDown(client.dispose);
    final service = SupabaseAuthService(client);

    final user = await service.signInWithPassword(
      email: 'alex@example.com',
      password: 'a-private-test-password',
    );
    final restoredUser = await service.restoreSession();

    expect(user.id, 'test-user');
    expect(user.email, 'alex@example.com');
    expect(user.displayName, 'Alex');
    expect(restoredUser?.id, 'test-user');
    expect(service.supportsGoogleSignIn, isFalse);
  });

  test('password update uses the authenticated Supabase session', () async {
    final accessToken = _accessToken();
    final client = _client(
      MockClient((request) async {
        if (request.url.path.endsWith('/token')) {
          return _jsonResponse(200, {
            'access_token': accessToken,
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': 'refresh-test-token',
            'user': _user(),
          });
        }
        expect(request.method, 'PUT');
        expect(request.url.path, '/auth/v1/user');
        expect(
          (jsonDecode(request.body) as Map<String, dynamic>)['password'],
          'a-new-private-password',
        );
        return _jsonResponse(200, _user());
      }),
    );
    addTearDown(client.dispose);
    final service = SupabaseAuthService(client);
    await service.signInWithPassword(
      email: 'alex@example.com',
      password: 'a-private-test-password',
    );

    final user = await service.updatePassword('a-new-private-password');

    expect(user.id, 'test-user');
  });

  test('password recovery uses the registered app redirect', () async {
    late Uri requestUri;
    final client = _client(
      MockClient((request) async {
        requestUri = request.url;
        return http.Response('', 200);
      }),
    );
    addTearDown(client.dispose);
    final service = SupabaseAuthService(client);

    await service.sendPasswordReset('alex@example.com');

    expect(requestUri.queryParameters['redirect_to'], supabaseRedirectUrl);
  });

  test('Google sign-in remains disabled without configured OAuth', () async {
    final client = _client(MockClient((_) async => http.Response('', 200)));
    addTearDown(client.dispose);
    final service = SupabaseAuthService(client);

    expect(service.isConfigured, isTrue);
    expect(service.supportsGoogleSignIn, isFalse);
    await expectLater(
      service.signInWithGoogle(),
      throwsA(
        isA<AuthException>().having(
          (exception) => exception.failure,
          'failure',
          AuthFailure.unavailable,
        ),
      ),
    );
  });
}
