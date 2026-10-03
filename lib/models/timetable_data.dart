import 'dart:convert';

import 'prayer.dart';

/// Thrown when a timetable file is malformed. [problems] lists what is wrong (capped).
class TimetableFormatException implements Exception {
  final List<String> problems;
  const TimetableFormatException(this.problems);

  String get message => problems.join('\n');

  @override
  String toString() => 'TimetableFormatException: $message';
}

final _timeRe = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
final _dayKeyRe = RegExp(r'^(\d{2})-(\d{2})$');
final _codeRe = RegExp(r'^\d{2}$');

const _daysInMonth = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]; // Feb 29 allowed

/// "MM-DD" key for a date (the timetable has no year; it repeats every year).
String dayKey(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

bool isValidDayKey(String k) {
  final m = _dayKeyRe.firstMatch(k);
  if (m == null) return false;
  final mo = int.parse(m.group(1)!), d = int.parse(m.group(2)!);
  return mo >= 1 && mo <= 12 && d >= 1 && d <= _daysInMonth[mo - 1];
}

int _minutes(String hhmm) => int.parse(hhmm.substring(0, 2)) * 60 + int.parse(hhmm.substring(3, 5));

/// One day's azan times for a region, as printed in the timetable ("HH:mm", 24h local time).
class DayTimes {
  final String fajr, sunrise, dhuhr, asr, maghrib, isha;

  const DayTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  String text(PrayerId id) => switch (id) {
        PrayerId.fajr => fajr,
        PrayerId.sunrise => sunrise,
        PrayerId.dhuhr => dhuhr,
        PrayerId.asr => asr,
        PrayerId.maghrib => maghrib,
        PrayerId.isha => isha,
      };

  /// The time of [id] on the calendar day of [date].
  DateTime on(PrayerId id, DateTime date) {
    final t = text(id);
    return DateTime(date.year, date.month, date.day, int.parse(t.substring(0, 2)), int.parse(t.substring(3, 5)));
  }

  DateTime fajrOn(DateTime d) => on(PrayerId.fajr, d);
  DateTime sunriseOn(DateTime d) => on(PrayerId.sunrise, d);
  DateTime dhuhrOn(DateTime d) => on(PrayerId.dhuhr, d);
  DateTime asrOn(DateTime d) => on(PrayerId.asr, d);
  DateTime maghribOn(DateTime d) => on(PrayerId.maghrib, d);
  DateTime ishaOn(DateTime d) => on(PrayerId.isha, d);

  Map<PrayerId, DateTime> allOn(DateTime date) => {for (final id in PrayerId.values) id: on(id, date)};

  Map<String, String> toJson() => {for (final id in PrayerId.values) id.name: text(id)};

  @override
  bool operator ==(Object other) =>
      other is DayTimes && [for (final id in PrayerId.values) text(id)].join() == [for (final id in PrayerId.values) other.text(id)].join();

  @override
  int get hashCode => Object.hashAll([for (final id in PrayerId.values) text(id)]);
}

/// Building-height correction: minutes added to fajr, sunrise, maghrib and isha.
class ApartmentAdjustment {
  final String floors; // "06-35"
  final String meters; // "24-140"
  final int fajr, sunrise, maghrib, isha;

  const ApartmentAdjustment({
    required this.floors,
    this.meters = '',
    this.fajr = 0,
    this.sunrise = 0,
    this.maghrib = 0,
    this.isha = 0,
  });

  int minutesFor(PrayerId id) => switch (id) {
        PrayerId.fajr => fajr,
        PrayerId.sunrise => sunrise,
        PrayerId.maghrib => maghrib,
        PrayerId.isha => isha,
        _ => 0, // dhuhr and asr are not affected
      };

  /// "6–35 floors (24–140 m)"
  String get label {
    String tidy(String s) => s.split('-').map((p) => int.tryParse(p)?.toString() ?? p).join('–');
    return meters.isEmpty ? '${tidy(floors)} floors' : '${tidy(floors)} floors (${tidy(meters)} m)';
  }

  Map<String, dynamic> toJson() => {
        'floors': floors,
        'meters': meters,
        'fajr': fajr,
        'sunrise': sunrise,
        'maghrib': maghrib,
        'isha': isha,
      };
}

class Coverage {
  /// "MM-DD" keys; they sort chronologically.
  final String first, last;
  final int days;
  const Coverage(this.first, this.last, this.days);
}

class Region {
  final String code; // "01".."13"
  final String name;
  final Map<String, DayTimes> days; // "MM-DD" -> times

  const Region(this.code, this.name, this.days);

  /// "01 – Colombo, Gampaha, Kalutara"
  String get label => '$code – $name';

  DayTimes? timesFor(DateTime date) => days[dayKey(date)];

  Coverage? get coverage {
    if (days.isEmpty) return null;
    final keys = days.keys.toList()..sort();
    return Coverage(keys.first, keys.last, keys.length);
  }
}

/// The whole timetable: every zone, every day. Parsed once and kept in memory.
class TimetableData {
  final String source;

  /// ISO timestamp; used to decide which copy wins when bundled and imported data overlap.
  final String generated;
  final int sahrEndMinutesBeforeFajr;
  final List<ApartmentAdjustment> adjustments;
  final Map<String, Region> regions;

  const TimetableData({
    this.source = '',
    this.generated = '',
    this.sahrEndMinutesBeforeFajr = 2,
    this.adjustments = const [],
    this.regions = const {},
  });

  static const empty = TimetableData();

  List<Region> get regionList => (regions.values.toList()..sort((a, b) => a.code.compareTo(b.code)));

  Region? region(String code) => regions[code];

  /// Today's (or any date's) times for a zone, or null when the timetable has no such row.
  DayTimes? getTimesFor(DateTime date, String regionCode) => regions[regionCode]?.timesFor(date);

  ApartmentAdjustment? adjustmentFor(String floors) {
    if (floors.isEmpty) return null;
    for (final a in adjustments) {
      if (a.floors == floors) return a;
    }
    return null;
  }

  /// Short source name for display, e.g. "ACJU".
  String get shortSource => source.isEmpty ? 'timetable' : source.split(RegExp(r'[\s(]')).first;

  /// Date range covered by one zone.
  Coverage? coverageOf(String regionCode) => regions[regionCode]?.coverage;

  /// Date range covered by any zone.
  Coverage? get overallCoverage {
    final keys = <String>{for (final r in regions.values) ...r.days.keys};
    if (keys.isEmpty) return null;
    final s = keys.toList()..sort();
    return Coverage(s.first, s.last, s.length);
  }

  /// How many consecutive days, starting at [from] (inclusive), have a row for the zone.
  int remainingDays(DateTime from, String regionCode, {int cap = 400}) {
    final r = regions[regionCode];
    if (r == null) return 0;
    var n = 0;
    while (n < cap && r.timesFor(DateTime(from.year, from.month, from.day + n)) != null) {
      n++;
    }
    return n;
  }

  Map<String, dynamic> toJson() => {
        'source': source,
        'generated': generated,
        'sahr_end_minutes_before_fajr': sahrEndMinutesBeforeFajr,
        'apartment_adjustments': [for (final a in adjustments) a.toJson()],
        'regions': {
          for (final r in regionList)
            r.code: {
              'name': r.name,
              'days': {for (final e in r.days.entries) e.key: e.value.toJson()},
            },
        },
      };

  String encode() => jsonEncode(toJson());

  factory TimetableData.parse(String text) {
    Object? j;
    try {
      j = jsonDecode(text);
    } on FormatException catch (e) {
      throw TimetableFormatException(['Not valid JSON (${e.message}).']);
    }
    if (j is! Map<String, dynamic>) {
      throw const TimetableFormatException(['The file must contain a JSON object.']);
    }
    return TimetableData.fromJson(j);
  }

  /// Strict parser. Rejects the whole file if anything is wrong, listing the first problems.
  factory TimetableData.fromJson(Map<String, dynamic> j) {
    final problems = <String>[];
    void bad(String m) {
      if (problems.length < 8) problems.add(m);
    }

    final rawRegions = j['regions'];
    if (rawRegions is! Map || rawRegions.isEmpty) {
      throw const TimetableFormatException(['"regions" is missing or empty.']);
    }

    final sahrRaw = j['sahr_end_minutes_before_fajr'];
    var sahr = 2;
    if (sahrRaw != null) {
      if (sahrRaw is int && sahrRaw >= 0 && sahrRaw <= 120) {
        sahr = sahrRaw;
      } else {
        bad('"sahr_end_minutes_before_fajr" must be a whole number 0–120.');
      }
    }

    final adjustments = <ApartmentAdjustment>[];
    final rawAdj = j['apartment_adjustments'];
    if (rawAdj != null) {
      if (rawAdj is! List) {
        bad('"apartment_adjustments" must be a list.');
      } else {
        for (final a in rawAdj) {
          if (a is! Map || a['floors'] is! String || (a['floors'] as String).isEmpty) {
            bad('Each apartment adjustment needs a "floors" text.');
            continue;
          }
          int n(String k) => a[k] is int ? a[k] as int : 0;
          if ([for (final k in ['fajr', 'sunrise', 'maghrib', 'isha']) a[k]].any((v) => v != null && v is! int)) {
            bad('Apartment adjustment "${a['floors']}" must use whole numbers of minutes.');
            continue;
          }
          adjustments.add(ApartmentAdjustment(
            floors: a['floors'] as String,
            meters: a['meters'] is String ? a['meters'] as String : '',
            fajr: n('fajr'),
            sunrise: n('sunrise'),
            maghrib: n('maghrib'),
            isha: n('isha'),
          ));
        }
      }
    }

    final regions = <String, Region>{};
    rawRegions.forEach((code, value) {
      if (code is! String || !_codeRe.hasMatch(code)) {
        bad('Region code "$code" must be two digits, e.g. "01".');
        return;
      }
      if (value is! Map || value['name'] is! String || (value['name'] as String).trim().isEmpty) {
        bad('Region $code needs a "name".');
        return;
      }
      final rawDays = value['days'];
      if (rawDays is! Map || rawDays.isEmpty) {
        bad('Region $code has no "days".');
        return;
      }
      final days = <String, DayTimes>{};
      rawDays.forEach((key, row) {
        if (key is! String || !isValidDayKey(key)) {
          bad('Region $code: "$key" is not a valid "MM-DD" date.');
          return;
        }
        if (row is! Map) {
          bad('Region $code $key: expected an object of prayer times.');
          return;
        }
        final t = <String>[];
        for (final id in PrayerId.values) {
          final v = row[id.name];
          if (v is! String || !_timeRe.hasMatch(v)) {
            bad('Region $code $key: "${id.name}" must be "HH:mm" (got ${jsonEncode(v)}).');
            return;
          }
          t.add(v);
        }
        for (var i = 1; i < t.length; i++) {
          if (_minutes(t[i]) <= _minutes(t[i - 1])) {
            bad('Region $code $key: times are not in order '
                '(${PrayerId.values[i - 1].name} ${t[i - 1]} → ${PrayerId.values[i].name} ${t[i]}).');
            return;
          }
        }
        days[key] = DayTimes(fajr: t[0], sunrise: t[1], dhuhr: t[2], asr: t[3], maghrib: t[4], isha: t[5]);
      });
      regions[code] = Region(code, (value['name'] as String).trim(), days);
    });

    if (problems.isNotEmpty) throw TimetableFormatException(problems);
    return TimetableData(
      source: j['source'] is String ? j['source'] as String : '',
      generated: j['generated'] is String ? j['generated'] as String : '',
      sahrEndMinutesBeforeFajr: sahr,
      adjustments: adjustments,
      regions: regions,
    );
  }
}
