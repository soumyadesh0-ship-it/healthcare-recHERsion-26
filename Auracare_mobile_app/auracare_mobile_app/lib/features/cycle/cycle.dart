import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/calendar.dart';
import '../../core/widgets.dart';
import '../../data/records.dart';
import '../logging/editor.dart';

class CyclePage extends StatefulWidget {
  const CyclePage({super.key});
  @override
  State<CyclePage> createState() => _CyclePageState();
}

class _CyclePageState extends State<CyclePage> {
  DateTime selected = dayOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final bleeding = session.records.entries
        .where((e) => e.type == EntryType.bleeding)
        .toList();
    final matches = bleeding
        .where((e) => dayLabel(e.when) == dayLabel(selected))
        .toList();

    return PageFrame(
      title: 'Cycle records',
      children: [
        const Heading('Your recorded days.'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable cycle tracking'),
          subtitle: const Text(
            'Enable the selected-day recording tools here. Existing records always remain visible in Timeline.',
          ),
          value: session.cycleEnabled,
          onChanged: (v) => session.update(() => session.cycleEnabled = v),
        ),
        if (!session.cycleEnabled)
          const EmptyNotice(
            'Optional, always',
            'You can use Auracare without cycle tracking. Enable it to add bleeding days.',
          ),
        if (session.cycleEnabled) ...[
          RecordCalendar(
            entries: bleeding,
            selected: selected,
            onSelect: (day) => setState(() => selected = day),
          ),
          Text('Selected: ${dayLabel(selected)}'),
          FilledButton(
            onPressed: () =>
                openEditor(context, type: EntryType.bleeding, day: selected),
            child: const Text('Record bleeding day'),
          ),
          for (final e in matches)
            EntryCard(
              entry: e,
              onTap: () => openEditor(context, entry: e),
            ),
          if (matches.isEmpty)
            const Text('No bleeding entry for this selected day.'),
        ],
        const Text(
          'No fertile windows, 28-day assumptions or pregnancy predictions. Cycle estimates are unavailable without a reviewed method. These records are not contraception guidance.',
        ),
      ],
    );
  }
}
