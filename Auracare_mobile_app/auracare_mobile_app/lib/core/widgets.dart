import 'characters.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../app/session.dart';
import '../data/records.dart';

void tell(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
Future<void> copyText(BuildContext context, String text) async {
  try {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) tell(context, 'Copied to clipboard');
  } catch (_) {
    if (context.mounted) {
      tell(context, 'Clipboard unavailable. Please try again.');
    }
  }
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message, {
  String action = 'Confirm',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;
void pushPage(BuildContext context, Widget child) {
  final duration = MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 180);
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, animation, secondary) => child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (_, animation, secondary, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key, this.isAuthenticated = false});
  final bool isAuthenticated;

  String get label => isAuthenticated
      ? 'Account signed in · records are session-only'
      : 'Demo — sample data';

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
    child: Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: Palette.orchid,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context
                        .dependOnInheritedWidgetOfExactType<SessionScope>()
                        ?.notifier
                        ?.records
                        .isRemote ==
                    true
                ? 'Cloud records are deployment-gated · status shown above'
                : label,
            style: Theme.of(context).textTheme.bodyMedium!
                .copyWith(fontSize: 14),
          ),
        ),
      ],
    ),
  );
}

double demoBadgeHeight(BuildContext context, {bool isAuthenticated = false}) {
  final availableWidth = MediaQuery.sizeOf(context).width - 55;
  // Android can attach the widget tree before its first viewport metrics arrive.
  if (availableWidth <= 0) return 0;
  final painter = TextPainter(
    text: TextSpan(
      text:
          context
                  .dependOnInheritedWidgetOfExactType<SessionScope>()
                  ?.notifier
                  ?.records
                  .isRemote ==
              true
          ? 'Cloud records are deployment-gated · status shown above'
          : isAuthenticated
          ? 'Account signed in · records are session-only'
          : 'Demo — sample data',
      style: Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: 14),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  );
  painter.layout(maxWidth: availableWidth);
  final height = painter.height.ceilToDouble() + 8;
  painter.dispose();
  return height;
}

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.children,
    this.embedded = false,
  });
  final String title;
  final List<Widget> children;
  final bool embedded;
  @override
  Widget build(BuildContext context) => embedded
      ? ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: spaced(children),
        )
      : Scaffold(
          appBar: AppBar(
            title: Text(title),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(demoBadgeHeight(context)),
              child: DemoBadge(),
            ),
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: spaced(children),
            ),
          ),
        );
}

List<Widget> spaced(List<Widget> items, {double gap = 16}) => [
  for (var i = 0; i < items.length; i++) ...[
    if (i > 0) SizedBox(height: gap),
    items[i],
  ],
];

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.color = Palette.input});
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
}

class Heading extends StatelessWidget {
  const Heading(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.headlineMedium);
}

class EmptyNotice extends StatelessWidget {
  const EmptyNotice(this.title, this.message, {super.key});
  final String title, message;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: spaced([
        const Character(kind: AuraCharacter.blob, size: 72),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        Text(message),
      ]),
    ),
  );
}

class ErrorNotice extends StatelessWidget {
  const ErrorNotice(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Palette.plum),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    this.leading,
    required this.onTap,
    this.color = Palette.input,
  }) : assert(icon != null || leading != null);
  final String title, subtitle;
  final IconData? icon;
  final Widget? leading;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            leading ?? Icon(icon, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, size: 20),
          ],
        ),
      ),
    ),
  );
}

IconData entryIcon(EntryType type) => switch (type) {
  EntryType.symptom => Icons.waves_outlined,
  EntryType.journal => Icons.edit_note,
  EntryType.spotting => Icons.grain,
  EntryType.discharge => Icons.opacity_outlined,
  EntryType.bleeding => Icons.water_drop_outlined,
  EntryType.wellness => Icons.spa_outlined,
};

class EntryCard extends StatelessWidget {
  const EntryCard({super.key, required this.entry, required this.onTap});
  final HealthEntry entry;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ActionCard(
    title: entry.title,
    subtitle:
        '${entry.observationTimeKnown ? timeLabel(entry.when) : 'Time not recorded'} · ${entry.type.name}\n${entry.zone}${entry.tracking == null ? '' : '\n${entry.tracking!.summary}'}',
    icon: entryIcon(entry.type),
    onTap: onTap,
  );
}

class Blossom extends StatelessWidget {
  const Blossom({super.key, this.size = 160, this.variant = 0});
  final double size;
  final int variant;
  @override
  Widget build(BuildContext context) => Character(
    size: size,
    kind: variant == 1 ? AuraCharacter.square : AuraCharacter.flower,
  );
}

class UnavailablePage extends StatelessWidget {
  const UnavailablePage(this.title, this.explanation, {super.key});
  final String title, explanation;
  @override
  Widget build(BuildContext context) => PageFrame(
    title: title,
    children: [
      Heading(title),
      EmptyNotice('Not connected', explanation),
      const Text(
        'No data is sent. Return to the demo to record, review or prepare questions.',
      ),
    ],
  );
}
