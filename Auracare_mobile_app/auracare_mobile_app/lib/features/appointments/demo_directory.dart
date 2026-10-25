import 'package:flutter/material.dart';

import '../../core/widgets.dart';
import '../../data/demo_doctors.dart';

/// Embedded in the existing appointment area. No calls, email intents, maps,
/// booking links or appointment-confirmation actions exist for these contacts.
class DemoDirectory extends StatefulWidget {
  const DemoDirectory({super.key});
  @override
  State<DemoDirectory> createState() => _DemoDirectoryState();
}

class _DemoDirectoryState extends State<DemoDirectory> {
  String query = '', specialty = 'All';
  @override
  Widget build(BuildContext context) {
    final matches = DemoDoctorDirectory.search(
      name: query,
      specialty: specialty,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaced([
        Text(
          'Demo doctor directory',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(DemoDoctorDirectory.notice),
        const Text(
          'These contacts cannot be called, emailed or booked. Your personal appointment organizer above is separate.',
        ),
        TextField(
          key: const ValueKey('doctor-directory-search'),
          decoration: const InputDecoration(
            labelText: 'Search fictional doctor names',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => query = v),
        ),
        DropdownButtonFormField<String>(
          key: const ValueKey('doctor-specialty-filter'),
          initialValue: specialty,
          isExpanded: true,
          itemHeight: null,
          decoration: const InputDecoration(labelText: 'Specialty'),
          items: [
            for (final s in [
              'All',
              'Gynecology',
              'Endocrinology',
              'General practice',
            ])
              DropdownMenuItem(value: s, child: Text(s)),
          ],
          onChanged: (v) => setState(() => specialty = v!),
        ),
        if (matches.isEmpty)
          const EmptyNotice(
            'No fictional doctors match',
            'Try a shorter name or choose All specialties.',
          ),
        for (final doctor in matches)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: spaced([
                Text(
                  doctor.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text('${doctor.specialty}\n${doctor.clinic} · ${doctor.city}'),
                Text('Phone placeholder: ${doctor.phone}'),
                Text('Email placeholder: ${doctor.email}'),
                const Text('Fictional contact · no booking or contact actions'),
              ], gap: 8),
            ),
          ),
      ]),
    );
  }
}
