import 'dart:convert';

import 'package:flutter/foundation.dart';

enum EntryType { symptom, journal, bleeding, wellness, spotting, discharge }

enum TrackingAmount { light, moderate, heavy }

enum ObservationAnswer { yes, no, unsure }

String observationLabel(Enum value) =>
    '${value.name[0].toUpperCase()}${value.name.substring(1)}';

@immutable
class TrackingDetails {
  const TrackingDetails({
    required this.amount,
    this.color,
    this.consistency,
    this.odorChange,
    this.irritation,
  });
  final TrackingAmount amount;
  final String? color, consistency;
  final ObservationAnswer? odorChange, irritation;
  String get summary => [
    'Amount: ${observationLabel(amount)}',
    if (color != null && color!.isNotEmpty) 'Color: $color',
    if (consistency != null && consistency!.isNotEmpty)
      'Consistency: $consistency',
    if (odorChange != null) 'Odor change: ${observationLabel(odorChange!)}',
    if (irritation != null)
      'Itching/irritation: ${observationLabel(irritation!)}',
  ].join(' · ');
  Map<String, Object?> toJson() => {
    'amount': amount.name,
    if (color != null) 'color': color,
    if (consistency != null) 'consistency': consistency,
    if (odorChange != null) 'odorChange': odorChange!.name,
    if (irritation != null) 'irritation': irritation!.name,
  };
}

enum Severity { unspecified, mild, moderate, severe }

enum FlowIntensity { unspecified, spotting, light, moderate, heavy }

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

/// Edit only selected wall-clock components, retaining precision and representation.
DateTime withWallClockComponents(
  DateTime value, {
  DateTime? date,
  int? hour,
  int? minute,
}) {
  final year = date?.year ?? value.year,
      month = date?.month ?? value.month,
      day = date?.day ?? value.day,
      h = hour ?? value.hour,
      m = minute ?? value.minute;
  if (year == value.year &&
      month == value.month &&
      day == value.day &&
      h == value.hour &&
      m == value.minute) {
    return value;
  }
  return value.isUtc
      ? DateTime.utc(
          year,
          month,
          day,
          h,
          m,
          value.second,
          value.millisecond,
          value.microsecond,
        )
      : DateTime(
          year,
          month,
          day,
          h,
          m,
          value.second,
          value.millisecond,
          value.microsecond,
        );
}

enum RecordProblem {
  conflict,
  notFound,
  validation,
  simulatedFailure,
  closed,
  cancelled,
  unavailable,
  authentication,
  deployment,
  busy,
}

/// Fixed local messages only; never constructed from SDK/transport exception text.
class RecordFailure extends StateError {
  RecordFailure(this.problem)
    : super(switch (problem) {
        RecordProblem.conflict =>
          'This entry changed. Reopen it before editing or deleting.',
        RecordProblem.notFound =>
          'This entry no longer exists. Your unsaved text is still here.',
        RecordProblem.validation =>
          'Check the title and field lengths before saving.',
        RecordProblem.simulatedFailure =>
          'Simulated demo failure. Your input is still here. Retry when ready.',
        RecordProblem.closed =>
          'This session has ended. Reopen the entry in your current session.',
        RecordProblem.cancelled =>
          'This session changed. Your operation was not saved.',
        RecordProblem.unavailable => 'Health records could not be reached. Your text is still here. Please retry.',
        RecordProblem.authentication =>
          'Please sign in again to access your health records.',
        RecordProblem.deployment => 'Cloud health records are not enabled. Database deployment and validation are required.',
        RecordProblem.busy =>
          'A record operation is already in progress. Please wait and retry.',
      });
  final RecordProblem problem;
  String get safeMessage => message;
  @override
  String toString() => safeMessage;
}

