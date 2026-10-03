// Helpers for the manual clock correction (for TVs that cannot sync time over the internet).

/// SharedPreferences key holding the latest (corrected) time the app has ever seen.
const kLastSeenKey = 'last_seen_ms';

DateTime applyClockOffset(DateTime device, int offsetSeconds) =>
    device.add(Duration(seconds: offsetSeconds));

/// Whole-second offset that makes [deviceNow] read as [target].
int clockOffsetFor(DateTime target, DateTime deviceNow) =>
    (target.difference(deviceNow).inMilliseconds / 1000).round();

final _inputRe = RegExp(r'^\s*(\d{4})-(\d{1,2})-(\d{1,2})[ T]+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*$');

/// Parses "yyyy-MM-dd HH:mm" (or with ":ss"). Returns null for anything invalid,
/// including impossible dates such as 2026-02-30.
DateTime? parseDateTimeInput(String s) {
  final m = _inputRe.firstMatch(s);
  if (m == null) return null;
  final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), d = int.parse(m.group(3)!);
  final h = int.parse(m.group(4)!), mi = int.parse(m.group(5)!), sec = int.parse(m.group(6) ?? '0');
  final t = DateTime(y, mo, d, h, mi, sec);
  final ok = t.year == y && t.month == mo && t.day == d && t.hour == h && t.minute == mi && t.second == sec;
  return ok ? t : null;
}

String formatDateTimeInput(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

/// "No correction", "+5 s", "-2 min 10 s", "+3 h 20 min", "+4 d 2 h".
String formatOffset(int seconds) {
  if (seconds == 0) return 'No correction';
  final sign = seconds < 0 ? '-' : '+';
  var r = seconds.abs();
  final d = r ~/ 86400;
  r %= 86400;
  final h = r ~/ 3600;
  r %= 3600;
  final m = r ~/ 60;
  final s = r % 60;
  final parts = <String>[
    if (d > 0) '$d d',
    if (h > 0) '$h h',
    // Keep the label short: seconds only matter for small corrections.
    if (m > 0) '$m min',
    if (s > 0 && d == 0 && h == 0) '$s s',
  ];
  return '$sign${parts.join(' ')}';
}
