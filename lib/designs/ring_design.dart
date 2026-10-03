import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets/clock_display.dart';
import '../widgets/date_lines.dart';
import '../widgets/prayer_panel.dart';
import '../widgets/ring_parts.dart';
import 'display_design.dart';

/// A countdown ring around the clock, with three prayers on each side.
const ringDesign = DisplayDesign(
  id: 'ring',
  name: 'Ring - countdown ring + side cards',
  build: _build,
);

Widget _build(BuildContext context) => const Column(
      children: [
        MosqueNameLine(),
        Expanded(flex: 94, child: _RingBody()),
      ],
    );

class _RingBody extends ConsumerWidget {
  const _RingBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(displayStateProvider);
    if (st.next == null) {
      // No timetable data for the needed date: plain clock + the banner, no ring or cards.
      return Column(
        children: [
          const Expanded(flex: 40, child: ClockDisplay()),
          const Expanded(flex: 16, child: DateLines()),
          Expanded(
            flex: 40,
            child: MissingBanner(
              date: st.missingDate!,
              labelLanguage: ref.watch(settingsProvider.select((s) => s.labelLanguage)),
            ),
          ),
        ],
      );
    }
    return const Row(
      children: [
        Expanded(flex: 27, child: RingSideCards(from: 0, to: 3)),
        Expanded(flex: 46, child: RingClock()),
        Expanded(flex: 27, child: RingSideCards(from: 3, to: 6)),
      ],
    );
  }
}
