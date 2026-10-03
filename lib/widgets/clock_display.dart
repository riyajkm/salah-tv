import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../utils/format.dart';
import 'seven_segment_text.dart';

/// The big live clock. This is the only widget that rebuilds every second
/// (together with the small countdown in PrayerPanel).
///
/// * [compact] shows hh:mm large with the seconds and AM/PM beside it, so it fits narrow areas.
/// * [color] overrides the clock colour from Settings (for themed designs).
class ClockDisplay extends ConsumerWidget {
  final bool compact;
  final Color? color;
  const ClockDisplay({super.key, this.compact = false, this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    final use24h = ref.watch(settingsProvider.select((s) => s.use24h));
    final c = color ?? Color(ref.watch(settingsProvider.select((s) => s.clockColor)));
    final (hms, mer) = formatClock(now, use24h: use24h);

    TextStyle merStyle(double size) =>
        TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: size, color: c);

    if (compact) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SevenSegmentText(hms.substring(0, 5), color: c, fontSize: 300),
            const SizedBox(width: 24),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SevenSegmentText(
                    hms.substring(6),
                    color: Color.lerp(c, const Color(0xFF0A0A0F), 0.25)!,
                    fontSize: 130,
                    glow: false,
                  ),
                  if (mer.isNotEmpty) Text(mer, style: merStyle(64)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SevenSegmentText(hms, color: c, fontSize: 300),
          if (mer.isNotEmpty) ...[
            const SizedBox(width: 24),
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(mer, style: merStyle(90))),
          ],
        ],
      ),
    );
  }
}
