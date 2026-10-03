import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets/clock_display.dart';
import '../widgets/date_lines.dart';
import '../widgets/prayer_panel.dart';
import '../widgets/prayer_table.dart';
import 'display_design.dart';

/// Clock, dates and countdown on the left; a table of every prayer on the right.
const listDesign = DisplayDesign(
  id: 'list',
  name: 'List - clock + prayer table',
  build: _build,
);

Widget _build(BuildContext context) => const Column(
      children: [
        MosqueNameLine(),
        Expanded(
          flex: 94,
          child: Row(
            children: [
              Expanded(flex: 40, child: _LeftColumn()),
              SizedBox(width: 28),
              Expanded(flex: 60, child: PrayerTable()),
            ],
          ),
        ),
      ],
    );

class _LeftColumn extends ConsumerWidget {
  const _LeftColumn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(displayStateProvider);
    final s = ref.watch(settingsProvider);
    final sahr = ref.watch(sahrEndProvider);
    return Column(
      children: [
        const Spacer(flex: 9),
        const Expanded(flex: 26, child: ClockDisplay(compact: true)),
        const Expanded(flex: 18, child: DateLines()),
        if (st.next != null)
          Expanded(
            flex: 16,
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 2),
              ),
              child: CountdownRow(state: st, settings: s, sahr: sahr),
            ),
          )
        else
          const Spacer(flex: 16),
        const Spacer(flex: 9),
      ],
    );
  }
}
