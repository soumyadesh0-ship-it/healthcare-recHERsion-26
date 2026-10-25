import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../app/theme.dart';
import '../../core/widgets.dart';
import '../../data/records.dart';
import '../logging/editor.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});
  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  bool sources = false;
  late DateTimeRange range = DateTimeRange(
    start: dayOnly(DateTime.now()).subtract(const Duration(days: 6)),
    end: dayOnly(DateTime.now()),
  );
  @override
  Widget build(BuildContext context) {
    final coverage = Coverage(
      SessionScope.of(context).records.entries,
      range.start,
      range.end,
    );
    return ListView(
      key: const PageStorageKey('insights'),
      padding: const EdgeInsets.all(20),
      children: spaced([
        const Heading('Insights'),
        const Text(
          'Descriptive counts only. Prototype logic: prototype-count-v1. Not clinically reviewed; no diagnosis or causal conclusions.',
        ),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Overview'),
              selected: !sources,
              onSelected: (_) => setState(() => sources = false),
            ),
            ChoiceChip(
              label: const Text('Source records'),
              selected: sources,
              onSelected: (_) => setState(() => sources = true),
            ),
          ],
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.date_range),
          label: Text('${dayLabel(range.start)} – ${dayLabel(range.end)}'),
          onPressed: () async {
            final selected = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              initialDateRange: range,
            );
            if (selected != null && mounted) setState(() => range = selected);
          },
        ),
        if (!sources && coverage.records.isNotEmpty)
          Panel(
            color: Palette.input,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: spaced([
                Text(
                  '${coverage.recordedDays} of ${coverage.totalDays} days with entries',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${coverage.unknownDays} days without entries are unknown, not symptom-free.',
                ),
                Semantics(
                  label:
                      '${coverage.recordedDays} recorded days out of ${coverage.totalDays}',
                  child: LinearProgressIndicator(
                    value: coverage.recordedDays / coverage.totalDays,
                  ),
                ),
              ]),
            ),
          ),
        if (coverage.records.isEmpty)
          const EmptyNotice(
            'Insufficient data',
            'No records in this range. No health conclusion can be drawn.',
          ),
        if (coverage.records.isNotEmpty && coverage.symptomDays.isEmpty)
          const EmptyNotice(
            'No symptom entries in this range',
            'Other entry types do not establish the presence or absence of symptoms.',
          ),
        if (!sources)
          for (final count in coverage.symptomDays.entries)
            if (!sources && coverage.records.isNotEmpty)
              Panel(
                child: Text(
                  '${count.key} recorded on ${count.value} of ${coverage.recordedDays} days with entries. Days without entries are unknown.',
                ),
              ),
        const Text(
          'Counting groups calendar dates as recorded in their declared timezone. Mixed-zone dates are not converted or compared as instants. Counts are not PCOS scores, cycle predictions or evidence of improvement.',
        ),
        if (sources)
          Text('Source records', style: Theme.of(context).textTheme.titleLarge),
        if (sources)
          for (final e in coverage.records) ...[
            Text('${dayLabel(e.when)} · v${e.version}'),
            EntryCard(
              entry: e,
              onTap: () => openEditor(context, entry: e),
            ),
          ],
      ]),
    );
  }
}
