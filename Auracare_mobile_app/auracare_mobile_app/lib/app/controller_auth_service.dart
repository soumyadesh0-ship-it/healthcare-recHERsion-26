import '../data/auth_service.dart' as account;
import 'auth_service.dart';

/// Connects the shared login widgets to the API token/session controller.
/// This facade never initializes a second Supabase client or stores credentials.
class ControllerAuthService implements AuthService, AccessTokenProvider {
  ControllerAuthService(this.controller);
  final account.AuraAuthController controller;

  @override
  Future<String?> accessToken() => controller.accessToken();

  AuthUser? get user {
    final session = controller.gateway?.session;
    if (session == null ||
        controller.mode != account.AccessMode.authenticated) {
      return null;
    }
    return AuthUser(
      id: session.userId,
      email: session.email,
      displayName: session.displayName,
    );
  }

  void _check() {
    if (controller.error == null) return;
    final failure =
        controller.error ==
            const account.AuthFailure(account.AuthProblem.verificationRequired)
                .message
        ? AuthFailure.emailNotVerified
        : controller.error ==
              const account.AuthFailure(account.AuthProblem.invalidCredentials)
                  .message
        ? AuthFailure.invalidCredentials
        : AuthFailure.rejected;
    throw AuthException(failure);
  }

  @override
  bool get isConfigured => controller.configured;
  @override
  bool get supportsGoogleSignIn => false;
  @override
  Future<AuthUser?> restoreSession() async => user;
  @override
  Stream<AuthUser?> get sessionChanges =>
      controller.gateway?.changes.map((_) => user) ?? const Stream.empty();
  @override
  Stream<void> get passwordRecoveryEvents =>
      controller.gateway?.changes
          .where((event) => event.event == account.AuthEvent.recovery)
          .map<void>((_) {}) ??
      const Stream.empty();

  @override
  Future<AuthUser> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await controller.signIn(email, password);
    _check();
    return user ?? (throw const AuthException(AuthFailure.rejected));
  }

  @override
  Future<AuthRegistrationResult> createAccount({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await controller.signUp(email, password, fullName: fullName);
    _check();
    return AuthRegistrationResult(
      accountCreated: true,
      user: user,
      emailVerificationRequired: user == null,
    );
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await controller.requestPasswordReset(email);
    _check();
  }

  @override
  Future<AuthUser> updatePassword(String password) async {
    final id = controller.userId;
    await controller.updatePassword(password);
    _check();
    // The controller signs out after recovery; the outer root returns to login.
    return AuthUser(id: id ?? '');
  }

  Future<void> resendVerification(String email) async {
    await controller.resendVerification(email);
    _check();
  }

  @override
  Future<AuthUser?> signInWithGoogle() async =>
      throw const AuthException(AuthFailure.unavailable);
  @override
  Future<void> signOut() async {
    await controller.signOut();
    _check();
  }
}
