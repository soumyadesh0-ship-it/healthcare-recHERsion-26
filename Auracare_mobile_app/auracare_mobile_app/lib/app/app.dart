import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'dart:async';

import 'auth_service.dart';
import 'quiz_integration.dart';
import 'session.dart';
import 'setup_preference.dart';
import '../data/records.dart';
import 'theme.dart';
import 'shell.dart';
import 'navigation.dart';
import '../core/brand.dart';
import '../features/profile/profile.dart';
import '../features/learn/learn.dart';
import '../features/insights/insights.dart';
import '../features/onboarding/onboarding.dart';
import '../features/auth/auth.dart';

class AuracareApp extends StatefulWidget {
  const AuracareApp({
    super.key,
    this.session,
    this.authService,
    this.showOnboarding = true,
  });
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
    authSubscription = auth.sessionChanges.listen(updateAuthUser);
    passwordRecoverySubscription = auth.passwordRecoveryEvents.listen(
      (_) => beginPasswordRecovery(),
    );
  }

  Future<void> loadSetup() async {
    final done = widget.showOnboarding ? await preference.completed() : true;
    final startingVersion = authEventVersion;
    AuthUser? user;
    try {
      user = await auth.restoreSession();
    } on AuthException {
      sessionRestoreMessage =
          'Could not restore the saved sign-in session. Please sign in again.';
    }
    if (mounted) {
      if (user != null && demoMode) session.reset();
      setState(() {
        entered = done;
        if (startingVersion == authEventVersion) {
          authenticatedUser = user;
          if (user != null) demoMode = false;
        }
        loading = false;
      });
    }
  }

  void updateAuthUser(AuthUser? user) {
    if (!mounted) return;
    authEventVersion++;
    if (user != null &&
        (demoMode ||
            (authenticatedUser != null && authenticatedUser!.id != user.id))) {
      session.reset();
    }
    setState(() {
      authenticatedUser = user;
      completingPasswordRecovery = false;
      if (user != null) demoMode = false;
    });
  }

  Future<void> beginPasswordRecovery() async {
    try {
      final user = await auth.restoreSession();
      if (!mounted) return;
      setState(() {
        authenticatedUser = user;
        completingPasswordRecovery = user != null;
        demoMode = false;
      });
    } on AuthException {
      if (!mounted) return;
      setState(() {
        sessionRestoreMessage = 'The password reset link could not be verified. Request a new link and try again.';
        completingPasswordRecovery = false;
        authenticatedUser = null;
      });
    }
  }

  Future<void> enter(bool _) async {
    final saved = await preference.complete();
    if (!mounted) return;
    setState(() {
      entered = true;
      demoMode = false;
    });
    if (!saved) {
      // Unsupported platforms still allow entry; Android persists the flag.
      debugPrint(
        'Setup preference unavailable; onboarding may appear next launch.',
      );
    }
  }

  void enterDemo(bool sample) {
    if (sample && session.records.entries.isEmpty) {
      session.records.reset(sample: true);
    }
    setState(() => demoMode = true);
  }

  Future<void> signOut() async {
    await auth.signOut();
    if (!mounted) return;
    session.reset();
    setState(() {
      authenticatedUser = null;
      demoMode = false;
      completingPasswordRecovery = false;
    });
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
      signedIn: authenticatedUser != null && !demoMode,
      userId: authenticatedUser?.id,
      service: modelQuizService,
      child: ListenableBuilder(
        listenable: session,
        builder: (context, _) => MaterialApp(
          title: 'AuraCare',
          debugShowCheckedModeBanner: false,
          theme: auracareTheme(),
          navigatorObservers: [auraRouteObserver],
          onGenerateRoute: (settings) {
            final destination = AppDestination.fromRoute(settings.name);
            if (destination == null &&
                !{
                  '/app/profile',
                  '/app/learn',
                  '/app/insights',
                }.contains(settings.name)) {
              return null;
            }
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (routeContext) {
                if (authenticatedUser == null && !demoMode) {
                  return LoginPage(
                    auth: auth,
                    onAuthenticated: (user) {
                      updateAuthUser(user);
                      Navigator.of(routeContext)
                          .popUntil((route) => route.isFirst);
                    },
                    onDemoSelected: (sample) {
                      enterDemo(sample);
                      Navigator.of(routeContext)
                          .popUntil((route) => route.isFirst);
                    },
                  );
                }
                if (destination != null) {
                  return AppShell(
                    initialDestination: destination,
                    authUser: authenticatedUser,
                    onSignOut: signOut,
                  );
                }
                final page = switch (settings.name) {
                  '/app/profile' => ProfilePage(
                    authUser: authenticatedUser,
                    onSignOut: () async {
                      await signOut();
                      if (routeContext.mounted) {
                        Navigator.of(routeContext)
                            .popUntil((route) => route.isFirst);
                      }
                    },
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
            return MediaQuery(
              data: media.copyWith(
                disableAnimations:
                    media.disableAnimations || session.reduceMotion,
              ),
              child: child!,
            );
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
              ? Onboarding(onEnter: enter)
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
