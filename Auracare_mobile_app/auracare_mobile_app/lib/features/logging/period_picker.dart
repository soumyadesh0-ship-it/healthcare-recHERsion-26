import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/calendar.dart';
import '../../core/widgets.dart';
import '../../data/records.dart';
import 'editor.dart';

Future<void> openPeriodDay(BuildContext context, DateTime day) async {
  final entry = RecordedDay(
    SessionScope.of(context).records.entries,
    day,
  ).period;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PeriodDayDialog(day: day, entry: entry),
  );
}

class PeriodPickerPage extends StatelessWidget {
  const PeriodPickerPage({super.key, this.initialDay});
  final DateTime? initialDay;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Period Picker')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Choose a date to record flow. Start, end and notes are optional.',
          ),
          RecordCalendar(
            entries: SessionScope.of(context).records.entries,
            selected: initialDay,
            onSelect: (day) => openPeriodDay(context, day),
          ),
        ],
      ),
    ),
  );
}

class _PeriodDayDialog extends StatefulWidget {
  const _PeriodDayDialog({required this.day, this.entry});
  final DateTime day;
  final HealthEntry? entry;
  @override
  State<_PeriodDayDialog> createState() => _PeriodDayDialogState();
}

class _PeriodDayDialogState extends State<_PeriodDayDialog> {
  bool notes = false;
  @override
  Widget build(BuildContext context) => Dialog(
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      width: 560,
      height: MediaQuery.sizeOf(context).height * .85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              dayLabel(widget.day),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (widget.entry != null)
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => setState(() => notes = true),
                  child: const Text('Add Notes'),
                ),
              ],
            ),
          Expanded(
            child: EntryEditor(
              type: EntryType.bleeding,
              entry: widget.entry,
              day: widget.day,
              showCalendar: false,
              allowNotes: notes,
              onContinueJournal: widget.entry == null
                  ? null
                  : () {
                      final journal = SessionScope.of(context).records.entries
                          .where(
                            (e) =>
                                e.type == EntryType.journal &&
                                dayLabel(e.when) == dayLabel(widget.day),
                          )
                          .firstOrNull;
                      Navigator.pop(context);
                      pushPage(
                        context,
                        EntryEditor(
                          type: EntryType.journal,
                          day: widget.day,
                          entry: journal,
                        ),
                      );
                    },
            ),
          ),
        ],
      ),
    ),
  );
}
