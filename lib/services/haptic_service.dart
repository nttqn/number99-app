import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Vibration feedback for cell taps. Uses Flutter's built-in
/// [HapticFeedback] (the platform's own haptic engine — no VIBRATE
/// permission needed on Android). Toggle persisted like
/// SoundService's, and shown next to it in the pause overlay.
class HapticService {
  static const _enabledPrefKey = 'haptics_enabled';

  static final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(true);
  static bool get enabled => enabledNotifier.value;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabledNotifier.value = prefs.getBool(_enabledPrefKey) ?? true;
    } catch (_) {}
  }

  static Future<void> setEnabled(bool value) async {
    enabledNotifier.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledPrefKey, value);
    } catch (_) {}
  }

  static void correct() {
    if (enabled) HapticFeedback.lightImpact();
  }

  /// Every 5th step of a combo gets a stronger pulse.
  static void comboMilestone() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  static void wrong() {
    if (enabled) HapticFeedback.heavyImpact();
  }
}
