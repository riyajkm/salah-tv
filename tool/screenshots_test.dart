// ignore_for_file: invalid_use_of_visible_for_testing_member
// Regenerates the README screenshots in docs/screenshots/.
//
//   flutter test tool/screenshots_test.dart
//
// Not part of `flutter test` (it lives in tool/, not test/), so CI does not run it.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salah_lk/designs/designs.dart';
import 'package:salah_lk/designs/display_design.dart';
import 'package:salah_lk/models/app_settings.dart';
import 'package:salah_lk/models/timetable_data.dart';
import 'package:salah_lk/providers.dart';
import 'package:salah_lk/services/timetable_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/fixtures.dart';

class _FixedNow extends NowNotifier {
  final DateTime t;
  _FixedNow(this.t);
  @override
  DateTime build() => t;
}

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final l = FontLoader(family);
    for (final f in files) {
      l.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync())));
    }
    await l.load();
  }

  await load('Poppins', ['Poppins-Medium.ttf', 'Poppins-Bold.ttf']);
  await load('Amiri', ['Amiri-Regular.ttf', 'Amiri-Bold.ttf']);
  await load('DSEG7', ['DSEG7Classic-Bold.ttf']);
}

const _size = Size(1920, 1080);
final _shotKey = GlobalKey();

Future<void> _shot(WidgetTester tester, String name, Widget Function(Size) child,
    {required DateTime now, AppSettings settings = const AppSettings(mosqueName: 'Masjid Example')}) async {
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'settings_v1': settings.encode()});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      initialTimetableProvider.overrideWithValue(TimetableData.parse(bundledJsonText())),
      timetableServiceProvider.overrideWithValue(TimetableService(store: MemoryTimetableStore())),
      nowProvider.overrideWith(() => _FixedNow(now)),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(key: _shotKey, child: child(_size)),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.runAsync(() async {
    final boundary = _shotKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final file = File('docs/screenshots/$name.png')..createSync(recursive: true);
    file.writeAsBytesSync(bytes.buffer.asUint8List());
  });
}

void main() {
  setUpAll(_loadFonts);

  final day = DateTime(2026, 10, 3, 10, 0);

  for (final design in kDesigns) {
    testWidgets('design ${design.id}', (tester) async {
      await _shot(
        tester,
        'design-${design.id}',
        (size) => Scaffold(
          backgroundColor: const Color(0xFF0A0A0F),
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: size.width * 0.02, vertical: size.height * 0.02),
            child: DesignCanvas(child: Builder(builder: design.build)),
          ),
        ),
        now: day,
        // Bilingual captions in some designs rely on a system Arabic fallback font, which
        // the test environment lacks, so render those in English only.
        settings: AppSettings(mosqueName: 'Masjid Example', design: design.id, labelLanguage: 'en'),
      );
    });
  }
}
