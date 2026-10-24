import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sound effects for the game's UI/gameplay taps.
///
/// One small reusable player pool per sound file. `FlameAudio.play()` spins
/// up a brand-new native AudioPlayer on every call and never disposes it —
/// fine for a rare sound, but these fire on every button/cell tap, so that
/// leaks player instances and the audio backend gets progressively
/// slower/laggier the longer a session runs (the exact delay problem seen
/// on dino-egg-shooter). Pools reuse a handful of players instead.
class SoundService {
  static const _menuConfirm = 'sfx_menu_confirm.wav';
  static const _menuBack = 'sfx_menu_back.wav';
  static const _hint = 'sfx_hint.wav';
  static const _select = 'sfx_select.wav';
  // The three below are synthesised by tool/gen_audio.js (v1.3.0); the five
  // above are the original sound_src/ files.
  static const _wrong = 'sfx_wrong.wav';
  static const _gameOver = 'sfx_game_over.wav';
  static const _win = 'sfx_win.wav';

  static const _enabledPrefKey = 'sound_enabled';

  /// Whether sound effects should play, persisted across launches. A
  /// [ValueNotifier] so the pause overlay's toggle can reflect it live.
  static final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(true);
  static bool get enabled => enabledNotifier.value;

  static final Map<String, AudioPool> _pools = {};

  static Future<void> preload() async {
    await _loadEnabledState();
    try {
      // Android: every audioplayers player requests audio focus on start by
      // default, which pauses whichever player had it — i.e. every tap
      // sound would cut the background music out. No focus for any player
      // (MusicService passes the same context to FlameAudio.bgm itself,
      // since the two inits race). iOS: ambient = mixes, obeys silent mode.
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ),
      );
    } catch (_) {}
    try {
      await FlameAudio.audioCache.loadAll([
        _menuConfirm,
        _menuBack,
        _hint,
        _select,
        _wrong,
        _gameOver,
        _win,
      ]);
      _pools[_menuConfirm] = await FlameAudio.createPool(
        _menuConfirm,
        maxPlayers: 2,
      );
      _pools[_menuBack] = await FlameAudio.createPool(_menuBack, maxPlayers: 2);
      _pools[_hint] = await FlameAudio.createPool(_hint, maxPlayers: 2);
      _pools[_select] = await FlameAudio.createPool(_select, maxPlayers: 4);
      _pools[_wrong] = await FlameAudio.createPool(_wrong, maxPlayers: 3);
      _pools[_gameOver] = await FlameAudio.createPool(_gameOver, maxPlayers: 1);
      _pools[_win] = await FlameAudio.createPool(_win, maxPlayers: 1);
    } catch (_) {
      // Missing audio hardware/permissions shouldn't block the game.
    }
  }

  static Future<void> _loadEnabledState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabledNotifier.value = prefs.getBool(_enabledPrefKey) ?? true;
    } catch (_) {
      // Fall back to the default (enabled) if prefs aren't available.
    }
  }

  static Future<void> setEnabled(bool value) async {
    enabledNotifier.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledPrefKey, value);
    } catch (_) {
      // Not persisting the choice isn't worth failing over.
    }
  }

  /// Menu/pause/game-over buttons that move forward: PLAY, LEADERBOARD,
  /// PAUSE, RESTART, MENU.
  static void playMenuConfirm() => _play(_menuConfirm);

  /// The system back button and the pause overlay's RESUME button.
  static void playMenuBack() => _play(_menuBack);

  /// The HINT button.
  static void playHint() => _play(_hint);

  /// Tapping the right number cell.
  static void playSelect() => _play(_select);

  /// Tapping a wrong number cell.
  static void playWrong() => _play(_wrong);

  /// A run ending badly: Classic/Daily timeout, the revive offer.
  static void playGameOver() => _play(_gameOver);

  /// A run ending well: a win, a finished Zen run, a new best.
  static void playWin() => _play(_win);

  static void _play(String file) {
    if (!enabled) return;
    // Fire-and-forget: a sound failing to play should never interrupt
    // gameplay or navigation.
    unawaited(_playSafely(file));
  }

  static Future<void> _playSafely(String file) async {
    try {
      final pool = _pools[file];
      if (pool != null) {
        await pool.start();
      } else {
        // Pool wasn't ready yet (e.g. preload() hadn't finished) — still
        // play something rather than staying silent.
        await FlameAudio.play(file);
      }
    } catch (_) {
      // Missing audio hardware/permissions shouldn't block the game.
    }
  }
}
