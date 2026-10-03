import 'package:flutter/material.dart';

/// Text in the DSEG7 7-segment font, with faint "unlit" segments behind the digits
/// (like a real LED display) and an optional soft glow.
///
/// Give it a large [fontSize] and wrap it in a [FittedBox]; the parent scales it down.
class SevenSegmentText extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;
  final bool glow;
  final bool ghost;

  const SevenSegmentText(
    this.text, {
    super.key,
    required this.color,
    this.fontSize = 200,
    this.glow = true,
    this.ghost = false,
  });

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: 'DSEG7',
      fontWeight: FontWeight.w700,
      fontSize: fontSize,
      height: 1.0,
      color: color,
      shadows: glow
          ? [Shadow(color: color.withValues(alpha: 0.35), blurRadius: fontSize * 0.12)]
          : null,
    );
    final live = Text(text, style: base, maxLines: 1, softWrap: false);
    if (!ghost) return live;
    return Stack(
      children: [
        Text(
          text.replaceAll(RegExp(r'[0-9]'), '8'),
          style: base.copyWith(color: color.withValues(alpha: 0.07), shadows: null),
          maxLines: 1,
          softWrap: false,
        ),
        live,
      ],
    );
  }
}
