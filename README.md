# SalahLK – Masjid Prayer Time Display (Android TV)

A full-screen, offline prayer-time clock for mosque TVs, written in Flutter.
Landscape only, D-pad (remote) controllable, runs 24/7.

## What it shows

* Live 7-segment clock `hh:mm:ss AM/PM` (DSEG7 Classic Bold)
* Hijri date (green) and Gregorian date (red)
* The **next** prayer (from the ACJU timetable for your zone): Azan time (red) and Iqamah time (green); Sunrise is display-only,
  Friday Dhuhr becomes **Jumu'ah**
* Countdown to azan, and "Iqamah in mm:ss" (pulsing highlight) between azan and iqamah
* After iqamah: full-screen *"Please silence your phones"* for N minutes
* Optional chime at azan, optional rotation through all prayers

## Install

Download the latest APK from the [Releases](../../releases) page and sideload it on your Android TV.

## Contributing & license

See [CONTRIBUTING.md](CONTRIBUTING.md) and [CHANGELOG.md](CHANGELOG.md). Licensed under the [MIT License](LICENSE).

## Using it

| Remote key | Action |
|---|---|
| **OK / Menu** (long-press on touch) | Open settings (asks for the PIN if enabled) |
| Up / Down | Move between settings |
| Left / Right | Change the focused value (numbers, choices, colours, toggles) |
| OK | Edit text values / open a picker / toggle |
| Back | Leave settings |

Settings are saved on the device (`shared_preferences`) and applied immediately.

### Prayer times: the ACJU timetable

The official ACJU timetable in `assets/prayer_times.json` is the **primary** source. Open
*Settings* and pick your **Zone** (the first item; names are read from the file). All times are
as printed in the timetable; the device clock must be on Sri Lanka time (UTC+5:30).

| Setting | What it does |
|---|---|
| **Zone** | One of the 13 ACJU zones. Takes effect immediately. |
| **Timetable coverage** | e.g. `Timetable: 1 Oct – 31 Dec (ACJU)`. A warning row appears when fewer than 14 days remain, and a small reminder shows on the main screen. |
| **When a date is missing** | *Calculate* (default): times are calculated with `adhan` for the zone's coordinates and a small **CALCULATED** label is shown. *Show banner*: the prayer panel shows **"Timetable missing for this date – please update"** instead of any time. Times are never guessed silently either way. |
| **Building height** | None / 6–35 floors / 35–87 floors. Shifts Fajr, Sunrise, Maghrib and Isha by the amounts in the file's `apartment_adjustments`. |
| **Show Sahr end time** | Shows `Sahr ends: HH:mm` (Fajr minus `sahr_end_minutes_before_fajr`) in the countdown row. Default off. |
| **Import timetable** | Pick a JSON file (USB / storage) or download it from a URL. See below. |
| **Reset to bundled timetable** | Throws away imported data. |

Day keys in the file are `MM-DD` (no year), so the same row is used every year. Iqamah is
unchanged: per prayer, fixed time or minutes after the (ACJU) azan. After Isha the "next prayer"
is tomorrow's Fajr, read from tomorrow's row (also across 31 Dec → 1 Jan).

### Updating the timetable

**On a TV, no rebuild needed:** *Settings → Prayer times → Import timetable* (file or URL).
The file is validated first (structure, zone codes, `MM-DD` keys, `HH:mm` times,
fajr < sunrise < dhuhr < asr < maghrib < isha); if anything is wrong nothing is changed and the
problems are listed. A valid file is **merged** with what is already loaded (new days added,
same days overwritten) and saved in the app's private storage, e.g.
*"Added 273 days for 13 zones. Coverage now: 1 Jan – 31 Dec."*

**In a future build:** replace `assets/prayer_times.json` with the new file (same structure,
`generated` timestamp updated), then `flutter build apk --release` and reinstall. On a TV that
already holds imported data, both copies are combined and, where they overlap, the one with the
newer `generated` timestamp wins, so a newer bundled file is never hidden by an old import.

Minimal file shape:

```json
{
  "source": "ACJU (All Ceylon Jamiyyathul Ulama)",
  "generated": "2026-10-03T19:23:44",
  "sahr_end_minutes_before_fajr": 2,
  "apartment_adjustments": [
    {"floors": "06-35", "meters": "24-140", "fajr": -1, "sunrise": -1, "maghrib": 1, "isha": 1}
  ],
  "regions": {
    "01": {"name": "Colombo, Gampaha, Kalutara",
           "days": {"10-01": {"fajr": "04:42", "sunrise": "05:59", "dhuhr": "12:02",
                              "asr": "15:16", "maghrib": "18:03", "isha": "19:12"}}}
  }
}
```

