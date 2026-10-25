import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'session.dart';
import 'setup_preference.dart';
import '../data/records.dart';
import 'theme.dart';
import 'shell.dart';
import 'navigation.dart';
import '../features/onboarding/onboarding.dart';

class AuracareApp extends StatefulWidget {
  const AuracareApp({super.key, this.session, this.showOnboarding = true});
  final DemoSession? session;
  final bool showOnboarding;
  @override
  State<AuracareApp> createState() => _AuracareAppState();
}

class _AuracareAppState extends State<AuracareApp> {
  String? lastLayoutMetrics;
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
