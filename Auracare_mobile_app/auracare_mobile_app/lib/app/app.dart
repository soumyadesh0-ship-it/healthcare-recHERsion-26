import 'package:flutter/material.dart';

import 'session.dart';
import 'setup_preference.dart';
import '../data/records.dart';
import 'theme.dart';
import 'shell.dart';
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
  bool splash = true;
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
    session.records.reset(sample: sample);
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
        home: loading
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : entered
            ? const AppShell()
            : splash
            ? WelcomeSplash(onContinue: () => setState(() => splash = false))
            : Onboarding(onEnter: enter),
      ),
    ),
  );
}
