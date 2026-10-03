import 'package:flutter/material.dart';

import '../widgets/clock_display.dart';
import '../widgets/date_lines.dart';
import '../widgets/prayer_panel.dart';
import 'display_design.dart';

/// The original look: big clock, dates, and the next prayer as one large Azan / Iqamah pair.
const classicDesign = DisplayDesign(
  id: 'classic',
  name: 'Classic - next prayer, large',
  build: _build,
);

Widget _build(BuildContext context) => const Column(
      children: [
        MosqueNameLine(),
        Expanded(flex: 34, child: ClockDisplay()),
        Expanded(flex: 13, child: DateLines()),
        Expanded(flex: 41, child: PrayerPanel()),
      ],
    );
