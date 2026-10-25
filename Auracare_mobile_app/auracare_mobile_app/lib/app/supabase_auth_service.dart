import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'auth_service.dart';

const supabaseRedirectUrl = String.fromEnvironment(
  'AURACARE_AUTH_REDIRECT_URL',
  defaultValue: 'auracare://auth-callback',
);

Future<AuthService> createAuthService() async {
  const urlValue = String.fromEnvironment('SUPABASE_URL');
  const keyValue = String.fromEnvironment('SUPABASE_ANON_KEY');
  final url = urlValue.trim();
  final publishableKey = keyValue.trim();

  if (url.isEmpty && publishableKey.isEmpty) {
    return const UnconfiguredAuthService();
  }
  if (url.isEmpty || publishableKey.isEmpty) {
    throw StateError(
      'Configure both SUPABASE_URL and SUPABASE_ANON_KEY to enable authentication.',
    );
  }

  final parsedUrl = Uri.tryParse(url);
  if (parsedUrl == null ||
      parsedUrl.scheme != 'https' ||
      parsedUrl.host.isEmpty) {
    throw StateError('SUPABASE_URL must be a valid HTTPS URL.');
  }
  if (!isSupabasePublishableKey(publishableKey)) {
    throw StateError(
      'SUPABASE_ANON_KEY must be a publishable/anon key. Server secret and service-role keys are not accepted by the Flutter app.',
    );
  }

  await supabase.Supabase.initialize(
    url: url,
    publishableKey: publishableKey,
    authOptions: const supabase.FlutterAuthClientOptions(
      authFlowType: supabase.AuthFlowType.pkce,
    ),
    debug: false,
  );
  return SupabaseAuthService(supabase.Supabase.instance.client);
}

bool isSupabasePublishableKey(String key) {
  if (key.startsWith('sb_publishable_')) return true;
  if (key.startsWith('sb_secret_')) return false;

  final parts = key.split('.');
  if (parts.length != 3) return false;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    return payload is Map && payload['role'] == 'anon';
  } on FormatException {
    return false;
  }
}

class SupabaseAuthService implements AuthService, AccessTokenProvider {
  const SupabaseAuthService(this.client);

  final supabase.SupabaseClient client;

  @override
  Future<String?> accessToken() => _withAuthErrors(() async {
    final session = client.auth.currentSession;
    if (session == null) return null;
    if (session.isExpired) {
      final refreshed = (await client.auth.refreshSession()).session;
      if (refreshed?.user.id != session.user.id ||
          client.auth.currentSession?.user.id != session.user.id) {
        return null;
      }
      return refreshed?.accessToken;
    }
    return session.accessToken;
  });

  @override
  bool get isConfigured => true;

  @override
  bool get supportsGoogleSignIn => false;

  @override
  Future<AuthUser?> restoreSession() async {
    final user = client.auth.currentSession?.user;
    return user == null ? null : _toAuthUser(user);
  }

  @override
  Stream<AuthUser?> get sessionChanges => client.auth.onAuthStateChange
      .where(
        (state) => state.event != supabase.AuthChangeEvent.passwordRecovery,
      )
      .map(
        (state) =>
            state.session == null ? null : _toAuthUser(state.session!.user),
      );

  @override
  Stream<void> get passwordRecoveryEvents => client.auth.onAuthStateChange
      .where(
        (state) => state.event == supabase.AuthChangeEvent.passwordRecovery,
      )
      .map((_) {});

  @override
  Future<AuthUser> signInWithPassword({
    required String email,
    required String password,
  }) => _withAuthErrors(() async {
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.session?.user;
    if (user == null) {
      throw const AuthException(AuthFailure.rejected);
    }
    return _toAuthUser(user);
  });

  @override
  Future<AuthRegistrationResult> createAccount({
    required String fullName,
    required String email,
    required String password,
  }) => _withAuthErrors(() async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: supabaseRedirectUrl,
      data: {'display_name': fullName},
    );
    final user = response.user;
    if (user == null) {
      throw const AuthException(AuthFailure.rejected);
    }
    final requiresVerification = response.session == null;
    return AuthRegistrationResult(
      accountCreated: true,
      emailVerificationRequired: requiresVerification,
      user: requiresVerification ? null : _toAuthUser(user),
    );
  });

  @override
  Future<void> sendPasswordReset(String email) => _withAuthErrors(
    () => client.auth.resetPasswordForEmail(
      email,
      redirectTo: supabaseRedirectUrl,
    ),
  );

  @override
  Future<AuthUser> updatePassword(String password) => _withAuthErrors(() async {
    final response = await client.auth.updateUser(
      supabase.UserAttributes(password: password),
    );
    final user = response.user;
    if (user == null) {
      throw const AuthException(AuthFailure.rejected);
    }
    return _toAuthUser(user);
  });

  @override
  Future<AuthUser?> signInWithGoogle() async {
    throw const AuthException(AuthFailure.unavailable);
  }

  @override
  Future<void> signOut() => _withAuthErrors(client.auth.signOut);

  Future<T> _withAuthErrors<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on supabase.AuthWeakPasswordException {
      throw const AuthException(AuthFailure.weakPassword);
    } on supabase.AuthRetryableFetchException {
      throw const AuthException(AuthFailure.network);
    } on supabase.AuthException catch (exception) {
      throw AuthException(_failureFor(exception));
    }
  }

  AuthFailure _failureFor(supabase.AuthException exception) {
    final code = exception.code?.toLowerCase();
    if (exception.statusCode == '429' ||
        code == 'over_email_send_rate_limit' ||
        code == 'over_request_rate_limit') {
      return AuthFailure.rateLimited;
    }
    return switch (code) {
      'invalid_credentials' ||
      'invalid_login_credentials' => AuthFailure.invalidCredentials,
      'email_not_confirmed' => AuthFailure.emailNotVerified,
      'email_exists' || 'user_already_exists' => AuthFailure.emailAlreadyInUse,
      'weak_password' => AuthFailure.weakPassword,
      _ => AuthFailure.rejected,
    };
  }

  AuthUser _toAuthUser(supabase.User user) {
    final displayName = user.userMetadata?['display_name'];
    return AuthUser(
      id: user.id,
      email: user.email,
      displayName: displayName is String ? displayName : null,
    );
  }
}
