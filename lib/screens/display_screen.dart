import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../designs/designs.dart';
import '../designs/display_design.dart';
import '../widgets/overlays.dart';
import 'pin_dialog.dart';
import 'settings_screen.dart';

/// The always-on main screen. OK / Menu on the remote (or a long press) opens settings.
class DisplayScreen extends ConsumerStatefulWidget {
  const DisplayScreen({super.key});

  @override
  ConsumerState<DisplayScreen> createState() => _DisplayScreenState();
}

class _DisplayScreenState extends ConsumerState<DisplayScreen> {
  final FocusNode _focus = FocusNode(debugLabel: 'display');
  bool _opening = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    if (_opening) return;
    _opening = true;
    try {
      final s = ref.read(settingsProvider);
      if (s.pinEnabled && !(await showPinDialog(context, s.pin))) return;
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    } finally {
      _opening = false;
      if (mounted) _focus.requestFocus();
    }
  }

  static final _openKeys = {
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.contextMenu,
    LogicalKeyboardKey.gameButtonA,
  };

  @override
  Widget build(BuildContext context) {
    final design = designById(ref.watch(settingsProvider.select((s) => s.design)));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && _openKeys.contains(event.logicalKey)) {
            _openSettings();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: _openSettings,
          // Mouse: right-click or double-click also opens settings.
          onSecondaryTap: _openSettings,
          onDoubleTap: _openSettings,
          child: ChimeListener(
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(decoration: design.background ?? const BoxDecoration(color: Color(0xFF0A0A0F))),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.sizeOf(context).width * 0.02,
                    vertical: MediaQuery.sizeOf(context).height * 0.02,
                  ),
                  child: DesignCanvas(child: Builder(builder: design.build)),
                ),
                const SilenceOverlay(),
                const StatusBadges(),
                const TimeWarning(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
