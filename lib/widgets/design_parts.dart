import 'package:flutter/material.dart';

import '../models/prayer.dart';
import '../utils/format.dart';
import 'seven_segment_text.dart';

bool sameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// English / Arabic prayer name according to the label-language setting ('both' | 'en' | 'ar').
/// Stacked by default, side by side with [inline].
class PrayerNameText extends StatelessWidget {
  final PrayerEntry entry;
  final String language;
  final double enSize;
  final double arSize;
  final Color enColor;
  final Color arColor;
  final bool inline;

  const PrayerNameText({
    super.key,
    required this.entry,
    required this.language,
    required this.enColor,
    required this.arColor,
    this.enSize = 64,
    this.arSize = 56,
    this.inline = false,
  });

  @override
  Widget build(BuildContext context) {
    final (en, ar) = prayerNames(entry);
    final parts = <Widget>[
      if (language != 'ar')
        Text(en, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: enSize, color: enColor)),
      if (language != 'en')
        Text(ar, style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.w700, fontSize: arSize, color: arColor)),
    ];
    if (inline) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < parts.length; i++) ...[if (i > 0) SizedBox(width: enSize * 0.45), parts[i]],
        ],
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: parts);
  }
}

/// Small caption such as "AZAN · أذان", in the label language.
class CaptionText extends StatelessWidget {
  final String language;
  final String en;
  final String ar;
  final double size;
  final Color color;
  final Alignment alignment;

  const CaptionText({
    super.key,
    required this.language,
    required this.en,
    required this.ar,
    this.size = 34,
    this.color = Colors.white60,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text(
          language == 'ar' ? ar : (language == 'en' ? en : '$en · $ar'),
          style: TextStyle(
            fontFamily: language == 'ar' ? 'Amiri' : 'Poppins',
            fontWeight: FontWeight.w500,
            fontSize: size,
            color: color,
          ),
        ),
      );
}

/// A 7-segment time that scales down to fit whatever space it is given.
class TimeBlock extends StatelessWidget {
  final String text;
  final Color color;
  final Alignment alignment;
  final bool glow;

  const TimeBlock(this.text, {super.key, required this.color, this.alignment = Alignment.center, this.glow = false});

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: SevenSegmentText(text, color: color, fontSize: 160, glow: glow),
      );
}
