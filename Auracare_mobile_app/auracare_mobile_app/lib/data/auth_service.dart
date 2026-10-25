import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_client.dart';

const authCallbackUrl = 'org.auracare.auracare_mobile_app://auth/callback';

class SupabaseConfiguration {
  SupabaseConfiguration({required this.url, required this.anonKey}) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        !_clientKey(anonKey)) {
      throw const AuthFailure(AuthProblem.configuration);
    }
  }

  factory SupabaseConfiguration.fromEnvironment() => SupabaseConfiguration(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  final String url, anonKey;

  static bool _clientKey(String key) {
    if (key.startsWith('sb_publishable_') && key.length > 20) return true;
    // This rejects accidentally supplied privileged keys; it does NOT verify JWTs.
    try {
      final parts = key.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return payload is Map && payload['role'] == 'anon';
    } catch (_) {
      return false;
    }
  }

  @override
  String toString() => 'SupabaseConfiguration';
}

enum AuthProblem {
  configuration,
  invalidCredentials,
  verificationRequired,
  weakPassword,
  unavailable,
  rateLimited,
}

class AuthFailure implements Exception {
  const AuthFailure(this.problem);
  final AuthProblem problem;
  String get message => switch (problem) {
    AuthProblem.configuration =>
      'Account access is not configured. Demo mode is available.',
    AuthProblem.invalidCredentials =>
      'Unable to sign in. Check your email and password.',
    AuthProblem.verificationRequired => 'Verify your email before signing in. You can request a new verification email.',
    AuthProblem.weakPassword =>
      'Choose a stronger password that meets the account password policy.',
    AuthProblem.rateLimited =>
      'Too many attempts. Please wait before trying again.',
    AuthProblem.unavailable =>
      'Account access is temporarily unavailable. Please try again.',
  };
  @override
  String toString() => 'AuthFailure(${problem.name})';
}

class UserSession {
  const UserSession({
    required this.userId,
    required this.token,
    required this.expiresAt,
    required this.emailVerified,
  });
  final String userId, token;
  final DateTime expiresAt;
  final bool emailVerified;
  @override
  String toString() => 'UserSession';
}

enum AuthEvent { restored, signedIn, refreshed, signedOut, recovery }

class AuthUpdate {
  const AuthUpdate(this.event, this.session);
  final AuthEvent event;
  final UserSession? session;
}

abstract interface class AuthGateway {
  UserSession? get session;
  Stream<AuthUpdate> get changes;
  Future<void> signIn(String email, String password);
  Future<UserSession?> signUp(String email, String password);
  Future<void> resendVerification(String email);
  Future<void> requestPasswordReset(String email);
  Future<void> updatePassword(String password);
  Future<void> signOut();
  Future<UserSession?> refresh();
}

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this.client);
  final SupabaseClient client;

  static UserSession? _session(Session? value) => value == null
      ? null
      : UserSession(
          userId: value.user.id,
          token: value.accessToken,
          expiresAt: DateTime.fromMillisecondsSinceEpoch(
            (value.expiresAt ?? 0) * 1000,
            isUtc: true,
          ),
          emailVerified: value.user.emailConfirmedAt != null,
        );

  @override
  UserSession? get session => _session(client.auth.currentSession);
  @override
  Stream<AuthUpdate> get changes => client.auth.onAuthStateChange.map(
    (state) => AuthUpdate(switch (state.event) {
      AuthChangeEvent.passwordRecovery => AuthEvent.recovery,
      AuthChangeEvent.signedOut => AuthEvent.signedOut,
      AuthChangeEvent.tokenRefreshed => AuthEvent.refreshed,
      AuthChangeEvent.initialSession => AuthEvent.restored,
      _ => AuthEvent.signedIn,
    }, _session(state.session)),
  );

  Future<T> _safe<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthException catch (error) {
      throw AuthFailure(switch (error.code) {
        'invalid_credentials' => AuthProblem.invalidCredentials,
        'email_not_confirmed' => AuthProblem.verificationRequired,
        'weak_password' => AuthProblem.weakPassword,
        'over_request_rate_limit' ||
        'over_email_send_rate_limit' => AuthProblem.rateLimited,
        _ => AuthProblem.unavailable,
      });
    } catch (_) {
      throw const AuthFailure(AuthProblem.unavailable);
    }
  }

  @override
  Future<void> signIn(String email, String password) => _safe(() async {
    await client.auth.signInWithPassword(email: email, password: password);
  });
  @override
  Future<UserSession?> signUp(String email, String password) => _safe(() async {
    final result = await client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: authCallbackUrl,
    );
    return _session(result.session);
  });
  @override
  Future<void> resendVerification(String email) => _safe(() async {
    await client.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: authCallbackUrl,
    );
  });
  @override
  Future<void> requestPasswordReset(String email) => _safe(
    () => client.auth.resetPasswordForEmail(email, redirectTo: authCallbackUrl),
  );
  @override
  Future<void> updatePassword(String password) => _safe(() async {
    await client.auth.updateUser(UserAttributes(password: password));
  });
  @override
  Future<void> signOut() =>
      _safe(() => client.auth.signOut(scope: SignOutScope.local));
  @override
  Future<UserSession?> refresh() => _safe(() async {
    final result = await client.auth.refreshSession();
    return _session(result.session);
  });
}