String recordErrorMessage(Object error, {required bool deleting}) =>
    error is RecordFailure
    ? error.safeMessage
    : deleting
    ? 'The entry could not be deleted. Please try again.'
    : 'The entry could not be saved. Your text is still here. Please try again.';

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
    this.periodStart,
    this.periodEnd,
    this.tracking,
    this.observationTimeKnown = true,
  });
  final String id, title, note, zone;
  final EntryType type;
  final DateTime when;
  final Severity severity;
  final int version;
  final RecordedMood? mood;

  /// Successful save time, separate from the observation's calendar date.
  final DateTime? savedAt;
  final bool? periodStart, periodEnd;
  final TrackingDetails? tracking;
  final bool observationTimeKnown;

  FlowIntensity? get flowIntensity {
    if (type != EntryType.bleeding) return null;
    // The original form already saves intensity in these exact titles.
    return switch (title) {
      'Bleeding · Spotting' => FlowIntensity.spotting,
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
    periodStart: periodStart,
    periodEnd: periodEnd,
    tracking: tracking,
    observationTimeKnown: observationTimeKnown,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'wallClock': observationTimeKnown ? when.toIso8601String() : dayLabel(when),
    if (!observationTimeKnown) 'observationTimeKnown': false,
    'timezoneLabel': zone,
    'note': note,
    'severity': severity.name,
    'version': version,
    if (mood != null) 'mood': mood!.name,
    if (savedAt != null) 'savedAt': savedAt!.toIso8601String(),
    if (periodStart != null) 'periodStart': periodStart,
    if (periodEnd != null) 'periodEnd': periodEnd,
    if (tracking != null) 'tracking': tracking!.toJson(),
  };
  String get description =>
      '${dayLabel(when)} ${observationTimeKnown ? timeLabel(when) : 'Time not recorded'} · $zone\n$title · ${type.name}'
      '${tracking == null ? '' : '\n${tracking!.summary}'}'
      '${severity == Severity.unspecified ? '' : ' · ${severity.name}'}${note.isEmpty ? '' : '\n$note'}';
}

abstract class RecordsRepository extends ChangeNotifier {
  List<HealthEntry> get entries;
  bool get isRemote => false;
  bool get loading => false;
  String? get loadError => null;
  bool get loaded => true;
  String newId();
  Future<void> load() async {}
  void reset({bool sample = false, DateTime? now});
  // Demo-only controls are ignored by authenticated repositories.
  set failNextWrite(bool value) {}
  Future<void> save(HealthEntry entry);
  Future<void> delete(String id, {required int expectedVersion});
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
  int _generation = 0;
  bool _disposed = false;
  @override
  bool failNextWrite = false;
  void _checkActive() {
    if (_disposed) throw RecordFailure(RecordProblem.closed);
  }

  @override
  String newId() {
    _checkActive();
    return 'demo-${++_counter}';
  }

  @override
  List<HealthEntry> get entries => List.unmodifiable(
    [..._entries]..sort((a, b) => b.when.compareTo(a.when)),
  );
  Future<int> _write() async {
    _checkActive();
    final generation = _generation;
    await Future<void>.delayed(const Duration(milliseconds: 280));
    _checkActive();
    if (generation != _generation) throw RecordFailure(RecordProblem.cancelled);
    if (failNextWrite) {
      failNextWrite = false;
      throw RecordFailure(RecordProblem.simulatedFailure);
    }
    return generation;
  }

  void _checkWrite(int generation) {
    _checkActive();
    if (generation != _generation) throw RecordFailure(RecordProblem.cancelled);
  }

  @override
  Future<void> save(HealthEntry entry) async {
    _checkWrite(await _write());
    if (entry.note.length > 2000 || entry.title.trim().isEmpty) {
      throw RecordFailure(RecordProblem.validation);
    }
    if ((entry.tracking?.color?.length ?? 0) > 80 ||
        (entry.tracking?.consistency?.length ?? 0) > 80) {
      throw RecordFailure(RecordProblem.validation);
    }
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      if (entry.version != _entries[index].version + 1) {
        throw RecordFailure(RecordProblem.conflict);
      }
      _entries[index] = entry.savedOn(DateTime.now().toUtc());
    } else {
      if (entry.type == EntryType.bleeding &&
          _entries.any(
            (e) =>
                e.type == EntryType.bleeding &&
                dayLabel(e.when) == dayLabel(entry.when),
          )) {
        throw StateError(
          'A flow entry already exists for this date. Reopen it to edit.',
        );
      }
      // Version 1 is a create; later versions must update an existing record.
      if (entry.version != 1) throw RecordFailure(RecordProblem.notFound);
      _entries.add(entry.savedOn(DateTime.now().toUtc()));
    }
    notifyListeners();
  }

  @override
  Future<void> delete(String id, {required int expectedVersion}) async {
    _checkWrite(await _write());
    final index = _entries.indexWhere((e) => e.id == id);
    if (index < 0) throw RecordFailure(RecordProblem.notFound);
    if (_entries[index].version != expectedVersion) {
      throw RecordFailure(RecordProblem.conflict);
    }
    _entries.removeAt(index);
    notifyListeners();
  }

  @override
  void reset({bool sample = false, DateTime? now}) {
    _checkActive();
    _generation++;
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

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _entries.clear();
    failNextWrite = false;
    super.dispose();
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
