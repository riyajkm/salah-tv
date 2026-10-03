import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../models/prayer.dart';
import '../providers.dart';
import '../utils/format.dart';
import 'design_parts.dart';
import 'prayer_panel.dart';

/// Palette of the Emerald design (it ignores the colour settings so the theme stays coherent).
class Emerald {
  static const gold = Color(0xFFE7C873);
  static const cream = Color(0xFFFFF1C9);
  static const mint = Color(0xFFA7F3D0);
  static const deep = Color(0xFF041A14);
  static const green = Color(0xFF0B3D2E);
}

/// Prayers as mihrab-style arches (rounded top). The next one glows gold.
class ArchRow extends ConsumerWidget {
  const ArchRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    final st = ref.watch(displayStateProvider);
    final s = ref.watch(settingsProvider);
    final day = ref.watch(shownDayProvider);
    final next = st.next;
    if (next == null || day == null) {
      return MissingBanner(date: st.missingDate!, labelLanguage: s.labelLanguage);
    }
    final between = st.phase == Phase.betweenAzanAndIqamah;

    return Row(
      children: [
        for (final e in day.entries)
          Expanded(
            flex: e.id == PrayerId.sunrise ? 2 : 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: _Arch(
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

class _Arch extends StatelessWidget {
  final PrayerEntry entry;
  final AppSettings settings;
  final bool isNext;
  final bool pulsing;
  final bool passed;

  const _Arch({
    required this.entry,
    required this.settings,
    required this.isNext,
    required this.pulsing,
    required this.passed,
  });

  @override
  Widget build(BuildContext context) {
    final s = settings;
    final hasIqamah = entry.iqamah != null;

    return LayoutBuilder(
      builder: (context, c) {
        // A half-circle on top turns the card into an arch.
        final radius = BorderRadius.vertical(top: Radius.circular(c.maxWidth / 2), bottom: const Radius.circular(26));

        final content = Column(
          children: [
            SizedBox(height: c.maxWidth * 0.10), // keep text clear of the curve
            Expanded(
              flex: 30,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: PrayerNameText(
                  entry: entry,
                  language: s.labelLanguage,
                  enSize: 44,
                  arSize: 78,
                  enColor: Emerald.cream,
                  arColor: Emerald.gold,
                ),
              ),
            ),
            Expanded(
              flex: 8,
              child: entry.id == PrayerId.sunrise
                  ? const SizedBox.shrink()
                  : CaptionText(language: s.labelLanguage, en: 'AZAN', ar: 'أذان', size: 30, color: Emerald.gold),
            ),
            Expanded(
              flex: 22,
              child: TimeBlock(formatPrayerTime(entry.azan, use24h: s.use24h), color: Emerald.cream),
            ),
            Expanded(
              flex: 8,
              child: hasIqamah
                  ? CaptionText(language: s.labelLanguage, en: 'IQAMATH', ar: 'الإقامة', size: 30, color: Emerald.gold)
                  : const SizedBox.shrink(),
            ),
            Expanded(
              flex: 22,
              child: hasIqamah
                  ? TimeBlock(formatPrayerTime(entry.iqamah!, use24h: s.use24h), color: Emerald.mint)
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
          ],
        );

        final arch = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isNext
                  ? [Emerald.gold.withValues(alpha: 0.30), Emerald.green.withValues(alpha: 0.55)]
                  : [Emerald.green.withValues(alpha: 0.75), Emerald.deep.withValues(alpha: 0.85)],
            ),
            border: Border.all(
              color: isNext ? Emerald.gold : Emerald.gold.withValues(alpha: 0.45),
              width: isNext ? 4 : 2,
            ),
            boxShadow: isNext ? [BoxShadow(color: Emerald.gold.withValues(alpha: 0.35), blurRadius: 36)] : null,
          ),
          child: content,
        );

        return Opacity(
          opacity: passed && !isNext ? 0.45 : 1,
          child: PulseGlow(
            active: isNext && pulsing,
            color: Emerald.mint,
            margin: EdgeInsets.zero,
            radius: c.maxWidth / 2,
            child: arch,
          ),
        );
      },
    );
  }
}
