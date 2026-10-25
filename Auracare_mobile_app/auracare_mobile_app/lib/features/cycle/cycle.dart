import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/widgets.dart';
import '../../data/records.dart';
import '../../data/cycles.dart';
import '../logging/editor.dart';

/// Compatibility route retained for Profile; this is a summary, not a second calendar.
class CyclePage extends StatelessWidget {
  const CyclePage({super.key});
  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final history = CycleHistory(session.records.entries);
    final bleeding = session.records.entries
        .where((e) => e.type == EntryType.bleeding)
        .toList();
    return PageFrame(
      title: 'Cycle Summary',
      children: [
        const Heading('Your recorded rhythm.'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable cycle tracking'),
          subtitle: const Text(
            'This preference never deletes records. Log periods in Timeline.',
          ),
          value: session.cycleEnabled,
          onChanged: (v) => session.update(() => session.cycleEnabled = v),
        ),
        if (history.periods.isEmpty)
          const EmptyNotice(
            'Keep tracking your cycle to see patterns over time.',
            'Mark the first day of each period in Log period. Existing unmarked bleeding records remain below.',
          ),
        if (history.periods.isNotEmpty)
          Text('${history.periods.length} period starts recorded'),
        if (history.lengths.isNotEmpty)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: spaced([
                Text(
                  'Average recorded cycle: ${history.averageLength!.toStringAsFixed(1)} days',
                ),
                Text('${history.lengths.length} start-to-start interval(s)'),
                if (history.lengths.length >= 2)
                  Text(
                    'Shortest ${history.shortest} · longest ${history.longest} days',
                  ),
              ]),
            ),
          ),
        if (history.averageDuration != null)
          Text(
            'Average recorded period duration: ${history.averageDuration!.toStringAsFixed(1)} days (${history.periods.where((p) => p.duration != null).length} periods with an explicit end)',
          ),
        const Text(
          'Gaps in logging are unknown. Only explicitly marked starts and ends are used; these counts do not confirm ovulation.',
        ),
        if (history.periods.isNotEmpty)
          Text(
            'Recent period history',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        for (final period in history.periods.reversed.take(8))
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${dayLabel(period.start)} — ${period.end == null ? 'end not recorded' : dayLabel(period.end!)}',
                ),
                Text(
                  '${period.records.map((e) => dayLabel(e.when)).toSet().length} bleeding days logged',
                ),
                Text(
                  FlowIntensity.values
                      .map(
                        (f) =>
                            '${f.name}: ${period.records.where((e) => e.flowIntensity == f).map((e) => dayLabel(e.when)).toSet().length}',
                      )
                      .join(' · '),
                ),
              ],
            ),
          ),
        Text(
          'Saved bleeding entries',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (bleeding.isEmpty) const Text('No period records yet.'),
        for (final e in bleeding)
          EntryCard(
            entry: e,
            onTap: () => openEditor(context, entry: e),
          ),
        const Text(
          'Review or correct an entry here. Use the main Timeline calendar to record another day.',
        ),
      ],
    );
  }
}