## Build & run (development)

```powershell
flutter pub get
flutter test                         # unit tests (prayer selection, Friday, rollovers…)
flutter run -d <android-tv-emulator> # see "Emulator" below
```

**Emulator:** Android Studio → Device Manager → *Create Device* → **TV** → "Television (1080p)"
→ an Android TV system image. In the emulator, arrow keys / Enter simulate the D-pad.

## Release APK and sideloading onto a TV

1. **Application id** is `lk.salah.clock` (set in `android/app/build.gradle.kts`; Kotlin sources live in
   `android/app/src/main/kotlin/lk/salah/clock/`). Changing it installs as a *new* app, so settings
   saved under an old id do not carry over.
2. **Create a signing key** (once; keep the file and passwords safe):
   ```powershell
   keytool -genkey -v -keystore salahlk-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias salahlk
   ```
3. Create `android/key.properties`:
   ```properties
   storePassword=•••
   keyPassword=•••
   keyAlias=salahlk
   storeFile=C:/path/to/salahlk-release.jks
   ```
   and make `android/app/build.gradle.kts` load it into a `release` signing config
   (see <https://docs.flutter.dev/deployment/android#sign-the-app>). Without this step
   `flutter build apk --release` still works but signs with the debug key – fine for a
   private mosque TV, not for the Play Store.
4. **Build:**
   ```powershell
   flutter build apk --release --split-per-abi
   ```
   Most TV boxes are `armeabi-v7a` or `arm64-v8a`:
   `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` /
   `app-arm64-v8a-release.apk`. (Plain `flutter build apk --release` makes one fat APK that
   runs everywhere.)
5. **Sideload** – enable *Developer options → USB/Network debugging* on the TV, then:
   ```powershell
   adb connect <TV-IP>:5555
   adb install -r build/app/outputs/flutter-apk/app-release.apk
   ```
   or copy the APK to a USB stick and open it with a file manager app on the TV
   (allow "Install unknown apps" for that file manager).

## Run 24/7 on the TV

* **Auto-start after power-up:** the app registers a boot receiver. On Android 10+ also grant
  *Settings → Apps → Special app access → Display over other apps → SalahLK → Allow*
  (otherwise Android blocks apps from opening themselves after boot). Open the app once first –
  Android only delivers boot events to apps that have been launched at least once.
* **Keep the screen on:** the app holds a wake lock; also set the TV's screen saver / sleep timer
  to *Never* (*Settings → Device Preferences → Screen saver*).
* **Correct time:** *Settings → Device Preferences → Date & time → Automatic date & time* ON,
  and connect to the internet once. A red banner appears if the date is obviously wrong.
* **Battery/power saving:** disable any "optimise battery" setting for SalahLK on boxes that have one.
* **Kiosk mode (optional):** to stop visitors leaving the app, use *Screen pinning* where the box
  offers it, or a launcher/kiosk app that pins `lk.salah.clock`.

### Display designs

*Settings → General → Display design* switches between six looks. They all show the same data, honour the 12/24-hour, English/Arabic and colour settings (Emerald uses its own green and gold palette), and share the countdown, Sahr line, missing-timetable banner, silence screen and warnings.

| Design | What it shows |
|---|---|
| **Classic** (default) | Clock, dates, and the next prayer as one big Azan / Iqamah pair. |
| **All prayers** | Clock, dates, and a card per prayer (Fajr, Sunrise, Dhuhr or Jumu'ah, Asr, Maghrib, Isha). |
| **List** | Clock, dates and countdown on the left; a table of every prayer on the right. |
| **Focus** | A huge clock, the next prayer as a hero line with a progress bar, and a slim strip of every prayer. |
| **Ring** | A countdown ring around the clock (fills towards the next azan, then the iqamah) with three prayers on each side. |
| **Emerald** | Green and gold theme with a Bismillah header and prayers on mihrab-style arches. |

In the all-prayer designs the next prayer is highlighted and pulses between azan and iqamah, finished prayers are dimmed, and after Isha the cards show tomorrow's times.

Every design is laid out on a fixed canvas (about 1840 px wide) that is scaled to the screen, so it looks the same on 720p, 1080p, 4K and tablets whatever the pixel density.

**Adding a design** (about 15 lines): create `lib/designs/my_design.dart` with a `const DisplayDesign(id: 'my', name: '...', build: ...)` that arranges the existing widgets (`ClockDisplay` (also `compact`), `DateLines`, `PrayerPanel`, `AllPrayersPanel`, `PrayerTable`, `NextHero`, `PrayerStrip`, `RingClock`, `ArchRow`, `CountdownRow`, `MosqueNameLine`...). Write sizes in canvas pixels (see above); `background` is optional, then add it to `kDesigns` in `lib/designs/designs.dart`. It appears in Settings automatically. Data, settings, the silence screen, warnings, chime and remote/mouse handling are shared, and an unknown saved id falls back to Classic. Never change an existing design id.

### Open automatically when the TV turns on

Open *Settings → Start-up*; it shows the status of each step and has a shortcut for each.

1. **Auto-start after power-on** (the reliable one). SalahLK has a boot receiver, but Android 10+ only
   lets an app open itself at boot if it may "Display over other apps". Press OK on this row, or
   TV settings → Apps → Special app access → Display over other apps → SalahLK → Allow, or from a PC:
   `adb shell appops set lk.salah.clock SYSTEM_ALERT_WINDOW allow`.
   Open the app once first (Android ignores boot events for apps that were never started).
   Tested: with this permission the emulator showed SalahLK by itself after a reboot.
2. **Default home app** (optional, extra). SalahLK also declares itself as a home app, so on TVs that
   allow a replacement launcher, the Home button returns to SalahLK and Android starts it at power-on.
   Use *Make SalahLK the default home app*, or choose it when the TV asks after pressing Home, or
   `adb shell cmd role add-role-holder --user 0 android.app.role.HOME lk.salah.clock`.
   Many Google TV / Android TV builds do not let a third-party app replace their own launcher (the
   emulator image used for testing is one), in which case use step 1.
3. **Open Android TV settings** is the way back to the TV's menus while SalahLK is on screen.

Also set the TV's own *Power on behaviour / Boot to app* option if it has one, so the TV powers on
by itself after a power cut, and keep the screen saver off.

### No internet / wrong TV clock

The app trusts the TV's clock. If the TV cannot sync time over the internet (and especially after
a power cut on a box without a clock battery), use *Settings → Clock*:

* **Set date & time**: type the correct `yyyy-MM-dd HH:mm` and press OK at that exact minute.
  The app stores the difference to the TV clock and applies it to everything (clock, prayer
  times, iqamah, countdowns, midnight rollover). It survives app restarts.
* **Fine adjust**: Left/Right changes the correction by 1 second per press.
* **Reset clock correction**: go back to the TV clock as it is.

The app also remembers the latest time it has ever seen. If the TV boots with a clock *earlier*
than that, a red banner asks you to set the time, so a reset clock is never silently trusted.

Limit: a correction is relative to the TV clock. If the TV clock itself is reset (power loss on a
box with no battery-backed clock), the correction no longer matches; set the time again. Setting
the TV's own date and time in Android settings (or connecting it to the internet once) is still
the best fix when possible.

## Project layout

```
lib/
  models/      app_settings.dart, prayer.dart, timetable_data.dart   (plain Dart types)
  services/    timetable_service.dart load / validate / merge / import the ACJU timetable
               prayer_service.dart   build a day's schedule (timetable, else adhan fallback)
               prayer_logic.dart     next prayer / iqamah phase / silence window
               hijri_service.dart    Hijri date, adjustment, Maghrib rollover
               settings_service.dart shared_preferences persistence
  providers.dart                      Riverpod: settings, 1 s clock, schedules, display state
  designs/     display_design.dart (registry type), designs.dart (list), classic_design.dart, all_prayers_design.dart, list_design.dart, focus_design.dart, ring_design.dart, emerald_design.dart
  widgets/     seven_segment_text, clock_display, date_lines, prayer_panel, overlays
  screens/     display_screen, settings_screen, pin_dialog
test/          prayer_logic_test.dart, timetable_test.dart, missing_banner_test.dart, clock_correction_test.dart, all_prayers_panel_test.dart, designs_test.dart, designs_render_test.dart
```

Only `ClockDisplay` and the small countdown/time blocks in `PrayerPanel` rebuild every second;
the date lines rebuild once a minute. The clock timer is re-aimed at the next whole second of the
system clock on every tick, so it cannot drift.

## Fonts / licences

DSEG (OFL) – <https://github.com/keshikan/DSEG>; Poppins (OFL); Amiri (OFL).

## Rebuilding icons, splash and APK

```powershell
python tool/generate_icons.py                    # icon / banner / splash PNGs from the geometry in the script
dart run flutter_launcher_icons                  # mipmaps + adaptive icon
dart run flutter_native_splash:create            # splash screen
flutter build apk --release                      # build/app/outputs/flutter-apk/app-release.apk
copy build\app\outputs\flutter-apk\app-release.apk SalahLK-v1.0.0.apk
```
