import 'package:flutter_test/flutter_test.dart';
import 'package:salah_lk/models/app_settings.dart';
import 'package:salah_lk/models/prayer.dart';
import 'package:salah_lk/models/timetable_data.dart';
import 'package:salah_lk/services/hijri_service.dart';
import 'package:salah_lk/services/prayer_logic.dart';
import 'package:salah_lk/services/prayer_service.dart';
import 'package:salah_lk/utils/format.dart';

import 'fixtures.dart';

// Fixed iqamah rules; no calculation fallback, so a missing date really is missing.
const _settings = AppSettings(
  fallbackCalculated: false,
  iqamah: {
    'fajr': IqamahRule(minutes: 20),
    'dhuhr': IqamahRule(fixed: true, time: '12:45'),
    'asr': IqamahRule(minutes: 15),
    'maghrib': IqamahRule(minutes: 10),
    'isha': IqamahRule(minutes: 15),
    'jumuah': IqamahRule(minutes: 30),
  },
);

// 2026-10-02 is a Friday, 2026-10-03 a Saturday.
List<DaySchedule> _around(DateTime now, TimetableData data, [AppSettings s = _settings]) {
  final today = DateTime(now.year, now.month, now.day);
  return [
    for (var i = -1; i <= 1; i++) PrayerService.buildDay(DateTime(today.year, today.month, today.day + i), s, data),
  ];
}

DisplayState _state(DateTime now, {TimetableData? data, int silence = 2, AppSettings s = _settings}) =>
    computeDisplayState(now, _around(now, data ?? buildData(), s), silenceMinutes: silence);

