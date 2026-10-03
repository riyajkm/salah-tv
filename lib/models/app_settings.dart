import 'dart:convert';

import 'prayer.dart';

/// How the iqamah time of one prayer is determined.
class IqamahRule {
  /// true = fixed clock time ([time]); false = [minutes] after azan.
  final bool fixed;
  final int minutes;

  /// "HH:mm" (24h), used when [fixed].
  final String time;

  const IqamahRule({this.fixed = false, this.minutes = 15, this.time = '05:30'});

  IqamahRule copyWith({bool? fixed, int? minutes, String? time}) => IqamahRule(
        fixed: fixed ?? this.fixed,
        minutes: minutes ?? this.minutes,
        time: time ?? this.time,
      );

  Map<String, dynamic> toJson() => {'fixed': fixed, 'minutes': minutes, 'time': time};

  factory IqamahRule.fromJson(Map<String, dynamic> j) => IqamahRule(
        fixed: j['fixed'] as bool? ?? false,
        minutes: j['minutes'] as int? ?? 15,
        time: j['time'] as String? ?? '05:30',
      );
}

/// Keys used in [AppSettings.iqamah].
const iqamahKeys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha', 'jumuah'];

class AppSettings {
  final String mosqueName;

  // --- Prayer time source (ACJU timetable, calculation as fallback) --------
  /// ACJU zone code, "01".."13" (names come from the timetable file).
  final String zone;

  /// When the timetable has no row for a date, calculate the times with `adhan`
  /// (marked "CALCULATED" on screen) instead of showing a "timetable missing" banner.
  final bool fallbackCalculated;

  /// Building-height correction: the "floors" key of an apartment adjustment, or '' for none.
  final String buildingFloors;

  /// Show "Sahr ends: HH:mm" (Fajr minus the timetable's sahr margin).
  final bool showSahr;

  /// Manual clock correction in whole seconds, added to the device clock (for TVs that
  /// cannot sync time over the internet). 0 = trust the device clock.
  final int clockOffsetSeconds;

  /// Name of an `adhan` CalculationMethod enum value.
  final String method;

  /// 'shafi' | 'hanafi'
  final String madhab;

  /// 'none' | 'middle_of_the_night' | 'seventh_of_the_night' | 'twilight_angle'
  final String highLatitudeRule;

  /// Minutes added to the azan time, keyed by [PrayerId.name].
  final Map<String, int> adjustments;
  final Map<String, IqamahRule> iqamah;

  // --- Hijri ---------------------------------------------------------------
  final int hijriAdjust;
  final bool hijriRolloverAtMaghrib;
  final bool arabicMonthNames;

  // --- Display -------------------------------------------------------------
  final bool use24h;

  /// 'classic' = one prayer shown big (the original look); 'all' = clock plus every prayer at once.
  final String design;

  /// 'both' | 'en' | 'ar'
  final String labelLanguage;
  final int clockColor;
  final int hijriColor;
  final int gregorianColor;
  final int labelColor;
  final int azanColor;
  final int iqamahColor;
  final bool rotate;
  final int rotateSeconds;

  // --- Alerts --------------------------------------------------------------
  final bool chime;
  final String silenceMessage;
  final int silenceMinutes;

  // --- Security ------------------------------------------------------------
  final bool pinEnabled;
  final String pin;

