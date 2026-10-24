import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/widgets.dart';
import '../../data/records.dart';

void openEditor(
  BuildContext context, {
  EntryType type = EntryType.symptom,
  HealthEntry? entry,
  DateTime? day,
}) => pushPage(
  context,
  EntryEditor(type: entry?.type ?? type, entry: entry, day: day),
);

class EntryEditor extends StatefulWidget {
  const EntryEditor({super.key, required this.type, this.entry, this.day});
  final EntryType type;
  final HealthEntry? entry;
  final DateTime? day;
  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<EntryEditor> {
  final form = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.entry?.title ?? '');
  late final note = TextEditingController(text: widget.entry?.note ?? '');
  late Severity severity = widget.entry?.severity ?? Severity.unspecified;
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
    selection ??= widget.entry?.title;
  }

  @override
  void dispose() {
    title.dispose();
    note.dispose();
    super.dispose();
  }

  void changed() => setState(() => dirty = true);
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
              : selection!,
          when: when!,
          zone: zone!,
          note: note.text.trim(),
          severity: severity,
          version: (widget.entry?.version ?? 0) + 1,
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
            widget.entry == null ? 'New ${widget.type.name}' : 'Entry details',
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
                  Heading(
                    widget.type == EntryType.journal
                        ? 'Room for your words.'
                        : 'What did you notice?',
                  ),
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
                  else
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
