import 'package:flutter/services.dart';

/// Android system shortcuts (see MainActivity.kt). Every call is safe to make on any platform:
/// failures simply return a "not available" answer.
class SystemService {
  static const _channel = MethodChannel('lk.salah.clock/system');

  /// Is SalahLK currently the TV's default home app?
  static Future<bool> isDefaultHome() async {
    try {
      return await _channel.invokeMethod<bool>('isDefaultHome') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Asks Android to make SalahLK the home app. Returns 'already', 'requested' or 'unavailable'.
  static Future<String> requestHomeRole() async {
    try {
      return await _channel.invokeMethod<String>('requestHomeRole') ?? 'unavailable';
    } catch (_) {
      return 'unavailable';
    }
  }

  /// Opens the system "Home app" chooser. False if this TV has no such screen.
  static Future<bool> openHomeSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openHomeSettings') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// May SalahLK open itself after the TV boots ("Display over other apps")?
  static Future<bool> canAutoStart() async {
    try {
      return await _channel.invokeMethod<bool>('canDrawOverlays') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the "Display over other apps" screen for SalahLK. False if this TV has no such screen.
  static Future<bool> openAutoStartPermission() async {
    try {
      return await _channel.invokeMethod<bool>('openOverlaySettings') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the Android TV settings (the way out while SalahLK is the home screen).
  static Future<bool> openAndroidSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openAndroidSettings') ?? false;
    } catch (_) {
      return false;
    }
  }
}
