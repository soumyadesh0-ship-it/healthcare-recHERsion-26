import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/widgets.dart';
import '../../core/calendar.dart';
import '../../data/records.dart';
import '../logging/editor.dart';

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Timeline'),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(demoBadgeHeight(context)),
        child: const DemoBadge(),
      ),
    ),
    body: const SafeArea(top: false, child: TimelinePage()),
  );
}

class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key, this.onlyType});
  final EntryType? onlyType;
  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  EntryType? filter;
  DateTimeRange? range;
  @override
  void initState() {
    super.initState();
    filter = widget.onlyType;
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final all = session.records.entries;
    final entries = all
        .where(
          (e) =>
              (filter == null || e.type == filter) &&
              (range == null ||
                  (!dayOnly(e.when).isBefore(dayOnly(range!.start)) &&
                      !dayOnly(e.when).isAfter(dayOnly(range!.end)))),
        )
        .toList();
    final groups = <String, List<HealthEntry>>{};
    for (final e in entries) {
      groups.putIfAbsent(dayLabel(e.when), () => []).add(e);
    }
    return ListView(
      key: PageStorageKey('timeline-${widget.onlyType}'),
      padding: const EdgeInsets.all(20),
      children: spaced([
        Heading(
          widget.onlyType == EntryType.journal
              ? 'Your journal.'
              : 'Cycle timeline',
        ),
        const Text(
          'Recorded days tell part of the story. Unrecorded days are unknown.',
        ),
        if (widget.onlyType == null)
          RecordCalendar(
            entries: all,
            selected: range?.start,
            onSelect: (day) =>
                setState(() => range = DateTimeRange(start: day, end: day)),
          ),
        FilledButton.icon(
          onPressed: () =>
              openEditor(context, type: widget.onlyType ?? EntryType.symptom),
          icon: const Icon(Icons.add),
          label: Text(
            widget.onlyType == EntryType.journal
                ? 'Write journal entry'
                : 'Log entry',
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (widget.onlyType == null)
              ChoiceChip(
                label: const Text('All records'),
                selected: filter == null,
                onSelected: (_) => setState(() => filter = null),
              ),
            for (final type in EntryType.values.where(
              (t) => widget.onlyType == null || t == widget.onlyType,
            ))
              ChoiceChip(
                label: Text(type.name),
                selected: filter == type,
                onSelected: (_) => setState(() => filter = type),
              ),
          ],
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.date_range),
          label: Text(
            range == null
                ? 'Filter date range'
                : '${dayLabel(range!.start)} – ${dayLabel(range!.end)}',
          ),
          onPressed: () async {
            final chosen = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              initialDateRange: range,
            );
            if (chosen != null && mounted) setState(() => range = chosen);
          },
        ),
        if (range != null)
          TextButton(
            onPressed: () => setState(() => range = null),
            child: const Text('Clear date filter'),
          ),
        if (entries.isEmpty)
          EmptyNotice(
            all.isEmpty ? 'No records yet' : 'No matching records',
            all.isEmpty
                ? 'Start with a fictional observation when you are ready.'
                : 'Try another record type or clear the date range.',
          ),
        for (final group in groups.entries) ...[
          Text(group.key, style: Theme.of(context).textTheme.titleMedium),
          for (final e in group.value)
            EntryCard(
              entry: e,
              onTap: () => openEditor(context, entry: e),
            ),
        ],
      ]),
    );
  }
}
