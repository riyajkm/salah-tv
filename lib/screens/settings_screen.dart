import 'dart:io';

import 'package:adhan/adhan.dart' as adhan;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../designs/designs.dart';
import '../models/app_settings.dart';
import '../providers.dart';
import '../models/timetable_data.dart';
import '../services/prayer_service.dart';
import '../services/system_service.dart';
import '../services/timetable_service.dart';
import '../utils/clock_correction.dart';

const _gold = Color(0xFFFFD700);

/// App version for the About section, e.g. "1.0.0 (1)".
final _versionProvider = FutureProvider.autoDispose<String>((ref) async {
  final i = await PackageInfo.fromPlatform();
  return '${i.version} (${i.buildNumber})';
});

/// Whether SalahLK is the TV's default home app. Re-read each time Settings opens.
final _isHomeProvider = FutureProvider.autoDispose<bool>((ref) => SystemService.isDefaultHome());

/// Whether SalahLK is allowed to open itself at boot ("Display over other apps").
final _canAutoStartProvider = FutureProvider.autoDispose<bool>((ref) => SystemService.canAutoStart());

/// Re-reads both statuses when the user comes back from a system settings screen.
final _resumeRefreshProvider = Provider.autoDispose<void>((ref) {
  final l = AppLifecycleListener(onResume: () {
    ref.invalidate(_isHomeProvider);
    ref.invalidate(_canAutoStartProvider);
  });
  ref.onDispose(l.dispose);
});

const _palette = <String, int>{
  'White': 0xFFFFFFFF,
  'Red': 0xFFE8202A,
  'Green': 0xFF2ECC40,
  'Yellow': 0xFFFFD700,
  'Cyan': 0xFF00E5FF,
  'Orange': 0xFFFF8C00,
  'Magenta': 0xFFFF4DFF,
  'Blue': 0xFF4D9DFF,
};

const _prayerKeys = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];

String _title(String key) => switch (key) {
      'jumuah' => "Jumu'ah",
      _ => key[0].toUpperCase() + key.substring(1),
    };

