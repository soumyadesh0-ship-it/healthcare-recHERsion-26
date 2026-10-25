import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/records.dart';
import '../data/cycles.dart';

Color phaseColor(PhaseEstimate estimate) => switch (estimate.phase) {
  CyclePhase.menstrual => Palette.blush,
  CyclePhase.follicular => Palette.follicular,
  CyclePhase.fertile => Palette.fertile,
  CyclePhase.ovulation => Palette.ovulation,
  CyclePhase.luteal => Palette.lavender,
  CyclePhase.approaching => Palette.approaching[estimate.step.clamp(0, 2)],
  CyclePhase.predictedPeriod => Palette.pink,
};

Color eventColor(EntryType type) => switch (type) {
  EntryType.bleeding => Palette.pink,
  EntryType.symptom => Palette.yellow,
  EntryType.wellness => Palette.turquoise,
  EntryType.journal => Palette.periwinkle,
  EntryType.spotting => Palette.orchid,
  EntryType.discharge => Palette.apricot,
};
Color flowColor(FlowIntensity intensity) => switch (intensity) {
  FlowIntensity.spotting => Palette.blush,
  FlowIntensity.light => Palette.lightFlow,
  FlowIntensity.moderate => Palette.moderateFlow,
  FlowIntensity.heavy => Palette.heavyFlow,
  FlowIntensity.unspecified => Palette.lavender,
};
Color moodColor(RecordedMood mood) => switch (mood) {
  RecordedMood.happy => Palette.happyMood,
  RecordedMood.calm => Palette.turquoise,
  RecordedMood.sad => Palette.blue,
  RecordedMood.anxious => Palette.coral,
  RecordedMood.tired => Palette.tiredMood,
  RecordedMood.energetic => Palette.pink,
};
String flowLabel(FlowIntensity intensity) => switch (intensity) {
  FlowIntensity.spotting => 'Spotting',
  FlowIntensity.light => 'Light flow',
  FlowIntensity.moderate => 'Medium flow',
  FlowIntensity.heavy => 'Heavy flow',
  FlowIntensity.unspecified => 'Unspecified period',
};

/// Monday-first calendar: period intensity is fill; the latest saved mood is border.
class RecordCalendar extends StatefulWidget {
  const RecordCalendar({
    super.key,
    required this.entries,
    required this.onSelect,
    this.selected,
    this.estimates,
  });
  final List<HealthEntry> entries;
  final ValueChanged<DateTime> onSelect;
  final DateTime? selected;
  final CycleEstimates? estimates;
  @override
  State<RecordCalendar> createState() => _RecordCalendarState();
}

