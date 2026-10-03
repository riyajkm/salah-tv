import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../models/prayer.dart';
import '../providers.dart';
import '../utils/format.dart';
import 'clock_display.dart';
import 'date_lines.dart';
import 'design_parts.dart';
import 'prayer_panel.dart';

/// The clock, dates and countdown inside a circular progress ring. The ring fills as the
/// next azan (or, between azan and iqamah, the iqamah) gets closer.
class RingClock extends ConsumerWidget {
  const RingClock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(displayStateProvider);
    final s = ref.watch(settingsProvider);
    final progress = ref.watch(progressProvider);
    final sahr = ref.watch(sahrEndProvider);
    final between = st.phase == Phase.betweenAzanAndIqamah;
    final color = between ? Color(s.iqamahColor) : Color(s.labelColor);

    return LayoutBuilder(
      builder: (context, c) {
        final d = math.min(c.maxWidth, c.maxHeight);
        return Center(
          child: SizedBox(
            width: d,
            height: d,
            child: CustomPaint(
              painter: _RingPainter(progress: st.next == null ? 0 : progress, color: color),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: d * 0.17, vertical: d * 0.2),
                child: Column(
                  children: [
                    const Expanded(flex: 34, child: ClockDisplay(compact: true)),
                    const Expanded(flex: 22, child: DateLines()),
                    Expanded(
                      flex: 16,
                      child: st.next == null
                          ? const SizedBox.shrink()
                          : CountdownRow(state: st, settings: s, sahr: sahr),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.032;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width / 2 - stroke,
    );

    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: 0.09),
    );
    if (progress <= 0) return;

    final sweep = math.pi * 2 * progress.clamp(0.0, 1.0);
    // Soft glow under the arc, then the arc itself.
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 1.9
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 0.8),
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color;
}

/// One side of the Ring design: [from, to) of the day's prayers as stacked cards.
class RingSideCards extends ConsumerWidget {
  final int from;
  final int to;
  const RingSideCards({super.key, required this.from, required this.to});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    final st = ref.watch(displayStateProvider);
    final s = ref.watch(settingsProvider);
    final day = ref.watch(shownDayProvider);
    final next = st.next;
    if (next == null || day == null) return const SizedBox.shrink();
    final between = st.phase == Phase.betweenAzanAndIqamah;

    return Column(
      children: [
        for (final e in day.entries.sublist(from, to))
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: _SideCard(
                entry: e,
                settings: s,
                isNext: e.id == next.id && sameDate(e.azan, next.azan),
                pulsing: between,
                passed: !e.end.isAfter(now),
              ),
            ),
          ),
      ],
    );
  }
}

class _SideCard extends StatelessWidget {
  final PrayerEntry entry;
  final AppSettings settings;
  final bool isNext;
  final bool pulsing;
  final bool passed;

  const _SideCard({
    required this.entry,
    required this.settings,
    required this.isNext,
    required this.pulsing,
    required this.passed,
  });

  @override
  Widget build(BuildContext context) {
    final s = settings;
    final label = Color(s.labelColor);
    final hasIqamah = entry.iqamah != null;

    Widget time(String en, String ar, String text, int color) => Column(
          children: [
            Expanded(flex: 24, child: CaptionText(language: s.labelLanguage, en: en, ar: ar, size: 30)),
            Expanded(flex: 76, child: TimeBlock(text, color: Color(color))),
          ],
        );

    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isNext ? label.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.045),
        border: Border.all(
          color: isNext ? label : Colors.white.withValues(alpha: 0.12),
          width: isNext ? 4 : 2,
        ),
      ),
      child: Column(
        children: [
          Expanded(
            flex: 34,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: PrayerNameText(
                entry: entry,
                language: s.labelLanguage,
                inline: true,
                enSize: 60,
                arSize: 56,
                enColor: isNext ? label : Colors.white,
                arColor: label,
              ),
            ),
          ),
          Expanded(
            flex: 66,
            child: Row(
              children: [
                Expanded(child: time('AZAN', 'أذان', formatPrayerTime(entry.azan, use24h: s.use24h), s.azanColor)),
                if (hasIqamah) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: time('IQAMATH', 'الإقامة', formatPrayerTime(entry.iqamah!, use24h: s.use24h), s.iqamahColor),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Opacity(
      opacity: passed && !isNext ? 0.4 : 1,
      child: PulseGlow(
        active: isNext && pulsing,
        color: Color(s.iqamahColor),
        margin: EdgeInsets.zero,
        radius: 24,
        child: card,
      ),
    );
  }
}
