import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../utils/format.dart';

/// Hijri (green) and Gregorian (red) date lines. Rebuilds at most once a minute.
/// [hijri] / [gregorian] override the colours from Settings (for themed designs).
class DateLines extends ConsumerWidget {
  final Color? hijri;
  final Color? gregorian;
  const DateLines({super.key, this.hijri, this.gregorian});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minute = ref.watch(minuteProvider);
    final hijriDate = ref.watch(hijriProvider);
    final s = ref.watch(settingsProvider);

    Widget line(String text, Color color, {String font = 'Poppins'}) => Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              maxLines: 1,
              style: TextStyle(
                fontFamily: font,
                fontWeight: FontWeight.w700,
                fontSize: 80,
                color: color,
              ),
            ),
          ),
        );

    return Column(
      children: [
        line(formatHijri(hijriDate, arabic: s.arabicMonthNames), hijri ?? Color(s.hijriColor),
            font: s.arabicMonthNames ? 'Amiri' : 'Poppins'),
        line(formatGregorian(minute), gregorian ?? Color(s.gregorianColor)),
      ],
    );
  }
}