  const AppSettings({
    this.mosqueName = '',
    this.zone = '01',
    this.fallbackCalculated = true,
    this.buildingFloors = '',
    this.showSahr = false,
    this.clockOffsetSeconds = 0,
    this.method = 'muslim_world_league',
    this.madhab = 'shafi',
    this.highLatitudeRule = 'none',
    this.adjustments = const {},
    this.iqamah = const {
      'fajr': IqamahRule(minutes: 20),
      'dhuhr': IqamahRule(minutes: 15),
      'asr': IqamahRule(minutes: 15),
      'maghrib': IqamahRule(minutes: 10),
      'isha': IqamahRule(minutes: 15),
      'jumuah': IqamahRule(minutes: 20),
    },
    this.hijriAdjust = 0,
    this.hijriRolloverAtMaghrib = false,
    this.arabicMonthNames = false,
    this.use24h = false,
    this.design = 'classic',
    this.labelLanguage = 'both',
    this.clockColor = 0xFFFFFFFF,
    this.hijriColor = 0xFF2ECC40,
    this.gregorianColor = 0xFFE8202A,
    this.labelColor = 0xFFFFD700,
    this.azanColor = 0xFFE8202A,
    this.iqamahColor = 0xFF2ECC40,
    this.rotate = false,
    this.rotateSeconds = 10,
    this.chime = true,
    this.silenceMessage = 'Please silence your phones',
    this.silenceMinutes = 2,
    this.pinEnabled = false,
    this.pin = '1234',
  });

  int adjustmentFor(PrayerId id) => adjustments[id.name] ?? 0;

  IqamahRule iqamahRule(String key) => iqamah[key] ?? const IqamahRule();

  AppSettings copyWith({
    String? mosqueName,
    String? zone,
    bool? fallbackCalculated,
    String? buildingFloors,
    bool? showSahr,
    int? clockOffsetSeconds,
    String? method,
    String? madhab,
    String? highLatitudeRule,
    Map<String, int>? adjustments,
    Map<String, IqamahRule>? iqamah,
    int? hijriAdjust,
    bool? hijriRolloverAtMaghrib,
    bool? arabicMonthNames,
    bool? use24h,
    String? design,
    String? labelLanguage,
    int? clockColor,
    int? hijriColor,
    int? gregorianColor,
    int? labelColor,
    int? azanColor,
    int? iqamahColor,
    bool? rotate,
    int? rotateSeconds,
    bool? chime,
    String? silenceMessage,
    int? silenceMinutes,
    bool? pinEnabled,
    String? pin,
  }) =>
      AppSettings(
        mosqueName: mosqueName ?? this.mosqueName,
        zone: zone ?? this.zone,
        fallbackCalculated: fallbackCalculated ?? this.fallbackCalculated,
        buildingFloors: buildingFloors ?? this.buildingFloors,
        showSahr: showSahr ?? this.showSahr,
        clockOffsetSeconds: clockOffsetSeconds ?? this.clockOffsetSeconds,
        method: method ?? this.method,
        madhab: madhab ?? this.madhab,
        highLatitudeRule: highLatitudeRule ?? this.highLatitudeRule,
        adjustments: adjustments ?? this.adjustments,
        iqamah: iqamah ?? this.iqamah,
        hijriAdjust: hijriAdjust ?? this.hijriAdjust,
        hijriRolloverAtMaghrib: hijriRolloverAtMaghrib ?? this.hijriRolloverAtMaghrib,
        arabicMonthNames: arabicMonthNames ?? this.arabicMonthNames,
        use24h: use24h ?? this.use24h,
        design: design ?? this.design,
        labelLanguage: labelLanguage ?? this.labelLanguage,
        clockColor: clockColor ?? this.clockColor,
        hijriColor: hijriColor ?? this.hijriColor,
        gregorianColor: gregorianColor ?? this.gregorianColor,
        labelColor: labelColor ?? this.labelColor,
        azanColor: azanColor ?? this.azanColor,
        iqamahColor: iqamahColor ?? this.iqamahColor,
        rotate: rotate ?? this.rotate,
        rotateSeconds: rotateSeconds ?? this.rotateSeconds,
        chime: chime ?? this.chime,
        silenceMessage: silenceMessage ?? this.silenceMessage,
        silenceMinutes: silenceMinutes ?? this.silenceMinutes,
        pinEnabled: pinEnabled ?? this.pinEnabled,
        pin: pin ?? this.pin,
      );

