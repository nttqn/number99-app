import 'dart:async';

import 'package:flame_audio/flame_audio.dart';

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
  static const _fail = 'sfx_fail.wav';

  static final Map<String, AudioPool> _pools = {};

  static Future<void> preload() async {
    try {
      await FlameAudio.audioCache.loadAll([
        _menuConfirm,
        _menuBack,
        _hint,
        _select,
        _fail,
      ]);
      _pools[_menuConfirm] = await FlameAudio.createPool(
        _menuConfirm,
        maxPlayers: 2,
      );
      _pools[_menuBack] = await FlameAudio.createPool(_menuBack, maxPlayers: 2);
      _pools[_hint] = await FlameAudio.createPool(_hint, maxPlayers: 2);
      _pools[_select] = await FlameAudio.createPool(_select, maxPlayers: 4);
      _pools[_fail] = await FlameAudio.createPool(_fail, maxPlayers: 2);
    } catch (_) {
      // Missing audio hardware/permissions shouldn't block the game.
    }
  }

  /// Menu/pause/game-over buttons that move forward: PLAY, LEADERBOARD,
  /// PAUSE, RESTART, MENU.
  static void playMenuConfirm() => _play(_menuConfirm);

  /// The system back button and the pause overlay's RESUME button.
  static void playMenuBack() => _play(_menuBack);

  /// The HINT button.
  static void playHint() => _play(_hint);

  /// Tapping a number cell in the grid, right or wrong.
  static void playSelect() => _play(_select);

  /// Round/game ending (timeout or all numbers found).
  static void playFail() => _play(_fail);

  static void _play(String file) {
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
