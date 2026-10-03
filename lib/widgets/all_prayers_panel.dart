import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../models/prayer.dart';
import '../providers.dart';
import '../utils/format.dart';
import 'prayer_panel.dart';
import 'seven_segment_text.dart';

bool _sameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Second display design: every prayer of the day side by side, the next one highlighted
/// (and pulsing between azan and iqamah), with the countdown underneath.
class AllPrayersPanel extends ConsumerWidget {
  const AllPrayersPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    final st = ref.watch(displayStateProvider);
    final s = ref.watch(settingsProvider);
    final days = ref.watch(schedulesProvider);
    final sahr = ref.watch(sahrEndProvider);

    final next = st.next;
    if (next == null) {
      return MissingBanner(date: st.missingDate!, labelLanguage: s.labelLanguage);
    }

    // After Isha the next prayer is tomorrow's Fajr, so show tomorrow's times then.
    final today = days[1];
    final day = _sameDate(next.azan, today.date) ? today : days[2];
    final between = st.phase == Phase.betweenAzanAndIqamah;

    return Column(
      children: [
        Expanded(
          flex: 86,
          child: Row(
            children: [
              for (final e in day.entries)
                Expanded(
                  // Sunrise has no iqamah, so its card is narrower.
                  flex: e.id == PrayerId.sunrise ? 2 : 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _PrayerCard(
                      entry: e,
                      isNext: e.id == next.id && _sameDate(e.azan, next.azan),
                      pulsing: between,
                      passed: !e.end.isAfter(now),
                      settings: s,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(flex: 14, child: CountdownRow(state: st, settings: s, sahr: sahr)),
      ],
    );
  }
}

class _PrayerCard extends StatelessWidget {
  final PrayerEntry entry;
  final bool isNext;
  final bool pulsing;
  final bool passed;
  final AppSettings settings;

  const _PrayerCard({
    required this.entry,
    required this.isNext,
    required this.pulsing,
    required this.passed,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final s = settings;
    final labelColor = Color(s.labelColor);
    final (en, ar) = prayerNames(entry);
    final hasIqamah = entry.iqamah != null;
    final showEn = s.labelLanguage != 'ar';
    final showAr = s.labelLanguage != 'en';

    Widget caption(String en, String ar) => FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            s.labelLanguage == 'ar' ? ar : (s.labelLanguage == 'en' ? en : '$en · $ar'),
            style: TextStyle(
              fontFamily: s.labelLanguage == 'ar' ? 'Amiri' : 'Poppins',
              fontWeight: FontWeight.w500,
              fontSize: 34,
              color: Colors.white60,
            ),
          ),
        );

    final content = Column(
      children: [
        Expanded(
          flex: 24,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showEn)
                  Text(en,
                      style: TextStyle(
                          fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 64, color: labelColor)),
                if (showAr)
                  Text(ar,
                      style: TextStyle(
                          fontFamily: 'Amiri', fontWeight: FontWeight.w700, fontSize: 56, color: labelColor)),
              ],
            ),
          ),
        ),
        Expanded(flex: 8, child: entry.id == PrayerId.sunrise ? const SizedBox.shrink() : caption('AZAN', 'أذان')),
        Expanded(
          flex: 26,
          child: _time(formatPrayerTime(entry.azan, use24h: s.use24h), s.azanColor),
        ),
        Expanded(flex: 8, child: hasIqamah ? caption('IQAMATH', 'الإقامة') : const SizedBox.shrink()),
        Expanded(
          flex: 26,
          child: hasIqamah
              ? _time(formatPrayerTime(entry.iqamah!, use24h: s.use24h), s.iqamahColor)
              : const SizedBox.shrink(),
        ),
      ],
    );

    final card = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: isNext ? labelColor.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: isNext ? labelColor : Colors.white.withValues(alpha: 0.12),
          width: isNext ? 4 : 2,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: content,
    );

    return Opacity(
      opacity: passed && !isNext ? 0.4 : 1,
      child: PulseGlow(
        active: isNext && pulsing,
        color: Color(s.iqamahColor),
        margin: EdgeInsets.zero,
        radius: 22,
        child: card,
      ),
    );
  }

  Widget _time(String text, int color) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SevenSegmentText(text, color: Color(color), fontSize: 160),
        ),
      );
}
