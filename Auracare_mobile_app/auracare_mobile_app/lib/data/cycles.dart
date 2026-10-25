import 'records.dart';

int calendarDays(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
DateTime addDays(DateTime day, int count) =>
    DateTime(day.year, day.month, day.day + count);

class RecordedPeriod {
  const RecordedPeriod(this.start, this.end, this.records);
  final DateTime start;
  final DateTime? end;
  final List<HealthEntry> records;
  int? get duration => end == null ? null : calendarDays(start, end!) + 1;
}

class CycleHistory {
  CycleHistory(Iterable<HealthEntry> entries) {
    final bleeding = entries.where((e) => e.type == EntryType.bleeding).toList()
      ..sort((a, b) => a.when.compareTo(b.when));
    final starts =
        bleeding
            .where((e) => e.periodStart == true)
            .map((e) => dayLabel(e.when))
            .toSet()
            .map(DateTime.parse)
            .toList()
          ..sort((a, b) => a.compareTo(b));
    for (var i = 0; i < starts.length; i++) {
      final start = starts[i],
          next = i + 1 < starts.length ? starts[i + 1] : null;
      final records = bleeding
          .where(
            (e) =>
                !dayOnly(e.when).isBefore(start) &&
                (next == null || dayOnly(e.when).isBefore(next)),
          )
          .toList();
      final ends = records
          .where((e) => e.periodEnd == true)
          .map((e) => dayOnly(e.when))
          .toList();
      periods.add(RecordedPeriod(start, ends.firstOrNull, records));
      if (next != null) lengths.add(calendarDays(start, next));
    }
    unmarkedDays = bleeding
        .where((e) => !starts.any((s) => !dayOnly(e.when).isBefore(s)))
        .map((e) => dayLabel(e.when))
        .toSet()
        .length;
  }
  final List<RecordedPeriod> periods = [];
  final List<int> lengths = [];
  int unmarkedDays = 0;
  double? get averageLength =>
      lengths.isEmpty ? null : lengths.reduce((a, b) => a + b) / lengths.length;
  double? get averageDuration {
    final durations = periods.map((e) => e.duration).whereType<int>().toList();
    return durations.isEmpty
        ? null
        : durations.reduce((a, b) => a + b) / durations.length;
  }

  int? get shortest => lengths.isEmpty ? null : ([...lengths]..sort()).first;
  int? get longest => lengths.isEmpty ? null : ([...lengths]..sort()).last;
}

enum CyclePhase {
  menstrual,
  follicular,
  fertile,
  ovulation,
  luteal,
  approaching,
  predictedPeriod,
}

extension CyclePhaseLabel on CyclePhase {
  String get label => switch (this) {
    CyclePhase.menstrual => 'Menstrual phase (recorded bleeding)',
    CyclePhase.follicular => 'Estimated follicular phase',
    CyclePhase.fertile => 'Approximate fertile interval',
    CyclePhase.ovulation => 'Estimated ovulation midpoint',
    CyclePhase.luteal => 'Estimated luteal phase',
    CyclePhase.approaching => 'Estimated period approaching',
    CyclePhase.predictedPeriod => 'Estimated upcoming period',
  };
}

class PhaseEstimate {
  const PhaseEstimate(this.phase, {this.step = 0});
  final CyclePhase phase;
  final int step;
}

/// Basic calendar visualization, not a fertility-awareness or diagnostic method.
/// Guardrails (four starts, 21–35-day intervals, <=3-day spread) are conservative
/// product rules, not clinically validated accuracy thresholds.
class CycleEstimates {
  CycleEstimates(this.history, {this.unsuitable = false, DateTime? today})
    : today = dayOnly(today ?? DateTime.now());
  final CycleHistory history;
  final bool unsuitable;
  final DateTime today;
  bool get available =>
      !unsuitable &&
      history.lengths.length >= 3 &&
      !history.periods.last.start.isAfter(today) &&
      history.lengths.every((n) => n >= 21 && n <= 35) &&
      history.longest! - history.shortest! <= 3;
  String get status => unsuitable
      ? 'Estimates are hidden because you marked cycles as irregular or unsuitable for calendar estimates.'
      : history.lengths.length < 3
      ? 'Mark at least four actual period starts to enable approximate estimates.'
      : !available
      ? 'Your recorded intervals vary or fall outside this basic method. Phase and fertility estimates are withheld.'
      : 'Basic calendar estimates only; not clinically validated. Ovulation may occur earlier, later, or not at all.';
  DateTime? get nextPeriod => available
      ? addDays(history.periods.last.start, history.averageLength!.round())
      : null;
  PhaseEstimate? on(DateTime date) {
    if (!available) return null;
    final period = history.periods
        .where((p) => !p.start.isAfter(dayOnly(date)))
        .lastOrNull;
    if (period == null) return null;
    final start = period.start;
    final index = history.periods.indexOf(period);
    final offset = calendarDays(start, date),
        length = index < history.lengths.length
            ? history.lengths[index]
            : history.averageLength!.round();
    if (offset < 0) return null;
    final durations = history.periods
        .map((p) => p.duration)
        .whereType<int>()
        .toList();
    final duration =
        durations.length >= 2 && durations.every((d) => d >= 1 && d <= 10)
        ? history.averageDuration!.round()
        : 1;
    if (offset >= length && offset < length + duration) {
      return const PhaseEstimate(CyclePhase.predictedPeriod);
    }
    if (offset >= length) return null; // Never roll overdue cycles forward.
    if (offset >= length - 3) {
      return PhaseEstimate(CyclePhase.approaching, step: offset - (length - 3));
    }
    // NHS: ovulation often 10–16 days before the next period; use the
    // midpoint only as a labeled visual anchor, not a confirmed event.
    final midpoint = length - 13;
    if (offset == midpoint) return const PhaseEstimate(CyclePhase.ovulation);
    if (offset >= length - 23 && offset <= length - 10) {
      return const PhaseEstimate(CyclePhase.fertile);
    }
    if (offset > length - 10) return const PhaseEstimate(CyclePhase.luteal);
    if (period.end == null || offset <= calendarDays(start, period.end!)) {
      return null;
    }
    return const PhaseEstimate(CyclePhase.follicular);
  }

  static const warning =
      'Cycle predictions are estimates based on recorded data and may not reflect actual ovulation or fertility. Do not use these estimates as contraception.';
}
