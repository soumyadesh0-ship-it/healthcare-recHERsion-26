import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../app/theme.dart';
import '../../core/widgets.dart';

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
    'Record what\nyou notice.',
    'Your history,\nin context.',
    'A little more\nprepared.',
  ];
  static const descriptions = [
    'A gentle space for symptoms, small observations and your own words. You choose what to record.',
    'Look back at the entries you made. Days without entries stay unknown, without assumptions.',
    'Bring selected notes and questions to a healthcare conversation. Your words stay yours.',
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
                  Text(
                    'auracare',
                    style: Theme.of(context).textTheme.titleLarge,
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
                      Center(child: Blossom(size: 190, variant: i % 2)),
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
                            color: index == i ? Palette.plum : Palette.orchid,
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
                          child: const Text('Next'),
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