/// D-pad friendly settings. Up/Down moves between rows, Left/Right changes the value of the
/// focused row, OK activates it (toggle / edit / pick), Back leaves.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final data = ref.watch(timetableProvider);
    final status = ref.watch(timetableStatusProvider);
    final isHome = ref.watch(_isHomeProvider);
    final version = ref.watch(_versionProvider);
    final canAutoStart = ref.watch(_canAutoStartProvider);
    ref.watch(_resumeRefreshProvider);
    void up(AppSettings Function(AppSettings s) f) => ref.read(settingsProvider.notifier).update(f);

    final methods = adhan.CalculationMethod.values.where((m) => m.name != 'other').map((m) => m.name).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 32),
          children: [
            const _Header('Settings', big: true),
            // ZONE: the first item. Names come from the timetable file, not from the code.
            _choice<String>(
              context,
              'Zone',
              s.zone,
              {
                for (final r in data.regionList) r.code: r.label,
                if (!data.regions.containsKey(s.zone)) s.zone: '${s.zone} - (not in timetable)',
              },
              (v) => up((x) => x.copyWith(zone: v)),
              autofocus: true,
            ),

            // ---------------------------------------------------------------- General
            const _Header('General'),
            SettingTile(
              title: 'Mosque name',
              value: s.mosqueName.isEmpty ? '(none)' : s.mosqueName,
              onSelect: () async {
                final v = await askText(context, 'Mosque name', s.mosqueName);
                if (v != null) up((x) => x.copyWith(mosqueName: v.trim()));
              },
            ),
            _choice<String>(
              context,
              'Display design',
              s.design,
              {for (final d in kDesigns) d.id: d.name},
              (v) => up((x) => x.copyWith(design: v)),
            ),
            _toggle('12h / 24h clock', s.use24h, '24-hour', '12-hour', (v) => up((x) => x.copyWith(use24h: v))),
            _choice<String>(
              context,
              'Label language',
              s.labelLanguage,
              const {'both': 'English + Arabic', 'en': 'English only', 'ar': 'Arabic only'},
              (v) => up((x) => x.copyWith(labelLanguage: v)),
            ),

            // ------------------------------------------------------------ Prayer times
            const _Header('Prayer times'),
            SettingTile(
              title: 'Timetable coverage',
              value: status.coverage == null
                  ? 'No data for this zone'
                  : 'Timetable: ${formatCoverage(status.coverage!)} (${status.source})',
              valueColor: status.coverage == null ? const Color(0xFFFFB300) : null,
            ),
            if (status.coverage != null && status.daysRemaining < TimetableStatus.warnBelowDays)
              SettingTile(
                title: 'Warning: timetable running out',
                value: status.daysRemaining == 0
                    ? 'Today has no data - import a newer file'
                    : 'Only ${status.daysRemaining} day${status.daysRemaining == 1 ? '' : 's'} left - import a newer file',
                valueColor: const Color(0xFFFFB300),
              ),
            _toggle('When a date is missing', s.fallbackCalculated, 'Calculate (marked CALCULATED)', 'Show "missing" banner',
                (v) => up((x) => x.copyWith(fallbackCalculated: v))),
            _choice<String>(
              context,
              'Building height',
              s.buildingFloors,
              {'': 'None', for (final a in data.adjustments) a.floors: a.label},
              (v) => up((x) => x.copyWith(buildingFloors: v)),
            ),
            _toggle('Show Sahr end time', s.showSahr, 'On (${data.sahrEndMinutesBeforeFajr} min before Fajr)', 'Off',
                (v) => up((x) => x.copyWith(showSahr: v))),
            SettingTile(
              title: 'Import timetable (JSON file / USB)',
              value: 'Press OK',
              onSelect: () => _importFile(context, ref),
            ),
            SettingTile(
              title: 'Import timetable (download from URL)',
              value: 'Press OK',
              onSelect: () => _importUrl(context, ref),
            ),
            SettingTile(
              title: 'Reset to bundled timetable',
              value: 'Press OK',
              onSelect: () async {
                if (await confirm(context, 'Discard imported timetable data?')) {
                  await ref.read(timetableProvider.notifier).resetToBundled();
                  if (context.mounted) await _info(context, 'Timetable reset', 'Using the timetable bundled with the app.');
                }
              },
            ),

            const _Header('Calculation (used only when a date is missing)'),
            _choice<String>(
              context,
              'Calculation method',
              s.method,
              {for (final m in methods) m: m.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ')},
              (v) => up((x) => x.copyWith(method: v)),
            ),
            _choice<String>(context, 'Asr (madhab)', s.madhab, const {'shafi': "Shafi'i", 'hanafi': 'Hanafi'},
                (v) => up((x) => x.copyWith(madhab: v))),
            _choice<String>(
              context,
              'High-latitude rule',
              s.highLatitudeRule,
              const {
                'none': 'None',
                'middle_of_the_night': 'Middle of the night',
                'seventh_of_the_night': 'Seventh of the night',
                'twilight_angle': 'Twilight angle',
              },
              (v) => up((x) => x.copyWith(highLatitudeRule: v)),
            ),

            // ------------------------------------------------------------ Adjustments
            const _Header('Azan adjustment (minutes, + later / - earlier)'),
            for (final k in _prayerKeys)
              _number('${_title(k)} azan', s.adjustments[k] ?? 0, -30, 30, 1,
                  (v) => up((x) => x.copyWith(adjustments: {...x.adjustments, k: v})), suffix: ' min'),

            // ---------------------------------------------------------------- Iqamah
            const _Header('Iqamah'),
            for (final k in iqamahKeys) ...[
              _choice<bool>(
                context,
                '${_title(k)} iqamah',
                s.iqamahRule(k).fixed,
                const {false: 'Minutes after azan', true: 'Fixed time'},
                (v) => up((x) => x.copyWith(iqamah: {...x.iqamah, k: x.iqamahRule(k).copyWith(fixed: v)})),
              ),
              if (s.iqamahRule(k).fixed)
                SettingTile(
                  title: '   ${_title(k)} fixed time (24h HH:mm)',
                  value: s.iqamahRule(k).time,
                  onSelect: () async {
                    final v = await askText(context, '${_title(k)} iqamah time, e.g. 05:10 or 13:30', s.iqamahRule(k).time);
                    if (v != null && PrayerService.parseHm(v) != null) {
                      up((x) => x.copyWith(iqamah: {...x.iqamah, k: x.iqamahRule(k).copyWith(time: v.trim())}));
                    }
                  },
                )
              else
                _number('   ${_title(k)} minutes after azan', s.iqamahRule(k).minutes, 1, 90, 1,
                    (v) => up((x) => x.copyWith(iqamah: {...x.iqamah, k: x.iqamahRule(k).copyWith(minutes: v)})),
                    suffix: ' min'),
            ],

            // ----------------------------------------------------------------- Hijri
            const _Header('Hijri date'),
            _number('Day adjustment', s.hijriAdjust, -3, 3, 1, (v) => up((x) => x.copyWith(hijriAdjust: v)), suffix: ' day(s)'),
            _toggle('Roll over at Maghrib', s.hijriRolloverAtMaghrib, 'At Maghrib', 'At midnight',
                (v) => up((x) => x.copyWith(hijriRolloverAtMaghrib: v))),
            _toggle('Month names', s.arabicMonthNames, 'Arabic', 'English', (v) => up((x) => x.copyWith(arabicMonthNames: v))),

            // --------------------------------------------------------------- Display
            const _Header('Colours'),
            _color(context, 'Clock', s.clockColor, (v) => up((x) => x.copyWith(clockColor: v))),
            _color(context, 'Hijri date', s.hijriColor, (v) => up((x) => x.copyWith(hijriColor: v))),
            _color(context, 'Gregorian date', s.gregorianColor, (v) => up((x) => x.copyWith(gregorianColor: v))),
            _color(context, 'Labels', s.labelColor, (v) => up((x) => x.copyWith(labelColor: v))),
            _color(context, 'Azan time', s.azanColor, (v) => up((x) => x.copyWith(azanColor: v))),
            _color(context, 'Iqamah time', s.iqamahColor, (v) => up((x) => x.copyWith(iqamahColor: v))),

            const _Header('Rotation'),
            _toggle('Cycle through all prayers', s.rotate, 'On', 'Off (show next prayer)', (v) => up((x) => x.copyWith(rotate: v))),
            _number('Seconds per prayer', s.rotateSeconds, 3, 60, 1, (v) => up((x) => x.copyWith(rotateSeconds: v)), suffix: ' s'),

            // ---------------------------------------------------------------- Alerts
            const _Header('Alerts'),
            _toggle('Chime at azan', s.chime, 'On', 'Off', (v) => up((x) => x.copyWith(chime: v))),
            SettingTile(
              title: '"Silence phones" message',
              value: s.silenceMessage,
              onSelect: () async {
                final v = await askText(context, 'Message shown at iqamah', s.silenceMessage);
                if (v != null && v.trim().isNotEmpty) up((x) => x.copyWith(silenceMessage: v.trim()));
              },
            ),
            _number('Message duration (0 = off)', s.silenceMinutes, 0, 30, 1, (v) => up((x) => x.copyWith(silenceMinutes: v)),
                suffix: ' min'),

            // -------------------------------------------------------------- Security
            // ------------------------------------------------------------- Start-up
            const _Header('Start-up (open automatically when the TV turns on)'),
            SettingTile(
              title: 'Auto-start after power-on',
              value: canAutoStart.when(
                data: (yes) => yes ? 'Allowed' : 'Not allowed - press OK to allow',
                loading: () => '...',
                error: (_, _) => 'Unknown',
              ),
              valueColor: canAutoStart.value == false ? const Color(0xFFFFB300) : null,
              onSelect: () async {
                if (canAutoStart.value == true) {
                  await _info(context, 'Allowed', 'SalahLK opens by itself when the TV turns on.');
                } else if (!await SystemService.openAutoStartPermission() && context.mounted) {
                  await _info(
                    context,
                    'Allow it from the TV',
                    'Open Android TV settings > Apps > Special app access > Display over other apps > SalahLK > Allow.\n\n'
                        'Or run this from a computer:\n'
                        'adb shell appops set lk.salah.clock SYSTEM_ALERT_WINDOW allow',
                  );
                }
              },
            ),
            SettingTile(
              title: 'Default home app',
              value: isHome.when(
                data: (yes) => yes ? 'Yes - starts when the TV turns on' : 'No',
                loading: () => '...',
                error: (_, _) => 'Unknown',
              ),
              valueColor: isHome.value == false ? const Color(0xFFFFB300) : null,
              onSelect: () => ref.invalidate(_isHomeProvider),
            ),
            SettingTile(
              title: 'Make SalahLK the default home app',
              value: 'Press OK',
              onSelect: () => _makeDefaultHome(context, ref),
            ),
            SettingTile(
              title: 'Open Android TV settings',
              value: 'Press OK',
              onSelect: () async {
                if (!await SystemService.openAndroidSettings() && context.mounted) {
                  await _info(context, 'Not available', 'This TV does not allow opening its settings from here. Press Home on the remote.');
                }
              },
            ),

            // ------------------------------------------------------------------ Clock
            const _Header('Clock (for TVs without internet time sync)'),
            SettingTile(
              title: 'Set date & time',
              value: 'Press OK',
              onSelect: () async {
                final now = ref.read(nowProvider);
                final v = await askText(
                  context,
                  'Type the correct date & time, then press OK at that exact minute\n(yyyy-MM-dd HH:mm)',
                  formatDateTimeInput(now),
                );
                if (v == null || !context.mounted) return;
                final t = parseDateTimeInput(v);
                if (t == null) {
                  await _info(context, 'Not a valid date & time', 'Use the form 2026-10-03 20:15');
                } else {
                  setClockTo(ref, t);
                }
              },
            ),
            SettingTile(
              title: 'Fine adjust (1 second per press)',
              value: formatOffset(s.clockOffsetSeconds),
              hint: '‹  ›',
              onLeft: () => up((x) => x.copyWith(clockOffsetSeconds: x.clockOffsetSeconds - 1)),
              onRight: () => up((x) => x.copyWith(clockOffsetSeconds: x.clockOffsetSeconds + 1)),
            ),
            SettingTile(
              title: 'Reset clock correction',
              value: 'Use the TV clock as it is',
              onSelect: () => up((x) => x.copyWith(clockOffsetSeconds: 0)),
            ),

            const _Header('Security'),
            _toggle('Require PIN for settings', s.pinEnabled, 'On', 'Off', (v) => up((x) => x.copyWith(pinEnabled: v))),
            SettingTile(
              title: 'PIN code',
              value: '••••',
              onSelect: () async {
                final v = await askText(context, 'New 4-digit PIN', '', numeric: true);
                if (v != null && RegExp(r'^\d{4}$').hasMatch(v.trim())) up((x) => x.copyWith(pin: v.trim()));
              },
            ),

            const _Header('Reset'),
            SettingTile(
              title: 'Reset all settings to defaults',
              value: 'Press OK',
              onSelect: () async {
                if (await confirm(context, 'Reset all settings?')) {
                  ref.read(settingsProvider.notifier).replace(const AppSettings());
                }
              },
            ),
            SettingTile(
              title: 'Close settings',
              value: 'Press OK (or Back)',
              onSelect: () => Navigator.of(context).pop(),
            ),

            // ----------------------------------------------------------------- About
            const _Header('About'),
            const SettingTile(title: 'App', value: 'SalahLK'),
            const SettingTile(title: 'Tagline', value: 'Mosque Prayer Times for Sri Lanka'),
            SettingTile(title: 'Version', value: version.value ?? '...'),
            const SettingTile(title: 'Prayer times', value: 'ACJU (All Ceylon Jamiyyathul Ulama)'),
            SettingTile(
              title: 'Timetable coverage',
              value: status.coverage == null ? 'No data for this zone' : formatCoverage(status.coverage!),
            ),
            const SettingTile(title: 'Developed by', value: 'IT Starter (Pvt) Ltd'),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ row builders

  Widget _toggle(String title, bool v, String onLabel, String offLabel, ValueChanged<bool> set) => SettingTile(
        title: title,
        value: v ? onLabel : offLabel,
        onSelect: () => set(!v),
        onLeft: () => set(!v),
        onRight: () => set(!v),
      );

  Widget _number(String title, int v, int min, int max, int step, ValueChanged<int> set, {String suffix = ''}) =>
      SettingTile(
        title: title,
        value: '${v > 0 && min < 0 ? '+' : ''}$v$suffix',
        onLeft: () => set((v - step).clamp(min, max)),
        onRight: () => set((v + step).clamp(min, max)),
        onSelect: () => set(v + step > max ? min : v + step),
        hint: '‹  ›',
      );

  Widget _choice<T>(BuildContext context, String title, T current, Map<T, String> options, ValueChanged<T> set,
      {bool autofocus = false}) {
    final keys = options.keys.toList();
    final i = keys.indexOf(current).clamp(0, keys.length - 1);
    return SettingTile(
      title: title,
      autofocus: autofocus,
      value: options[keys[i]] ?? '',
      hint: '‹  ›',
      onLeft: () => set(keys[(i - 1 + keys.length) % keys.length]),
      onRight: () => set(keys[(i + 1) % keys.length]),
      onSelect: () async {
        final picked = await showDialog<T>(
          context: context,
          builder: (_) => SimpleDialog(
            backgroundColor: const Color(0xFF16161F),
            title: Text(title),
            children: [
              for (final k in keys)
                ListTile(
                  autofocus: k == keys[i],
                  selected: k == keys[i],
                  selectedColor: _gold,
                  focusColor: _gold.withValues(alpha: 0.25),
                  onTap: () => Navigator.of(context).pop(k),
                  title: Text(options[k] ?? '', style: const TextStyle(fontSize: 22)),
                ),
            ],
          ),
        );
        if (picked != null) set(picked);
      },
    );
  }

  Widget _color(BuildContext context, String title, int current, ValueChanged<int> set) {
    final names = _palette.keys.toList();
    final i = _palette.values.toList().indexOf(current);
    final idx = i < 0 ? 0 : i;
    return SettingTile(
      title: '$title colour',
      value: names[idx],
      hint: '‹  ›',
      swatch: Color(current),
      onLeft: () => set(_palette[names[(idx - 1 + names.length) % names.length]]!),
      onRight: () => set(_palette[names[(idx + 1) % names.length]]!),
      onSelect: () => set(_palette[names[(idx + 1) % names.length]]!),
    );
  }

  Future<void> _makeDefaultHome(BuildContext context, WidgetRef ref) async {
    final r = await SystemService.requestHomeRole();
    if (!context.mounted) return;
    if (r == 'already') {
      await _info(context, 'Already set', 'SalahLK is the default home app. It opens by itself when the TV turns on.');
    } else if (r == 'requested') {
      // The system shows its own confirmation; re-check the status when it is done.
      await Future<void>.delayed(const Duration(seconds: 2));
      ref.invalidate(_isHomeProvider);
    } else if (!await SystemService.openHomeSettings() && context.mounted) {
      await _info(
        context,
        'Choose it from the TV',
        'This TV has no direct way for the app to do this.\n\n'
            '1. Press the Home button on the remote.\n'
            '2. If the TV asks which home app to use, choose SalahLK and "Always".\n\n'
            'Otherwise open Android TV settings > Apps > Default apps > Home app, or run this from a computer:\n'
            'adb shell cmd package set-home-activity lk.salah.clock/.MainActivity',
      );
    }
  }

  Future<void> _importFile(BuildContext context, WidgetRef ref) async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      if (files.isEmpty) return;
      final path = files.first.path;
      if (path == null) throw const FormatException('Could not read the selected file.');
      final text = await File(path).readAsString();
      if (context.mounted) await _apply(context, ref, text);
    } on FormatException catch (e) {
      if (context.mounted) await _info(context, 'Import failed', e.message);
    } catch (e) {
      if (context.mounted) await _info(context, 'Import failed', '$e');
    }
  }

  Future<void> _importUrl(BuildContext context, WidgetRef ref) async {
    final url = await askText(context, 'Timetable address (URL)', 'https://');
    if (url == null || url.trim().isEmpty || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      messenger.showSnackBar(const SnackBar(content: Text('Downloading...'), duration: Duration(seconds: 20)));
      final text = await downloadTimetable(Uri.parse(url.trim()));
      messenger.hideCurrentSnackBar();
      if (context.mounted) await _apply(context, ref, text);
    } on FormatException catch (e) {
      messenger.hideCurrentSnackBar();
      if (context.mounted) await _info(context, 'Download failed', e.message);
    } catch (e) {
      messenger.hideCurrentSnackBar();
      if (context.mounted) await _info(context, 'Download failed', 'Could not download the file.\n$e');
    }
  }

  /// Validates and merges [text]; a rejected file changes nothing.
  Future<void> _apply(BuildContext context, WidgetRef ref, String text) async {
    try {
      final result = await ref.read(timetableProvider.notifier).importText(text);
      if (context.mounted) await _info(context, 'Timetable imported', result.summary);
    } on TimetableFormatException catch (e) {
      if (context.mounted) {
        await _info(context, 'File rejected - nothing was changed', e.message);
      }
    }
  }
}

