import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'session.dart';
import 'setup_preference.dart';
import '../data/records.dart';
import 'theme.dart';
import 'shell.dart';
import 'navigation.dart';
import '../features/profile/profile.dart';
import '../features/learn/learn.dart';
import '../features/insights/insights.dart';
import '../features/onboarding/onboarding.dart';

class AuracareApp extends StatefulWidget {
  const AuracareApp({super.key, this.session, this.showOnboarding = true});
  final DemoSession? session;
  final bool showOnboarding;
  @override
  State<AuracareApp> createState() => _AuracareAppState();
}

class _AuracareAppState extends State<AuracareApp> {
  late final DemoSession session =
      widget.session ??
      DemoSession(records: DemoRecordsRepository(sample: false));
  late bool entered = !widget.showOnboarding;
  bool loading = true;
  late bool splash = widget.showOnboarding;
  bool previewOnboarding =
      kDebugMode && const bool.fromEnvironment('PREVIEW_ONBOARDING');
  final preference = SetupPreference();
  @override
  void initState() {
    super.initState();
    loadSetup();
  }

  Future<void> loadSetup() async {
    final done = widget.showOnboarding ? await preference.completed() : true;
    if (mounted) {
      setState(() {
        entered = done;
        loading = false;
      });
    }
  }

  Future<void> enter(bool sample) async {
    final saved = await preference.complete();
    if (!mounted) return;
    if (sample && session.records.entries.isEmpty) {
      session.records.reset(sample: true);
    }
    setState(() => entered = true);
    if (!saved) {
      // Unsupported platforms still allow entry; Android persists the flag.
      debugPrint(
        'Setup preference unavailable; onboarding may appear next launch.',
      );
    }
  }

  @override
  void dispose() {
    if (widget.session == null) session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SessionScope(
    session: session,
    child: ListenableBuilder(
      listenable: session,
      builder: (context, _) => MaterialApp(
        title: 'AuraCare',
        navigatorObservers: [auraRouteObserver],
        debugShowCheckedModeBanner: false,
        theme: auracareTheme(),
        onGenerateRoute: (settings) {
          final destination = AppDestination.fromRoute(settings.name);
          if (destination == null) {
            final page = switch (settings.name) {
              '/app/profile' => const ProfilePage(),
              '/app/learn' => const LearnPage(),
              '/app/insights' => const InsightsPage(),
              _ => null,
            };
            if (page == null) return null;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('auracare')),
                body: SafeArea(child: page),
              ),
            );
          }
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => AppShell(initialDestination: destination),
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
            : entered
            ? const AppShell()
            : Onboarding(onEnter: enter),
      ),
    ),
  );
}
