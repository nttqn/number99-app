import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

/// Leaderboard wiring: Google Play Games Services on Android, Game Center on
/// iOS (games_services covers both under one API).
///
/// `_androidLeaderboardId` is the real Play Console leaderboard ID.
/// `_iosLeaderboardId` is a **placeholder** — it must be replaced with the
/// real Leaderboard Reference Name created in App Store Connect (App >
/// Features/Game Center > Leaderboards) before iOS does anything. Every call
/// here is wrapped in a try/catch: without a real leaderboard ID (or, on
/// Android, without the `com.google.android.gms.games.APP_ID` manifest
/// meta-data — see PLAY_GAMES_APP_ID in build-apk.yml) sign-in/submit/show
/// calls fail, and that must never crash or block gameplay, the same way a
/// failed ad load never blocks gameplay in AdmobService.
class LeaderboardService {
  static const _androidLeaderboardId = 'CgkIst2gm-UKEAIQAA';
  static const _iosLeaderboardId = 'highscore';

  static bool get _isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get _hasRealLeaderboardId =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? !_iosLeaderboardId.startsWith('REPLACE_')
      : !_androidLeaderboardId.startsWith('REPLACE_');

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

  static Future<void> submitScore(int score) async {
    if (!_isSupported || !_hasRealLeaderboardId) return;
    try {
      await Leaderboards.submitScore(
        score: Score(
          androidLeaderboardID: _androidLeaderboardId,
          iOSLeaderboardID: _iosLeaderboardId,
          value: score,
        ),
      );
    } catch (_) {
      // Fire-and-forget — a failed submit must never interrupt the
      // game-over flow the player is looking at.
    }
  }

  /// Opens the platform's own leaderboard UI. Returns whether it could — the
  /// caller can use this to show a "not available" message instead of
  /// silently doing nothing when the user explicitly tapped a button for it.
  static Future<bool> showLeaderboard() async {
    if (!_isSupported || !_hasRealLeaderboardId) {
      return false;
    }
    try {
      await GameAuth.signIn();
      await Leaderboards.showLeaderboards(
        androidLeaderboardID: _androidLeaderboardId,
        iOSLeaderboardID: _iosLeaderboardId,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
