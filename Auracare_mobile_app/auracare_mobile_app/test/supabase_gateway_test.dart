import 'dart:convert';

import 'package:auracare_mobile_app/data/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sdk;

Map<String, Object?> user({bool verified = true}) => {
  'id': 'synthetic-user',
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': 'synthetic@example.com',
  if (verified) 'email_confirmed_at': '2026-10-25T00:00:00Z',
  'user_metadata': {'display_name': 'Synthetic Person'},
  'app_metadata': {
    'provider': 'email',
    'providers': ['email'],
  },
  'created_at': '2026-10-25T00:00:00Z',
};

Map<String, Object?> session({bool verified = true, String suffix = 'one'}) {
  final expiry =
      DateTime.now()
          .toUtc()
          .add(const Duration(hours: 1))
          .millisecondsSinceEpoch ~/
      1000;
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'sub': 'synthetic-user', 'exp': expiry})))
      .replaceAll('=', '');
  return {
    'access_token': 'eyJhbGciOiJub25lIn0.$payload.$suffix',
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'synthetic-refresh',
    'user': user(verified: verified),
  };
}

sdk.SupabaseClient client(
  Future<http.Response> Function(http.Request) handler,
) => sdk.SupabaseClient(
  'https://synthetic.supabase.co',
  'synthetic-public-client-key',
  authOptions: const sdk.AuthClientOptions(
    autoRefreshToken: false,
    authFlowType: sdk.AuthFlowType.implicit,
  ),
  httpClient: MockClient(handler),
);

http.Response jsonResponse(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  test(
    'active Supabase gateway signs in, refreshes and signs out through SDK',
    () async {
      final grants = <String?>[];
      final supabase = client((request) async {
        if (request.url.path.endsWith('/logout')) return jsonResponse({});
        final grant = request.url.queryParameters['grant_type'];
        grants.add(grant);
        if (grant == 'refresh_token') {
          expect(
            jsonDecode(request.body)['refresh_token'],
            'synthetic-refresh',
          );
        }
        return jsonResponse(
          session(suffix: grant == 'refresh_token' ? 'two' : 'one'),
        );
      });
      addTearDown(supabase.dispose);
      final gateway = SupabaseAuthGateway(supabase);
      await gateway.signIn('synthetic@example.com', 'synthetic-password');
      expect(gateway.session?.userId, 'synthetic-user');
      expect(gateway.session?.emailVerified, isTrue);
      expect(gateway.session?.displayName, 'Synthetic Person');
      final refreshed = await gateway.refresh();
      expect(refreshed?.token, endsWith('.two'));
      expect(grants, ['password', 'refresh_token']);
      await gateway.signOut();
      expect(gateway.session, isNull);
    },
  );

  test('active gateway registration preserves display name and configured callback', () async {
    final supabase = client((request) async {
      expect(request.url.path, endsWith('/signup'));
      expect(request.url.queryParameters['redirect_to'], authCallbackUrl);
      expect(jsonDecode(request.body)['data'], {
        'display_name': 'Synthetic Person',
      });
      return jsonResponse(user(verified: false));
    });
    addTearDown(supabase.dispose);
    final gateway = SupabaseAuthGateway(supabase);
    expect(
      await gateway.signUp(
        'synthetic@example.com',
        'synthetic-password',
        fullName: 'Synthetic Person',
      ),
      isNull,
    );
    expect(gateway.session, isNull);
  });

  test('active gateway sanitizes invalid credentials', () async {
    final supabase = client(
      (_) async => jsonResponse({
        'error_code': 'invalid_credentials',
        'message': 'private provider detail',
      }, status: 400),
    );
    addTearDown(supabase.dispose);
    await expectLater(
      SupabaseAuthGateway(supabase)
          .signIn('synthetic@example.com', 'wrong-synthetic-password'),
      throwsA(
        isA<AuthFailure>().having(
          (e) => e.problem,
          'problem',
          AuthProblem.invalidCredentials,
        ),
      ),
    );
  });
}
