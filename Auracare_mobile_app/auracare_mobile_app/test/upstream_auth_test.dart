import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auracare_mobile_app/app/app.dart';
import 'package:auracare_mobile_app/app/auth_service.dart';
import 'package:auracare_mobile_app/app/setup_preference.dart';
import 'package:auracare_mobile_app/app/theme.dart';
import 'package:auracare_mobile_app/app/session.dart';
import 'package:auracare_mobile_app/data/records.dart';
import 'package:auracare_mobile_app/features/logging/editor.dart';

import 'local_records_correctness_test.dart' show journal, problem;
import 'widget_test.dart' show tapText;

import 'package:auracare_mobile_app/features/auth/auth.dart';

class _TestAuthService implements AuthService {
  final sessions = StreamController<AuthUser?>.broadcast();
  final recoveries = StreamController<void>.broadcast();
  bool configured = true;
  bool verificationRequired = false;
  AuthFailure? nextFailure;
  AuthUser? user;
  Completer<void>? pendingSignOut;

  @override
  bool get isConfigured => configured;

  @override
  bool get supportsGoogleSignIn => configured;

  @override
  Stream<AuthUser?> get sessionChanges => sessions.stream;

  @override
  Stream<void> get passwordRecoveryEvents => recoveries.stream;

  @override
  Future<AuthUser?> restoreSession() async => user;

  @override
  Future<AuthUser> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (nextFailure case final failure?) throw AuthException(failure);
    return user = const AuthUser(
      id: 'test-user',
      email: 'alex@example.com',
      displayName: 'Alex',
    );
  }

  @override
  Future<AuthRegistrationResult> createAccount({
    required String fullName,
    required String email,
    required String password,
  }) async {
    if (nextFailure case final failure?) throw AuthException(failure);
    return AuthRegistrationResult(
      accountCreated: true,
      emailVerificationRequired: verificationRequired,
      user: verificationRequired ? null : AuthUser(id: 'created-user'),
    );
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    if (nextFailure case final failure?) throw AuthException(failure);
  }

  @override
  Future<AuthUser> updatePassword(String password) async =>
      user ??= const AuthUser(id: 'password-updated-user');

  @override
  Future<AuthUser?> signInWithGoogle() async {
    if (nextFailure case final failure?) throw AuthException(failure);
    return const AuthUser(id: 'google-user');
  }

  @override
  Future<void> signOut() async {
    if (pendingSignOut != null) await pendingSignOut!.future;
    user = null;
    sessions.add(null);
  }

  Future<void> dispose() async {
    await sessions.close();
    await recoveries.close();
  }
}

Widget _page(AuthService auth) => MaterialApp(
  theme: auracareTheme(),
  home: LoginPage(auth: auth, onAuthenticated: (_) {}, onDemoSelected: (_) {}),
);

Widget _appPage(Widget child) =>
    MaterialApp(theme: auracareTheme(), home: child);