  Map<String, dynamic> toJson() => {
        'mosqueName': mosqueName,
        'zone': zone,
        'fallbackCalculated': fallbackCalculated,
        'buildingFloors': buildingFloors,
        'showSahr': showSahr,
        'clockOffsetSeconds': clockOffsetSeconds,
        'method': method,
        'madhab': madhab,
        'highLatitudeRule': highLatitudeRule,
        'adjustments': adjustments,
        'iqamah': iqamah.map((k, v) => MapEntry(k, v.toJson())),
        'hijriAdjust': hijriAdjust,
        'hijriRolloverAtMaghrib': hijriRolloverAtMaghrib,
        'arabicMonthNames': arabicMonthNames,
        'use24h': use24h,
        'design': design,
        'labelLanguage': labelLanguage,
        'clockColor': clockColor,
        'hijriColor': hijriColor,
        'gregorianColor': gregorianColor,
        'labelColor': labelColor,
        'azanColor': azanColor,
        'iqamahColor': iqamahColor,
        'rotate': rotate,
        'rotateSeconds': rotateSeconds,
        'chime': chime,
        'silenceMessage': silenceMessage,
        'silenceMinutes': silenceMinutes,
        'pinEnabled': pinEnabled,
        'pin': pin,
      };

  /// Tolerant decoding: any missing/invalid field falls back to its default,
  /// so settings saved by an older app version never crash a newer one.
  factory AppSettings.fromJson(Map<String, dynamic> j) {
    const d = AppSettings();
    final iq = <String, IqamahRule>{...d.iqamah};
    final rawIq = j['iqamah'];
    if (rawIq is Map) {
      rawIq.forEach((k, v) {
        if (v is Map) iq['$k'] = IqamahRule.fromJson(Map<String, dynamic>.from(v));
      });
    }
    final adj = <String, int>{};
    final rawAdj = j['adjustments'];
    if (rawAdj is Map) {
      rawAdj.forEach((k, v) {
        if (v is num) adj['$k'] = v.toInt();
      });
    }
    T pick<T>(String key, T fallback) => j[key] is T ? j[key] as T : fallback;
    return AppSettings(
      mosqueName: pick('mosqueName', d.mosqueName),
      zone: pick('zone', d.zone),
      fallbackCalculated: pick('fallbackCalculated', d.fallbackCalculated),
      buildingFloors: pick('buildingFloors', d.buildingFloors),
      showSahr: pick('showSahr', d.showSahr),
      clockOffsetSeconds: pick('clockOffsetSeconds', d.clockOffsetSeconds),
      method: pick('method', d.method),
      madhab: pick('madhab', d.madhab),
      highLatitudeRule: pick('highLatitudeRule', d.highLatitudeRule),
      adjustments: adj,
      iqamah: iq,
      hijriAdjust: pick('hijriAdjust', d.hijriAdjust),
      hijriRolloverAtMaghrib: pick('hijriRolloverAtMaghrib', d.hijriRolloverAtMaghrib),
      arabicMonthNames: pick('arabicMonthNames', d.arabicMonthNames),
      use24h: pick('use24h', d.use24h),
      design: pick('design', d.design),
      labelLanguage: pick('labelLanguage', d.labelLanguage),
      clockColor: pick('clockColor', d.clockColor),
      hijriColor: pick('hijriColor', d.hijriColor),
      gregorianColor: pick('gregorianColor', d.gregorianColor),
      labelColor: pick('labelColor', d.labelColor),
      azanColor: pick('azanColor', d.azanColor),
      iqamahColor: pick('iqamahColor', d.iqamahColor),
      rotate: pick('rotate', d.rotate),
      rotateSeconds: pick('rotateSeconds', d.rotateSeconds),
      chime: pick('chime', d.chime),
      silenceMessage: pick('silenceMessage', d.silenceMessage),
      silenceMinutes: pick('silenceMinutes', d.silenceMinutes),
      pinEnabled: pick('pinEnabled', d.pinEnabled),
      pin: pick('pin', d.pin),
    );
  }

  String encode() => jsonEncode(toJson());

  factory AppSettings.decode(String s) =>
      AppSettings.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
