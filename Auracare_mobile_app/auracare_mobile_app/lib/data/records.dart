import 'dart:convert';

import 'package:flutter/foundation.dart';

enum EntryType { symptom, journal, bleeding, wellness }

enum Severity { unspecified, mild, moderate, severe }

enum FlowIntensity { unspecified, light, moderate, heavy }

enum RecordedMood {
  happy,
  calm,
  sad,
  anxious,
  tired,
  energetic;

  String get label => '${name[0].toUpperCase()}${name.substring(1)}';
  static RecordedMood? fromLabel(String? label) =>
      values.where((mood) => mood.label == label).firstOrNull;
}

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
    this.mood,
    this.savedAt,
  });
  final String id, title, note, zone;
  final EntryType type;
  final DateTime when;
  final Severity severity;
  final int version;
  final RecordedMood? mood;

  /// Successful save time, separate from the observation's calendar date.
  final DateTime? savedAt;

  FlowIntensity? get flowIntensity {
    if (type != EntryType.bleeding) return null;
    // The original form already saves intensity in these exact titles.
    return switch (title) {
      'Bleeding · Light' => FlowIntensity.light,
      'Bleeding · Moderate' => FlowIntensity.moderate,
      'Bleeding · Heavy' => FlowIntensity.heavy,
      _ => FlowIntensity.unspecified,
    };
  }

  RecordedMood? get recordedMood {
    if (type != EntryType.wellness || title != 'Mood') return null;
    if (mood != null) return mood;
    // Read the old picker's explicit prefix; never infer mood from free text.
    final match = RegExp(
      r'^Feeling: (Happy|Calm|Sad|Anxious|Tired|Energetic)\.(?:\s|$)',
    ).firstMatch(note);
    return RecordedMood.fromLabel(match?.group(1));
  }

  HealthEntry savedOn(DateTime timestamp) => HealthEntry(
    id: id,
    type: type,
    title: title,
    when: when,
    zone: zone,
    note: note,
    severity: severity,
    version: version,
    mood: mood,
    savedAt: timestamp,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'wallClock': '${dayLabel(when)}T${timeLabel(when)}',
    'timezoneLabel': zone,
    'note': note,
    'severity': severity.name,
    'version': version,
    if (mood != null) 'mood': mood!.name,
    if (savedAt != null) 'savedAt': savedAt!.toIso8601String(),
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

/// Keeps all records; only the calendar's summary chooses one value per type.
class RecordedDay {
  RecordedDay(Iterable<HealthEntry> records, DateTime day)
    : entries = records.where((e) => dayLabel(e.when) == dayLabel(day)).toList()
        ..sort((a, b) {
          if (a.savedAt != null && b.savedAt == null) return -1;
          if (b.savedAt != null && a.savedAt == null) return 1;
          final order = (b.savedAt ?? b.when).compareTo(a.savedAt ?? a.when);
          return order != 0 ? order : b.id.compareTo(a.id);
        });
  final List<HealthEntry> entries;
  HealthEntry? get period =>
      entries.where((e) => e.type == EntryType.bleeding).firstOrNull;
  HealthEntry? get moodEntry =>
      entries.where((e) => e.recordedMood != null).firstOrNull;
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
      _entries[index] = entry.savedOn(DateTime.now().toUtc());
    } else {
      _entries.add(entry.savedOn(DateTime.now().toUtc()));
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
