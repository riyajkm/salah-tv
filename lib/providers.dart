import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/app_settings.dart';
import 'models/prayer.dart';
import 'models/timetable_data.dart';
import 'services/hijri_service.dart';
import 'services/prayer_logic.dart';
import 'services/prayer_service.dart';
import 'services/settings_service.dart';
import 'services/timetable_service.dart';
import 'utils/clock_correction.dart';

/// Overridden in main() once SharedPreferences has been loaded.
final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError());

final settingsServiceProvider =
    Provider<SettingsService>((ref) => SettingsService(ref.watch(sharedPrefsProvider)));

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(settingsServiceProvider).loadSettings();

  void update(AppSettings Function(AppSettings s) change) {
    state = change(state);
    ref.read(settingsServiceProvider).saveSettings(state);
  }

  void replace(AppSettings s) => update((_) => s);
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

/// Set in main() once the timetable has been loaded (parsed once, then kept in memory).
final timetableServiceProvider = Provider<TimetableService>((ref) => throw UnimplementedError());
final initialTimetableProvider = Provider<TimetableData>((ref) => throw UnimplementedError());

class TimetableNotifier extends Notifier<TimetableData> {
  @override
  TimetableData build() => ref.read(initialTimetableProvider);

  /// Validates, merges and stores [jsonText]. Throws [TimetableFormatException] when invalid
  /// (nothing is changed in that case).
  Future<ImportResult> importText(String jsonText) async {
    final result = await ref.read(timetableServiceProvider).importText(jsonText, state);
    state = result.data;
    return result;
  }

  Future<void> resetToBundled() async {
    state = await ref.read(timetableServiceProvider).resetToBundled();
  }
}

final timetableProvider = NotifierProvider<TimetableNotifier, TimetableData>(TimetableNotifier.new);

/// Wall-clock "now", ticking once per second.
///
/// Each timer is aimed at the next whole second of the *system* clock (instead of a
/// fixed 1 s period), so it never drifts and recovers by itself after clock changes.
///
/// The device clock plus the manual correction from Settings (whole seconds, so the
/// second boundaries still line up with the device clock).
class NowNotifier extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    ref.onDispose(() => _timer?.cancel());
    // A new correction takes effect immediately, not on the next tick. It only ever changes
    // through a deliberate action in Settings (set, fine adjust, reset), so the user vouches for
    // the new time: it replaces the remembered "latest time seen" and cancels any reset warning.
    ref.listen(settingsProvider.select((s) => s.clockOffsetSeconds), (_, _) {
      state = _corrected();
      ref.read(sharedPrefsProvider).setInt(kLastSeenKey, state.millisecondsSinceEpoch);
      ref.invalidate(lastSeenAtStartProvider);
    });
    _arm();
    return _corrected();
  }

  DateTime _corrected() => applyClockOffset(DateTime.now(), ref.read(settingsProvider).clockOffsetSeconds);

  void _arm() {
    final n = DateTime.now();
    _timer = Timer(Duration(milliseconds: 1000 - n.millisecond + 3), () {
      state = _corrected();
      _rememberLatest(state);
      _arm();
    });
  }

  /// Once a minute, remember the latest time ever seen. It only moves forward, so a clock
  /// that was reset to the past can be recognised after a restart (see [clockBehindProvider]).
  void _rememberLatest(DateTime t) {
    if (t.second != 0) return;
    final prefs = ref.read(sharedPrefsProvider);
    final last = prefs.getInt(kLastSeenKey);
    if (last == null || t.millisecondsSinceEpoch > last) {
      prefs.setInt(kLastSeenKey, t.millisecondsSinceEpoch);
    }
  }
}

final nowProvider = NotifierProvider<NowNotifier, DateTime>(NowNotifier.new);

/// Changes only at (local) midnight -> triggers recalculation of the schedules.
final todayProvider = Provider<DateTime>(
  (ref) => ref.watch(nowProvider.select((n) => DateTime(n.year, n.month, n.day))),
);

/// Yesterday, today and tomorrow. Recomputed on a settings/timetable change or at midnight.
final schedulesProvider = Provider<List<DaySchedule>>((ref) {
  final today = ref.watch(todayProvider);
  final settings = ref.watch(settingsProvider);
  final data = ref.watch(timetableProvider);
  return [
    for (var i = -1; i <= 1; i++)
      PrayerService.buildDay(DateTime(today.year, today.month, today.day + i), settings, data),
  ];
});

final todayScheduleProvider = Provider<DaySchedule>((ref) => ref.watch(schedulesProvider)[1]);

