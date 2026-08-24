import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

/// Google Play Games Services leaderboard wiring.
///
/// The leaderboard ID below is a **placeholder** — it must be replaced with
/// the real ID created in Play Console (Play Games Services > Leaderboards)
/// before this does anything useful. Every call here is wrapped in a
/// try/catch: without a real leaderboard ID (or without the
/// `com.google.android.gms.games.APP_ID` manifest meta-data — see
/// PLAY_GAMES_APP_ID in build-apk.yml) sign-in/submit/show calls fail, and
/// that must never crash or block gameplay, the same way a failed ad load
/// never blocks gameplay in AdmobService.
///
/// Android-only: games_services also supports Game Center on iOS/macOS, but
/// this app has no iOS build target (see build-apk.yml, --platforms=android
/// only), so anything else no-ops.
class LeaderboardService {
  static const _androidLeaderboardId = 'CgkIst2gm-UKEAIQAA';

  static bool get _isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Silent sign-in, best attempted once at app/game startup. Play Games
  /// Services v2 also auto-prompts sign-in on its own, but the plugin docs
  /// say this must still be called before submitScore/showLeaderboards.
  static Future<void> signIn() async {
    if (!_isSupported) return;
    try {
      await GameAuth.signIn();
    } catch (_) {
      // No Google account signed in, Play Games not set up yet, no network,
      // etc. — the game must stay fully playable without a leaderboard.
    }
  }

  static Future<void> submitScore(int score) async {
    if (!_isSupported || _androidLeaderboardId.startsWith('REPLACE_')) return;
    try {
      await Leaderboards.submitScore(
        score: Score(androidLeaderboardID: _androidLeaderboardId, value: score),
      );
    } catch (_) {
      // Fire-and-forget — a failed submit must never interrupt the
      // game-over flow the player is looking at.
    }
  }

  /// Opens Play Games' own leaderboard UI. Returns whether it could — the
  /// caller can use this to show a "chưa khả dụng" message instead of
  /// silently doing nothing when the user explicitly tapped a button for it.
  static Future<bool> showLeaderboard() async {
    if (!_isSupported || _androidLeaderboardId.startsWith('REPLACE_')) return false;
    try {
      await GameAuth.signIn();
      await Leaderboards.showLeaderboards(androidLeaderboardID: _androidLeaderboardId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
