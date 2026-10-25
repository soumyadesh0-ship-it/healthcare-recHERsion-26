import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../app/theme.dart';
import '../../core/widgets.dart';
import '../../data/records.dart';

import '../logging/editor.dart';
import '../logging/inline_log_entry.dart';
import '../journal/journal.dart';
import '../timeline/timeline.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, this.onWellbeing, this.onQuiz, this.displayName});
  final VoidCallback? onWellbeing, onQuiz;
  final String? displayName;
  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final name = displayName?.trim();
    final entries = session.records.entries;
    final now = session.zone == 'UTC' ? DateTime.now().toUtc() : DateTime.now();
    return ListView(
      key: const PageStorageKey('home'),
      padding: const EdgeInsets.all(20),
      children: spaced([
        Text(
          '${dayLabel(now)} · ${session.zone}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const Heading('A little space\nfor you.'),
        Panel(
          color: Palette.blush,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name == null || name.isEmpty ? 'Hello.' : 'Hello, $name.',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text('Take a moment. Go at your own pace.'),
                  ],
                ),
              ),
              const Blossom(size: 88),
            ],
          ),
        ),
        Text(
          '${entries.length} records in this session',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text('Log Entry', style: Theme.of(context).textTheme.titleLarge),
        const InlineLogEntry(),
        Text('Your spaces', style: Theme.of(context).textTheme.titleLarge),
        ActionCard(
          title: 'AI Assistant',
          color: Palette.lavender,
          subtitle: 'Ask AuraCare a question',
          icon: Icons.chat_bubble_outline,
          onTap: () => Navigator.of(context).pushNamed('/app/assistant'),
        ),
        ActionCard(
          title: 'Journal',
          color: Palette.periwinkle,
          subtitle: 'A separate place for your words',
          icon: Icons.edit_note,
          onTap: () => pushPage(context, const JournalPage()),
        ),

        TextButton(
          onPressed: () => pushPage(context, const TimelineScreen()),
          child: const Text('View source records'),
        ),
        Text('Recent records', style: Theme.of(context).textTheme.titleLarge),
        if (entries.isEmpty)
          const EmptyNotice(
            'No records yet',
            'This is different from having no symptoms. Unrecorded days remain unknown.',
          ),
        for (final e in entries.take(3)) ...[
          Text(dayLabel(e.when), style: Theme.of(context).textTheme.bodySmall),
          EntryCard(
            entry: e,
            onTap: () => openEditor(context, entry: e),
          ),
        ],
      ]),
    );
  }
}
