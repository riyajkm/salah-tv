import 'package:flutter/material.dart';

import '../widgets/all_prayers_panel.dart';
import '../widgets/clock_display.dart';
import '../widgets/date_lines.dart';
import 'display_design.dart';

/// Clock and dates on top, every prayer of the day as a card underneath.
const allPrayersDesign = DisplayDesign(
  id: 'all', // keep: this id is already stored in saved settings
  name: 'All prayers - clock + every salah',
  build: _build,
);

Widget _build(BuildContext context) => const Column(
      children: [
        MosqueNameLine(),
        Expanded(flex: 28, child: ClockDisplay()),
        Expanded(flex: 13, child: DateLines()),
        Expanded(flex: 47, child: AllPrayersPanel()),
      ],
    );