/// Recomputed every second; cheap (a sort of 18 items).
final displayStateProvider = Provider<DisplayState>((ref) {
  final now = ref.watch(nowProvider);
  final days = ref.watch(schedulesProvider);
  final silence = ref.watch(settingsProvider.select((s) => s.silenceMinutes));
  return computeDisplayState(now, days, silenceMinutes: silence);
});

/// Whole-minute clock, for widgets that only change once a minute.
final minuteProvider = Provider<DateTime>(
  (ref) => ref.watch(nowProvider.select((n) => DateTime(n.year, n.month, n.day, n.hour, n.minute))),
);

final hijriProvider = Provider<HijriDate>((ref) {
  final now = ref.watch(minuteProvider);
  final s = ref.watch(settingsProvider);
  final maghrib = ref.watch(todayScheduleProvider).maybeEntry(PrayerId.maghrib)?.azan;
  return hijriDateFor(
    now,
    maghrib: maghrib,
    adjust: s.hijriAdjust,
    rolloverAtMaghrib: s.hijriRolloverAtMaghrib,
  );
});

/// Timetable health for the selected zone; changes at most once a day.
class TimetableStatus {
  /// Consecutive days with data, counting from today (0 when today has no row).
  final int daysRemaining;
  final Coverage? coverage;
  final String source;
  const TimetableStatus(this.daysRemaining, this.coverage, this.source);

  static const warnBelowDays = 14;

  /// Today has data but the data is about to run out.
  bool get runningLow => daysRemaining > 0 && daysRemaining < warnBelowDays;

  @override
  bool operator ==(Object other) =>
      other is TimetableStatus && other.daysRemaining == daysRemaining && other.source == source &&
      other.coverage?.first == coverage?.first && other.coverage?.last == coverage?.last && other.coverage?.days == coverage?.days;

  @override
  int get hashCode => Object.hash(daysRemaining, source, coverage?.first, coverage?.last, coverage?.days);
}

final timetableStatusProvider = Provider<TimetableStatus>((ref) {
  final today = ref.watch(todayProvider);
  final zone = ref.watch(settingsProvider.select((s) => s.zone));
  final data = ref.watch(timetableProvider);
  return TimetableStatus(data.remainingDays(today, zone), data.coverageOf(zone), data.shortSource);
});

/// Next "Sahr ends" moment, or null if it cannot be determined. Changes rarely.
final sahrEndProvider = Provider<DateTime?>((ref) {
  final show = ref.watch(settingsProvider.select((s) => s.showSahr));
  if (!show) return null;
  final minute = ref.watch(minuteProvider);
  final days = ref.watch(schedulesProvider);
  final margin = ref.watch(timetableProvider.select((d) => d.sahrEndMinutesBeforeFajr));
  return PrayerService.sahrEnd(minute, days, margin);
});

/// The latest time the app had seen before this run started (null on the very first run).
final lastSeenAtStartProvider = Provider<DateTime?>((ref) {
  final ms = ref.watch(sharedPrefsProvider).getInt(kLastSeenKey);
  return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
});

/// True while the clock reads earlier than a time the app has already seen, i.e. the TV
/// lost its time (typically a power cut on a box without a clock battery).
final clockBehindProvider = Provider<bool>((ref) {
  final last = ref.watch(lastSeenAtStartProvider);
  if (last == null) return false;
  final now = ref.watch(minuteProvider);
  return now.isBefore(last.subtract(const Duration(minutes: 2)));
});

/// Makes the app's clock read [target] right now (used by "Set date & time").
void setClockTo(WidgetRef ref, DateTime target) {
  final offset = clockOffsetFor(target, DateTime.now());
  ref.read(settingsProvider.notifier).update((s) => s.copyWith(clockOffsetSeconds: offset));
}

bool _sameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// The day whose prayers the all-prayer designs list: today, or tomorrow once today's last
/// prayer is over. Null when the timetable has no data for the date that is needed.
final shownDayProvider = Provider<DaySchedule?>((ref) {
  final next = ref.watch(displayStateProvider).next;
  if (next == null) return null;
  final days = ref.watch(schedulesProvider);
  return _sameDate(next.azan, days[1].date) ? days[1] : days[2];
});

/// 0..1 progress of the current countdown (see [countdownProgress]). Updates every second.
final progressProvider = Provider<double>((ref) {
  final now = ref.watch(nowProvider);
  return countdownProgress(now, ref.watch(schedulesProvider), ref.watch(displayStateProvider));
});
