import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salah_lk/models/app_settings.dart';
import 'package:salah_lk/models/timetable_data.dart';
import 'package:salah_lk/providers.dart';
import 'package:salah_lk/services/timetable_service.dart';
import 'package:salah_lk/widgets/overlays.dart';
import 'package:salah_lk/widgets/prayer_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

/// A clock that never ticks, so widget tests have no pending timers.
class _FixedNow extends NowNotifier {
  final DateTime t;
  _FixedNow(this.t);
  @override
  DateTime build() => t;
}

Future<Widget> _app(DateTime now, AppSettings settings, TimetableData data, Widget child) async {
  SharedPreferences.setMockInitialValues({'settings_v1': settings.encode()});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      initialTimetableProvider.overrideWithValue(data),
      timetableServiceProvider.overrideWithValue(TimetableService(store: MemoryTimetableStore())),
      nowProvider.overrideWith(() => _FixedNow(now)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 1920, height: 1080, child: Stack(children: [child, const StatusBadges()])),
      ),
    ),
  );
}

void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  testWidgets('missing date + fallback OFF: banner instead of times', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _app(
      DateTime(2027, 1, 1, 10, 0), // not in the timetable
      const AppSettings(fallbackCalculated: false),
      buildData(days: ['12-30', '12-31']),
      const PrayerPanel(),
    ));
    expect(find.text('Timetable missing for this date – please update'), findsOneWidget);
    expect(find.text('1 Jan 2027'), findsOneWidget);
    expect(find.text('CALCULATED'), findsNothing);
  });

  testWidgets('English-only labels hide the Arabic banner line', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _app(
      DateTime(2027, 1, 1, 10, 0),
      const AppSettings(fallbackCalculated: false, labelLanguage: 'en'),
      buildData(days: ['12-31']),
      const PrayerPanel(),
    ));
    expect(find.text('Timetable missing for this date – please update'), findsOneWidget);
    expect(find.textContaining('جدول'), findsNothing);
  });

  testWidgets('31 Dec after Isha with no 1 Jan row: banner names tomorrow', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _app(
      DateTime(2026, 12, 31, 23, 0),
      const AppSettings(fallbackCalculated: false),
      buildData(days: ['12-30', '12-31']),
      const PrayerPanel(),
    ));
    expect(find.text('Timetable missing for this date – please update'), findsOneWidget);
    expect(find.text('1 Jan 2027'), findsOneWidget);
  });

  testWidgets('fallback ON: no banner, times shown and marked CALCULATED', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _app(
      DateTime(2027, 1, 1, 10, 0),
      const AppSettings(fallbackCalculated: true),
      buildData(days: ['12-31']),
      const PrayerPanel(),
    ));
    expect(find.text('Timetable missing for this date – please update'), findsNothing);
    expect(find.text('CALCULATED'), findsOneWidget);
  });

  testWidgets('normal day: no banner and no badges', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _app(
      DateTime(2026, 10, 3, 10, 0),
      const AppSettings(),
      TimetableData.parse(bundledJsonText()),
      const PrayerPanel(),
    ));
    expect(find.textContaining('missing'), findsNothing);
    expect(find.text('CALCULATED'), findsNothing);
    expect(find.textContaining('Timetable ends'), findsNothing);
  });

  testWidgets('fewer than 14 days left: small reminder on the main screen', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(await _app(
      DateTime(2026, 12, 25, 10, 0), // 7 days left incl. today (25..31 Dec)
      const AppSettings(),
      TimetableData.parse(bundledJsonText()),
      const PrayerPanel(),
    ));
    expect(find.text('Timetable ends in 7 days\nplease update'), findsOneWidget);
  });
}
