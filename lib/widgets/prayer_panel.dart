import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../models/prayer.dart';
import '../providers.dart';
import '../services/prayer_logic.dart';
import '../utils/format.dart';
import 'seven_segment_text.dart';

// Unicode right-to-left isolate / pop-directional-isolate, built from code points.
final _rli = String.fromCharCode(0x2067);
final _pdi = String.fromCharCode(0x2069);

/// Label row + Azan/Iqamah time blocks + countdown line.
class PrayerPanel extends ConsumerWidget {
  const PrayerPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    final st = ref.watch(displayStateProvider);
    final s = ref.watch(settingsProvider);
    final today = ref.watch(todayScheduleProvider);
    final sahr = ref.watch(sahrEndProvider);

    // No timetable row for the date we need (and no calculation fallback): say so, never guess.
    final next = st.next;
    if (next == null) {
      return MissingBanner(date: st.missingDate!, labelLanguage: s.labelLanguage);
    }

    final between = st.phase == Phase.betweenAzanAndIqamah;
    // Rotation never hijacks the screen while an iqamah countdown is running.
    final shown = (s.rotate && !between && today.entries.isNotEmpty)
        ? rotationEntry(today.entries, now, s.rotateSeconds)
        : next;

    final azanText = formatPrayerTime(shown.azan, use24h: s.use24h);
    final iqText = shown.iqamah == null ? '--:--' : formatPrayerTime(shown.iqamah!, use24h: s.use24h);

    return Column(
      children: [
        Expanded(
          flex: 86,
          child: PulseGlow(
            active: between,
            color: Color(s.iqamahColor),
            child: Row(
              children: [
                Expanded(child: _Block(label: _azanLabel(shown, s), time: azanText, color: s.azanColor)),
                Container(width: 3, margin: const EdgeInsets.symmetric(vertical: 8), color: Colors.white),
                Expanded(
                  child: _Block(
                    label: shown.iqamah == null ? const [] : _iqamahLabel(s),
                    time: iqText,
                    color: s.iqamahColor,
                    dim: shown.iqamah == null,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(flex: 14, child: CountdownRow(state: st, settings: s, sahr: sahr)),
      ],
    );
  }

  /// The "Prayer Azan (Arabic)" label as styled spans, honouring the label-language setting.
  List<InlineSpan> _azanLabel(PrayerEntry e, AppSettings s) {
    final (en, ar) = prayerNames(e);
    final enText = e.id == PrayerId.sunrise ? en : '$en Azan';
    return _bilingual(s, enText, ar, e.id == PrayerId.sunrise ? ar : 'أذان $ar');
  }

  List<InlineSpan> _iqamahLabel(AppSettings s) =>
      _bilingual(s, 'Iqamath', 'وقت الإقامة', 'وقت الإقامة');

  List<InlineSpan> _bilingual(AppSettings s, String en, String arInParens, String arOnly) {
    const arStyle = TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.w700);
    switch (s.labelLanguage) {
      case 'en':
        return [TextSpan(text: en)];
      case 'ar':
        return [TextSpan(text: arOnly, style: arStyle)];
      default:
        // Right-to-left isolate (RLI ... PDI) keeps the brackets on the correct sides.
        return [
          TextSpan(text: '$en ('),
          TextSpan(text: '$_rli$arInParens$_pdi', style: arStyle),
          const TextSpan(text: ')'),
        ];
    }
  }
}

class _Block extends ConsumerWidget {
  final List<InlineSpan> label;
  final String time;
  final int color;
  final bool dim;

  const _Block({required this.label, required this.time, required this.color, this.dim = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labelColor = Color(ref.watch(settingsProvider.select((s) => s.labelColor)));
    return Column(
      children: [
        Expanded(
          flex: 18,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 64,
                  color: labelColor,
                ),
                children: label,
              ),
              maxLines: 1,
            ),
          ),
        ),
        Expanded(
          flex: 82,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SevenSegmentText(
                time,
                color: dim ? Color(color).withValues(alpha: 0.25) : Color(color),
                fontSize: 260,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Soft pulsing border shown between azan and iqamah. Idle (no animation) otherwise.
class PulseGlow extends StatefulWidget {
  final bool active;
  final Color color;
  final Widget child;
  final EdgeInsets margin;
  final double radius;
  const PulseGlow({
    super.key,
    required this.active,
    required this.color,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 12),
    this.radius = 24,
  });

  @override
  State<PulseGlow> createState() => PulseGlowState();
}

class PulseGlowState extends State<PulseGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(PulseGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.active) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final a = widget.active ? 0.25 + 0.6 * _c.value : 0.0;
        return Container(
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: widget.color.withValues(alpha: a), width: 4),
            boxShadow: widget.active
                ? [BoxShadow(color: widget.color.withValues(alpha: a * 0.4), blurRadius: 40)]
                : null,
          ),
          child: child,
        );
      },
    );
  }
}

/// Shown instead of the time blocks when the timetable has no data for the needed date.
class MissingBanner extends StatelessWidget {
  final DateTime date;
  final String labelLanguage;
  const MissingBanner({super.key, required this.date, required this.labelLanguage});

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFE8202A);
    final showEn = labelLanguage != 'ar';
    final showAr = labelLanguage != 'en';
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 40),
          decoration: BoxDecoration(
            border: Border.all(color: red, width: 6),
            borderRadius: BorderRadius.circular(28),
            color: red.withValues(alpha: 0.10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showEn)
                const Text(
                  'Timetable missing for this date – please update',
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 72, color: Colors.white),
                ),
              if (showAr)
                const Text(
                  'جدول المواقيت غير متوفر لهذا التاريخ – يرجى التحديث',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.w700, fontSize: 72, color: Colors.white),
                ),
              const SizedBox(height: 12),
              Text(
                '${date.day} ${_months[date.month - 1]} ${date.year}',
                style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500, fontSize: 44, color: red),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Fajr Azan in 05:41:40" / "Iqamah in 04:32", plus the optional "Sahr ends" line on the right.
/// Shared by both display designs.
class CountdownRow extends StatelessWidget {
  final DisplayState state;
  final AppSettings settings;
  final DateTime? sahr;
  const CountdownRow({super.key, required this.state, required this.settings, this.sahr});

  @override
  Widget build(BuildContext context) {
    final next = state.next;
    if (next == null) return const SizedBox.shrink();
    final between = state.phase == Phase.betweenAzanAndIqamah;
    final (en, _) = prayerNames(next);
    final text = between
        ? 'Iqamah in ${formatCountdown(state.countdown)}'
        : '${next.id == PrayerId.sunrise ? en : '$en Azan'} in ${formatCountdown(state.countdown)}';

    final countdown = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w500,
          fontSize: 56,
          color: between ? Color(settings.iqamahColor) : Colors.white70,
        ),
      ),
    );
    final sahrTime = sahr;
    // The Sahr line shares this row, so the layout never changes when it is switched on.
    if (sahrTime == null) return countdown;
    return Row(
      children: [
        Expanded(flex: 3, child: countdown),
        Expanded(
          flex: 1,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              'Sahr ends: ${formatPrayerTime(sahrTime, use24h: settings.use24h)}',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                fontSize: 40,
                color: Color(settings.labelColor).withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
