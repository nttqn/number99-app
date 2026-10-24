import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Looping background music — menu and in-game tracks, both synthesised by
/// `tool/gen_audio.js` (regenerate from there rather than editing the WAVs).
///
/// Separate from [SoundService] (one-shot AudioPool effects) because
/// `FlameAudio.bgm` is a different mechanism: one lifecycle-aware looping
/// player that pauses itself when the app is backgrounded. Its on/off
/// toggle is independent of the sound-effects one on purpose — muting
/// effects must not silence music and vice versa.
///
/// Ported from block-puzzle-app's MusicService, including both of its
/// real-device fixes (see [init]).
class MusicService {
  static const _menuTrack = 'bgm_menu.wav';
  static const _gameTrack = 'bgm_game.wav';
  static const _volume = 0.4;
  static const _enabledPrefKey = 'music_enabled';

  static final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(true);

  static String? _wanted;
  static bool _initialized = false;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabledNotifier.value = prefs.getBool(_enabledPrefKey) ?? true;
    } catch (_) {}
    try {
      // Same no-audio-focus context SoundService sets globally, passed
      // explicitly: FlameAudio.bgm is a lazily-created singleton with its
      // own fallback context, and main() doesn't await either init, so it
      // can't rely on the global default having been set first. Without
      // it, every tap sound would cut the music out on Android.
      await FlameAudio.bgm.initialize(
        audioContext: AudioContext(
          android: const AudioContextAndroid(
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ),
      );
      _initialized = true;
      // The menu asks for its track before this unawaited init finishes —
      // start that pending request now, or first launch stays silent.
      final pending = _wanted;
      if (pending != null) _play(pending);
    } catch (_) {
      // No music this session — the game stays fully playable in silence.
    }
  }

  static void playMenu() => _play(_menuTrack);

  static void playGame() => _play(_gameTrack);

  static void _play(String track) {
    if (_initialized && _wanted == track && FlameAudio.bgm.isPlaying) return;
    _wanted = track;
    if (!_initialized || !enabledNotifier.value) return;
    // Bgm.play() releases the previous source itself, so switching tracks
    // is just playing the other one.
    FlameAudio.bgm.play(track, volume: _volume).catchError((_) {});
  }

  static Future<void> setEnabled(bool value) async {
    enabledNotifier.value = value;
    if (_initialized && _wanted != null) {
      if (value) {
        FlameAudio.bgm.play(_wanted!, volume: _volume).catchError((_) {});
      } else {
        FlameAudio.bgm.stop().catchError((_) {});
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledPrefKey, value);
    } catch (_) {}
  }
}
