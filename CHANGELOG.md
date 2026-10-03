# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) · Versioning: [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- Release builds are signed with an upload key (`android/key.properties` locally, `ANDROID_*` secrets in CI), falling back to the debug key when none is configured.
- The release workflow now also builds and attaches a Google Play app bundle (`.aab`).

### Added
- README screenshots of all six display designs and `tool/screenshots_test.dart` to regenerate them.

## [1.0.0] - 2026-10-03

### Added
- Full-screen prayer-time clock for Android TV with 7-segment clock, Hijri and Gregorian dates.
- Bundled ACJU timetable (`assets/prayer_times.json`) with 13 zones and apartment-height adjustments.
- Iqamah countdown, "silence your phones" screen, optional azan chime, optional Sahr end time.
- Timetable import, merge and coverage warnings; calculated fallback via `adhan` for missing dates.
- D-pad controlled settings with optional PIN.

[Unreleased]: https://github.com/riyajkm/salah-tv/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/riyajkm/salah-tv/releases/tag/v1.0.0
