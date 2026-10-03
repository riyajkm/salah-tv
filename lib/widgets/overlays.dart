import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/prayer.dart';
import '../providers.dart';

/// Earliest year a correctly-set device clock can show; older means "no network time yet".
const kMinSaneYear = 2025;

/// Full-screen "Please silence your phones" message, shown for the configured minutes after iqamah.
class SilenceOverlay extends ConsumerWidget {
  const SilenceOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(displayStateProvider.select((d) => d.silenceFor != null));
    final s = ref.watch(settingsProvider);
    if (!active) return const SizedBox.shrink();
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xFF0A0A0F),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_off_rounded, size: 260, color: Color(s.labelColor)),
                  const SizedBox(height: 32),
                  Text(
                    s.silenceMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 150,
                      color: Color(s.labelColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Red banner when the device clock is obviously wrong (e.g. 1970 / pre-2025).
class TimeWarning extends ConsumerWidget {
  const TimeWarning({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(nowProvider.select((n) => n.year));
    final behind = ref.watch(clockBehindProvider);
    if (year >= kMinSaneYear && !behind) return const SizedBox.shrink();
    final message = behind && year >= kMinSaneYear
        ? 'The TV clock was reset (it is behind a time already seen). Open Settings > Clock '
            'and choose "Set date & time", or enable "Automatic date & time" on the TV.'
        : 'Device date/time looks wrong. Open Settings > Clock and choose "Set date & time", '
            'or enable "Automatic date & time" on the TV and connect to the internet once.';
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: const Color(0xFFB00020),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 22, color: Colors.white),
        ),
      ),
    );
  }
}

/// Plays the chime when the clock crosses an azan time. Renders nothing.
class ChimeListener extends ConsumerStatefulWidget {
  final Widget child;
  const ChimeListener({super.key, required this.child});

  @override
  ConsumerState<ChimeListener> createState() => _ChimeListenerState();
}

class _ChimeListenerState extends ConsumerState<ChimeListener> {
  final AudioPlayer _player = AudioPlayer();

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DateTime>(nowProvider, (prev, now) {
      if (prev == null || !ref.read(settingsProvider).chime) return;
      // Ignore clock jumps (manual time change, NTP sync): only react to ~1 s steps.
      if (now.difference(prev).abs() > const Duration(seconds: 5)) return;
      for (final day in ref.read(schedulesProvider)) {
        for (final e in day.entries) {
          if (e.id != PrayerId.sunrise && e.azan.isAfter(prev) && !e.azan.isAfter(now)) {
            _player.play(AssetSource('audio/chime.wav'));
            return;
          }
        }
      }
    });
    return widget.child;
  }
}

/// Small labels in the bottom-left corner of the main screen:
/// "CALCULATED" when the shown times did not come from the ACJU timetable, and a reminder
/// when fewer than [TimetableStatus.warnBelowDays] days of timetable data remain.
class StatusBadges extends ConsumerWidget {
  const StatusBadges({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calculated = ref.watch(displayStateProvider.select((d) => d.next?.calculated ?? false));
    final status = ref.watch(timetableStatusProvider);
    if (!calculated && !status.runningLow) return const SizedBox.shrink();

    final size = MediaQuery.sizeOf(context).height * 0.026;
    TextStyle style(Color c) =>
        TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: size, color: c);

    return Positioned.fill(
      child: IgnorePointer(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: size, vertical: size * 0.4),
          // Bottom-left is the one corner the optional Sahr line never uses.
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (calculated) Text('CALCULATED', style: style(const Color(0xFFFFB300))),
                if (status.runningLow)
                  Text(
                    'Timetable ends in ${status.daysRemaining} day${status.daysRemaining == 1 ? '' : 's'}\nplease update',
                    style: style(const Color(0xFFFFB300)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
