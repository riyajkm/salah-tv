import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salah_lk/models/app_settings.dart';
import 'package:salah_lk/providers.dart';
import 'package:salah_lk/utils/clock_correction.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container({int offset = 0, int? lastSeenMs}) async {
  SharedPreferences.setMockInitialValues({
    'settings_v1': AppSettings(clockOffsetSeconds: offset).encode(),
    kLastSeenKey: ?lastSeenMs,
  });
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('offset maths', () {
    test('offset makes the device clock read the target', () {
      final device = DateTime(2020, 1, 1, 8, 0, 0);
      final target = DateTime(2026, 10, 3, 20, 15);
      final off = clockOffsetFor(target, device);
      expect(applyClockOffset(device, off), target);
      expect(clockOffsetFor(device, device), 0);
    });

    test('negative offsets (device clock ahead) work', () {
      final device = DateTime(2026, 10, 3, 20, 20);
      final target = DateTime(2026, 10, 3, 20, 15);
      expect(clockOffsetFor(target, device), -300);
      expect(applyClockOffset(device, -300), target);
    });

    test('formatOffset', () {
      expect(formatOffset(0), 'No correction');
      expect(formatOffset(5), '+5 s');
      expect(formatOffset(-130), '-2 min 10 s');
      expect(formatOffset(3 * 3600 + 20 * 60), '+3 h 20 min');
      expect(formatOffset(-(4 * 86400 + 2 * 3600)), '-4 d 2 h');
    });
  });

  group('date & time input', () {
    test('valid forms', () {
      expect(parseDateTimeInput('2026-10-03 20:15'), DateTime(2026, 10, 3, 20, 15));
      expect(parseDateTimeInput(' 2026-10-03 07:05:30 '), DateTime(2026, 10, 3, 7, 5, 30));
      expect(parseDateTimeInput('2026-1-3 7:05'), DateTime(2026, 1, 3, 7, 5));
    });

    test('invalid forms are rejected', () {
      for (final bad in ['', 'tomorrow', '2026-02-30 10:00', '2026-13-01 10:00', '2026-10-03 25:00',
          '2026-10-03 10:61', '03/10/2026 10:00', '2026-10-03']) {
        expect(parseDateTimeInput(bad), isNull, reason: bad);
      }
    });

    test('format round-trips', () {
      final t = DateTime(2026, 10, 3, 7, 5);
      expect(parseDateTimeInput(formatDateTimeInput(t)), t);
    });
  });

  group('the app clock', () {
    test('uses the device clock when there is no correction', () async {
      final c = await _container();
      expect(c.read(nowProvider).difference(DateTime.now()).inSeconds.abs() <= 1, isTrue);
    });

    test('adds the saved correction', () async {
      final c = await _container(offset: 3600);
      final diff = c.read(nowProvider).difference(DateTime.now());
      expect((diff - const Duration(hours: 1)).inSeconds.abs() <= 1, isTrue);
    });

    test('a new correction applies immediately', () async {
      final c = await _container();
      c.read(nowProvider); // start the clock
      c.read(settingsProvider.notifier).update((s) => s.copyWith(clockOffsetSeconds: -7200));
      final diff = c.read(nowProvider).difference(DateTime.now());
      expect((diff + const Duration(hours: 2)).inSeconds.abs() <= 1, isTrue);
    });
  });

  group('clock reset detection', () {
    test('no history -> no warning', () async {
      final c = await _container();
      expect(c.read(clockBehindProvider), isFalse);
    });

    test('clock behind the latest time already seen -> warning', () async {
      final future = DateTime.now().add(const Duration(days: 3)).millisecondsSinceEpoch;
      final c = await _container(lastSeenMs: future);
      expect(c.read(clockBehindProvider), isTrue);
    });

    test('a small step back (seconds) is tolerated', () async {
      final slightly = DateTime.now().add(const Duration(seconds: 30)).millisecondsSinceEpoch;
      final c = await _container(lastSeenMs: slightly);
      expect(c.read(clockBehindProvider), isFalse);
    });

    test('turning the correction back (e.g. reset) does not raise the warning', () async {
      final ahead = DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch;
      final c = await _container(offset: 7200, lastSeenMs: ahead);
      c.read(nowProvider); // the clock is running, as in the app
      expect(c.read(clockBehindProvider), isFalse);
      c.read(settingsProvider.notifier).update((s) => s.copyWith(clockOffsetSeconds: 0));
      expect(c.read(clockBehindProvider), isFalse);
      // ...and what is remembered now is the new, corrected time.
      final stored = c.read(sharedPrefsProvider).getInt(kLastSeenKey)!;
      expect((stored - DateTime.now().millisecondsSinceEpoch).abs() < 5000, isTrue);
    });

    test('a correction that brings the clock past the latest seen time clears it', () async {
      final future = DateTime.now().add(const Duration(days: 3)).millisecondsSinceEpoch;
      final c = await _container(lastSeenMs: future);
      expect(c.read(clockBehindProvider), isTrue);
      c.read(nowProvider);
      c.read(settingsProvider.notifier).update((s) => s.copyWith(clockOffsetSeconds: 4 * 86400));
      expect(c.read(clockBehindProvider), isFalse);
    });
  });
}
