import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salah_lk/designs/designs.dart';
import 'package:salah_lk/designs/display_design.dart';
import 'package:salah_lk/models/app_settings.dart';
import 'package:salah_lk/models/prayer.dart';
import 'package:salah_lk/models/timetable_data.dart';
import 'package:salah_lk/providers.dart';
import 'package:salah_lk/services/prayer_logic.dart';
import 'package:salah_lk/services/prayer_service.dart';
import 'package:salah_lk/services/timetable_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

class _FixedNow extends NowNotifier {
  final DateTime t;
  _FixedNow(this.t);
  @override
  DateTime build() => t;
}

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final l = FontLoader(family);
    for (final f in files) {
      l.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync())));
    }
    await l.load();
  }

  await load('Poppins', ['Poppins-Medium.ttf', 'Poppins-Bold.ttf']);
  await load('Amiri', ['Amiri-Regular.ttf', 'Amiri-Bold.ttf']);
  await load('DSEG7', ['DSEG7Classic-Bold.ttf']);
}

Future<void> _pump(WidgetTester tester, DisplayDesignRef design, DateTime now, AppSettings settings, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'settings_v1': settings.encode()});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      initialTimetableProvider.overrideWithValue(TimetableData.parse(bundledJsonText())),
      timetableServiceProvider.overrideWithValue(TimetableService(store: MemoryTimetableStore())),
      nowProvider.overrideWith(() => _FixedNow(now)),
    ],
    child: MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: size.width * 0.02, vertical: size.height * 0.02),
          child: DesignCanvas(child: Builder(builder: design.build)),
        ),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 300));
}

typedef DisplayDesignRef = ({String id, Widget Function(BuildContext) build});

void main() {
  setUpAll(_loadFonts);

  final sizes = {'720p': const Size(1280, 720), '1080p': const Size(1920, 1080), '4K': const Size(3840, 2160)};
  final situations = <String, (DateTime, AppSettings)>{
    'normal day': (DateTime(2026, 10, 3, 10, 0), const AppSettings(mosqueName: 'Masjid Test')),
    'between azan and iqamah': (DateTime(2026, 10, 3, 4, 50), const AppSettings(showSahr: true)),
    'after Isha (tomorrow)': (DateTime(2026, 10, 3, 23, 30), const AppSettings(use24h: true, labelLanguage: 'en')),
    'Arabic labels': (DateTime(2026, 10, 2, 12, 5), const AppSettings(labelLanguage: 'ar')), // Friday
    'timetable missing': (DateTime(2027, 1, 1, 10, 0), const AppSettings(fallbackCalculated: false)),
    'calculated fallback': (DateTime(2027, 1, 1, 10, 0), const AppSettings()),
  };

  for (final design in kDesigns) {
    for (final sz in sizes.entries) {
      for (final sit in situations.entries) {
        testWidgets('${design.id} @ ${sz.key} - ${sit.key}: lays out without errors', (tester) async {
          await _pump(tester, (id: design.id, build: design.build), sit.value.$1, sit.value.$2, sz.value);
          expect(tester.takeException(), isNull);
          if (sit.key == 'timetable missing') {
            expect(find.text('Timetable missing for this date – please update').evaluate().isNotEmpty ||
                find.textContaining('جدول').evaluate().isNotEmpty, isTrue,
                reason: '${design.id} must show the banner when the timetable is missing');
          }
        });
      }
    }
  }

  group('countdownProgress', () {
    final data = buildData(days: ['10-02', '10-03', '10-04']);
    DisplayState stateAt(DateTime now, List<DaySchedule> days) =>
        computeDisplayState(now, days, silenceMinutes: 0);
    List<DaySchedule> around(DateTime now) => [
          for (var i = -1; i <= 1; i++)
            PrayerService.buildDay(DateTime(now.year, now.month, now.day + i), const AppSettings(), data),
        ];

    test('0 right after the previous prayer, ~1 just before the next azan', () {
      // Day schedule from stdRow: fajr 05:00, sunrise 06:15, dhuhr 12:15 (iqamah +15 = 12:30), asr 15:30.
      final just = DateTime(2026, 10, 3, 12, 31); // right after dhuhr iqamah
      final p0 = countdownProgress(just, around(just), stateAt(just, around(just)));
      expect(p0, lessThan(0.01));
      final late = DateTime(2026, 10, 3, 15, 29);
      final p1 = countdownProgress(late, around(late), stateAt(late, around(late)));
      expect(p1, greaterThan(0.99));
    });

    test('halfway is about 0.5', () {
      // Previous end 12:30, next azan 15:30 -> midpoint 14:00.
      final mid = DateTime(2026, 10, 3, 14, 0);
      expect(countdownProgress(mid, around(mid), stateAt(mid, around(mid))), closeTo(0.5, 0.01));
    });

    test('between azan and iqamah it measures the way to iqamah', () {
      // Asr azan 15:30, iqamah 15:45 -> 15:37:30 is halfway.
      final mid = DateTime(2026, 10, 3, 15, 37, 30);
      expect(countdownProgress(mid, around(mid), stateAt(mid, around(mid))), closeTo(0.5, 0.01));
    });

    test('0 when there is no next prayer (missing data)', () {
      final now = DateTime(2027, 1, 1, 10);
      final days = [for (var i = -1; i <= 1; i++) PrayerService.buildDay(DateTime(2027, 1, 1 + i), const AppSettings(fallbackCalculated: false), data)];
      expect(countdownProgress(now, days, stateAt(now, days)), 0);
    });
  });
}
