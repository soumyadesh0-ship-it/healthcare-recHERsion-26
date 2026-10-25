import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../app/theme.dart';
import '../../core/widgets.dart';
import '../../data/records.dart';

import '../logging/editor.dart';
import '../journal/journal.dart';
import '../appointments/appointments.dart';
import '../pcos_quiz/quiz.dart';
import '../timeline/timeline.dart';
import '../chat/chat.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
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
          title: 'Wellbeing check-in',
          color: Palette.lavender,
          subtitle: 'Optional mood, energy, stress or sleep note',
          icon: Icons.spa_outlined,
          onTap: () => pushPage(context, const MoodCheckInPage()),
        ),
        ActionCard(
          title: 'PCOS quiz',
          color: Palette.yellow,
          subtitle: 'Experimental questionnaire demo',
          icon: Icons.assignment_outlined,
          onTap: () => pushPage(context, const QuizPage()),
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
        Text(
          'More from Auracare',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        ActionCard(
          title: 'AI Assistant',
          subtitle: session.chatService == null
              ? 'Not available in demo mode'
              : 'General information — consent required for every message',
          icon: Icons.chat_bubble_outline,
          onTap: () => pushPage(context, const ChatPage()),
        ),
        ActionCard(
          title: 'Sisterhood',
          subtitle: 'Community — not connected',
          icon: Icons.people_outline,
          onTap: () => pushPage(
            context,
            const UnavailablePage(
              'Sisterhood',
              'Community and moderation are not connected. Private records never attach to community posts. Pseudonyms would not guarantee complete anonymity.',
            ),
          ),
        ),
        ActionCard(
          title: 'Appointments & Clinic',
          subtitle: 'Directory and booking — not connected',
          icon: Icons.local_hospital_outlined,
          onTap: () => pushPage(
            context,
            const UnavailablePage(
              'Appointments & Clinic',
              'No verified provider directory or booking integration exists. No appointment availability or confirmation is shown. Appointment preparation is available from Home.',
            ),
          ),
        ),
      ]),
    );
  }
}