enum AccessMode { signedOut, authenticated, demo, recovery }

/// Sole token provider for the application. Demo/recovery never yield tokens.
class AuraAuthController extends ChangeNotifier implements AccessTokenProvider {
  AuraAuthController({
    this.gateway,
    DateTime Function()? clock,
    this.operationTimeout = const Duration(seconds: 20),
  }) : _clock = clock ?? DateTime.now {
    final restored = gateway?.session;
    if (restored != null && restored.emailVerified) {
      mode = AccessMode.authenticated;
      userId = restored.userId;
    }
    _subscription = gateway?.changes.listen(
      _changed,
      onError: (Object _) {
        if (mode != AccessMode.demo) _expire();
      },
    );
  }

  final AuthGateway? gateway;
  final DateTime Function() _clock;
  final Duration operationTimeout;
  StreamSubscription<AuthUpdate>? _subscription;
  Future<UserSession?>? _refreshing;
  AccessMode mode = AccessMode.signedOut;
  String? userId, message, error;
  bool busy = false, _disposed = false, _acceptEvents = true;
  int _generation = 0;
  bool get configured => gateway != null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _changed(AuthUpdate update) {
    if (_disposed || mode == AccessMode.demo) return;
    if (update.event == AuthEvent.recovery && update.session != null) {
      _generation++;
      _acceptEvents = true;
      mode = AccessMode.recovery;
      userId = update.session!.userId;
      message = error = null;
      _notify();
      return;
    }
    if (!_acceptEvents || mode == AccessMode.demo || busy) return;
    if (update.event == AuthEvent.restored &&
        update.session == null &&
        mode == AccessMode.signedOut) {
      // An ordinary empty startup must still accept later confirmation events.
      return;
    }
    if (update.event == AuthEvent.signedOut || update.session == null) {
      _expire();
    } else if (mode != AccessMode.recovery && update.session!.emailVerified) {
      mode = AccessMode.authenticated;
      userId = update.session!.userId;
      _notify();
    }
  }

  void _expire() {
    _generation++;
    _acceptEvents = false;
    mode = AccessMode.signedOut;
    userId = null;
    error = 'Your session could not be renewed. Please sign in again.';
    _notify();
  }

  void enterDemo() {
    _generation++;
    _acceptEvents = false;
    mode = AccessMode.demo;
    userId = null;
    error = message = null;
    _notify();
  }

  void leaveDemo() {
    _generation++;
    _acceptEvents = false;
    mode = AccessMode.signedOut;
    userId = null;
    error = message = null;
    _notify();
  }