Future<void> _info(BuildContext context, String title, String message) => showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16161F),
        title: Text(title, style: const TextStyle(fontSize: 24)),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(child: Text(message, style: const TextStyle(fontSize: 20))),
        ),
        actions: [FilledButton(autofocus: true, onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
      ),
    );

// ------------------------------------------------------------------------ dialogs

Future<String?> askText(BuildContext context, String title, String initial, {bool numeric = false}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF16161F),
      title: Text(title, style: const TextStyle(fontSize: 22)),
      content: SizedBox(
        width: 480,
        child: TextField(
          controller: c,
          autofocus: true,
          style: const TextStyle(fontSize: 26),
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(decimal: true, signed: true)
              : TextInputType.text,
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(c.text), child: const Text('OK')),
      ],
    ),
  );
}

Future<bool> confirm(BuildContext context, String question) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF16161F),
      title: Text(question),
      actions: [
        TextButton(autofocus: true, onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Yes')),
      ],
    ),
  );
  return r ?? false;
}

// ------------------------------------------------------------------------- widgets

class _Header extends StatelessWidget {
  final String text;
  final bool big;
  const _Header(this.text, {this.big = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: big ? 0 : 36, bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: big ? 40 : 24,
            color: big ? Colors.white : _gold,
          ),
        ),
      );
}

