/// The four ways to play the same 9x11 board.
///
/// - [classic]: the original game — random targets, a per-number countdown
///   that shrinks by level, 11 levels, a win on clearing level 11.
/// - [daily]: one board + target order per calendar day, identical for every
///   player (seeded from the date), fixed 10s per number, one board only.
///   Only the first attempt each day counts for the streak/leaderboard.
/// - [zen]: no countdown — find 1 → 99 in order as fast as possible,
///   ranked by total time.
/// - [timeAttack]: one 60s clock for the whole run, random targets, score =
///   how many numbers were found.
enum GameMode { classic, daily, zen, timeAttack }

extension GameModeInfo on GameMode {
  String get title => switch (this) {
    GameMode.classic => 'CLASSIC',
    GameMode.daily => 'DAILY CHALLENGE',
    GameMode.zen => 'ZEN',
    GameMode.timeAttack => 'TIME ATTACK',
  };

  /// Whether a wrong tap costs time — the modes ranked on a clock would
  /// otherwise reward blindly spamming taps across the grid.
  bool get penalizesWrongTaps =>
      this == GameMode.zen || this == GameMode.timeAttack;
}

/// Zen times are kept in milliseconds everywhere; this formats them the way
/// the HUD/results/share card show them (m:ss.t).
String formatMillis(int ms) {
  final totalTenths = ms ~/ 100;
  final minutes = totalTenths ~/ 600;
  final seconds = (totalTenths ~/ 10) % 60;
  final tenths = totalTenths % 10;
  return '$minutes:${seconds.toString().padLeft(2, '0')}.$tenths';
}
