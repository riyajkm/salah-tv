import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../models/timetable_data.dart';

const bundledTimetableAsset = 'assets/prayer_times.json';

/// Where an imported timetable is kept between runs.
abstract class TimetableStore {
  Future<String?> read();
  Future<void> write(String json);
  Future<void> delete();
}

/// Stores the imported timetable as a file in the app's private storage.
class FileTimetableStore implements TimetableStore {
  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}prayer_times_imported.json');
  }

  @override
  Future<String?> read() async {
    final f = await _file();
    return await f.exists() ? f.readAsString() : null;
  }

  @override
  Future<void> write(String json) async {
    final f = await _file();
    // Write to a temp file first so a power cut mid-write cannot corrupt the stored copy.
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<void> delete() async {
    final f = await _file();
    if (await f.exists()) await f.delete();
  }
}

class MemoryTimetableStore implements TimetableStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String json) async => value = json;
  @override
  Future<void> delete() async => value = null;
}

/// Outcome of merging an incoming timetable into the existing one.
class ImportResult {
  final TimetableData data;

  /// Distinct "MM-DD" days that were new for at least one zone.
  final int addedDays;

  /// Existing zone/day rows that were replaced by the incoming file.
  final int overwrittenRows;
  final int zones;

  const ImportResult(this.data, {required this.addedDays, required this.overwrittenRows, required this.zones});

  String get summary {
    final c = data.overallCoverage;
    final cov = c == null ? '' : ' Coverage now: ${formatCoverage(c)}.';
    final upd = overwrittenRows > 0 ? ' Updated $overwrittenRows existing rows.' : '';
    return 'Added $addedDays days for $zones zones.$upd$cov';
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "10-01" -> "1 Oct"
String formatDayKey(String key) => '${int.parse(key.substring(3))} ${_months[int.parse(key.substring(0, 2)) - 1]}';

/// "1 Oct – 31 Dec"
String formatCoverage(Coverage c) => '${formatDayKey(c.first)} – ${formatDayKey(c.last)}';

/// Adds [incoming] on top of [base]: new days are added, identical zone/day rows are overwritten.
/// Header fields (source, sahr margin, apartment table) come from [incoming] when it has them.
ImportResult mergeTimetables(TimetableData base, TimetableData incoming) {
  final regions = <String, Region>{...base.regions};
  final newKeys = <String>{};
  var overwritten = 0;

  for (final r in incoming.regions.values) {
    final existing = base.regions[r.code];
    final days = <String, DayTimes>{...?existing?.days};
    r.days.forEach((key, times) {
      if (days.containsKey(key)) {
        if (days[key] != times) overwritten++;
      } else {
        newKeys.add(key);
      }
      days[key] = times;
    });
    regions[r.code] = Region(r.code, r.name, days);
  }

  final merged = TimetableData(
    source: incoming.source.isNotEmpty ? incoming.source : base.source,
    generated: incoming.generated.compareTo(base.generated) >= 0 ? incoming.generated : base.generated,
    sahrEndMinutesBeforeFajr: incoming.sahrEndMinutesBeforeFajr,
    adjustments: incoming.adjustments.isNotEmpty ? incoming.adjustments : base.adjustments,
    regions: regions,
  );
  return ImportResult(merged, addedDays: newKeys.length, overwrittenRows: overwritten, zones: incoming.regions.length);
}

/// Loads, validates, merges and stores the prayer timetable.
class TimetableService {
  final TimetableStore store;
  final Future<String> Function() loadBundledText;

  TimetableService({TimetableStore? store, Future<String> Function()? loadBundledText})
      : store = store ?? FileTimetableStore(),
        loadBundledText = loadBundledText ?? (() => rootBundle.loadString(bundledTimetableAsset));

  /// Parses the bundled asset and, if present, the imported copy. Called once at startup.
  ///
  /// With both available the result is their union; where they overlap the one with the
  /// newer `generated` timestamp wins, so shipping a newer bundled file in a future build
  /// still takes effect on a TV that previously imported older data.
  Future<TimetableData> load() async {
    final bundled = TimetableData.parse(await loadBundledText());
    final importedText = await store.read();
    if (importedText == null) return bundled;
    try {
      final imported = TimetableData.parse(importedText);
      return imported.generated.compareTo(bundled.generated) >= 0
          ? mergeTimetables(bundled, imported).data
          : mergeTimetables(imported, bundled).data;
    } on TimetableFormatException {
      return bundled; // a damaged stored copy must never stop the display
    }
  }

  /// Validates [jsonText] (throws [TimetableFormatException] if bad), merges it into
  /// [current], stores the result and returns it.
  Future<ImportResult> importText(String jsonText, TimetableData current) async {
    final incoming = TimetableData.parse(jsonText);
    final result = mergeTimetables(current, incoming);
    await store.write(result.data.encode());
    return result;
  }

  /// Forgets all imported data and returns the bundled timetable.
  Future<TimetableData> resetToBundled() async {
    await store.delete();
    return TimetableData.parse(await loadBundledText());
  }
}

/// Downloads a timetable JSON from [url]. Throws on network errors, a non-200 reply or
/// an unreasonably large body (> 20 MB).
Future<String> downloadTimetable(Uri url, {Duration timeout = const Duration(seconds: 25)}) async {
  if (!url.hasScheme || (url.scheme != 'https' && url.scheme != 'http')) {
    throw const FormatException('Enter a full web address starting with http:// or https://');
  }
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final req = await client.getUrl(url).timeout(timeout);
    final res = await req.close().timeout(timeout);
    if (res.statusCode != 200) throw HttpException('Server replied ${res.statusCode}');
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in res.timeout(timeout)) {
      bytes.add(chunk);
      if (bytes.length > 20 * 1024 * 1024) throw const FormatException('File is too large.');
    }
    return utf8.decode(bytes.takeBytes());
  } finally {
    client.close(force: true);
  }
}
