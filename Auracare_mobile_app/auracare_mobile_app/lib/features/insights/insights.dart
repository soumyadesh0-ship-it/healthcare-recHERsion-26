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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          key: const PageStorageKey('insights'),
          padding: const EdgeInsets.all(20),
          children: spaced([
            const Heading('Your insights'),
            Text(
              'A little perspective on your recorded days.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Palette.lavender, Palette.blush],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    color: Palette.ink,
                    size: 30,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your story, at a glance',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Explore what you have recorded, with space for what is still unknown.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Text('Date range', style: Theme.of(context).textTheme.labelLarge),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final days in [7, 30, 90])
                  ChoiceChip(
                    label: Text('Last $days days'),
                    selected:
                        dayLabel(range.end) == dayLabel(DateTime.now()) &&
                        coverage.totalDays == days,
                    onSelected: (_) => setState(() {
                      final today = dayOnly(DateTime.now());
                      range = DateTimeRange(
                        start: today.subtract(Duration(days: days - 1)),
                        end: today,
                      );
                    }),
                  ),
              ],
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
              icon: const Icon(Icons.date_range_outlined),
              label: Text('${dayLabel(range.start)} – ${dayLabel(range.end)}'),
              onPressed: () async {
                final selected = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  initialDateRange: range,
                );
                if (selected != null && mounted) {
                  setState(() => range = selected);
                }
              },
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
            if (!sources)
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked =
                      constraints.maxWidth < 340 ||
                      MediaQuery.textScalerOf(context).scale(14) > 20;
                  final width = stacked
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: width,
                        child: _InsightMetric(
                          label: 'Days with entries',
                          value: '${coverage.recordedDays}',
                          icon: Icons.event_available_outlined,
                          color: Palette.blush,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _InsightMetric(
                          label: 'Days without entries',
                          value: '${coverage.unknownDays}',
                          icon: Icons.calendar_today_outlined,
                          color: Palette.lavender,
                        ),
                      ),
                    ],
                  );
                },
              ),
            if (!sources && coverage.records.isNotEmpty)
              Panel(
                color: Palette.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: spaced([
                    Text(
                      '${coverage.recordedDays} of ${coverage.totalDays} days with entries',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${coverage.unknownDays} days without entries are unknown, not symptom-free.',
                    ),
                    Semantics(
                      label:
                          '${coverage.recordedDays} recorded days out of ${coverage.totalDays}',
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                        value: coverage.recordedDays / coverage.totalDays,
                        color: Palette.purple,
                        backgroundColor: Palette.lavender,
                      ),
                    ),
                  ]),
                ),
              ),
            if (!sources) _ActivityCard(coverage: coverage),
            if (coverage.records.isEmpty)
              Panel(
                color: Palette.input,
                child: Column(
                  children: [
                    const Icon(
                      Icons.auto_graph_rounded,
                      size: 48,
                      color: Palette.secondary,
                    ),
                    const SizedBox(height: 16),
                    const Heading('No entries in this range'),
                    const SizedBox(height: 12),
                    const Text(
                      'Your recorded days will appear here. Days without entries remain unknown; no health conclusion can be drawn.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => pushPage(context, const LogEntryPage()),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Log an entry'),
                    ),
                  ],
                ),
              ),
            if (coverage.records.isNotEmpty && coverage.symptomDays.isEmpty)
              const EmptyNotice(
                'No symptom entries in this range',
                'Other entry types do not establish the presence or absence of symptoms.',
              ),
            if (!sources && coverage.symptomDays.isNotEmpty)
              Text(
                'What you recorded',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            if (!sources)
              for (final count in coverage.symptomDays.entries)
                if (!sources && coverage.records.isNotEmpty)
                  Panel(
                    color: Palette.input,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.notes_rounded,
                              color: Palette.action,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                count.key,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Semantics(
                          label:
                              '${count.key}: ${count.value} of ${coverage.recordedDays} recorded days',
                          child: LinearProgressIndicator(
                            value: count.value / coverage.recordedDays,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(8),
                            color: Palette.action,
                            backgroundColor: Palette.lavender,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${count.key} recorded on ${count.value} of ${coverage.recordedDays} days with entries. Days without entries are unknown.',
                        ),
                      ],
                    ),
                  ),
            if (sources)
              Text(
                'Source records',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            if (sources && coverage.records.isNotEmpty)
              const Text(
                'Open an entry to review or edit its original details.',
              ),
            if (sources)
              for (final e in coverage.records) ...[
                Text('${dayLabel(e.when)} · v${e.version}'),
                EntryCard(
                  entry: e,
                  onTap: () => openEditor(context, entry: e),
                ),
              ],
            ExpansionTile(
              key: const PageStorageKey('insights-method'),
              tilePadding: EdgeInsets.zero,
              title: const Text('How to read these insights'),
              childrenPadding: const EdgeInsets.only(bottom: 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Descriptive counts only. Prototype logic: prototype-count-v1. Not clinically reviewed; no diagnosis or causal conclusions.',
                ),
                SizedBox(height: 12),
                Text(
                  'Counting groups calendar dates as recorded in their declared timezone. Mixed-zone dates are not converted or compared as instants. Counts are not PCOS scores, cycle predictions or evidence of improvement.',
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.coverage});
  final Coverage coverage;

  @override
  Widget build(BuildContext context) {
    final recorded = coverage.records.map((e) => dayLabel(e.when)).toSet();
    // Keep custom multi-year ranges readable without building thousands of cells.
    final visibleDays = coverage.totalDays > 90 ? 90 : coverage.totalDays;
    final start = DateTime(
      coverage.to.year,
      coverage.to.month,
      coverage.to.day - visibleDays + 1,
    );
    return Panel(
      color: Palette.input,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.grid_view_rounded, color: Palette.action),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your recorded days',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            coverage.totalDays > 90
                ? 'Showing the last 90 days of your selected range.'
                : 'Every entry adds a little more to your story.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < visibleDays; i++)
                Builder(
                  builder: (context) {
                    final date = DateTime(
                      start.year,
                      start.month,
                      start.day + i,
                    );
                    final hasEntry = recorded.contains(dayLabel(date));
                    final label =
                        '${dayLabel(date)}: ${hasEntry ? 'With entries' : 'Unknown'}';
                    return Tooltip(
                      message: label,
                      child: Semantics(
                        label: label,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: hasEntry ? Palette.action : Palette.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: hasEntry
                                  ? Palette.action
                                  : Palette.lavender,
                            ),
                          ),
                          child: hasEntry
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: Palette.white,
                                )
                              : null,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _legend(context, Palette.action, 'With entries'),
              _legend(context, Palette.white, 'Unknown'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Days without entries are unknown, not symptom-free.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _legend(BuildContext context, Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Palette.action),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _InsightMetric extends StatelessWidget {
  const _InsightMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Panel(
    color: color,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 26, color: Palette.ink),
        const SizedBox(height: 16),
        Text(value, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 6),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}
