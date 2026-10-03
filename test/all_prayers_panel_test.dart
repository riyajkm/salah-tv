import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salah_lk/models/app_settings.dart';
import 'package:salah_lk/models/timetable_data.dart';
import 'package:salah_lk/providers.dart';
import 'package:salah_lk/services/timetable_service.dart';
import 'package:salah_lk/widgets/all_prayers_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

class _FixedNow extends NowNotifier {
  final DateTime t;
  _FixedNow(this.t);
  @override
  DateTime build() => t;
}

Future<void> _pump(WidgetTester tester, DateTime now, AppSettings settings, TimetableData data) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'settings_v1': settings.encode()});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      initialTimetableProvider.overrideWithValue(data),
      timetableServiceProvider.overrideWithValue(TimetableService(store: MemoryTimetableStore())),
      nowProvider.overrideWith(() => _FixedNow(now)),
    ],
    child: const MaterialApp(home: Scaffold(body: SizedBox(width: 1920, height: 1080, child: AllPrayersPanel()))),
  ));
}

// Distinct times per day so the test can tell today's card from tomorrow's.
final _data = buildData(days: {
  '10-03': {'fajr': '04:50', 'sunrise': '06:00', 'dhuhr': '12:03', 'asr': '15:20', 'maghrib': '18:01', 'isha': '19:10'},
  '10-04': {'fajr': '04:51', 'sunrise': '06:01', 'dhuhr': '12:02', 'asr': '15:19', 'maghrib': '18:00', 'isha': '19:09'},
});

void main() {
  testWidgets('12-hour times, Arabic names, countdown to the next prayer', (tester) async {
    await _pump(tester, DateTime(2026, 10, 3, 10, 0), const AppSettings(), _data);
    expect(find.text('04:50'), findsOneWidget); // fajr azan
    expect(find.text('05:10'), findsOneWidget); // fajr iqamah (+20 min)
    expect(find.text('06:00'), findsOneWidget); // sunrise
    expect(find.text('07:10'), findsOneWidget); // isha azan, 12h
    for (final name in ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(find.text('فجر'), findsOneWidget);
    expect(find.text('Dhuhr Azan in 02:03:00'), findsOneWidget);
  });

  testWidgets('Friday shows Jumu\'ah instead of Dhuhr', (tester) async {
    final friday = buildData(days: ['10-02', '10-03']);
    await _pump(tester, DateTime(2026, 10, 2, 10, 0), const AppSettings(), friday);
    expect(find.text("Jumu'ah"), findsOneWidget);
    expect(find.text('Dhuhr'), findsNothing);
  });

  testWidgets('English-only labels hide the Arabic names', (tester) async {
    await _pump(tester, DateTime(2026, 10, 3, 10, 0), const AppSettings(labelLanguage: 'en'), _data);
    expect(find.text('Fajr'), findsOneWidget);
    expect(find.text('فجر'), findsNothing);
  });

  testWidgets("after Isha the cards show tomorrow's times", (tester) async {
    await _pump(tester, DateTime(2026, 10, 3, 23, 30), const AppSettings(use24h: true), _data);
    expect(find.text('04:51'), findsOneWidget); // tomorrow's fajr, not today's 04:50
    expect(find.text('04:50'), findsNothing);
    expect(find.textContaining('Fajr Azan in'), findsOneWidget);
  });

  testWidgets('between azan and iqamah the countdown is to iqamah', (tester) async {
    await _pump(tester, DateTime(2026, 10, 3, 4, 55), const AppSettings(), _data);
    expect(find.text('Iqamah in 15:00'), findsOneWidget); // iqamah 05:10
  });

  testWidgets('missing date: banner instead of cards', (tester) async {
    await _pump(tester, DateTime(2027, 1, 1, 10, 0), const AppSettings(fallbackCalculated: false), _data);
    expect(find.text('Timetable missing for this date – please update'), findsOneWidget);
    expect(find.text('Fajr'), findsNothing);
  });
}
