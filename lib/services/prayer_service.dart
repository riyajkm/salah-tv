import 'package:adhan/adhan.dart' as adhan;

import '../models/app_settings.dart';
import '../models/prayer.dart';
import '../models/timetable_data.dart';

/// Representative coordinates of each ACJU zone, used only by the calculation fallback.
const zoneCoordinates = <String, (double, double)>{
  '01': (6.9271, 79.8612), // Colombo
  '02': (9.6615, 80.0255), // Jaffna
  '03': (8.7514, 80.4971), // Vavuniya
  '04': (8.9810, 79.9044), // Mannar
  '05': (8.3114, 80.4037), // Anuradhapura
  '06': (7.4863, 80.3647), // Kurunegala
  '07': (7.2906, 80.6337), // Kandy
  '08': (7.7310, 81.6747), // Batticaloa
  '09': (8.5874, 81.2152), // Trincomalee
  '10': (6.9934, 81.0550), // Badulla
  '11': (6.6828, 80.3992), // Ratnapura
  '12': (6.0535, 80.2210), // Galle
  '13': (6.1241, 81.1185), // Hambantota
};

/// Builds the schedule for one calendar day. Pure: depends only on its arguments,
/// and interprets all times in the device's local time zone (set the TV to Asia/Colombo).
class PrayerService {
  const PrayerService._();

  /// 1. the zone's row in [data] (plus the building-height correction);
  /// 2. otherwise, if enabled, a calculation for the zone's coordinates (marked as calculated);
  /// 3. otherwise a *missing* day — never a silently guessed one.
  static DaySchedule buildDay(DateTime anyTimeOfDay, AppSettings s, TimetableData data) {
    final date = DateTime(anyTimeOfDay.year, anyTimeOfDay.month, anyTimeOfDay.day);

    Map<PrayerId, DateTime> base;
    DaySource source;
    final row = data.getTimesFor(date, s.zone);
    if (row != null) {
      final adj = data.adjustmentFor(s.buildingFloors);
      base = {
        for (final e in row.allOn(date).entries)
          e.key: e.value.add(Duration(minutes: adj?.minutesFor(e.key) ?? 0)),
      };
      source = DaySource.timetable;
    } else if (s.fallbackCalculated) {
      base = _calculate(date, s);
      source = DaySource.calculated;
    } else {
      return DaySchedule.missing(date);
    }

    final isFriday = date.weekday == DateTime.friday;
    final entries = <PrayerEntry>[];
    for (final id in PrayerId.values) {
      final azan = base[id]!.add(Duration(minutes: s.adjustmentFor(id)));
      final jumuah = isFriday && id == PrayerId.dhuhr;
      entries.add(PrayerEntry(
        id: id,
        azan: azan,
        isJumuah: jumuah,
        calculated: source == DaySource.calculated,
        iqamah: id == PrayerId.sunrise
            ? null
            : _iqamah(date, azan, s.iqamahRule(jumuah ? 'jumuah' : id.name)),
      ));
    }
    return DaySchedule(date, entries, source: source);
  }

  static DateTime _iqamah(DateTime date, DateTime azan, IqamahRule r) {
    if (r.fixed) {
      final t = parseHm(r.time);
      if (t != null) {
        final fixed = DateTime(date.year, date.month, date.day, t.$1, t.$2);
        // A fixed time at/before azan is a misconfiguration; fall back to azan + 1 min
        // so the countdown screen still behaves sensibly.
        return fixed.isAfter(azan) ? fixed : azan.add(const Duration(minutes: 1));
      }
    }
    return azan.add(Duration(minutes: r.minutes < 1 ? 1 : r.minutes));
  }

  static Map<PrayerId, DateTime> _calculate(DateTime date, AppSettings s) {
    final (lat, lng) = zoneCoordinates[s.zone] ?? zoneCoordinates['01']!;
    final method = adhan.CalculationMethod.values.firstWhere(
      (m) => m.name == s.method,
      orElse: () => adhan.CalculationMethod.muslim_world_league,
    );
    final params = method.getParameters()
      ..madhab = s.madhab == 'hanafi' ? adhan.Madhab.hanafi : adhan.Madhab.shafi;
    switch (s.highLatitudeRule) {
      case 'middle_of_the_night':
        params.highLatitudeRule = adhan.HighLatitudeRule.middle_of_the_night;
      case 'seventh_of_the_night':
        params.highLatitudeRule = adhan.HighLatitudeRule.seventh_of_the_night;
      case 'twilight_angle':
        params.highLatitudeRule = adhan.HighLatitudeRule.twilight_angle;
    }
    final t = adhan.PrayerTimes(
      adhan.Coordinates(lat, lng),
      adhan.DateComponents(date.year, date.month, date.day),
      params,
    );
    DateTime clean(DateTime d) {
      final l = d.toLocal();
      return DateTime(l.year, l.month, l.day, l.hour, l.minute);
    }

    return {
      PrayerId.fajr: clean(t.fajr),
      PrayerId.sunrise: clean(t.sunrise),
      PrayerId.dhuhr: clean(t.dhuhr),
      PrayerId.asr: clean(t.asr),
      PrayerId.maghrib: clean(t.maghrib),
      PrayerId.isha: clean(t.isha),
    };
  }

  /// Parses "H:mm" / "HH:mm" (24h). Returns (hour, minute) or null.
  static (int, int)? parseHm(String s) {
    final m = RegExp(r'^\s*(\d{1,2}):(\d{2})').firstMatch(s);
    if (m == null) return null;
    final h = int.parse(m.group(1)!), mi = int.parse(m.group(2)!);
    if (h > 23 || mi > 59) return null;
    return (h, mi);
  }

  /// "Sahr ends" = Fajr azan minus the timetable's margin, for the next Fajr after [now].
  /// Null when that Fajr is unknown (missing day).
  static DateTime? sahrEnd(DateTime now, List<DaySchedule> days, int minutesBeforeFajr) {
    DateTime? best;
    for (final d in days) {
      final f = d.maybeEntry(PrayerId.fajr);
      if (f == null) continue;
      final end = f.azan.subtract(Duration(minutes: minutesBeforeFajr));
      if (end.isAfter(now) && (best == null || end.isBefore(best))) best = end;
    }
    return best;
  }
}
