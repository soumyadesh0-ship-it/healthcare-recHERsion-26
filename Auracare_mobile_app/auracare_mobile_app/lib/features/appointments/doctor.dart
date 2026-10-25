import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/widgets.dart';
import '../../data/appointments.dart';
import '../../data/records.dart';
import 'appointments.dart';
import 'demo_directory.dart';

class DoctorPage extends StatelessWidget {
  const DoctorPage({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = SessionScope.of(context).appointments;
    final now = DateTime.now();
    final upcoming = repo.entries.where((a) => !a.when.isBefore(now)).toList();
    final history = repo.entries
        .where((a) => a.when.isBefore(now))
        .toList()
        .reversed;
    return ListView(
      key: const PageStorageKey('doctor'),
      padding: const EdgeInsets.all(20),
      children: spaced([
        const Heading('Your next conversation.'),
        const Text(
          'A private appointment organizer. Entries are personal reminders, not clinic bookings. Times use the device-local clock.',
        ),
        if (repo.busy) const LinearProgressIndicator(),
        if (repo.error != null) ErrorNotice(repo.error!),
        if (!repo.loaded)
          OutlinedButton(
            onPressed: repo.busy ? null : repo.load,
            child: const Text('Retry loading appointments'),
          ),
        if (repo.loaded) ...[
          FilledButton.icon(
            onPressed: repo.busy
                ? null
                : () => pushPage(context, const DoctorAppointmentEditor()),
            icon: const Icon(Icons.add),
            label: const Text('Add appointment'),
          ),
          Text(
            'Upcoming appointments',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (upcoming.isEmpty)
            const EmptyNotice(
              'No upcoming appointments',
              'Add a date you have arranged, or prepare questions for your next visit.',
            ),
          for (final appointment in upcoming) _tile(context, appointment),
        ],
        ActionCard(
          title: 'Appointment preparation',
          subtitle:
              'Choose source records, write questions and review your notes',
          icon: Icons.description_outlined,
          onTap: () => pushPage(context, const AppointmentPage()),
        ),
        if (repo.loaded) ...[
          Text(
            'Appointment history',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (history.isEmpty) const Text('No past appointments saved.'),
          for (final appointment in history) _tile(context, appointment),
        ],
        const Text(
          'Appointments are stored on this Android device in app-private storage, excluded from Android backup. They are not sent to a clinic or cloud service. Uninstalling the app or clearing its storage deletes them. Device security still matters.',
        ),
        const Divider(),
        const DemoDirectory(),
      ]),
    );
  }

  Widget _tile(BuildContext context, DoctorAppointment a) => ActionCard(
    title: a.doctor,
    subtitle:
        '${dayLabel(a.when)} · ${timeLabel(a.when)}${a.specialty.isEmpty ? '' : '\n${a.specialty}'}${a.location.isEmpty ? '' : '\n${a.location}'}',
    icon: Icons.event_outlined,
    onTap: () => pushPage(context, DoctorAppointmentEditor(appointment: a)),
  );
}

class DoctorAppointmentEditor extends StatefulWidget {
  const DoctorAppointmentEditor({super.key, this.appointment});
  final DoctorAppointment? appointment;
  @override
  State<DoctorAppointmentEditor> createState() =>
      _DoctorAppointmentEditorState();
}

class _DoctorAppointmentEditorState extends State<DoctorAppointmentEditor> {
  final form = GlobalKey<FormState>();
  late final doctor = TextEditingController(
    text: widget.appointment?.doctor ?? '',
  );
  late final specialty = TextEditingController(
    text: widget.appointment?.specialty ?? '',
  );
  late final location = TextEditingController(
    text: widget.appointment?.location ?? '',
  );
  late final notes = TextEditingController(
    text: widget.appointment?.notes ?? '',
  );
  late DateTime when =
      widget.appointment?.when ?? DateTime.now().add(const Duration(days: 1));
  late final String id =
      widget.appointment?.id ??
      'appointment-${DateTime.now().microsecondsSinceEpoch}';
  bool busy = false, dirty = false, allowPop = false;
  String? error;
  @override
  void dispose() {
    doctor.dispose();
    specialty.dispose();
    location.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> leave() async {
    if (busy) return;
    if (!dirty ||
        await confirm(
          context,
          'Discard appointment changes?',
          'Unsaved appointment details will be discarded.',
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
    final repo = SessionScope.of(context).appointments;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repo.save(
        DoctorAppointment(
          id: id,
          doctor: doctor.text.trim(),
          specialty: specialty.text.trim(),
          location: location.text.trim(),
          notes: notes.text.trim(),
          when: when,
        ),
      );
      if (!mounted) return;
      setState(() {
        allowPop = true;
        dirty = false;
        busy = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Appointment could not be saved. Your input is still here; please retry.';
        });
      }
    }
  }

  Future<void> remove() async {
    if (!await confirm(
      context,
      'Delete appointment?',
      'Remove this personal appointment from this device?',
      action: 'Delete',
    )) {
      return;
    }
    if (!mounted) return;
    final repo = SessionScope.of(context).appointments;
    setState(() => busy = true);
    try {
      await repo.delete(id);
      if (!mounted) return;
      setState(() {
        busy = false;
        dirty = false;
        allowPop = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Could not delete the appointment. Please retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: allowPop || (!dirty && !busy),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) leave();
    },
    child: PageFrame(
      title: widget.appointment == null
          ? 'Add appointment'
          : 'Appointment details',
      children: [
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: spaced([
              TextFormField(
                key: const ValueKey('appointment-doctor'),
                enabled: !busy,
                controller: doctor,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Doctor name'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Enter the doctor name.'
                    : null,
                onChanged: (_) => setState(() => dirty = true),
              ),
              TextFormField(
                controller: specialty,
                enabled: !busy,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Specialty (optional)',
                ),
                onChanged: (_) => setState(() => dirty = true),
              ),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: when,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (date != null && mounted) {
                          setState(() {
                            when = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              when.hour,
                              when.minute,
                            );
                            dirty = true;
                          });
                        }
                      },
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text('Date: ${dayLabel(when)}'),
              ),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(when),
                        );
                        if (time != null && mounted) {
                          setState(() {
                            when = DateTime(
                              when.year,
                              when.month,
                              when.day,
                              time.hour,
                              time.minute,
                            );
                            dirty = true;
                          });
                        }
                      },
                icon: const Icon(Icons.schedule),
                label: Text('Time: ${timeLabel(when)} · device local'),
              ),
              TextFormField(
                controller: location,
                enabled: !busy,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Clinic or location (optional)',
                ),
                onChanged: (_) => setState(() => dirty = true),
              ),
              TextFormField(
                key: const ValueKey('appointment-notes'),
                enabled: !busy,
                controller: notes,
                maxLength: 2000,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Notes or questions (optional)',
                ),
                onChanged: (_) => setState(() => dirty = true),
              ),
              if (error != null) ErrorNotice(error!),
              if (busy) const LinearProgressIndicator(),
              FilledButton(
                onPressed: busy ? null : save,
                child: const Text('Save appointment'),
              ),
              OutlinedButton(
                onPressed: busy ? null : leave,
                child: const Text('Cancel'),
              ),
              if (widget.appointment != null)
                TextButton(
                  onPressed: busy ? null : remove,
                  child: const Text('Delete appointment'),
                ),
            ]),
          ),
        ),
      ],
    ),
  );
}
