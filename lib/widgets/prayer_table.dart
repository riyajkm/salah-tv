import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../models/prayer.dart';
import '../providers.dart';
import '../utils/format.dart';
import 'design_parts.dart';
import 'prayer_panel.dart';

/// A clean table of the day's prayers: name, azan, iqamah. The next row is framed in gold and
/// pulses between azan and iqamah; finished prayers are dimmed.
class PrayerTable extends ConsumerWidget {
  const PrayerTable({super.key});

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

    return Column(
      children: [
        Expanded(
          flex: 9,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Row(
              children: [
                Expanded(flex: 5, child: _head(s, 'PRAYER', 'الصلاة', Alignment.centerLeft)),
                Expanded(flex: 3, child: _head(s, 'AZAN', 'أذان', Alignment.center)),
                Expanded(flex: 3, child: _head(s, 'IQAMATH', 'الإقامة', Alignment.center)),
              ],
            ),
          ),
        ),
        for (final e in day.entries)
          Expanded(
            flex: 14,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: _Row(
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

  Widget _head(AppSettings s, String en, String ar, Alignment a) => CaptionText(
        language: s.labelLanguage,
        en: en,
        ar: ar,
        size: 34,
        color: Color(s.labelColor).withValues(alpha: 0.9),
        alignment: a,
      );
}

class _Row extends StatelessWidget {
  final PrayerEntry entry;
  final AppSettings settings;
  final bool isNext;
  final bool pulsing;
  final bool passed;

  const _Row({
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

    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isNext ? label.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.045),
        border: Border.all(color: isNext ? label : Colors.transparent, width: 4),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: PrayerNameText(
                entry: entry,
                language: s.labelLanguage,
                inline: true,
                enSize: 64,
                arSize: 60,
                enColor: isNext ? label : Colors.white,
                arColor: label,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TimeBlock(formatPrayerTime(entry.azan, use24h: s.use24h), color: Color(s.azanColor)),
            ),
          ),
          Expanded(
            flex: 3,
            child: hasIqamah
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TimeBlock(formatPrayerTime(entry.iqamah!, use24h: s.use24h), color: Color(s.iqamahColor)),
                  )
                : const Center(child: Text('—', style: TextStyle(color: Colors.white24, fontSize: 56))),
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
        radius: 20,
        child: row,
      ),
    );
  }
}
