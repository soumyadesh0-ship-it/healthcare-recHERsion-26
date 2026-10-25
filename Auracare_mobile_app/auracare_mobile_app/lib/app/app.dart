import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'dart:async';

import 'auth_service.dart';
import 'session.dart';
import 'quiz_integration.dart';

import 'package:http/http.dart' as http;

import '../core/brand.dart';
import '../features/profile/profile.dart';
import '../features/learn/learn.dart';
import '../features/insights/insights.dart';
import '../features/chat/chat.dart';
import 'setup_preference.dart';
import '../data/records.dart';
import 'theme.dart';
import 'shell.dart';
import 'navigation.dart';
import '../features/onboarding/onboarding.dart';
import '../features/auth/auth.dart';

class AuracareApp extends StatefulWidget {
  const AuracareApp({
    super.key,
    this.session,
    this.showOnboarding = true,
    this.accessWrapper,
    this.authService,
    this.externalAuthUser,
    this.externalSignOut,
  });
  final Widget Function(BuildContext context, Widget child)? accessWrapper;
  final AuthUser? externalAuthUser;
  final Future<void> Function()? externalSignOut;
  final DemoSession? session;
  final AuthService? authService;
  final bool showOnboarding;
  @override
  State<AuracareApp> createState() => _AuracareAppState();
}

class _AuracareAppState extends State<AuracareApp> {
  String? lastLayoutMetrics;
  late final AuthService auth =
      widget.authService ?? const UnconfiguredAuthService();
  final apiClient = http.Client();
  late final modelQuizService = configuredModelQuizService(auth, apiClient);
  StreamSubscription<AuthUser?>? authSubscription;
  StreamSubscription<void>? passwordRecoverySubscription;
  AuthUser? authenticatedUser;
  int authEventVersion = 0;
  int _navigationEpoch = 0;
  bool completingPasswordRecovery = false;
  String? sessionRestoreMessage;
  late final DemoSession session =
      widget.session ??
      DemoSession(records: DemoRecordsRepository(sample: false));
  late bool entered = !widget.showOnboarding;
  late bool demoMode = !widget.showOnboarding;
  bool loading = true;
  late bool splash = widget.showOnboarding;
  bool previewOnboarding =
      kDebugMode && const bool.fromEnvironment('PREVIEW_ONBOARDING');
  final preference = SetupPreference();
  @override
  void initState() {
    super.initState();
    loadSetup();
    if (widget.accessWrapper == null) {
      authSubscription = auth.sessionChanges.listen(updateAuthUser);
      passwordRecoverySubscription = auth.passwordRecoveryEvents.listen(
        (_) => beginPasswordRecovery(),
      );
    }
  }

  Future<void> loadSetup() async {
    final startingVersion = authEventVersion;
    final done = widget.showOnboarding ? await preference.completed() : true;
    if (widget.accessWrapper != null) {
      // AuthenticationRoot owns account boundaries and remote-record loading.
      if (mounted) {
        setState(() {
          entered = done;
          loading = false;
        });
      }
      return;
    }
    AuthUser? user;
    try {
      user = await auth.restoreSession();
    } on AuthException {
      if (mounted && startingVersion == authEventVersion) {
        sessionRestoreMessage = 'Could not restore the saved sign-in session. Please sign in again.';
      }
    }
    if (mounted) {
      if (startingVersion == authEventVersion) updateAuthUser(user);
      setState(() {
        entered = done;
        loading = false;
      });
    }
  }

  void _clearSessionBoundary() {
    // reset invalidates pending local writes; a new Navigator disposes old editors.
    session.reset();
    _navigationEpoch++;
  }

  void updateAuthUser(AuthUser? user) {
    if (!mounted) return;
    authEventVersion++;
    if (authenticatedUser?.id != user?.id || (user != null && demoMode)) {
      _clearSessionBoundary();
    }
    setState(() {
      authenticatedUser = user;
      completingPasswordRecovery = false;
      if (user != null) demoMode = false;
    });
  }

  Future<void> beginPasswordRecovery() async {
    final version = ++authEventVersion;
    _clearSessionBoundary();
    setState(() {
      authenticatedUser = null;
      demoMode = false;
      completingPasswordRecovery = false;
    });
    try {
      final user = await auth.restoreSession();
      if (!mounted || version != authEventVersion) return;
      setState(() {
        authenticatedUser = user;
        completingPasswordRecovery = user != null;
        demoMode = false;
      });
    } on AuthException {
      if (!mounted || version != authEventVersion) return;
      setState(() {
        sessionRestoreMessage = 'The password reset link could not be verified. Request a new link and try again.';
        completingPasswordRecovery = false;
        authenticatedUser = null;
      });
    }
  }

  Future<void> enter(bool sample) async {
    final saved = await preference.complete();
    if (!mounted) return;
    if (widget.accessWrapper != null &&
        sample &&
        session.records.entries.isEmpty) {
      session.records.reset(sample: true);
    }
    setState(() {
      entered = true;
      demoMode = widget.accessWrapper != null;
    });
    if (!saved) {
      // Unsupported platforms still allow entry; Android persists the flag.
      debugPrint(
        'Setup preference unavailable; onboarding may appear next launch.',
      );
    }
  }

