import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salah_lk/models/app_settings.dart';
import 'package:salah_lk/models/prayer.dart';
import 'package:salah_lk/models/timetable_data.dart';
import 'package:salah_lk/services/prayer_service.dart';
import 'package:salah_lk/services/timetable_service.dart';

import 'fixtures.dart';

/// Parses [m] (after JSON round-trip, as a real file would be).
TimetableData _parse(Map<String, dynamic> m) => TimetableData.parse(jsonEncode(m));

void main() {
  late TimetableData bundled;
  setUpAll(() => bundled = TimetableData.parse(bundledJsonText()));

  group('loading and parsing the bundled ACJU file', () {
    test('13 zones, 01..13, names read from the file', () {
      expect(bundled.regionList.map((r) => r.code), [for (var i = 1; i <= 13; i++) i.toString().padLeft(2, '0')]);
      expect(bundled.region('01')!.name, 'Colombo, Gampaha, Kalutara');
      expect(bundled.region('01')!.label, '01 – Colombo, Gampaha, Kalutara');
      expect(bundled.source, startsWith('ACJU'));
      expect(bundled.shortSource, 'ACJU');
      expect(bundled.sahrEndMinutesBeforeFajr, 2);
      expect(bundled.adjustments.map((a) => a.floors), ['06-35', '35-87']);
    });

    test('every zone covers 1 Oct - 31 Dec (92 days)', () {
      for (final r in bundled.regionList) {
        expect(r.coverage!.first, '10-01', reason: r.code);
        expect(r.coverage!.last, '12-31', reason: r.code);
        expect(r.coverage!.days, 92, reason: r.code);
      }
      expect(formatCoverage(bundled.overallCoverage!), '1 Oct – 31 Dec');
    });
  });

  group('lookup by date and region', () {
    test('known row', () {
      final t = bundled.getTimesFor(DateTime(2026, 10, 1), '01')!;
      expect([t.fajr, t.sunrise, t.dhuhr, t.asr, t.maghrib, t.isha],
          ['04:42', '05:59', '12:02', '15:16', '18:03', '19:12']);
    });

    test('DayTimes gives DateTimes on the requested date', () {
      final t = bundled.getTimesFor(DateTime(2026, 10, 1), '01')!;
      final d = DateTime(2026, 10, 3);
      expect(t.fajrOn(d), DateTime(2026, 10, 3, 4, 42));
      expect(t.dhuhrOn(d), DateTime(2026, 10, 3, 12, 2));
      expect(t.ishaOn(d), DateTime(2026, 10, 3, 19, 12));
    });

    test('zones differ', () {
      final a = bundled.getTimesFor(DateTime(2026, 10, 1), '01')!;
      final b = bundled.getTimesFor(DateTime(2026, 10, 1), '08')!;
      expect(a, isNot(b));
    });

    test('keys have no year: the same row serves any year', () {
      expect(bundled.getTimesFor(DateTime(2027, 10, 1), '01'), bundled.getTimesFor(DateTime(2026, 10, 1), '01'));
    });

    test('missing date, unknown zone -> null', () {
      expect(bundled.getTimesFor(DateTime(2026, 9, 30), '01'), isNull);
      expect(bundled.getTimesFor(DateTime(2027, 1, 1), '01'), isNull);
      expect(bundled.getTimesFor(DateTime(2026, 10, 1), '99'), isNull);
    });

    test('remainingDays counts consecutive days from today', () {
      expect(bundled.remainingDays(DateTime(2026, 12, 31), '01'), 1);
      expect(bundled.remainingDays(DateTime(2026, 12, 20), '01'), 12);
      expect(bundled.remainingDays(DateTime(2026, 10, 1), '01'), 92);
      expect(bundled.remainingDays(DateTime(2026, 9, 30), '01'), 0);
      expect(bundled.remainingDays(DateTime(2026, 10, 1), '99'), 0);
    });
  });

  group('Friday Jumu\'ah with real data', () {
    test("2 Oct 2026 (Friday): Dhuhr slot is Jumu'ah at that day's dhuhr time", () {
      final day = PrayerService.buildDay(DateTime(2026, 10, 2), const AppSettings(), bundled);
      final row = bundled.getTimesFor(DateTime(2026, 10, 2), '01')!;
      final d = day.entry(PrayerId.dhuhr);
      expect(d.isJumuah, isTrue);
      expect(d.azan, row.dhuhrOn(DateTime(2026, 10, 2)));
      expect(day.source, DaySource.timetable);
    });
  });

  group('import validation rejects bad files', () {
    void rejects(String why, String text) =>
        test(why, () => expect(() => TimetableData.parse(text), throwsA(isA<TimetableFormatException>())));

    void rejectsEdit(String why, void Function(Map<String, dynamic> row, Map<String, dynamic> region, Map<String, dynamic> root) edit) {
      test(why, () {
        final root = timetableJson();
        final region = (root['regions'] as Map)['01'] as Map<String, dynamic>;
        final days = Map<String, dynamic>.from(region['days'] as Map);
        final row = Map<String, dynamic>.from(days['10-01'] as Map);
        days['10-01'] = row;
        region['days'] = days;
        edit(row, region, root); // edits may change the row, the day map, the region or the root
        expect(() => TimetableData.parse(jsonEncode(root)), throwsA(isA<TimetableFormatException>()));
      });
    }

    rejects('not JSON', 'this is not json');
    rejects('JSON array instead of object', '[1,2,3]');
    rejects('no regions', '{"regions": {}}');
    rejectsEdit('region code not two digits', (r, reg, root) => (root['regions'] as Map)['A1'] = reg);
    rejectsEdit('region without a name', (r, reg, root) => reg.remove('name'));
    rejectsEdit('region without days', (r, reg, root) => reg['days'] = <String, dynamic>{});
    rejectsEdit('day key month 13', (r, reg, root) => (reg['days'] as Map)['13-01'] = r);
    rejectsEdit('day key 02-30', (r, reg, root) => (reg['days'] as Map)['02-30'] = r);
    rejectsEdit('day key not MM-DD', (r, reg, root) => (reg['days'] as Map)['2026-10-05'] = r);
    rejectsEdit('time hour 25', (r, reg, root) => r['asr'] = '25:00');
    rejectsEdit('time without leading zero', (r, reg, root) => r['fajr'] = '4:42');
    rejectsEdit('time with seconds / text', (r, reg, root) => r['isha'] = '7:12 PM');
    rejectsEdit('missing prayer', (r, reg, root) => r.remove('sunrise'));
    rejectsEdit('time is not a string', (r, reg, root) => r['dhuhr'] = 1202);
    rejectsEdit('times out of order (asr before dhuhr)', (r, reg, root) {
      r['asr'] = '11:00';
    });
    rejectsEdit('equal times', (r, reg, root) => r['sunrise'] = r['fajr']);
    rejectsEdit('sahr margin not a number', (r, reg, root) => root['sahr_end_minutes_before_fajr'] = 'two');
    rejectsEdit('apartment adjustment without floors', (r, reg, root) => root['apartment_adjustments'] = [{'fajr': -1}]);

    test('error message names the problem', () {
      final root = timetableJson();
      (((root['regions'] as Map)['01'] as Map)['days'] as Map)['10-01'] = {...stdRow, 'asr': '11:00'};
      try {
        TimetableData.parse(jsonEncode(root));
        fail('should have thrown');
      } on TimetableFormatException catch (e) {
        expect(e.message, contains('01'));
        expect(e.message, contains('10-01'));
        expect(e.message, contains('order'));
      }
    });

    test('29 Feb is a valid key (leap years)', () {
      expect(() => _parse(timetableJson(days: ['02-29'])), returnsNormally);
    });

    test('the file as shipped passes the same validation', () {
      expect(() => TimetableData.parse(bundledJsonText()), returnsNormally);
    });
  });

  group('merge', () {
    /// Jan-Sep of a non-leap year (273 days) for all zones of the bundled file.
    Map<String, dynamic> janToSep() {
      final days = <String, dynamic>{};
      for (var m = 1; m <= 9; m++) {
        final n = DateTime(2025, m + 1, 0).day;
        for (var d = 1; d <= n; d++) {
          days['${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}'] = stdRow;
        }
      }
      expect(days.length, 273);
      return timetableJson(
        days: days,
        zones: bundled.regionList.map((r) => r.code).toList(),
        generated: '2026-12-01T10:00:00',
      );
    }

    test('adds new days and reports a summary', () {
      final result = mergeTimetables(bundled, _parse(janToSep()));
      expect(result.addedDays, 273);
      expect(result.zones, 13);
      expect(result.overwrittenRows, 0);
      expect(result.summary, 'Added 273 days for 13 zones. Coverage now: 1 Jan – 31 Dec.');
      expect(result.data.getTimesFor(DateTime(2027, 3, 5), '01'), isNotNull);
      // Existing days are untouched.
      expect(result.data.getTimesFor(DateTime(2026, 10, 1), '01'), bundled.getTimesFor(DateTime(2026, 10, 1), '01'));
    });

    test('same days are overwritten by the new file', () {
      final fix = timetableJson(days: {
        '10-01': {...stdRow, 'fajr': '04:50'},
        '10-02': stdRow,
      });
      final result = mergeTimetables(bundled, _parse(fix));
      expect(result.addedDays, 0);
      expect(result.overwrittenRows, 2);
      expect(result.data.getTimesFor(DateTime(2026, 10, 1), '01')!.fajr, '04:50');
      // Other zones keep their original rows.
      expect(result.data.getTimesFor(DateTime(2026, 10, 1), '02'), bundled.getTimesFor(DateTime(2026, 10, 1), '02'));
      // Days not in the new file are kept.
      expect(result.data.getTimesFor(DateTime(2026, 10, 3), '01'), bundled.getTimesFor(DateTime(2026, 10, 3), '01'));
      expect(result.data.region('01')!.coverage!.days, 92);
    });

    test('identical rows do not count as overwritten', () {
      final same = timetableJson(days: {'10-01': bundled.getTimesFor(DateTime(2026, 10, 1), '01')!.toJson()});
      expect(mergeTimetables(bundled, _parse(same)).overwrittenRows, 0);
    });

    test('a zone that only exists in the new file is added', () {
      final r = mergeTimetables(buildData(), _parse(timetableJson(zones: ['01', '05'])));
      expect(r.data.regions.keys, containsAll(['01', '05']));
    });
  });

  group('TimetableService (store, import, reset)', () {
    TimetableService make(MemoryTimetableStore store, {String? text}) =>
        TimetableService(store: store, loadBundledText: () async => text ?? bundledJsonText());

    test('load returns the bundled data when nothing was imported', () async {
      final data = await make(MemoryTimetableStore()).load();
      expect(data.regions.length, 13);
    });

    test('import validates, merges, persists, and survives a restart', () async {
      final store = MemoryTimetableStore();
      final svc = make(store);
      final current = await svc.load();
      final result = await svc.importText(jsonEncode(timetableJson(days: ['01-05'], generated: '2027-01-01T00:00:00')), current);
      expect(result.addedDays, 1);
      expect(store.value, isNotNull);

      final reloaded = await make(store).load(); // "app restart"
      expect(reloaded.getTimesFor(DateTime(2027, 1, 5), '01'), isNotNull);
      expect(reloaded.getTimesFor(DateTime(2026, 10, 1), '08'), isNotNull); // bundled data still there
    });

    test('a rejected file changes nothing and stores nothing', () async {
      final store = MemoryTimetableStore();
      final svc = make(store);
      final current = await svc.load();
      await expectLater(svc.importText('{"regions": {"01": {"name": "x", "days": {"13-40": {}}}}}', current),
          throwsA(isA<TimetableFormatException>()));
      expect(store.value, isNull);
    });

    test('reset to bundled removes imported data', () async {
      final store = MemoryTimetableStore();
      final svc = make(store);
      await svc.importText(jsonEncode(timetableJson(days: ['01-05'])), await svc.load());
      final data = await svc.resetToBundled();
      expect(store.value, isNull);
      expect(data.getTimesFor(DateTime(2027, 1, 5), '01'), isNull);
    });

    test('a corrupted stored copy falls back to the bundled timetable', () async {
      final store = MemoryTimetableStore()..value = '{ broken';
      final data = await make(store).load();
      expect(data.regions.length, 13);
    });

    test('where bundled and imported overlap, the newer "generated" wins', () async {
      // Imported (older) says 1 Oct fajr is 04:55; the app now ships a newer file saying 04:42.
      final store = MemoryTimetableStore()
        ..value = jsonEncode(timetableJson(days: {'10-01': {...stdRow, 'fajr': '04:55'}, '01-05': stdRow}, generated: '2026-09-01T00:00:00'));
      final data = await make(store).load();
      expect(data.getTimesFor(DateTime(2026, 10, 1), '01')!.fajr, '04:42'); // newer bundled wins
      expect(data.getTimesFor(DateTime(2027, 1, 5), '01'), isNotNull); // older import still adds its extra day

      // Conversely, a newer import beats the bundled file.
      store.value = jsonEncode(timetableJson(days: {'10-01': {...stdRow, 'fajr': '04:55'}}, generated: '2027-02-01T00:00:00'));
      final data2 = await make(store).load();
      expect(data2.getTimesFor(DateTime(2026, 10, 1), '01')!.fajr, '04:55');
    });
  });

  group('building height adjustment', () {
    final data = buildData();
    PrayerEntry e(DaySchedule d, PrayerId id) => d.entry(id);

    test('none (default): times as printed', () {
      final d = PrayerService.buildDay(DateTime(2026, 10, 3), const AppSettings(), data);
      expect(e(d, PrayerId.fajr).azan, DateTime(2026, 10, 3, 5, 0));
      expect(e(d, PrayerId.isha).azan, DateTime(2026, 10, 3, 19, 30));
    });

    test('6-35 floors: fajr -1, sunrise -1, maghrib +1, isha +1; dhuhr and asr unchanged', () {
      final d = PrayerService.buildDay(DateTime(2026, 10, 3), const AppSettings(buildingFloors: '06-35'), data);
      expect(e(d, PrayerId.fajr).azan, DateTime(2026, 10, 3, 4, 59));
      expect(e(d, PrayerId.sunrise).azan, DateTime(2026, 10, 3, 6, 14));
      expect(e(d, PrayerId.dhuhr).azan, DateTime(2026, 10, 3, 12, 15));
      expect(e(d, PrayerId.asr).azan, DateTime(2026, 10, 3, 15, 30));
      expect(e(d, PrayerId.maghrib).azan, DateTime(2026, 10, 3, 18, 21));
      expect(e(d, PrayerId.isha).azan, DateTime(2026, 10, 3, 19, 31));
    });

    test('35-87 floors: -2 / +2', () {
      final d = PrayerService.buildDay(DateTime(2026, 10, 3), const AppSettings(buildingFloors: '35-87'), data);
      expect(e(d, PrayerId.fajr).azan, DateTime(2026, 10, 3, 4, 58));
      expect(e(d, PrayerId.sunrise).azan, DateTime(2026, 10, 3, 6, 13));
      expect(e(d, PrayerId.maghrib).azan, DateTime(2026, 10, 3, 18, 22));
      expect(e(d, PrayerId.isha).azan, DateTime(2026, 10, 3, 19, 32));
    });

    test('iqamah (minutes after azan) follows the adjusted azan', () {
      final d = PrayerService.buildDay(
          DateTime(2026, 10, 3), const AppSettings(buildingFloors: '35-87', iqamah: {'isha': IqamahRule(minutes: 10)}), data);
      expect(e(d, PrayerId.isha).iqamah, DateTime(2026, 10, 3, 19, 42));
    });

    test('an unknown value is ignored', () {
      final d = PrayerService.buildDay(DateTime(2026, 10, 3), const AppSettings(buildingFloors: '99-100'), data);
      expect(e(d, PrayerId.fajr).azan, DateTime(2026, 10, 3, 5, 0));
    });

    test('labels are built from the file', () {
      expect(data.adjustments.map((a) => a.label), ['6–35 floors (24–140 m)', '35–87 floors (140–350 m)']);
    });
  });

  group('Sahr end time', () {
    test("is Fajr minus the file's margin (2 min), for the next Fajr", () {
      final data = buildData();
      final days = [for (var i = -1; i <= 1; i++) PrayerService.buildDay(DateTime(2026, 10, 3 + i), const AppSettings(), data)];
      expect(PrayerService.sahrEnd(DateTime(2026, 10, 3, 3, 0), days, 2), DateTime(2026, 10, 3, 4, 58));
      // After today's Sahr ended, the next one is tomorrow's.
      expect(PrayerService.sahrEnd(DateTime(2026, 10, 3, 12, 0), days, 2), DateTime(2026, 10, 4, 4, 58));
    });

    test('unknown when the next Fajr is on a missing day', () {
      final data = buildData(days: ['10-03']);
      final days = [for (var i = -1; i <= 1; i++) PrayerService.buildDay(DateTime(2026, 10, 3 + i), const AppSettings(fallbackCalculated: false), data)];
      expect(PrayerService.sahrEnd(DateTime(2026, 10, 3, 12, 0), days, 2), isNull);
    });
  });
}
