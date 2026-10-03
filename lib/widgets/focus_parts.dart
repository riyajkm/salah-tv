import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../models/prayer.dart';
import '../providers.dart';
import '../utils/format.dart';
import 'design_parts.dart';
import 'prayer_panel.dart';

/// The "hero" line of the Focus design: the next prayer with its azan and iqamah times and a
/// progress bar for the current countdown. Between azan and iqamah it pulses.
class NextHero extends ConsumerWidget {
  const NextHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(displayStateProvider);
    final s = ref.watch(settingsProvider);
    final progress = ref.watch(progressProvider);
    final next = st.next;
    if (next == null) return MissingBanner(date: st.missingDate!, labelLanguage: s.labelLanguage);

    final between = st.phase == Phase.betweenAzanAndIqamah;
    final label = Color(s.labelColor);
    final barColor = between ? Color(s.iqamahColor) : label;

    return PulseGlow(
      active: between,
      color: Color(s.iqamahColor),
      margin: EdgeInsets.zero,
      radius: 28,
      child: Container(
        padding: const EdgeInsets.fromLTRB(36, 14, 36, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 2),
        ),
        child: Column(
          children: [
            Expanded(
              flex: 80,
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 22,
                          child: CaptionText(
                            language: 'en',
                            en: between ? 'NOW' : 'NEXT PRAYER',
                            ar: '',
                            size: 40,
                            color: Colors.white54,
                            alignment: Alignment.centerLeft,
                          ),
                        ),
                        Expanded(
                          flex: 78,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: PrayerNameText(
                              entry: next,
                              language: s.labelLanguage,
                              inline: true,
                              enSize: 110,
                              arSize: 100,
                              enColor: Colors.white,
                              arColor: label,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(flex: 3, child: _time(s, 'AZAN', 'أذان', formatPrayerTime(next.azan, use24h: s.use24h), s.azanColor)),
                  if (next.iqamah != null)
                    Expanded(
                      flex: 3,
                      child: _time(s, 'IQAMATH', 'الإقامة', formatPrayerTime(next.iqamah!, use24h: s.use24h), s.iqamahColor),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _Bar(progress: progress, color: barColor),
          ],
        ),
      ),
    );
  }

  Widget _time(AppSettings s, String en, String ar, String text, int color) => Column(
        children: [
          Expanded(flex: 22, child: CaptionText(language: s.labelLanguage, en: en, ar: ar, size: 36)),
          Expanded(
            flex: 78,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: TimeBlock(text, color: Color(color), glow: true),
            ),
          ),
        ],
      );
}

class _Bar extends StatelessWidget {
  final double progress;
  final Color color;
  const _Bar({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 14,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Stack(
            children: [
              Container(color: Colors.white.withValues(alpha: 0.10)),
              FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 12)],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

/// A slim row of every prayer with its azan time. The next one is highlighted.
class PrayerStrip extends ConsumerWidget {
  const PrayerStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    final st = ref.watch(displayStateProvider);
    final s = ref.watch(settingsProvider);
    final day = ref.watch(shownDayProvider);
    final next = st.next;
    if (next == null || day == null) return const SizedBox.shrink();
    final label = Color(s.labelColor);

    return Row(
      children: [
        for (final e in day.entries)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Opacity(
                opacity: !e.end.isAfter(now) && e.id != next.id ? 0.4 : 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: e.id == next.id ? label.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
                    border: Border.all(
                      color: e.id == next.id ? label : Colors.white.withValues(alpha: 0.10),
                      width: e.id == next.id ? 3 : 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        flex: 40,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: PrayerNameText(
                            entry: e,
                            language: s.labelLanguage,
                            inline: true,
                            enSize: 44,
                            arSize: 40,
                            enColor: e.id == next.id ? label : Colors.white,
                            arColor: label,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 60,
                        child: TimeBlock(formatPrayerTime(e.azan, use24h: s.use24h), color: Color(s.azanColor), glow: false),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
