import 'dart:convert';

import 'package:flutter/foundation.dart';

enum EntryType { symptom, journal, bleeding, wellness }

enum Severity { unspecified, mild, moderate, severe }

String dayLabel(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String timeLabel(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Wall-clock components are recorded with their declared zone; no IANA conversion.
@immutable
class HealthEntry {
  const HealthEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.when,
    required this.zone,
    this.note = '',
    this.severity = Severity.unspecified,
    this.version = 1,
  });
  final String id, title, note, zone;
  final EntryType type;
  final DateTime when;
  final Severity severity;
  final int version;
  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'wallClock': '${dayLabel(when)}T${timeLabel(when)}',
    'timezoneLabel': zone,
    'note': note,
    'severity': severity.name,
    'version': version,
  };
  String get description =>
      '${dayLabel(when)} ${timeLabel(when)} · $zone\n$title · ${type.name}'
      '${severity == Severity.unspecified ? '' : ' · ${severity.name}'}${note.isEmpty ? '' : '\n$note'}';
}

abstract class RecordsRepository extends ChangeNotifier {
  List<HealthEntry> get entries;
  Future<void> save(HealthEntry entry);
  Future<void> delete(String id);
}

class DemoRecordsRepository extends RecordsRepository {
  DemoRecordsRepository({bool sample = true, DateTime? now}) {
    if (sample) reset(sample: true, now: now);
  }
  final List<HealthEntry> _entries = [];
  int _counter = 0;
  bool failNextWrite = false;
  String newId() => 'demo-${++_counter}';
  @override
  List<HealthEntry> get entries => List.unmodifiable(
    [..._entries]..sort((a, b) => b.when.compareTo(a.when)),
  );
  Future<void> _write() async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError(
        'Simulated demo failure. Your input is still here. Retry when ready.',
      );
    }
  }

  @override
  Future<void> save(HealthEntry entry) async {
    await _write();
    if (entry.note.length > 2000 || entry.title.trim().isEmpty) {
      throw ArgumentError('Check the title and note length.');
    }
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      if (entry.version != _entries[index].version + 1) {
        throw StateError('This entry changed. Reopen it before editing.');
      }
      _entries[index] = entry;
    } else {
      _entries.add(entry);
    }
    notifyListeners();
  }

  @override
  Future<void> delete(String id) async {
    await _write();
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void reset({bool sample = false, DateTime? now}) {
    _entries.clear();
    failNextWrite = false;
    if (sample) {
      final today = dayOnly(now ?? DateTime.now());
      _entries.addAll([
        HealthEntry(
          id: newId(),
          type: EntryType.symptom,
          title: 'Headache',
          when: today.add(const Duration(hours: 9)),
          zone: 'Device local',
          severity: Severity.mild,
          note: 'Fictional sample: noticed after breakfast.',
        ),
        HealthEntry(
          id: newId(),
          type: EntryType.journal,
          title: 'A little room to reflect',
          when: today
              .subtract(const Duration(days: 1))
              .add(const Duration(hours: 18)),
          zone: 'Device local',
          note: 'Fictional sample: I made time for a quiet moment.',
        ),
        HealthEntry(
          id: newId(),
          type: EntryType.symptom,
          title: 'Headache',
          when: today
              .subtract(const Duration(days: 3))
              .add(const Duration(hours: 11)),
          zone: 'Device local',
          severity: Severity.unspecified,
        ),
      ]);
    }
    notifyListeners();
  }
}

@immutable
class Coverage {
  Coverage(List<HealthEntry> entries, this.from, this.to)
    : records = entries
          .where(
            (e) =>
                !dayOnly(e.when).isBefore(dayOnly(from)) &&
                !dayOnly(e.when).isAfter(dayOnly(to)),
          )
          .toList();
  final DateTime from, to;
  final List<HealthEntry> records;
  int get totalDays =>
      DateTime.utc(
        to.year,
        to.month,
        to.day,
      ).difference(DateTime.utc(from.year, from.month, from.day)).inDays +
      1;
  int get recordedDays => records.map((e) => dayLabel(e.when)).toSet().length;
  int get unknownDays => totalDays - recordedDays;
  Map<String, int> get symptomDays {
    final result = <String, Set<String>>{};
    for (final e in records.where((e) => e.type == EntryType.symptom)) {
      result.putIfAbsent(e.title, () => <String>{}).add(dayLabel(e.when));
    }
    return result.map((key, value) => MapEntry(key, value.length));
  }
}

abstract interface class AccountPrivacyService {
  bool get connected;
  String exportSession(List<HealthEntry> entries);
}

class DemoAccountPrivacyService implements AccountPrivacyService {
  @override
  bool get connected => false;
  @override
  String exportSession(List<HealthEntry> entries) =>
      const JsonEncoder.withIndent('  ').convert({
        'mode': 'synthetic-demo',
        'persistent': false,
        'records': entries.map((e) => e.toJson()).toList(),
      });
}