  void enterDemo(bool sample) {
    authEventVersion++;
    _clearSessionBoundary();
    if (sample) session.records.reset(sample: true);
    setState(() {
      authenticatedUser = null;
      completingPasswordRecovery = false;
      demoMode = true;
    });
  }

  Future<void> signOut() async {
    authEventVersion++;
    _clearSessionBoundary();
    setState(() {
      authenticatedUser = null;
      demoMode = false;
      completingPasswordRecovery = false;
    });
    // Clear immediately even if SDK sign-out fails or completes after another login.
    await auth.signOut();
  }

  @override
  void dispose() {
    apiClient.close();
    authSubscription?.cancel();
    passwordRecoverySubscription?.cancel();
    if (widget.session == null) session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SessionScope(
    session: session,
    child: QuizIntegrationScope(
      signedIn:
          widget.externalAuthUser != null ||
          (authenticatedUser != null && !demoMode),
      userId: widget.externalAuthUser?.id ?? authenticatedUser?.id,
      service: modelQuizService,
      child: ListenableBuilder(
        listenable: session,
        builder: (context, _) => MaterialApp(
          key: ValueKey(_navigationEpoch),
          onGenerateRoute: (settings) {
            final destination = AppDestination.fromRoute(settings.name);
            if (destination == null &&
                !{
                  '/app/profile',
                  '/app/learn',
                  '/app/insights',
                  '/app/assistant',
                }.contains(settings.name)) {
              return null;
            }
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (routeContext) {
                if (widget.externalAuthUser == null &&
                    authenticatedUser == null &&
                    !demoMode) {
                  return LoginPage(
                    auth: auth,
                    onAuthenticated: updateAuthUser,
                    onDemoSelected: enterDemo,
                  );
                }
                if (destination != null) {
                  return AppShell(
                    initialDestination: destination,
                    authUser: widget.externalAuthUser ?? authenticatedUser,
                    onSignOut: widget.externalSignOut ?? signOut,
                  );
                }
                if (settings.name == '/app/assistant') return const ChatPage();
                final page = switch (settings.name) {
                  '/app/profile' => ProfilePage(
                    authUser: widget.externalAuthUser ?? authenticatedUser,
                    onSignOut: widget.externalSignOut ?? signOut,
                  ),
                  '/app/learn' => const LearnPage(),
                  _ => const InsightsPage(),
                };
                return Scaffold(
                  appBar: AppBar(title: const AuraCareBrandHeader()),
                  body: SafeArea(child: page),
                );
              },
            );
          },
          title: 'AuraCare',
          debugShowCheckedModeBanner: false,
          theme: auracareTheme(),
          navigatorObservers: [auraRouteObserver],
          routes: kDebugMode
              ? {
                  '/debug/onboarding': (context) =>
                      Onboarding(onEnter: (_) => Navigator.pop(context)),
                  '/debug/splash': (context) =>
                      WelcomeSplash(onContinue: () => Navigator.pop(context)),
                }
              : const {},
          builder: (context, child) {
            final media = MediaQuery.of(context);
            if (kDebugMode) {
              final physicalSize = Size(
                media.size.width * media.devicePixelRatio,
                media.size.height * media.devicePixelRatio,
              );
              final metrics =
                  'logical=${media.size.width.toStringAsFixed(1)}x'
                  '${media.size.height.toStringAsFixed(1)} dp, '
                  'physical=${physicalSize.width.toStringAsFixed(0)}x'
                  '${physicalSize.height.toStringAsFixed(0)} px, '
                  'dpr=${media.devicePixelRatio.toStringAsFixed(2)}, '
                  'textScale=${(media.textScaler.scale(14) / 14).toStringAsFixed(2)}, '
                  'padding=${media.padding}, viewPadding=${media.viewPadding}, '
                  'viewInsets=${media.viewInsets}, platform=${Theme.of(context).platform}';
              if (metrics != lastLayoutMetrics) {
                lastLayoutMetrics = metrics;
                debugPrint('[AuraCare layout] $metrics');
              }
            }
            final content = MediaQuery(
              data: media.copyWith(
                disableAnimations:
                    media.disableAnimations || session.reduceMotion,
              ),
              child: child!,
            );
            return widget.accessWrapper?.call(context, content) ?? content;
          },
          home: previewOnboarding
              ? Onboarding(
                  onEnter: (_) => setState(() => previewOnboarding = false),
                )
              : splash
              ? WelcomeSplash(
                  buttonLabel: entered ? 'Continue' : 'Get started',
                  onContinue: () {
                    if (!loading) setState(() => splash = false);
                  },
                )
              : !entered
              ? Onboarding(
                  onEnter: enter,
                  demoEntry: widget.accessWrapper != null,
                )
              : widget.accessWrapper != null
              ? AppShell(
                  authUser: widget.externalAuthUser,
                  onSignOut: widget.externalSignOut,
                )
              : completingPasswordRecovery
              ? UpdatePasswordPage(
                  auth: auth,
                  onPasswordUpdated: updateAuthUser,
                )
              : authenticatedUser != null || demoMode
              ? AppShell(authUser: authenticatedUser, onSignOut: signOut)
              : LoginPage(
                  auth: auth,
                  onAuthenticated: updateAuthUser,
                  onDemoSelected: enterDemo,
                  initialMessage: sessionRestoreMessage,
                ),
        ),
      ),
    ),
  );
}
