import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Asks for the 4-digit PIN. Works with the D-pad (on-screen keypad) and a number keyboard.
/// Returns true when the PIN matches.
Future<bool> showPinDialog(BuildContext context, String pin) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _PinDialog(pin: pin),
  );
  return ok ?? false;
}

class _PinDialog extends StatefulWidget {
  final String pin;
  const _PinDialog({required this.pin});

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  String _entered = '';
  bool _wrong = false;

  void _digit(String d) {
    if (_entered.length >= widget.pin.length) return;
    setState(() {
      _entered += d;
      _wrong = false;
    });
    if (_entered.length == widget.pin.length) {
      if (_entered == widget.pin) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _entered = '';
          _wrong = true;
        });
      }
    }
  }

  void _back() => setState(() {
        if (_entered.isNotEmpty) _entered = _entered.substring(0, _entered.length - 1);
      });

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, e) {
        if (e is! KeyDownEvent) return KeyEventResult.ignored;
        final label = e.logicalKey.keyLabel;
        if (label.length == 1 && '0123456789'.contains(label)) {
          _digit(label);
          return KeyEventResult.handled;
        }
        if (e.logicalKey == LogicalKeyboardKey.backspace) {
          _back();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AlertDialog(
        backgroundColor: const Color(0xFF16161F),
        title: const Text('Enter PIN', style: TextStyle(fontFamily: 'Poppins', color: Colors.white)),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                List.generate(widget.pin.length, (i) => i < _entered.length ? '●' : '○').join(' '),
                style: TextStyle(fontSize: 40, color: _wrong ? Colors.redAccent : Colors.white),
              ),
              SizedBox(
                height: 28,
                child: _wrong
                    ? const Text('Wrong PIN', style: TextStyle(color: Colors.redAccent))
                    : null,
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '⌫', '0', '✕'])
                    SizedBox(
                      width: 100,
                      height: 60,
                      child: FilledButton(
                        autofocus: d == '5',
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2A2A38),
                        ).copyWith(
                          side: WidgetStateProperty.resolveWith(
                            (s) => s.contains(WidgetState.focused)
                                ? const BorderSide(color: Color(0xFFFFD700), width: 3)
                                : null,
                          ),
                        ),
                        onPressed: () {
                          if (d == '⌫') {
                            _back();
                          } else if (d == '✕') {
                            Navigator.of(context).pop(false);
                          } else {
                            _digit(d);
                          }
                        },
                        child: Text(d, style: const TextStyle(fontSize: 26)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