void main() {
  for (final signOut in [false, true]) {
    testWidgets(
      'alternate app ${signOut ? 'sign-out' : 'account switch'} clears records, routes and pending writes',
      (tester) async {
        final auth = _TestAuthService()..user = const AuthUser(id: 'account-a');
        final session = DemoSession(
          records: DemoRecordsRepository(sample: false),
        );
        await tester.pumpWidget(
          AuracareApp(
            authService: auth,
            session: session,
            showOnboarding: false,
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() => session.records.save(journal()));
        // A same-user token refresh must preserve the shared repository.
        auth.sessions.add(const AuthUser(id: 'account-a'));
        await tester.pumpAndSettle();
        expect(session.records.entries, hasLength(1));
        final context = tester.element(find.byKey(const ValueKey('tab-Home')));
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EntryEditor(
              type: EntryType.journal,
              entry: session.records.entries.single,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('entry-note')),
          'Private account A draft',
        );
        final pending = session.records.save(journal(version: 2));
        final checked = expectLater(
          pending,
          throwsA(problem(RecordProblem.cancelled)),
        );
        auth.sessions.add(signOut ? null : const AuthUser(id: 'account-b'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 300));
        await checked;
        expect(session.records.entries, isEmpty);
        expect(find.byType(EntryEditor), findsNothing);
        expect(find.text('Private account A draft'), findsNothing);
        expect(
          find.byKey(ValueKey(signOut ? 'login-email' : 'tab-Home')),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        session.dispose();
        await auth.dispose();
      },
    );
  }

  testWidgets('explicit sign-out clears cache before a failing SDK response', (
    tester,
  ) async {
    final auth = _TestAuthService()..user = const AuthUser(id: 'account-a');
    final session = DemoSession(records: DemoRecordsRepository(sample: false));
    await tester.pumpWidget(
      AuracareApp(authService: auth, session: session, showOnboarding: false),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() => session.records.save(journal()));
    await tester.tap(find.byKey(const ValueKey('tab-Profile')));
    await tester.pumpAndSettle();
    auth.pendingSignOut = Completer<void>();
    await tapText(tester, 'Sign out / exit demo');
    expect(session.records.entries, isEmpty);
    expect(find.byKey(const ValueKey('login-email')), findsOneWidget);
    auth.pendingSignOut!.completeError(
      const AuthException(AuthFailure.network),
    );
    await tester.pumpAndSettle();
    expect(session.records.entries, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
    await auth.dispose();
  });

  testWidgets('login validates email and password and toggles visibility', (
    tester,
  ) async {
    const auth = UnconfiguredAuthService();
    await tester.pumpWidget(_page(auth));

    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('login-email')), 'bad');
    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      'private-password',
    );
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);

    final password = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('login-password')),
        matching: find.byType(EditableText),
      ),
    );
    expect(password.obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const ValueKey('login-password')),
              matching: find.byType(EditableText),
            ),
          )
          .obscureText,
      isFalse,
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-email')),
      'person@example.com',
    );
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.textContaining('not configured in this build'), findsOneWidget);
    final googleButton = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Continue with Google · unavailable'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(googleButton.onPressed, isNull);
  });

  testWidgets('create account and password recovery routes work', (
    tester,
  ) async {
    const auth = UnconfiguredAuthService();
    await tester.pumpWidget(_page(auth));
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('create-name')), 'Alex');
    await tester.enterText(
      find.byKey(const ValueKey('create-email')),
      'alex@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('create-password')),
      '12345678',
    );
    await tester.enterText(
      find.byKey(const ValueKey('create-confirm-password')),
      'different',
    );
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match.'), findsOneWidget);
    await tester.ensureVisible(find.text('Log in'));
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Forgot password?'));
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset your password'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('reset-email')),
      'alex@example.com',
    );
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('unavailable until the shared authentication'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Back to login'));
    await tester.tap(find.text('Back to login'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to AuraCare'), findsOneWidget);
  });

  testWidgets('registration only reports provider-confirmed success', (
    tester,
  ) async {
    final auth = _TestAuthService();
    addTearDown(auth.dispose);
    var authenticated = false;
    await tester.pumpWidget(
      _appPage(
        CreateAccountPage(
          auth: auth,
          onAuthenticated: (_) => authenticated = true,
        ),
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('create-name')), 'Alex');
    await tester.enterText(
      find.byKey(const ValueKey('create-email')),
      'alex@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('create-password')),
      'secure-pass',
    );
    await tester.enterText(
      find.byKey(const ValueKey('create-confirm-password')),
      'secure-pass',
    );
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(authenticated, isTrue);
  });

  testWidgets('registration waits for email verification before app access', (
    tester,
  ) async {
    final auth = _TestAuthService()..verificationRequired = true;
    addTearDown(auth.dispose);
    var authenticated = false;
    await tester.pumpWidget(
      _appPage(
        CreateAccountPage(
          auth: auth,
          onAuthenticated: (_) => authenticated = true,
        ),
      ),
    );
    await tester.enterText(find.byKey(const ValueKey('create-name')), 'Alex');
    await tester.enterText(
      find.byKey(const ValueKey('create-email')),
      'alex@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('create-password')),
      'secure-pass',
    );
    await tester.enterText(
      find.byKey(const ValueKey('create-confirm-password')),
      'secure-pass',
    );
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(authenticated, isFalse);
    expect(find.textContaining('verification instructions'), findsOneWidget);
  });

  testWidgets(
    'app opens login after onboarding and returns to home only on auth',
    (tester) async {
      var setupComplete = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SetupPreference.channel, (call) async {
            if (call.method == 'completed') return setupComplete;
            if (call.method == 'complete') {
              setupComplete = true;
              return true;
            }
            throw PlatformException(code: 'unsupported');
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SetupPreference.channel, null);
      });
      final auth = _TestAuthService();
      addTearDown(auth.dispose);
      await tester.pumpWidget(AuracareApp(authService: auth));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to AuraCare'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('login-email')),
        'alex@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login-password')),
        'correct-horse',
      );
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tab-Home')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('tab-Profile')));
      await tester.pumpAndSettle();
      expect(find.text('Signed in as alex@example.com'), findsOneWidget);
      expect(
        find.textContaining('are not uploaded to your account'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Sign out / exit demo'),
        240,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Sign out / exit demo'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to AuraCare'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('restored authenticated session skips login', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SetupPreference.channel, (call) async {
          if (call.method == 'completed') return true;
          throw PlatformException(code: 'unsupported');
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SetupPreference.channel, null);
    });
    final auth = _TestAuthService()..user = const AuthUser(id: 'restored-user');
    addTearDown(auth.dispose);

    await tester.pumpWidget(AuracareApp(authService: auth));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tab-Home')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/brand/auracare-icon.png',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('verified recovery link requires a new password', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SetupPreference.channel, (call) async {
          if (call.method == 'completed') return true;
          throw PlatformException(code: 'unsupported');
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SetupPreference.channel, null);
    });
    final auth = _TestAuthService()
      ..user = const AuthUser(id: 'recovery-user', email: 'alex@example.com');
    addTearDown(auth.dispose);

    await tester.pumpWidget(AuracareApp(authService: auth));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    auth.recoveries.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Choose a new password'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('recovery-password')),
      'a-new-private-password',
    );
    await tester.enterText(
      find.byKey(const ValueKey('recovery-confirm-password')),
      'a-new-private-password',
    );
    await tester.ensureVisible(find.text('Update password'));
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tab-Home')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('auth page fits ${width}dp at ${scale}x text', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.view.resetViewInsets();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        await tester.pumpWidget(_page(const UnconfiguredAuthService()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.enterText(
          find.byKey(const ValueKey('login-email')),
          'person@example.com',
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Log in'));
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          _appPage(
            CreateAccountPage(
              auth: const UnconfiguredAuthService(),
              onAuthenticated: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          _appPage(ResetPasswordPage(auth: const UnconfiguredAuthService())),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
