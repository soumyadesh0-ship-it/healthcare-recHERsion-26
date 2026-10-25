import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@immutable
class DoctorAppointment {
  const DoctorAppointment({
    required this.id,
    required this.doctor,
    required this.when,
    this.specialty = '',
    this.location = '',
    this.notes = '',
  });
  final String id, doctor, specialty, location, notes;
  final DateTime when;
  Map<String, Object?> toJson() => {
    'id': id,
    'doctor': doctor,
    'when': when.toIso8601String(),
    'specialty': specialty,
    'location': location,
    'notes': notes,
  };
  factory DoctorAppointment.fromJson(Map<String, dynamic> json) {
    final value = DoctorAppointment(
      id: json['id'] as String,
      doctor: json['doctor'] as String,
      when: DateTime.parse(json['when'] as String),
      specialty: json['specialty'] as String? ?? '',
      location: json['location'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
    );
    if (value.id.isEmpty || value.doctor.trim().isEmpty) {
      throw const FormatException('Invalid appointment');
    }
    return value;
  }
}

abstract interface class AppointmentStore {
  Future<String?> read();
  Future<void> write(String json);
}

class AndroidAppointmentStore implements AppointmentStore {
  static const channel = MethodChannel('org.auracare/appointments');
  @override
  Future<String?> read() => channel.invokeMethod<String>('read');
  @override
  Future<void> write(String json) => channel.invokeMethod<void>('write', json);
}

class AppointmentsRepository extends ChangeNotifier {
  AppointmentsRepository({AppointmentStore? store})
    : store = store ?? AndroidAppointmentStore();
  final AppointmentStore store;
  List<DoctorAppointment> _entries = [];
  List<DoctorAppointment> get entries => List.unmodifiable(
    [..._entries]..sort((a, b) => a.when.compareTo(b.when)),
  );
  bool loaded = false, busy = false;
  String? error;
  bool _disposed = false;
  void changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (busy) return;
    busy = true;
    loaded = false;
    error = null;
    changed();
    try {
      final text = await store.read();
      final json = text == null
          ? <String, dynamic>{'version': 1, 'appointments': []}
          : jsonDecode(text) as Map<String, dynamic>;
      if (json['version'] != 1) {
        throw const FormatException('Unsupported appointment format');
      }
      final next = (json['appointments'] as List)
          .map((e) => DoctorAppointment.fromJson(e as Map<String, dynamic>))
          .toList();
      if (next.map((e) => e.id).toSet().length != next.length) {
        throw const FormatException('Duplicate appointment IDs');
      }
      _entries = next;
      loaded = true;
    } catch (_) {
      error = 'Appointments could not be loaded. Your saved file has not been changed. Retry to continue.';
    } finally {
      busy = false;
      changed();
    }
  }

  Future<void> commit(List<DoctorAppointment> next) async {
    if (!loaded || busy) {
      throw StateError('Wait for appointments to load, then retry.');
    }
    busy = true;
    error = null;
    changed();
    try {
      await store.write(
        jsonEncode({
          'version': 1,
          'appointments': next.map((e) => e.toJson()).toList(),
        }),
      );
      _entries = next;
    } catch (_) {
      throw StateError(
        'Could not save appointments. Your previous records are unchanged; please retry.',
      );
    } finally {
      busy = false;
      changed();
    }
  }

  Future<void> save(DoctorAppointment entry) async {
    if (entry.doctor.trim().isEmpty ||
        entry.doctor.length > 100 ||
        entry.notes.length > 2000) {
      throw ArgumentError('Check the doctor name and notes.');
    }
    await commit([..._entries.where((e) => e.id != entry.id), entry]);
  }

  Future<void> delete(String id) =>
      commit(_entries.where((e) => e.id != id).toList());
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