/// One focusable settings row with a clearly visible focus ring.
class SettingTile extends StatefulWidget {
  final String title;
  final String value;
  final String? hint;
  final Color? valueColor;
  final Color? swatch;
  final bool autofocus;
  final VoidCallback? onSelect;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;

  const SettingTile({
    super.key,
    required this.title,
    required this.value,
    this.hint,
    this.valueColor,
    this.swatch,
    this.autofocus = false,
    this.onSelect,
    this.onLeft,
    this.onRight,
  });

  @override
  State<SettingTile> createState() => _SettingTileState();
}

class _SettingTileState extends State<SettingTile> {
  bool _focused = false;

  static final _activate = {
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.gameButtonA,
  };

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) {
        setState(() => _focused = f);
        if (f) Scrollable.ensureVisible(context, alignment: 0.4, duration: const Duration(milliseconds: 120));
      },
      onKeyEvent: (node, e) {
        if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
        final k = e.logicalKey;
        if (e is KeyDownEvent && _activate.contains(k) && widget.onSelect != null) {
          widget.onSelect!();
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowLeft && widget.onLeft != null) {
          widget.onLeft!();
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowRight && widget.onRight != null) {
          widget.onRight!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: _focused ? const Color(0xFF26263A) : const Color(0xFF14141C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _focused ? _gold : Colors.transparent, width: 3),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(widget.title, style: const TextStyle(fontSize: 24, color: Colors.white)),
              ),
              if (widget.swatch != null)
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: widget.swatch,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white54),
                  ),
                ),
              Expanded(
                flex: 6,
                child: Text(
                  _focused && widget.hint != null ? '${widget.hint}  ${widget.value}' : widget.value,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 24, color: widget.valueColor ?? (_focused ? _gold : Colors.white70)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
