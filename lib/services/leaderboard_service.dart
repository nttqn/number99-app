import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

/// One leaderboard per game mode.
///
/// [classic] is the original 2014 leaderboard. The other three were added in
/// v1.3.0 and must be created in Play Console (Play Games Services >
/// Leaderboards) and App Store Connect (Game Center > Leaderboards) — see
/// CLAUDE.md "Leaderboard". An `androidId` starting with `REPLACE_` hasn't
/// been created yet and is skipped on Android.
///
/// [zen] is a *time* leaderboard (lower is better): Play Console format
/// "Time", sorted "Smaller is better", values in milliseconds; Game Center
/// format "Elapsed Time – hundredths of a second", sorted low-to-high, values
/// in hundredths — [LeaderboardService.submitScore] converts.
enum Board {
  classic('CgkIst2gm-UKEAIQAA', 'highscore'),
  daily('CgkIst2gm-UKEAIQCg', 'daily'),
  zen('CgkIst2gm-UKEAIQCw', 'zen_time'),
  timeAttack('CgkIst2gm-UKEAIQDA', 'time_attack');

  const Board(this.androidId, this.iosId);

  final String androidId;
  final String iosId;
}

/// Leaderboard wiring: Google Play Games Services on Android, Game Center on
/// iOS (games_services covers both under one API). Every call here is wrapped
/// in a try/catch: without a real leaderboard ID (or, on Android, without the
/// `com.google.android.gms.games.APP_ID` manifest meta-data — see
/// PLAY_GAMES_APP_ID in build-apk.yml) sign-in/submit/show calls fail, and
/// that must never crash or block gameplay, the same way a failed ad load
/// never blocks gameplay in AdmobService.
class LeaderboardService {
  static bool get _isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  /// Silent sign-in, best attempted once at app/game startup. Play Games
  /// Services v2 / Game Center also auto-prompt sign-in on their own, but
  /// the plugin docs say this must still be called before
  /// submitScore/showLeaderboards.
  static Future<void> signIn() async {
    if (!_isSupported) return;
    try {
      await GameAuth.signIn();
    } catch (_) {
      // No account signed in, Play Games/Game Center not set up yet, no
      // network, etc. — the game must stay fully playable without a
      // leaderboard.
    }
  }

  /// [value] is the score, or for [Board.zen] the time in milliseconds.
  static Future<void> submitScore(Board board, int value) async {
    if (!_isSupported) return;
    if (!_isIos && board.androidId.startsWith('REPLACE_')) return;
    try {
      await Leaderboards.submitScore(
        score: Score(
          androidLeaderboardID: board.androidId,
          iOSLeaderboardID: board.iosId,
          value: board == Board.zen && _isIos ? value ~/ 10 : value,
        ),
      );
    } catch (_) {
      // Fire-and-forget — a failed submit must never interrupt the
      // game-over flow the player is looking at.
    }
  }

  /// Opens the platform's leaderboard UI — the list of all leaderboards when
  /// [board] is null. Returns whether it could, so the caller can show a
  /// "not available" message instead of silently doing nothing when the user
  /// explicitly tapped a button for it.
  static Future<bool> showLeaderboard([Board? board]) async {
    if (!_isSupported) return false;
    try {
      await GameAuth.signIn();
      await Leaderboards.showLeaderboards(
        androidLeaderboardID: board?.androidId ?? '',
        iOSLeaderboardID: board?.iosId ?? '',
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
