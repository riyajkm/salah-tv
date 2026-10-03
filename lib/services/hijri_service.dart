import 'package:hijri/hijri_calendar.dart';

class HijriDate {
  final int day;
  final int month; // 1..12
  final int year;
  const HijriDate(this.day, this.month, this.year);

  @override
  bool operator ==(Object other) =>
      other is HijriDate && other.day == day && other.month == month && other.year == year;

  @override
  int get hashCode => Object.hash(day, month, year);

  @override
  String toString() => 'HijriDate($day/$month/$year)';
}

/// Hijri date for [now].
///
/// * [adjust] shifts the date by whole days (local moon-sighting differences).
/// * With [rolloverAtMaghrib] the Hijri day changes at [maghrib] instead of midnight,
///   as in the Islamic day, which begins at sunset.
HijriDate hijriDateFor(
  DateTime now, {
  DateTime? maghrib,
  int adjust = 0,
  bool rolloverAtMaghrib = false,
}) {
  var shift = adjust;
  if (rolloverAtMaghrib && maghrib != null && !now.isBefore(maghrib)) shift += 1;
  final g = DateTime(now.year, now.month, now.day + shift);
  final h = HijriCalendar.fromDate(g);
  return HijriDate(h.hDay, h.hMonth, h.hYear);
}
