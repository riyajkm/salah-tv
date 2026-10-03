import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets/arch_parts.dart';
import '../widgets/clock_display.dart';
import '../widgets/date_lines.dart';
import '../widgets/prayer_panel.dart';
import 'display_design.dart';

/// A green and gold theme: Bismillah header, gold clock, prayers on mihrab-style arches.
const emeraldDesign = DisplayDesign(
  id: 'emerald',
  name: 'Emerald - green & gold, arches',
  background: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Emerald.deep, Emerald.green],
    ),
  ),
  build: _build,
);

Widget _build(BuildContext context) => Container(
  // A thin gold frame around everything.
  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(34),
    border: Border.all(color: Emerald.gold.withValues(alpha: 0.55), width: 3),
  ),
  child: const Column(
    children: [
      Expanded(flex: 18, child: _Header()),
      Expanded(flex: 24, child: ClockDisplay(color: Emerald.cream)),
      Expanded(
        flex: 12,
        child: DateLines(hijri: Emerald.mint, gregorian: Emerald.gold),
      ),
      Expanded(
        flex: 37,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: ArchRow(),
        ),
      ),
      Expanded(flex: 10, child: _Countdown()),
    ],
  ),
);

/// Bismillah, and the mosque name under it when one is set.
class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(settingsProvider.select((s) => s.mosqueName));
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
            style: TextStyle(
              fontFamily: 'Amiri',
              fontWeight: FontWeight.w700,
              fontSize: 68,
              height: 1.7,
              color: Emerald.gold,
            ),
          ),
          if (name.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                name,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 40,
                  color: Emerald.cream,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Countdown extends ConsumerWidget {
  const _Countdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(displayStateProvider);
    if (st.next == null) return const SizedBox.shrink();
    return CountdownRow(
      state: st,
      settings: ref.watch(settingsProvider),
      sahr: ref.watch(sahrEndProvider),
    );
  }
}
