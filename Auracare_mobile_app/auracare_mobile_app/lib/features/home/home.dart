import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../app/quiz_integration.dart';
import '../../app/theme.dart';
import '../../core/widgets.dart';
import '../../data/records.dart';

import '../logging/editor.dart';
import '../journal/journal.dart';
import '../appointments/appointments.dart';
import '../pcos_quiz/quiz.dart';
import '../timeline/timeline.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, this.onWellbeing, this.onQuiz});
  final VoidCallback? onWellbeing, onQuiz;
  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
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
                      'Hello, Alex.',
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
        FilledButton.icon(
          onPressed: () => pushPage(context, const LogEntryPage()),
          icon: const Icon(Icons.add),
          label: const Text('Log entry'),
        ),
        Text('Your spaces', style: Theme.of(context).textTheme.titleLarge),
        ActionCard(
          title: 'Journal',
          color: Palette.periwinkle,
          subtitle: 'A separate place for your words',
          icon: Icons.edit_note,
          onTap: () => pushPage(context, const JournalPage()),
        ),
        ActionCard(
          title: 'Wellbeing',
          color: Palette.lavender,
          subtitle: 'A little play or a gentle pause',
          icon: Icons.spa_outlined,
          onTap:
              onWellbeing ?? () => pushPage(context, const MoodCheckInPage()),
        ),
        ActionCard(
          title: 'PCOS quiz',
          color: Palette.yellow,
          subtitle: QuizIntegrationScope.maybeOf(context)?.signedIn == true
              ? 'Experimental questionnaire'
              : 'Experimental questionnaire demo',
          icon: Icons.assignment_outlined,
          onTap: onQuiz ?? () => pushPage(context, const QuizPage()),
        ),
        ActionCard(
          title: 'Appointment preparation',
          color: Palette.turquoise,
          subtitle: 'Choose notes and questions to take with you',
          icon: Icons.description_outlined,
          onTap: () => pushPage(context, const AppointmentPage()),
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
