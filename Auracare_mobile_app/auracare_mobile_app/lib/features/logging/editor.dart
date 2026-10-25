import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/widgets.dart';
import '../../core/calendar.dart';
import '../../core/characters.dart';
import '../../app/theme.dart';
import '../../data/records.dart';
import '../wellbeing/merge_game.dart';
import '../wellbeing/breathing.dart';
import 'period_picker.dart';

void openEditor(
  BuildContext context, {
  EntryType type = EntryType.symptom,
  HealthEntry? entry,
  DateTime? day,
}) => pushPage(
  context,
  type == EntryType.bleeding && entry == null
      ? PeriodPickerPage(initialDay: day)
      : EntryEditor(type: entry?.type ?? type, entry: entry, day: day),
);

class EntryEditor extends StatefulWidget {
  const EntryEditor({
    super.key,
    required this.type,
    this.entry,
    this.day,
    this.initialMood,
    this.showCalendar = true,
    this.allowNotes = true,
    this.onContinueJournal,
  });
  final String? initialMood;
  final bool showCalendar, allowNotes;
  final VoidCallback? onContinueJournal;
  final EntryType type;
  final HealthEntry? entry;
  final DateTime? day;
  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<EntryEditor> {
  final form = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.entry?.title ?? '');
  late final note = TextEditingController(
    text:
        widget.entry?.note ??
        (widget.initialMood == null ? '' : 'Feeling: ${widget.initialMood}. '),
  );
  late final color = TextEditingController(
    text: widget.entry?.tracking?.color ?? '',
  );
  late final consistency = TextEditingController(
    text: widget.entry?.tracking?.consistency ?? '',
  );
  late TrackingAmount? amount = widget.entry?.tracking?.amount;
  late ObservationAnswer? odorChange = widget.entry?.tracking?.odorChange;
  late ObservationAnswer? irritation = widget.entry?.tracking?.irritation;
  bool get isTracking =>
      widget.type == EntryType.spotting || widget.type == EntryType.discharge;
  late Severity severity = widget.entry?.severity ?? Severity.unspecified;
  late bool? periodStart = widget.entry?.periodStart;
  late bool? periodEnd = widget.entry?.periodEnd;
  late RecordedMood? mood =
      widget.entry?.recordedMood ?? RecordedMood.fromLabel(widget.initialMood);
  DateTime? when;
  String? zone, selection, id;
  bool busy = false, dirty = false, allowPop = false;
  String? error;
  List<String> get choices => switch (widget.type) {
    EntryType.symptom => [
      'Headache',
      'Cramps',
      'Fatigue',
      'Bloating',
      'Other symptom',
    ],
    EntryType.bleeding => [
      'Bleeding · Unspecified',
      'Bleeding · Light',
      'Bleeding · Moderate',
      'Bleeding · Heavy',
    ],
    EntryType.wellness => ['Mood', 'Energy', 'Stress', 'Sleep'],
    EntryType.journal => [],
    EntryType.spotting || EntryType.discharge => [],
  };
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = SessionScope.of(context);
    zone ??= widget.entry?.zone ?? s.zone;
    when ??=
        widget.entry?.when ??
        widget.day ??
        (zone == 'UTC' ? DateTime.now().toUtc() : DateTime.now());
    selection ??=
        widget.entry?.title ?? (widget.initialMood == null ? null : 'Mood');
  }

  @override
  void dispose() {
    title.dispose();
    note.dispose();
    color.dispose();
    consistency.dispose();
    super.dispose();
  }

  void changed() => setState(() => dirty = true);
  Widget _answerField(
    String label,
    String key,
    ObservationAnswer? value,
    ValueChanged<ObservationAnswer?> onChanged,
  ) => DropdownButtonFormField<ObservationAnswer>(
    key: ValueKey(key),
    initialValue: value,
    isExpanded: true,
    itemHeight: null,
    decoration: InputDecoration(labelText: label),
    items: [
      const DropdownMenuItem(value: null, child: Text('Not recorded')),
      for (final answer in ObservationAnswer.values)
        DropdownMenuItem(value: answer, child: Text(observationLabel(answer))),
    ],
    onChanged: busy ? null : onChanged,
  );
  Future<void> leave() async {
    if (busy) return;
    if (!dirty ||
        await confirm(
          context,
          'Discard unsaved changes?',
          'Your unsaved demo text will be discarded.',
          action: 'Discard',
        )) {
      if (!mounted) return;
      setState(() => allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    final repo = SessionScope.of(context).records;
    id ??= widget.entry?.id ?? repo.newId();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repo.save(
        HealthEntry(
          id: id!,
          type: widget.type,
          title: widget.type == EntryType.journal
              ? (title.text.trim().isEmpty
                    ? 'Journal entry'
                    : title.text.trim())
              : isTracking
              ? observationLabel(widget.type)
              : selection!,
          when: when!,
          zone: zone!,
          note: widget.type == EntryType.bleeding && !widget.allowNotes
              ? (widget.entry?.note ?? '')
              : note.text.trim(),
          severity: severity,
          version: (widget.entry?.version ?? 0) + 1,
          periodStart: widget.type == EntryType.bleeding ? periodStart : null,
          periodEnd: widget.type == EntryType.bleeding ? periodEnd : null,
          tracking: isTracking
              ? TrackingDetails(
                  amount: amount!,
                  color: color.text.trim().isEmpty ? null : color.text.trim(),
                  consistency:
                      widget.type == EntryType.discharge &&
                          consistency.text.trim().isNotEmpty
                      ? consistency.text.trim()
                      : null,
                  odorChange: widget.type == EntryType.discharge
                      ? odorChange
                      : null,
                  irritation: widget.type == EntryType.discharge
                      ? irritation
                      : null,
                )
              : null,
          mood: widget.type == EntryType.wellness && selection == 'Mood'
              ? mood
              : null,
        ),
      );
      if (!mounted) return;
      tell(
        context,
        widget.entry == null
            ? 'Added to demo session'
            : 'Updated in demo session',
      );
      setState(() {
        dirty = false;
        allowPop = true;
        busy = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.type == EntryType.wellness && selection == 'Mood') {
          SessionScope.of(context).requestHome();
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          Navigator.pop(context);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e.toString();
        });
      }
    }
  }

  Future<void> remove() async {
    final repo = SessionScope.of(context).records;
    if (!await confirm(
      context,
      'Delete this demo entry?',
      'This removes it from the timeline and refreshes derived summaries.',
      action: 'Delete',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repo.delete(widget.entry!.id);
      if (!mounted) return;
      tell(context, 'Removed from demo session');
      setState(() {
        dirty = false;
        allowPop = true;
        busy = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = SessionScope.of(context).records;
    return PopScope(
      canPop: allowPop || (!dirty && !busy),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.entry == null
                ? widget.type == EntryType.bleeding
                      ? 'Period tracking'
                      : 'New ${widget.type.name}'
                : 'Entry details',
          ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(demoBadgeHeight(context)),
            child: DemoBadge(),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Form(
            key: form,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: spaced([
                  if (widget.type != EntryType.bleeding)
                    Heading(
                      widget.type == EntryType.journal
                          ? 'Room for your words.'
                          : 'What did you notice?',
                    ),
                  if (widget.type != EntryType.bleeding)
                    Text(
                      widget.type == EntryType.journal
                          ? 'Journal text stays in this demo session. No AI, clinician or community receives it.'
                          : 'Use fictional observations. This session has no account storage.',
                    ),
                  if (widget.type == EntryType.journal)
                    TextFormField(
                      controller: title,
                      decoration: const InputDecoration(
                        labelText: 'Title (optional)',
                      ),
                      maxLength: 80,
                      onChanged: (_) => changed(),
                    )
                  else if (!isTracking && widget.type != EntryType.bleeding)
                    DropdownButtonFormField<String>(
                      itemHeight: null,
                      initialValue: selection,
                      decoration: InputDecoration(
                        labelText: widget.type == EntryType.bleeding
                            ? 'Recorded flow'
                            : widget.type == EntryType.wellness
                            ? 'Wellbeing observation'
                            : 'Symptom',
                      ),
                      isExpanded: true,
                      items: choices
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      validator: (v) => v == null ? 'Choose an option.' : null,
                      onChanged: busy
                          ? null
                          : (v) {
                              setState(() {
                                selection = v;
                                dirty = true;
                              });
                            },
                    ),
                  if (isTracking) ...[
                    const Text(
                      'Describe what you observed. These choices do not diagnose a condition. Health records last only for this session.',
                    ),
                    DropdownButtonFormField<TrackingAmount>(
                      key: const ValueKey('tracking-amount'),
                      initialValue: amount,
                      isExpanded: true,
                      itemHeight: null,
                      decoration: const InputDecoration(labelText: 'Amount'),
                      items: [
                        for (final value in TrackingAmount.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(observationLabel(value)),
                          ),
                      ],
                      validator: (value) =>
                          value == null ? 'Choose an amount.' : null,
                      onChanged: busy
                          ? null
                          : (value) => setState(() {
                              amount = value;
                              dirty = true;
                            }),
                    ),
                    TextFormField(
                      key: const ValueKey('tracking-color'),
                      controller: color,
                      enabled: !busy,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Color (optional)',
                      ),
                      onChanged: (_) => changed(),
                    ),
                    if (widget.type == EntryType.discharge) ...[
                      TextFormField(
                        key: const ValueKey('tracking-consistency'),
                        controller: consistency,
                        enabled: !busy,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          labelText: 'Consistency (optional)',
                        ),
                        onChanged: (_) => changed(),
                      ),
                      _answerField(
                        'Odor change (optional)',
                        'odor-change',
                        odorChange,
                        (value) => setState(() {
                          odorChange = value;
                          dirty = true;
                        }),
                      ),
                      _answerField(
                        'Itching or irritation (optional)',
                        'irritation',
                        irritation,
                        (value) => setState(() {
                          irritation = value;
                          dirty = true;
                        }),
                      ),
                    ],
                  ],
                  if (widget.type == EntryType.bleeding) ...[
                    Text(
                      'Selected date: ${dayLabel(when!)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (widget.showCalendar)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final scale =
                              MediaQuery.textScalerOf(context).scale(14) / 14;
                          final minWidth = 336 * scale;
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: constraints.maxWidth < minWidth
                                  ? minWidth
                                  : constraints.maxWidth,
                              child: CalendarDatePicker(
                                initialDate: when!,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                onDateChanged: busy
                                    ? (_) {}
                                    : (day) => setState(() {
                                        when = DateTime(
                                          day.year,
                                          day.month,
                                          day.day,
                                          when!.hour,
                                          when!.minute,
                                        );
                                        dirty = true;
                                      }),
                              ),
                            ),
                          );
                        },
                      ),
                    FormField<String>(
                      validator: (_) => selection == null
                          ? 'Choose the observed flow.'
                          : null,
                      builder: (field) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Flow'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final flow in [
                                'Spotting',
                                'Light',
                                'Moderate',
                                'Heavy',
                              ])
                                ChoiceChip(
                                  avatar: Icon(
                                    Icons.water_drop,
                                    size: 16,
                                    color: flowColor(switch (flow) {
                                      'Spotting' => FlowIntensity.spotting,
                                      'Light' => FlowIntensity.light,
                                      'Moderate' => FlowIntensity.moderate,
                                      _ => FlowIntensity.heavy,
                                    }),
                                  ),
                                  label: Text(
                                    flow == 'Moderate' ? 'Medium' : flow,
                                  ),
                                  selected: selection == 'Bleeding · $flow',
                                  onSelected: busy
                                      ? null
                                      : (_) => setState(() {
                                          selection = 'Bleeding · $flow';
                                          dirty = true;
                                          field.didChange(selection);
                                        }),
                                ),
                            ],
                          ),
                          if (widget.entry != null &&
                              widget.entry!.flowIntensity ==
                                  FlowIntensity.unspecified &&
                              selection == widget.entry!.title)
                            const Text(
                              'Historical flow: unspecified. Choose a flow only if known.',
                            ),
                          if (field.hasError)
                            Text(
                              field.errorText!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                        ],
                      ),
                    ),
                    FormField<bool>(
                      builder: (field) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Period boundary (optional)'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Neither'),
                                selected:
                                    periodStart != true && periodEnd != true,
                                onSelected: busy
                                    ? null
                                    : (_) => setState(() {
                                        periodStart = false;
                                        periodEnd = false;
                                        dirty = true;
                                        field.didChange(false);
                                      }),
                              ),
                              ChoiceChip(
                                label: const Text('Period start'),
                                selected: periodStart == true,
                                onSelected: busy
                                    ? null
                                    : (_) => setState(() {
                                        periodStart = true;
                                        periodEnd = false;
                                        dirty = true;
                                        field.didChange(true);
                                      }),
                              ),
                              ChoiceChip(
                                label: const Text('Period end'),
                                selected: periodEnd == true,
                                onSelected: busy
                                    ? null
                                    : (_) => setState(() {
                                        periodStart = false;
                                        periodEnd = true;
                                        dirty = true;
                                        field.didChange(false);
                                      }),
                              ),
                            ],
                          ),
                          if (widget.entry != null &&
                              periodStart == null &&
                              periodEnd == null)
                            const Text('Historical entry: start/end unknown.'),
                          if (field.hasError)
                            Text(
                              field.errorText!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (widget.type == EntryType.wellness && selection == 'Mood')
                    DropdownButtonFormField<RecordedMood>(
                      initialValue: mood,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Feeling (optional)',
                      ),
                      items: [
                        for (final value in RecordedMood.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) => setState(() {
                              mood = value;
                              dirty = true;
                            }),
                    ),
                  if (widget.type != EntryType.bleeding)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text('Date: ${dayLabel(when!)}'),
                      onPressed: busy
                          ? null
                          : () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: when!,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (d != null && mounted) {
                                setState(() {
                                  when = DateTime(
                                    d.year,
                                    d.month,
                                    d.day,
                                    when!.hour,
                                    when!.minute,
                                  );
                                  dirty = true;
                                });
                              }
                            },
                    ),
                  if (widget.type != EntryType.bleeding)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.schedule),
                      label: Text('Time: ${timeLabel(when!)}'),
                      onPressed: busy
                          ? null
                          : () async {
                              final t = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(when!),
                              );
                              if (t != null && mounted) {
                                setState(() {
                                  when = DateTime(
                                    when!.year,
                                    when!.month,
                                    when!.day,
                                    t.hour,
                                    t.minute,
                                  );
                                  dirty = true;
                                });
                              }
                            },
                    ),
                  Text(
                    'Recorded timezone: $zone. Existing wall-clock values are not converted when preferences change.',
                  ),
                  if (widget.type == EntryType.symptom) ...[
                    DropdownButtonFormField<Severity>(
                      itemHeight: null,
                      initialValue: severity,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Severity (optional)',
                      ),
                      items: Severity.values
                          .map(
                            (s) =>
                                DropdownMenuItem(value: s, child: Text(s.name)),
                          )
                          .toList(),
                      onChanged: busy
                          ? null
                          : (v) => setState(() {
                              severity = v!;
                              dirty = true;
                            }),
                    ),
                    const Text(
                      'Prototype-only scale: Unspecified, Mild, Moderate, Severe. Not clinically approved.',
                    ),
                  ],
                  if (widget.onContinueJournal != null)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () async {
                              if (dirty &&
                                  !await confirm(
                                    context,
                                    'Continue in Journal?',
                                    'Unsaved flow or note changes will be discarded.',
                                    action: 'Continue',
                                  )) {
                                return;
                              }
                              if (!mounted) return;
                              setState(() {
                                dirty = false;
                                allowPop = true;
                              });
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) widget.onContinueJournal!();
                              });
                            },
                      child: const Text('Continue in Journal'),
                    ),
                  if (widget.type != EntryType.bleeding || widget.allowNotes)
                    TextFormField(
                      controller: note,
                      key: const ValueKey('entry-note'),
                      decoration: InputDecoration(
                        labelText: widget.type == EntryType.journal
                            ? 'Journal text'
                            : 'Notes (optional)',
                      ),
                      minLines: 4,
                      maxLines: 8,
                      maxLength: 2000,
                      onChanged: (_) => changed(),
                      validator: (v) =>
                          widget.type == EntryType.journal &&
                              (v == null || v.trim().isEmpty)
                          ? 'Write some fictional text before saving.'
                          : null,
                    ),
                  if (widget.entry != null)
                    Text(
                      'Source ID: ${widget.entry!.id} · version ${widget.entry!.version}',
                    ),
                  if (error != null) ErrorNotice(error!),
                  if (busy)
                    Semantics(
                      label: 'Saving demo entry',
                      child: LinearProgressIndicator(),
                    ),
                  FilledButton(
                    key: const ValueKey('save-entry'),
                    onPressed: busy ? null : save,
                    child: Text(
                      error == null ? 'Save demo entry' : 'Retry save',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : leave,
                    child: const Text('Cancel'),
                  ),
                  if (widget.entry != null)
                    OutlinedButton(
                      onPressed: busy ? null : remove,
                      child: const Text('Delete entry'),
                    ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () {
                            repo.failNextWrite = true;
                            tell(
                              context,
                              'Next save or delete will simulate a failure.',
                            );
                          },
                    child: const Text('Demo controls: fail next write'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LogEntryPage extends StatelessWidget {
  const LogEntryPage({super.key});
  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Log entry',
    children: [
      const Heading('What would you like to track?'),
      const SizedBox(height: 8),
      for (final item in const [
        ('Period', EntryType.bleeding, Icons.water_drop_outlined, Palette.pink),
        ('Spotting', EntryType.spotting, Icons.grain, Palette.orchid),
        (
          'Discharge',
          EntryType.discharge,
          Icons.opacity_outlined,
          Palette.apricot,
        ),
        (
          'Symptoms',
          EntryType.symptom,
          Icons.waves_outlined,
          Palette.turquoise,
        ),
        (
          'Mood',
          EntryType.wellness,
          Icons.sentiment_satisfied_alt,
          Palette.yellow,
        ),
        ('Notes', EntryType.journal, Icons.edit_note, Palette.blue),
      ])
        Material(
          color: Palette.input,
          borderRadius: BorderRadius.circular(20),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            leading: Icon(item.$3, color: item.$4, size: 30),
            title: Text(
              item.$1,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            trailing: const Icon(Icons.arrow_forward, size: 20),
            onTap: () => openEditor(context, type: item.$2),
          ),
        ),
    ],
  );
}

class MoodCheckInPage extends StatefulWidget {
  const MoodCheckInPage({super.key});
  @override
  State<MoodCheckInPage> createState() => _MoodCheckInPageState();
}

class _MoodCheckInPageState extends State<MoodCheckInPage> {
  int? selected;
  final breathingKey = GlobalKey();
  static const moods = [
    (
      'Happy',
      AuraCharacter.flower,
      AuraMood.happy,
      'Yay! Enjoy this little bright moment in your day.',
    ),
    (
      'Sad',
      AuraCharacter.cloud,
      AuraMood.sad,
      'It’s okay to have a quiet day. Be kind to yourself.',
    ),
    (
      'Tired',
      AuraCharacter.blob,
      AuraMood.tired,
      'You can take things slowly. A little pause is okay.',
    ),
    (
      'Calm',
      AuraCharacter.diamond,
      AuraMood.calm,
      'Lovely. Take a gentle breath in, then breathe out.',
    ),
    (
      'Anxious',
      AuraCharacter.circle,
      AuraMood.anxious,
      'One small pause at a time. Try a breathing session or unwind with the game.',
    ),
    (
      'Energetic',
      AuraCharacter.square,
      AuraMood.energetic,
      'A little energy to brighten your day—enjoy it at your own pace.',
    ),
  ];
  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Wellbeing check-in',
    children: [
      const Heading('How are you feeling today?'),
      const Text('A small check-in, just for you.'),
      ActionCard(
        title: 'Merge & Unwind',
        subtitle: 'A little space to pause and play.',
        icon: Icons.bubble_chart_outlined,
        onTap: () => pushPage(context, const MergeGamePage()),
      ),
      LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: 16,
          runSpacing: 16,
          children: List.generate(
            moods.length,
            (i) => SizedBox(
              width: (constraints.maxWidth - 32) / 3,
              child: Semantics(
                selected: selected == i,
                child: Material(
                  color: selected == i ? Palette.blush : Palette.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                    side: BorderSide(
                      color: selected == i
                          ? Palette.action
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: InkWell(
                    key: ValueKey('mood-$i'),
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => setState(() => selected = i),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          Character(
                            kind: moods[i].$2,
                            mood: moods[i].$3,
                            size: ((constraints.maxWidth - 32) / 3 - 16).clamp(
                              24,
                              100,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            moods[i].$1,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 100),
        child: Semantics(
          liveRegion: true,
          child: selected == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      moods[selected!].$4,
                      key: const ValueKey('mood-feedback'),
                    ),
                    if (selected == 4)
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => Scrollable.ensureVisible(
                              breathingKey.currentContext!,
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 200),
                            ),
                            child: const Text('Try breathing'),
                          ),
                          TextButton(
                            onPressed: () =>
                                pushPage(context, const MergeGamePage()),
                            child: const Text('Play Merge & Unwind'),
                          ),
                        ],
                      ),
                  ],
                ),
        ),
      ),
      BreathingSection(key: breathingKey),
    ],
  );
}
