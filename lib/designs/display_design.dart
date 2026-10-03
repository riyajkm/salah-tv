import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// One selectable look of the main screen.
///
/// A design only arranges existing widgets (clock, dates, prayer panels...). Data, settings,
/// overlays (silence screen, warnings), the chime and the remote/mouse handling are shared by
/// every design, so a new design never has to re-implement any logic.
///
/// To add a design: create a file in `lib/designs/`, define a `const DisplayDesign(...)`, and
/// add it to `kDesigns` in `designs.dart`. It then appears in Settings → General → Display design.
class DisplayDesign {
  /// Stored in the settings. Never change an existing id (it would reset that choice).
  final String id;

  /// Shown in Settings.
  final String name;

  /// Screen background. Null = the standard near-black (#0A0A0F).
  final BoxDecoration? background;

  /// Builds the area inside the screen margins. It is given the whole screen to fill
  /// (typically a [Column] of [Expanded] widgets).
  final Widget Function(BuildContext context) build;

  const DisplayDesign({required this.id, required this.name, required this.build, this.background});
}

/// The optional mosque-name line at the top. Takes no space when no name is set.
/// Use it as a direct child of the design's [Column].
class MosqueNameLine extends ConsumerWidget {
  const MosqueNameLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(settingsProvider.select((s) => s.mosqueName));
    if (name.isEmpty) return const SizedBox.shrink();
    return Expanded(
      flex: 6,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          name,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 60,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}

/// Lays a design out on a fixed-width canvas and scales the whole canvas to the screen.
///
/// Designs are written in "canvas pixels" (about 1840 wide; the height follows the screen's
/// aspect ratio), so every font size, padding and gap keeps its proportions on any TV or
/// tablet, whatever its pixel density. Without this, a TV with a 2x density would show the
/// same fixed sizes twice as large relative to the layout.
class DesignCanvas extends StatelessWidget {
  static const double width = 1840;
  final Widget child;
  const DesignCanvas({super.key, required this.child});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          if (!c.hasBoundedWidth || !c.hasBoundedHeight || c.maxWidth <= 0 || c.maxHeight <= 0) {
            return const SizedBox.shrink();
          }
          return FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(width: width, height: width * c.maxHeight / c.maxWidth, child: child),
          );
        },
      );
}
