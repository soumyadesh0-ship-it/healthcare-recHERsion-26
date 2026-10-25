import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../app/theme.dart';
import '../../core/widgets.dart';
import '../../core/characters.dart';

class Onboarding extends StatefulWidget {
  const Onboarding({super.key, required this.onEnter});
  final ValueChanged<bool> onEnter;
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final controller = PageController();
  int index = 0;
  static const titles = [
    'Your body. Your rhythm. Your space.',
    'Small steps for a healthier you.',
    'Knowledge for every stage.',
  ];
  static const descriptions = [
    'A little room to notice, reflect and care for yourself.',
    'Track what matters to you, one observation at a time.',
    'Explore topics and prepare your own questions.',
  ];
  void go(int page) {
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.jumpToPage(page);
    } else {
      controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'auracare',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(onPressed: () => go(2), child: const Text('Skip')),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: controller,
                onPageChanged: (v) => setState(() => index = v),
                children: List.generate(
                  3,
                  (i) => ListView(
                    padding: const EdgeInsets.all(20),
                    children: spaced([
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: i == 1 ? Palette.lavender : Palette.blush,
                            borderRadius: BorderRadius.circular(
                              i == 1 ? 80 : 110,
                            ),
                          ),
                          child: Character(
                            size: 160,
                            kind: [
                              AuraCharacter.flower,
                              AuraCharacter.square,
                              AuraCharacter.diamond,
                            ][i],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Heading(titles[i]),
                      Text(descriptions[i]),
                      if (i == 2) ...[
                        const Panel(
                          child: Text(
                            'Explore with fictional sample records or start empty. Demo entries last only for this session and disappear on restart. Please do not enter real health information.',
                          ),
                        ),
                        const Text(
                          'Account connection coming later',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Text(
                          'Service purpose: display and edit a synthetic session. No account, remote storage or legal consent system is connected.',
                        ),
                        DropdownButtonFormField<String>(
                          itemHeight: null,
                          initialValue: session.zone,
                          decoration: const InputDecoration(
                            labelText: 'Time display',
                          ),
                          isExpanded: true,
                          items: const ['Device local', 'UTC']
                              .map(
                                (z) =>
                                    DropdownMenuItem(value: z, child: Text(z)),
                              )
                              .toList(),
                          onChanged: (v) =>
                              session.update(() => session.zone = v!),
                        ),
                        const Text(
                          'Device local uses this device’s clock. UTC is supported explicitly; no named-zone conversion is claimed.',
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Optional cycle tracking'),
                          value: session.cycleEnabled,
                          onChanged: (v) =>
                              session.update(() => session.cycleEnabled = v),
                        ),
                        FilledButton(
                          onPressed: () => widget.onEnter(true),
                          child: const Text('Explore demo'),
                        ),
                        OutlinedButton(
                          onPressed: () => widget.onEnter(false),
                          child: const Text('Start empty demo'),
                        ),
                      ],
                    ]),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    label: 'Page ${index + 1} of 3',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (i) => Container(
                          margin: const EdgeInsets.all(4),
                          width: index == i ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: index == i ? Palette.purple : Palette.input,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (index > 0)
                        OutlinedButton(
                          onPressed: () => go(index - 1),
                          child: const Text('Back'),
                        ),
                      const Spacer(),
                      if (index < 2)
                        FilledButton(
                          onPressed: () => go(index + 1),
                          style: FilledButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(16),
                          ),
                          child: Semantics(
                            label: 'Next',
                            child: const Icon(Icons.arrow_forward),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WelcomeSplash extends StatelessWidget {
  const WelcomeSplash({super.key, required this.onContinue});
  final VoidCallback onContinue;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 48),
                      Text(
                        'auracare',
                        style: Theme.of(context).textTheme.headlineLarge!
                            .copyWith(fontSize: 48, letterSpacing: -2),
                      ),
                      const SizedBox(height: 16),
                      const Text('A kinder way to understand your body.'),
                    ],
                  ),
                  const SizedBox(height: 100),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: CharacterCluster()),
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: onContinue,
                        child: const Text('Get started'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
