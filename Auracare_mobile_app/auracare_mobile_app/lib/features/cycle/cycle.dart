import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../app/theme.dart';
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
  late DateTime month = DateTime(selected.year, selected.month);
  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final bleeding = session.records.entries
        .where((e) => e.type == EntryType.bleeding)
        .toList();
    final matches = bleeding
        .where((e) => dayLabel(e.when) == dayLabel(selected))
        .toList();
    final days = DateTime(month.year, month.month + 1, 0).day;
    return PageFrame(
      title: 'Cycle records',
      children: [
        const Heading('Your recorded days.'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable cycle tracking'),
          subtitle: const Text(
            'Turning off hides the calendar action on Home. Existing records remain in Timeline; delete them separately.',
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
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => setState(
                  () => month = DateTime(month.year, month.month - 1),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${month.year}-${month.month.toString().padLeft(2, '0')}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: () => setState(
                  () => month = DateTime(month.year, month.month + 1),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const Text(
            'Filled day + drop: recorded bleeding. Outlined day: selected. Other days: unrecorded, not symptom-free.',
          ),
          // Flexible day grid preserves >=48px touch targets at narrow widths.
          const Text('Select a day to review or add a record.'),
          LayoutBuilder(
            builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
              final columns = constraints.maxWidth >= 360 ? 6 : 5;
              return Wrap(
                spacing: 4,
                runSpacing: 4,
                children: List.generate(days, (i) {
                  final day = DateTime(month.year, month.month, i + 1);
                  final recorded = bleeding.any(
                    (e) => dayLabel(e.when) == dayLabel(day),
                  );
                  final active = dayLabel(day) == dayLabel(selected);
                  return SizedBox(
                    width: (constraints.maxWidth - (columns - 1) * 4) / columns,
                    child: Semantics(
                      selected: active,
                      label:
                          '${dayLabel(day)}, ${recorded ? 'bleeding recorded' : 'unrecorded'}',
                      button: true,
                      excludeSemantics: true,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          minimumSize: Size(48, 48 * scale),
                          backgroundColor: recorded
                              ? Palette.blush
                              : Palette.mist,
                          side: BorderSide(
                            color: Palette.plum,
                            width: active ? 3 : 1,
                          ),
                        ),
                        onPressed: () => setState(() => selected = day),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${i + 1}'),
                            if (recorded)
                              const Icon(Icons.water_drop_outlined, size: 16),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
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
