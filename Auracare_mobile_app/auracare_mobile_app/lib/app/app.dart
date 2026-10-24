import 'package:flutter/material.dart';

import 'session.dart';
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
  late final DemoSession session = widget.session ?? DemoSession();
  late bool entered = !widget.showOnboarding;
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
        title: 'Auracare',
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
        home: entered
            ? const AppShell()
            : Onboarding(
                onEnter: (sample) {
                  session.records.reset(sample: sample);
                  setState(() => entered = true);
                },
              ),
      ),
    ),
  );
}