class _RecordCalendarState extends State<RecordCalendar> {
  late DateTime month = DateTime(
    (widget.selected ?? DateTime.now()).year,
    (widget.selected ?? DateTime.now()).month,
  );
  static const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  Widget legend(
    Color color,
    String label,
    BuildContext context, {
    bool border = false,
  }) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: border ? null : color,
          shape: BoxShape.circle,
          border: border ? Border.all(color: color, width: 2) : null,
        ),
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final offset = month.weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final cellHeight = 52.0 * scale;
    final selected = widget.selected == null
        ? null
        : RecordedDay(widget.entries, widget.selected!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: () =>
                  setState(() => month = DateTime(month.year, month.month - 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${months[month.month - 1]} ${month.year}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: () =>
                  setState(() => month = DateTime(month.year, month.month + 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth < 336 * scale
                ? 336 * scale
                : constraints.maxWidth;
            return SingleChildScrollView(
              key: const PageStorageKey('record-calendar-horizontal-scroll'),
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: Column(
                  children: [
                    Row(
                      children: [
                        for (final day in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                          Expanded(
                            child: Center(
                              child: Text(
                                day,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (var row = 0; row < (offset + days + 6) ~/ 7; row++)
                      Row(
                        children: List.generate(7, (column) {
                          final number = row * 7 + column - offset + 1;
                          if (number < 1 || number > days) {
                            return Expanded(
                              child: SizedBox(height: cellHeight),
                            );
                          }
                          final date = DateTime(
                            month.year,
                            month.month,
                            number,
                          );
                          final summary = RecordedDay(widget.entries, date);
                          final events = summary.entries
                              .map((e) => e.type)
                              .toSet();
                          final active =
                              widget.selected != null &&
                              dayLabel(widget.selected!) == dayLabel(date);
                          final flow = summary.period?.flowIntensity;
                          final estimate = widget.estimates?.on(date);
                          final mood = summary.moodEntry?.recordedMood;
                          final description = [
                            if (events.isEmpty)
                              'unrecorded'
                            else
                              events.map((e) => e.name).join(', '),
                            if (flow != null) flowLabel(flow),
                            if (flow != null) CyclePhase.menstrual.label,
                            if (mood != null) 'Mood: ${mood.label}',
                            if (estimate != null) estimate.phase.label,
                          ].join('; ');
                          return Expanded(
                            child: SizedBox(
                              height: cellHeight,
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Semantics(
                                  selected: active,
                                  label: '${dayLabel(date)}, $description',
                                  button: true,
                                  excludeSemantics: true,
                                  child: Material(
                                    key: ValueKey(
                                      'calendar-day-${dayLabel(date)}',
                                    ),
                                    color: flow == null
                                        ? (estimate == null
                                              ? Palette.white
                                              : phaseColor(estimate))
                                        : flowColor(flow),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(
                                        color: mood == null
                                            ? Colors.transparent
                                            : moodColor(mood),
                                        width: 2,
                                      ),
                                    ),
                                    child: Ink(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        gradient: flow == null
                                            ? null
                                            : LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Color.lerp(
                                                    Palette.white,
                                                    flowColor(flow),
                                                    .55,
                                                  )!,
                                                  flowColor(flow),
                                                ],
                                              ),
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: () => widget.onSelect(date),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              '$number',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color:
                                                    flow == FlowIntensity.heavy
                                                    ? Palette.flowInk
                                                    : Palette.ink,
                                                fontWeight: active
                                                    ? FontWeight.w800
                                                    : FontWeight.w400,
                                                decoration: active
                                                    ? TextDecoration.underline
                                                    : null,
                                                decorationColor: Palette.action,
                                                decorationThickness: 2,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            if (estimate != null)
                                              Container(
                                                key: ValueKey(
                                                  'estimate-${dayLabel(date)}',
                                                ),
                                                width: 8,
                                                height: 4,
                                                decoration: BoxDecoration(
                                                  color: phaseColor(estimate),
                                                  border: Border.all(
                                                    color: Palette.action,
                                                  ),
                                                ),
                                              ),
                                            Wrap(
                                              spacing: 2,
                                              children: [
                                                for (final type in events.where(
                                                  (t) =>
                                                      t != EntryType.bleeding &&
                                                      (t !=
                                                              EntryType
                                                                  .wellness ||
                                                          mood == null),
                                                ))
                                                  Container(
                                                    width: 5,
                                                    height: 5,
                                                    decoration: BoxDecoration(
                                                      color: eventColor(type),
                                                      shape: BoxShape.circle,
                                                    ),
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
                            ),
                          );
                        }),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        if (widget.estimates?.available == true) ...[
          Text(
            'Approximate phases · outlined markers are estimates',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final phase in CyclePhase.values.where(
                (p) => p != CyclePhase.menstrual,
              ))
                legend(phaseColor(PhaseEstimate(phase)), phase.label, context),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            for (final flow in FlowIntensity.values)
              legend(flowColor(flow), flowLabel(flow), context),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Fill: recorded flow. Border: mood. Tap a day for details.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        ExpansionTile(
          // Keep the boolean expansion state separate from ancestor scroll offsets.
          key: const PageStorageKey('record-calendar-mood-legend'),
          tilePadding: EdgeInsets.zero,
          dense: true,
          title: Text(
            'Mood borders & other records',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 14,
                runSpacing: 10,
                children: [
                  for (final mood in RecordedMood.values)
                    legend(moodColor(mood), mood.label, context, border: true),
                  for (final type in EntryType.values.where(
                    (t) => t != EntryType.bleeding,
                  ))
                    legend(eventColor(type), type.name, context),
                ],
              ),
            ),
          ],
        ),
        if (selected != null)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dayLabel(widget.selected!),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    selected.period == null
                        ? 'No period record'
                        : 'Recorded flow: ${flowLabel(selected.period!.flowIntensity!)}',
                  ),
                  Text(
                    selected.moodEntry == null
                        ? 'No recorded mood'
                        : 'Recorded mood: ${selected.moodEntry!.recordedMood!.label}',
                  ),
                  if (widget.estimates != null)
                    Text(
                      'Calendar estimate: ${widget.estimates!.on(widget.selected!)?.phase.label ?? 'unavailable for this date'}',
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          'Unmarked days are unknown. Latest saved flow and mood shown; all entries are retained.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
