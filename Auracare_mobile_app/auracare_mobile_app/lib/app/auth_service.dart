abstract interface class AuthService {
  bool get isConfigured;
  bool get supportsGoogleSignIn;
  Future<AuthUser?> restoreSession();
  Stream<AuthUser?> get sessionChanges;
  Stream<void> get passwordRecoveryEvents;
  Future<AuthUser> signInWithPassword({
    required String email,
    required String password,
  });
  Future<AuthRegistrationResult> createAccount({
    required String fullName,
    required String email,
    required String password,
  });
  Future<void> sendPasswordReset(String email);
  Future<AuthUser> updatePassword(String password);
  Future<AuthUser?> signInWithGoogle();
  Future<void> signOut();
}

class AuthUser {
  const AuthUser({required this.id, this.email, this.displayName});

  final String id;
  final String? email;
  final String? displayName;
}

class AuthRegistrationResult {
  const AuthRegistrationResult({
    required this.accountCreated,
    this.user,
    this.emailVerificationRequired = false,
  });

  final bool accountCreated;
  final AuthUser? user;
  final bool emailVerificationRequired;
}

enum AuthFailure {
  unavailable,
  invalidCredentials,
  emailAlreadyInUse,
  emailNotVerified,
  weakPassword,
  network,
  rateLimited,
  rejected,
}

class AuthException implements Exception {
  const AuthException(this.failure);

  final AuthFailure failure;
}

class UnconfiguredAuthService implements AuthService {
  const UnconfiguredAuthService();

  @override
  bool get isConfigured => false;

  @override
  bool get supportsGoogleSignIn => false;

  @override
  Stream<AuthUser?> get sessionChanges => const Stream.empty();

  @override
  Stream<void> get passwordRecoveryEvents => const Stream.empty();

  @override
  Future<AuthUser?> restoreSession() async => null;

  @override
  Future<AuthUser> signInWithPassword({
    required String email,
    required String password,
  }) => _unavailable();

  @override
  Future<AuthRegistrationResult> createAccount({
    required String fullName,
    required String email,
    required String password,
  }) => _unavailable();

  @override
  Future<void> sendPasswordReset(String email) => _unavailable();

  @override
  Future<AuthUser> updatePassword(String password) => _unavailable();

  @override
  Future<AuthUser?> signInWithGoogle() => _unavailable();

  @override
  Future<void> signOut() async {}

  Future<T> _unavailable<T>() =>
      Future.error(const AuthException(AuthFailure.unavailable));
}

String authFailureMessage(AuthFailure failure) => switch (failure) {
  AuthFailure.unavailable => 'Account access is unavailable until AuraCare is connected to its shared authentication provider.',
  AuthFailure.invalidCredentials => 'Email or password is incorrect.',
  AuthFailure.emailAlreadyInUse =>
    'An account with this email already exists. Try logging in.',
  AuthFailure.emailNotVerified =>
    'Verify your email using the link we sent, then try logging in again.',
  AuthFailure.weakPassword =>
    'Choose a stronger password that meets the account requirements.',
  AuthFailure.network => 'Could not reach the authentication service. Check your connection and try again.',
  AuthFailure.rateLimited =>
    'Too many attempts. Wait a little while before trying again.',
  AuthFailure.rejected =>
    'The request could not be completed. Please try again.',
};
