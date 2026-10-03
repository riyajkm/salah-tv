import '../models/prayer.dart';

bool _sameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Decides what the display should show at [now].
///
/// [days] must include yesterday, today and tomorrow, so late-night and just-after-midnight
/// moments always have a "next" prayer (month/year boundaries need no special handling:
/// the caller builds the days from real calendar dates).
///
/// * "next" is the first prayer whose end (iqamah, or azan for sunrise) is still ahead.
/// * Between azan and iqamah the same prayer stays on screen with an iqamah countdown.
/// * For [silenceMinutes] after an iqamah, [DisplayState.silenceFor] is set.
/// * If today has no data, or today is over and tomorrow has none, the result is a
///   [DisplayState.missing] naming the date to fix. Times are never guessed.
DisplayState computeDisplayState(
  DateTime now,
  List<DaySchedule> days, {
  required int silenceMinutes,
}) {
  final all = <PrayerEntry>[for (final d in days) ...d.entries]
    ..sort((a, b) => a.azan.compareTo(b.azan));

  // The silence window only needs past iqamahs, so it works even on a missing day.
  PrayerEntry? silence;
  if (silenceMinutes > 0) {
    for (final e in all.reversed) {
      final iq = e.iqamah;
      if (iq == null || iq.isAfter(now)) continue;
      if (now.difference(iq) < Duration(minutes: silenceMinutes)) silence = e;
      break; // only the most recent iqamah can still be in its silence window
    }
  }

  final today = days.firstWhere(
    (d) => _sameDate(d.date, now),
    orElse: () => DaySchedule.missing(DateTime(now.year, now.month, now.day)),
  );
  if (today.isMissing) return DisplayState.missing(today.date, silenceFor: silence);

  PrayerEntry? next;
  for (final e in all) {
    if (e.end.isAfter(now)) {
      next = e;
      break;
    }
  }
  if (next == null) {
    // Today is finished and tomorrow has no row.
    final t = DateTime(now.year, now.month, now.day + 1);
    return DisplayState.missing(t, silenceFor: silence);
  }

  final started = !now.isBefore(next.azan);
  final phase = started && next.iqamah != null ? Phase.betweenAzanAndIqamah : Phase.waitingAzan;
  final countdown = phase == Phase.betweenAzanAndIqamah
      ? next.iqamah!.difference(now)
      : next.azan.difference(now);

  return DisplayState(next: next, phase: phase, countdown: countdown, silenceFor: silence);
}

/// Rotation mode: picks which of the day's prayers to show based on wall-clock time,
/// so it needs no timer state of its own.
PrayerEntry rotationEntry(List<PrayerEntry> today, DateTime now, int seconds) {
  final s = seconds < 1 ? 1 : seconds;
  final slot = now.millisecondsSinceEpoch ~/ (s * 1000);
  return today[slot % today.length];
}

/// How far (0..1) we are through the current countdown: the time since the previous prayer
/// ended until the next azan, or, between azan and iqamah, the time since the azan until iqamah.
/// Drives the progress bar / ring in some designs.
double countdownProgress(DateTime now, List<DaySchedule> days, DisplayState state) {
  final next = state.next;
  if (next == null) return 0;

  final DateTime start;
  final DateTime end;
  if (state.phase == Phase.betweenAzanAndIqamah && next.iqamah != null) {
    start = next.azan;
    end = next.iqamah!;
  } else {
    end = next.azan;
    DateTime? prev;
    for (final d in days) {
      for (final e in d.entries) {
        final t = e.end;
        if (!t.isAfter(now) && t.isBefore(end) && (prev == null || t.isAfter(prev))) prev = t;
      }
    }
    start = prev ?? end.subtract(const Duration(hours: 6));
  }
  final total = end.difference(start).inMilliseconds;
  if (total <= 0) return 0;
  return (now.difference(start).inMilliseconds / total).clamp(0.0, 1.0);
}