void main() {
  group('next prayer selection', () {
    test('before Fajr: Fajr is next, counting down to azan', () {
      final st = _state(DateTime(2026, 10, 3, 4, 0));
      expect(st.next!.id, PrayerId.fajr);
      expect(st.phase, Phase.waitingAzan);
      expect(st.countdown, const Duration(hours: 1));
    });

    test('between azan and iqamah: same prayer, iqamah countdown', () {
      final st = _state(DateTime(2026, 10, 3, 5, 5, 30));
      expect(st.next!.id, PrayerId.fajr);
      expect(st.phase, Phase.betweenAzanAndIqamah);
      expect(st.countdown, const Duration(minutes: 14, seconds: 30)); // iqamah 05:20
    });

    test('exactly at azan the iqamah phase starts', () {
      expect(_state(DateTime(2026, 10, 3, 5, 0, 0)).phase, Phase.betweenAzanAndIqamah);
    });

    test('after iqamah: switches to the following prayer (Sunrise)', () {
      final st = _state(DateTime(2026, 10, 3, 5, 21));
      expect(st.next!.id, PrayerId.sunrise);
      expect(st.phase, Phase.waitingAzan);
    });

    test('sunrise has no iqamah and is skipped once it has passed', () {
      expect(_state(DateTime(2026, 10, 3, 6, 14)).next!.id, PrayerId.sunrise);
      expect(_state(DateTime(2026, 10, 3, 6, 16)).next!.id, PrayerId.dhuhr);
    });

    test('fixed iqamah time is honoured', () {
      final st = _state(DateTime(2026, 10, 3, 12, 20));
      expect(st.next!.id, PrayerId.dhuhr);
      expect(st.countdown, const Duration(minutes: 25)); // 12:45
    });
  });

  group("Jumu'ah", () {
    test("Friday shows Jumu'ah using that day's own dhuhr time and its own iqamah rule", () {
      final data = buildData(days: {
        '10-02': {...stdRow, 'dhuhr': '12:03'},
        '10-03': {...stdRow, 'dhuhr': '12:04'},
      });
      final day = _around(DateTime(2026, 10, 2, 10), data)[1];
      final d = day.entry(PrayerId.dhuhr);
      expect(day.date.weekday, DateTime.friday);
      expect(d.isJumuah, isTrue);
      expect(prayerNames(d), ("Jumu'ah", 'جمعة'));
      expect(d.azan, DateTime(2026, 10, 2, 12, 3));
      expect(d.iqamah, DateTime(2026, 10, 2, 12, 33)); // jumuah rule: +30 min
    });

    test('other days stay plain Dhuhr', () {
      final d = _around(DateTime(2026, 10, 3, 10), buildData())[1].entry(PrayerId.dhuhr);
      expect(d.isJumuah, isFalse);
      expect(prayerNames(d).$1, 'Dhuhr');
    });

    test("the display state carries the Jumu'ah entry on Friday", () {
      final st = _state(DateTime(2026, 10, 2, 11, 0));
      expect(st.next!.id, PrayerId.dhuhr);
      expect(st.next!.isJumuah, isTrue);
    });
  });

  group('silence-your-phones window', () {
    test('active for the configured minutes after iqamah, then off', () {
      expect(_state(DateTime(2026, 10, 3, 5, 19, 59)).silenceFor, isNull);
      expect(_state(DateTime(2026, 10, 3, 5, 20, 0)).silenceFor?.id, PrayerId.fajr);
      expect(_state(DateTime(2026, 10, 3, 5, 21, 59)).silenceFor?.id, PrayerId.fajr);
      expect(_state(DateTime(2026, 10, 3, 5, 22, 0)).silenceFor, isNull);
    });

    test('0 minutes disables it', () {
      expect(_state(DateTime(2026, 10, 3, 5, 20, 30), silence: 0).silenceFor, isNull);
    });
  });

  group("Isha -> tomorrow's Fajr", () {
    final data = buildData(days: {
      '10-03': {...stdRow, 'fajr': '05:00'},
      '10-04': {...stdRow, 'fajr': '05:01'}, // differs, so the lookup of *tomorrow's* row is proven
    });

    test("after Isha iqamah the next prayer is tomorrow's Fajr from tomorrow's row", () {
      final st = _state(DateTime(2026, 10, 3, 23, 59), data: data);
      expect(st.isMissing, isFalse);
      expect(st.next!.id, PrayerId.fajr);
      expect(st.next!.azan, DateTime(2026, 10, 4, 5, 1));
    });

    test("just after midnight the new day's Fajr is next", () {
      final st = _state(DateTime(2026, 10, 4, 0, 0, 1), data: data);
      expect(st.next!.id, PrayerId.fajr);
      expect(st.next!.azan, DateTime(2026, 10, 4, 5, 1));
      expect(st.silenceFor, isNull);
    });

    test('month rollover works (30 Sep -> 1 Oct)', () {
      final d = buildData(days: ['09-30', '10-01']);
      final st = _state(DateTime(2026, 9, 30, 22, 0), data: d);
      expect(st.next!.azan, DateTime(2026, 10, 1, 5, 0));
    });
  });

  group('year rollover and missing data', () {
    final dec = buildData(days: ['12-30', '12-31']);

    test('31 Dec evening, 1 Jan not in the timetable -> missing state naming 1 Jan', () {
      final st = _state(DateTime(2026, 12, 31, 23, 0), data: dec);
      expect(st.isMissing, isTrue);
      expect(st.next, isNull);
      expect(st.missingDate, DateTime(2027, 1, 1));
    });

    test('31 Dec daytime is still fine', () {
      final st = _state(DateTime(2026, 12, 31, 10, 0), data: dec);
      expect(st.isMissing, isFalse);
      expect(st.next!.id, PrayerId.dhuhr);
    });

    test("with a 1 Jan row present, Isha rolls over into the new year's Fajr", () {
      final d = buildData(days: ['12-31', '01-01']);
      final st = _state(DateTime(2026, 12, 31, 23, 30), data: d);
      expect(st.next!.id, PrayerId.fajr);
      expect(st.next!.azan, DateTime(2027, 1, 1, 5, 0));
    });

    test('1 Jan with no row: missing, even though 31 Dec exists', () {
      final st = _state(DateTime(2027, 1, 1, 6, 0), data: dec);
      expect(st.isMissing, isTrue);
      expect(st.missingDate, DateTime(2027, 1, 1));
    });

    test('today missing but tomorrow present: still missing (no guessing)', () {
      final st = _state(DateTime(2026, 10, 3, 10), data: buildData(days: ['10-04']));
      expect(st.isMissing, isTrue);
      expect(st.missingDate, DateTime(2026, 10, 3));
    });

    test('the silence window still works right after the last iqamah of the data', () {
      // Isha iqamah 19:45; tomorrow missing.
      final st = _state(DateTime(2026, 12, 31, 19, 46), data: dec);
      expect(st.isMissing, isTrue);
      expect(st.silenceFor?.id, PrayerId.isha);
    });
  });

  group('calculation fallback', () {
    test('missing date + fallback ON -> calculated day, flagged on every entry', () {
      const s = AppSettings(fallbackCalculated: true);
      final day = PrayerService.buildDay(DateTime(2027, 1, 1), s, buildData(days: ['12-31']));
      expect(day.source, DaySource.calculated);
      expect(day.entries.every((e) => e.calculated), isTrue);
      final t = day.entries.map((e) => e.azan).toList();
      for (var i = 1; i < t.length; i++) {
        expect(t[i].isAfter(t[i - 1]), isTrue, reason: 'entry $i out of order');
      }
    });

    test('missing date + fallback OFF -> a missing day without entries', () {
      final day = PrayerService.buildDay(DateTime(2027, 1, 1), _settings, buildData(days: ['12-31']));
      expect(day.isMissing, isTrue);
      expect(day.entries, isEmpty);
    });

    test('a date that exists is never calculated', () {
      final day = PrayerService.buildDay(DateTime(2026, 10, 3), const AppSettings(), buildData());
      expect(day.source, DaySource.timetable);
      expect(day.entry(PrayerId.fajr).calculated, isFalse);
    });

    test('the zone decides the coordinates (Batticaloa is east of Colombo)', () {
      final colombo = PrayerService.buildDay(DateTime(2027, 1, 1), const AppSettings(zone: '01'), TimetableData.empty);
      final batti = PrayerService.buildDay(DateTime(2027, 1, 1), const AppSettings(zone: '08'), TimetableData.empty);
      // Batticaloa (81.67E) is east of Colombo (79.86E): its sun events happen earlier.
      expect(batti.entry(PrayerId.sunrise).azan.isBefore(colombo.entry(PrayerId.sunrise).azan), isTrue);
    });
  });

  group('per-prayer azan adjustment and iqamah', () {
    test('minute adjustment shifts azan, and iqamah follows', () {
      final plain = PrayerService.buildDay(DateTime(2026, 10, 3), _settings, buildData());
      final adj = PrayerService.buildDay(
          DateTime(2026, 10, 3), _settings.copyWith(adjustments: {'asr': 3}), buildData());
      expect(adj.entry(PrayerId.asr).azan.difference(plain.entry(PrayerId.asr).azan), const Duration(minutes: 3));
      expect(adj.entry(PrayerId.asr).iqamah, DateTime(2026, 10, 3, 15, 48)); // 15:33 + 15
    });
  });

  group('Hijri date', () {
    test('rolls over at Maghrib instead of midnight when enabled', () {
      final maghrib = DateTime(2026, 10, 3, 18, 20);
      final before = hijriDateFor(DateTime(2026, 10, 3, 18, 19), maghrib: maghrib, rolloverAtMaghrib: true);
      final after = hijriDateFor(DateTime(2026, 10, 3, 18, 20), maghrib: maghrib, rolloverAtMaghrib: true);
      expect(before, hijriDateFor(DateTime(2026, 10, 3, 12)));
      expect(after, hijriDateFor(DateTime(2026, 10, 4, 12)));
      expect(after, isNot(before));
    });

    test('stays on the civil date when rollover is off', () {
      final maghrib = DateTime(2026, 10, 3, 18, 20);
      expect(hijriDateFor(DateTime(2026, 10, 3, 22), maghrib: maghrib), hijriDateFor(DateTime(2026, 10, 3, 1)));
    });

    test('manual +/- day adjustment', () {
      expect(hijriDateFor(DateTime(2026, 10, 3, 12), adjust: 1), hijriDateFor(DateTime(2026, 10, 4, 12)));
      expect(hijriDateFor(DateTime(2026, 10, 3, 12), adjust: -1), hijriDateFor(DateTime(2026, 10, 2, 12)));
    });

    test('formatting matches the design', () {
      expect(formatHijri(const HijriDate(15, 4, 1448)), "15th - Rabi'ul Akhir ( 4th month ) - 1448");
      expect(formatGregorian(DateTime(2026, 9, 27)), '27th , Sunday - September - 2026');
    });
  });

  group('rotation', () {
    test("cycles through the day's prayers by wall-clock slot", () {
      final today = _around(DateTime(2026, 10, 3, 12), buildData())[1].entries;
      final a = rotationEntry(today, DateTime.fromMillisecondsSinceEpoch(0), 10);
      final b = rotationEntry(today, DateTime.fromMillisecondsSinceEpoch(10 * 1000), 10);
      expect(a.id, isNot(b.id));
      expect(rotationEntry(today, DateTime.fromMillisecondsSinceEpoch(5 * 1000), 10).id, a.id);
    });
  });
}