  Future<void> _run(Future<void> Function(AuthGateway) action) async {
    if (busy || _disposed) return;
    final service = gateway;
    if (service == null) {
      error = const AuthFailure(AuthProblem.configuration).message;
      _notify();
      return;
    }
    final generation = _generation;
    busy = true;
    error = message = null;
    _notify();
    try {
      await action(service).timeout(operationTimeout);
    } catch (failure) {
      if (generation == _generation) {
        // Ignore late SDK completions after a failed or timed-out operation.
        _generation++;
        _acceptEvents = false;
        error = failure is AuthFailure
            ? failure.message
            : const AuthFailure(AuthProblem.unavailable).message;
      }
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> signIn(String email, String password) {
    _acceptEvents = true;
    final generation = _generation;
    return _run((service) async {
      await service.signIn(email, password);
      if (_disposed || generation != _generation) return;
      final current = service.session;
      if (current == null) {
        throw const AuthFailure(AuthProblem.invalidCredentials);
      }
      if (!current.emailVerified) {
        throw const AuthFailure(AuthProblem.verificationRequired);
      }
      mode = AccessMode.authenticated;
      userId = current.userId;
    });
  }

  Future<void> signUp(String email, String password) {
    _acceptEvents = true;
    final generation = _generation;
    return _run((service) async {
      final current = await service.signUp(email, password);
      if (_disposed || generation != _generation) return;
      if (current != null && current.emailVerified) {
        mode = AccessMode.authenticated;
        userId = current.userId;
      } else {
        message = 'If eligible, a verification email has been sent. Open it on this device, or verify and return to sign in.';
      }
    });
  }

  Future<void> resendVerification(String email) => _run((service) async {
    await service.resendVerification(email);
    message = 'If eligible, a verification email has been sent.';
  });

  Future<void> requestPasswordReset(String email) => _run((service) async {
    await service.requestPasswordReset(email);
    message = 'If an account exists, a password reset email has been sent. Open its link on this device.';
  });

  Future<void> updatePassword(String password) => _run((service) async {
    if (mode != AccessMode.recovery) {
      throw const AuthFailure(AuthProblem.unavailable);
    }
    final generation = _generation;
    await service.updatePassword(password);
    if (_disposed || generation != _generation) return;
    // Require normal sign-in after recovery rather than granting API access.
    await service.signOut();
    mode = AccessMode.signedOut;
    _acceptEvents = false;
    userId = null;
    message = 'Password updated. Sign in with your new password.';
  });

  Future<void> signOut() {
    _generation++;
    _acceptEvents = false;
    mode = AccessMode.signedOut;
    userId = null;
    _notify();
    return _run((service) => service.signOut());
  }

  @override
  Future<String?> accessToken() async {
    if (_disposed || mode != AccessMode.authenticated) return null;
    final generation = _generation;
    final expectedUser = userId;
    try {
      var current = gateway?.session;
      if (current == null ||
          !current.emailVerified ||
          current.userId != expectedUser) {
        return null;
      }
      if (!current.expiresAt.isAfter(
        _clock().add(const Duration(seconds: 30)),
      )) {
        final pending = _refreshing ??= gateway!.refresh().timeout(
          operationTimeout,
        );
        try {
          current = await pending;
        } finally {
          if (identical(_refreshing, pending)) _refreshing = null;
        }
      }
      if (_disposed ||
          mode != AccessMode.authenticated ||
          generation != _generation ||
          current == null ||
          current.userId != expectedUser ||
          !current.emailVerified ||
          !current.expiresAt.isAfter(_clock()) ||
          current.token.isEmpty) {
        return null;
      }
      return current.token;
    } catch (_) {
      if (!_disposed && generation == _generation) _expire();
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

Future<AuraAuthController> initializeAuthentication() async {
  try {
    final config = SupabaseConfiguration.fromEnvironment();
    final supabase = await Supabase.initialize(
      url: config.url,
      publishableKey: config.anonKey,
      debug: false,
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
        detectSessionInUriPredicate: (uri) =>
            uri.scheme == 'org.auracare.auracare_mobile_app' &&
            uri.host == 'auth' &&
            uri.path == '/callback',
      ),
    );
    return AuraAuthController(gateway: SupabaseAuthGateway(supabase.client));
  } catch (_) {
    return AuraAuthController();
  }
}
