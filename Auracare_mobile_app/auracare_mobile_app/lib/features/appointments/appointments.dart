import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/widgets.dart';
import '../../data/records.dart';
import '../../data/services.dart';
import '../logging/editor.dart';

class AppointmentPage extends StatefulWidget {
  const AppointmentPage({super.key});
  @override
  State<AppointmentPage> createState() => _AppointmentPageState();
}

class _AppointmentPageState extends State<AppointmentPage> {
  final selected = <String>{};
  final question = TextEditingController();
  bool notes = false, observations = false;
  late DateTimeRange range = DateTimeRange(
    start: dayOnly(DateTime.now()).subtract(const Duration(days: 30)),
    end: dayOnly(DateTime.now()),
  );
  @override
  void dispose() {
    question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final eligible = Coverage(
      session.records.entries,
      range.start,
      range.end,
    ).records;
    final chosen = eligible.where((e) => selected.contains(e.id)).toList();
    final summary = appointmentSummary(
      chosen,
      session.questions,
      includeNotes: notes,
      includeObservations: observations,
      from: range.start,
      to: range.end,
    );
    return PageFrame(
      title: 'Appointment preparation',
      children: [
        const Heading('Bring your own story.'),
        const Text(
          'Choose records deliberately. Journals start excluded. Preview updates when selected source records change. Nothing is delivered to a clinician.',
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.date_range),
          label: Text('${dayLabel(range.start)} – ${dayLabel(range.end)}'),
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
        if (eligible.isEmpty)
          const EmptyNotice(
            'No records in this range',
            'You can still prepare questions, or choose a different range.',
          ),
        for (final e in eligible)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(e.title),
                  subtitle: Text(
                    '${dayLabel(e.when)} · ${e.type.name} · v${e.version}',
                  ),
                  value: selected.contains(e.id),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      selected.add(e.id);
                    } else {
                      selected.remove(e.id);
                    }
                  }),
                ),
                TextButton(
                  onPressed: () => openEditor(context, entry: e),
                  child: const Text('View / edit source'),
                ),
              ],
            ),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Include selected record notes'),
          value: notes,
          onChanged: (v) => setState(() => notes = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Include descriptive observations'),
          value: observations,
          onChanged: (v) => setState(() => observations = v),
        ),
        TextField(
          controller: question,
          maxLength: 300,
          decoration: const InputDecoration(
            labelText: 'Question for a professional',
          ),
          minLines: 2,
          maxLines: 4,
        ),
        OutlinedButton(
          onPressed: () {
            if (question.text.trim().isEmpty) {
              tell(context, 'Write a question first.');
              return;
            }
            session.addQuestion(question.text.trim());
            question.clear();
          },
          child: const Text('Add question'),
        ),
        for (final q in session.questions)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q),
                TextButton(
                  onPressed: () =>
                      session.update(() => session.questions.remove(q)),
                  child: const Text('Remove question'),
                ),
              ],
            ),
          ),
        Text(
          'Review your preview',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Panel(
          child: SelectableText(
            summary,
            key: const ValueKey('appointment-preview'),
          ),
        ),
        FilledButton(
          key: const ValueKey('copy-summary'),
          onPressed: () => copyText(context, summary),
          child: const Text('Copy synthetic summary'),
        ),
        const Text(
          'PDF, native sharing and clinician delivery are unavailable: no export or provider service is connected. Clipboard copies leave the app and are not cleared by demo reset.',
        ),
      ],
    );
  }
}
