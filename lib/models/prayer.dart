// Core prayer-time value types (no Flutter imports so they are unit-testable).

enum PrayerId { fajr, sunrise, dhuhr, asr, maghrib, isha }

/// One row of the daily schedule.
class PrayerEntry {
  final PrayerId id;

  /// True for the Friday Dhuhr slot, which is shown as "Jumu'ah".
  final bool isJumuah;
  final DateTime azan;

  /// Null for sunrise (display only).
  final DateTime? iqamah;

  /// True when the time came from the astronomical fallback, not the ACJU timetable.
  final bool calculated;

  const PrayerEntry({
    required this.id,
    required this.azan,
    this.iqamah,
    this.isJumuah = false,
    this.calculated = false,
  });

  /// The moment this entry stops being "current": iqamah, or the azan for sunrise.
  DateTime get end => iqamah ?? azan;

  @override
  String toString() => 'PrayerEntry($id${isJumuah ? '/jumuah' : ''}, $azan, $iqamah)';
}

/// Where a day's times came from.
enum DaySource {
  /// The (bundled or imported) ACJU timetable.
  timetable,

  /// Calculated with the `adhan` package because the timetable has no row for this date.
  calculated,

  /// No timetable row and the calculation fallback is off: nothing may be shown.
  missing,
}

class DaySchedule {
  /// Midnight (local) of the day this schedule belongs to.
  final DateTime date;
  final List<PrayerEntry> entries;
  final DaySource source;

  const DaySchedule(this.date, this.entries, {this.source = DaySource.timetable});

  /// A day without any usable times.
  const DaySchedule.missing(this.date)
      : entries = const [],
        source = DaySource.missing;

  bool get isMissing => source == DaySource.missing;

  PrayerEntry entry(PrayerId id) => entries.firstWhere((e) => e.id == id);

  PrayerEntry? maybeEntry(PrayerId id) {
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }
}

enum Phase {
  /// Counting down to the next azan.
  waitingAzan,

  /// Azan has been called; counting down to iqamah.
  betweenAzanAndIqamah,
}

/// Everything the display needs to know about "now".
class DisplayState {
  /// The prayer to show by default (the next one, or the one in progress).
  /// Null when the timetable has no data for the date that is needed ([missingDate]).
  final PrayerEntry? next;
  final Phase phase;

  /// Time left until azan (waitingAzan) or iqamah (betweenAzanAndIqamah).
  final Duration countdown;

  /// Non-null while the "please silence your phones" window is active.
  final PrayerEntry? silenceFor;

  /// The date that has no data, when [next] is null.
  final DateTime? missingDate;

  const DisplayState({
    required PrayerEntry this.next,
    required this.phase,
    required this.countdown,
    this.silenceFor,
  }) : missingDate = null;

  const DisplayState.missing(DateTime this.missingDate, {this.silenceFor})
      : next = null,
        phase = Phase.waitingAzan,
        countdown = Duration.zero;

  bool get isMissing => next == null;
}
