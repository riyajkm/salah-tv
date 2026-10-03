import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'models/timetable_data.dart';
import 'providers.dart';
import 'screens/display_screen.dart';
import 'services/timetable_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Full-screen, landscape, never sleeps.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  WakelockPlus.enable();

  final prefs = await SharedPreferences.getInstance();

  // Parse the timetable once; everything else reads it from memory.
  final timetableService = TimetableService();
  TimetableData timetable;
  try {
    timetable = await timetableService.load();
  } catch (_) {
    timetable = TimetableData.empty; // calculation fallback still keeps the display useful
  }

  runApp(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      timetableServiceProvider.overrideWithValue(timetableService),
      initialTimetableProvider.overrideWithValue(timetable),
    ],
    child: const SalahLKApp(),
  ));
}

class SalahLKApp extends StatelessWidget {
  const SalahLKApp({super.key});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFFFD700);
    return MaterialApp(
      title: 'SalahLK',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: gold,
          brightness: Brightness.dark,
          surface: const Color(0xFF0A0A0F),
        ),
        fontFamily: 'Poppins',
        focusColor: gold.withValues(alpha: 0.25),
      ),
      home: const DisplayScreen(),
    );
  }
}
