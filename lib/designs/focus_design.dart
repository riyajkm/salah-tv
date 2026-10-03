import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets/clock_display.dart';
import '../widgets/date_lines.dart';
import '../widgets/focus_parts.dart';
import '../widgets/prayer_panel.dart';
import 'display_design.dart';

/// A huge clock, the next prayer as a hero line with a progress bar, and a slim strip of
/// every prayer along the bottom.
const focusDesign = DisplayDesign(
  id: 'focus',
  name: 'Focus - big clock, next prayer hero',
  build: _build,
);

Widget _build(BuildContext context) => const Column(
      children: [
        MosqueNameLine(),
        Expanded(flex: 32, child: ClockDisplay()),
        Expanded(flex: 11, child: DateLines()),
        Expanded(flex: 25, child: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: NextHero())),
        Expanded(flex: 15, child: PrayerStrip()),
        Expanded(flex: 8, child: _Countdown()),
      ],
    );

/// The hero already shows the times, so this line only repeats the live countdown (and Sahr).
class _Countdown extends ConsumerWidget {
  const _Countdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(displayStateProvider);
    if (st.next == null) return const SizedBox.shrink();
    return CountdownRow(state: st, settings: ref.watch(settingsProvider), sahr: ref.watch(sahrEndProvider));
  }
}
