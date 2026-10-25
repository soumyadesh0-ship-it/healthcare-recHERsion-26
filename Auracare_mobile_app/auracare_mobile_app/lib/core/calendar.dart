import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../data/records.dart';

Color eventColor(EntryType type) => switch (type) {
  EntryType.bleeding => Palette.pink,
  EntryType.symptom => Palette.yellow,
  EntryType.wellness => Palette.turquoise,
  EntryType.journal => Palette.periwinkle,
};

/// A true Monday-first calendar. Only recorded events receive markers.
class RecordCalendar extends StatefulWidget {
  const RecordCalendar({
    super.key,
    required this.entries,
    required this.onSelect,
    this.selected,
  });
  final List<HealthEntry> entries;
  final ValueChanged<DateTime> onSelect;
  final DateTime? selected;
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
  @override
  Widget build(BuildContext context) {
    final offset = month.weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final cellHeight = 52.0 * scale;
    return Column(
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
                          final events = widget.entries
                              .where((e) => dayLabel(e.when) == dayLabel(date))
                              .map((e) => e.type)
                              .toSet();
                          final active =
                              widget.selected != null &&
                              dayLabel(widget.selected!) == dayLabel(date);
                          final period = events.contains(EntryType.bleeding);
                          return Expanded(
                            child: SizedBox(
                              height: cellHeight,
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Semantics(
                                  selected: active,
                                  label:
                                      '${dayLabel(date)}, ${events.isEmpty ? 'unrecorded' : events.map((e) => e.name).join(', ')}',
                                  button: true,
                                  excludeSemantics: true,
                                  child: Material(
                                    color: period
                                        ? Palette.blush
                                        : Palette.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(
                                        color: active
                                            ? Palette.purple
                                            : Colors.transparent,
                                        width: 2,
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
                                              fontWeight: active
                                                  ? FontWeight.w800
                                                  : FontWeight.w400,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 2,
                                            children: [
                                              for (final type in events)
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
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            for (final type in EntryType.values)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: eventColor(type),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    type == EntryType.bleeding ? 'Period' : type.name,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Recorded events only. Unmarked days are unknown.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
