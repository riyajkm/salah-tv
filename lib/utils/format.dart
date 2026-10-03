import '../models/prayer.dart';
import '../services/hijri_service.dart';

String two(int n) => n.toString().padLeft(2, '0');

String ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  switch (n % 10) {
    case 1:
      return '${n}st';
    case 2:
      return '${n}nd';
    case 3:
      return '${n}rd';
    default:
      return '${n}th';
  }
}

const hijriMonthsEn = [
  'Muharram', 'Safar', "Rabi'ul Awwal", "Rabi'ul Akhir", 'Jumadal Ula', 'Jumadal Akhirah',
  'Rajab', "Sha'ban", 'Ramadan', 'Shawwal', "Dhul Qa'dah", 'Dhul Hijjah',
];

const hijriMonthsAr = [
  'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
  'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
];

const _gregMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// "15th - Rabi'ul Akhir ( 4th month ) - 1448"
String formatHijri(HijriDate h, {bool arabic = false}) {
  if (arabic) return '${h.day} - ${hijriMonthsAr[h.month - 1]} - ${h.year}';
  return '${ordinal(h.day)} - ${hijriMonthsEn[h.month - 1]} ( ${ordinal(h.month)} month ) - ${h.year}';
}

/// "27th , Sunday - September - 2026"
String formatGregorian(DateTime d) =>
    '${ordinal(d.day)} , ${_weekdays[d.weekday - 1]} - ${_gregMonths[d.month - 1]} - ${d.year}';

/// Clock text split into digits and meridiem: ("08:45:30", "PM"). Meridiem is '' in 24h mode.
(String, String) formatClock(DateTime t, {required bool use24h}) {
  if (use24h) return ('${two(t.hour)}:${two(t.minute)}:${two(t.second)}', '');
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return ('${two(h)}:${two(t.minute)}:${two(t.second)}', t.hour < 12 ? 'AM' : 'PM');
}

/// Prayer time without seconds: "05:12" (12h shows no AM/PM, as on mosque boards).
String formatPrayerTime(DateTime t, {required bool use24h}) {
  final h = use24h ? t.hour : (t.hour % 12 == 0 ? 12 : t.hour % 12);
  return '${two(h)}:${two(t.minute)}';
}

/// "mm:ss", or "hh:mm:ss" once an hour or more remains.
String formatCountdown(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final total = d.inSeconds + (d.inMilliseconds % 1000 > 0 ? 1 : 0); // round up
  final h = total ~/ 3600, m = (total % 3600) ~/ 60, s = total % 60;
  return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// (English, Arabic) display names.
(String, String) prayerNames(PrayerEntry e) {
  if (e.isJumuah) return ("Jumu'ah", 'جمعة');
  switch (e.id) {
    case PrayerId.fajr:
      return ('Fajr', 'فجر');
    case PrayerId.sunrise:
      return ('Sunrise', 'الشروق');
    case PrayerId.dhuhr:
      return ('Dhuhr', 'ظهر');
    case PrayerId.asr:
      return ('Asr', 'عصر');
    case PrayerId.maghrib:
      return ('Maghrib', 'مغرب');
    case PrayerId.isha:
      return ('Isha', 'عشاء');
  }
}
