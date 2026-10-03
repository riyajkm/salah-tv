import 'dart:io';

import 'package:salah_lk/models/timetable_data.dart';

/// The real bundled timetable, read straight from the asset file.
String bundledJsonText() => File('assets/prayer_times.json').readAsStringSync();

const stdRow = {
  'fajr': '05:00',
  'sunrise': '06:15',
  'dhuhr': '12:15',
  'asr': '15:30',
  'maghrib': '18:20',
  'isha': '19:30',
};

const apartmentAdjustments = [
  {'floors': '06-35', 'meters': '24-140', 'fajr': -1, 'sunrise': -1, 'maghrib': 1, 'isha': 1},
  {'floors': '35-87', 'meters': '140-350', 'fajr': -2, 'sunrise': -2, 'maghrib': 2, 'isha': 2},
];

/// A timetable JSON map. [days] is a list of "MM-DD" keys (all with [row]) or a map of
/// key -> row for rows that differ.
Map<String, dynamic> timetableJson({
  Object days = const ['10-01', '10-02', '10-03', '10-04'],
  Map<String, String> row = stdRow,
  List<String> zones = const ['01'],
  String generated = '2026-10-03T19:23:44',
}) {
  final Map<String, dynamic> dayMap = days is Map
      ? Map<String, dynamic>.from(days)
      : {for (final k in days as List<String>) k: row};
  return {
    'source': 'ACJU (All Ceylon Jamiyyathul Ulama)',
    'generated': generated,
    'sahr_end_minutes_before_fajr': 2,
    'apartment_adjustments': apartmentAdjustments,
    'regions': {
      for (final z in zones) z: {'name': 'Zone $z', 'days': dayMap},
    },
  };
}

TimetableData buildData({
  Object days = const ['10-01', '10-02', '10-03', '10-04'],
  Map<String, String> row = stdRow,
  List<String> zones = const ['01'],
  String generated = '2026-10-03T19:23:44',
}) =>
    TimetableData.fromJson(timetableJson(days: days, row: row, zones: zones, generated: generated));

TimetableData buildDataFromAsset() => TimetableData.parse(bundledJsonText());
