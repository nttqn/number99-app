import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lifetime player stats + per-mode bests + the Daily Challenge streak, all
/// persisted in shared_preferences.
///
/// Loaded once at startup ([load]) and kept in memory — the menu, stats
/// screen, theme picker and achievement checks all read the same snapshot
/// synchronously. [changes] ticks after every save so open screens refresh.
class StatsService {
  // Kept from the single-mode SaveService era so existing players don't lose
  // their Classic high score on update.
  static const _kHighScore = 'high_score';
  static const _kGamesPlayed = 'stats_games_played';
  static const _kBestLevel = 'stats_best_level';
  static const _kClassicWins = 'stats_classic_wins';
  static const _kBoardsCleared = 'stats_boards_cleared';
  static const _kTotalFound = 'stats_total_found';
  static const _kTotalReactionMs = 'stats_total_reaction_ms';
  static const _kBestCombo = 'stats_best_combo';
  static const _kZenBestMs = 'stats_zen_best_ms';
  static const _kTimeAttackBest = 'stats_time_attack_best';
  static const _kDailyStreak = 'daily_streak';
  static const _kDailyBestStreak = 'daily_best_streak';
  static const _kDailyLastDate = 'daily_last_date';
  static const _kDailyTodayScore = 'daily_today_score';
  static const _kDailyBestScore = 'daily_best_score';

  static int classicHighScore = 0;
  static int gamesPlayed = 0;
  static int bestLevel = 0;
  static int classicWins = 0;
  static int boardsCleared = 0;
  static int totalFound = 0;
  static int totalReactionMs = 0;
  static int bestCombo = 0;

  /// 0 = no Zen run completed yet.
  static int zenBestMs = 0;
  static int timeAttackBest = 0;

  static int _dailyStreak = 0;
  static int dailyBestStreak = 0;

  /// yyyymmdd of the last day a Daily Challenge attempt was started.
  static int dailyLastDate = 0;
  static int dailyTodayScore = 0;
  static int dailyBestScore = 0;

  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      classicHighScore = p.getInt(_kHighScore) ?? 0;
      gamesPlayed = p.getInt(_kGamesPlayed) ?? 0;
      bestLevel = p.getInt(_kBestLevel) ?? 0;
      classicWins = p.getInt(_kClassicWins) ?? 0;
      boardsCleared = p.getInt(_kBoardsCleared) ?? 0;
      totalFound = p.getInt(_kTotalFound) ?? 0;
      totalReactionMs = p.getInt(_kTotalReactionMs) ?? 0;
      bestCombo = p.getInt(_kBestCombo) ?? 0;
      zenBestMs = p.getInt(_kZenBestMs) ?? 0;
      timeAttackBest = p.getInt(_kTimeAttackBest) ?? 0;
      _dailyStreak = p.getInt(_kDailyStreak) ?? 0;
      dailyBestStreak = p.getInt(_kDailyBestStreak) ?? 0;
      dailyLastDate = p.getInt(_kDailyLastDate) ?? 0;
      dailyTodayScore = p.getInt(_kDailyTodayScore) ?? 0;
      dailyBestScore = p.getInt(_kDailyBestScore) ?? 0;
    } catch (_) {
      // Stats are nice-to-have — a prefs failure leaves the zero defaults.
    }
    changes.value++;
  }

  static Future<void> _save() async {
    changes.value++;
    try {
      final p = await SharedPreferences.getInstance();
      await Future.wait([
        p.setInt(_kHighScore, classicHighScore),
        p.setInt(_kGamesPlayed, gamesPlayed),
        p.setInt(_kBestLevel, bestLevel),
        p.setInt(_kClassicWins, classicWins),
        p.setInt(_kBoardsCleared, boardsCleared),
        p.setInt(_kTotalFound, totalFound),
        p.setInt(_kTotalReactionMs, totalReactionMs),
        p.setInt(_kBestCombo, bestCombo),
        p.setInt(_kZenBestMs, zenBestMs),
        p.setInt(_kTimeAttackBest, timeAttackBest),
        p.setInt(_kDailyStreak, _dailyStreak),
        p.setInt(_kDailyBestStreak, dailyBestStreak),
        p.setInt(_kDailyLastDate, dailyLastDate),
        p.setInt(_kDailyTodayScore, dailyTodayScore),
        p.setInt(_kDailyBestScore, dailyBestScore),
      ]);
    } catch (_) {
      // Not persisting stats isn't worth interrupting the game over.
    }
  }

  /// Average time from a target appearing to the player tapping it.
  static int get averageReactionMs =>
      totalFound == 0 ? 0 : totalReactionMs ~/ totalFound;

  // ---- Daily Challenge -----------------------------------------------------

  static int dateKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  static int get todayKey => dateKey(DateTime.now());

  static int get _yesterdayKey {
    final now = DateTime.now();
    return dateKey(DateTime(now.year, now.month, now.day - 1));
  }

  static bool get dailyPlayedToday => dailyLastDate == todayKey;

  /// The streak as it stands right now — a stored streak whose last day is
  /// older than yesterday is already broken, even though nothing has
  /// overwritten it yet.
  static int get dailyStreak =>
      dailyLastDate == todayKey || dailyLastDate == _yesterdayKey
      ? _dailyStreak
      : 0;

  /// Called when today's counted attempt *starts* (not ends), so quitting or
  /// killing the app mid-run can't be used to re-roll a bad attempt.
  static Future<void> startDailyAttempt() async {
    _dailyStreak = dailyLastDate == _yesterdayKey ? _dailyStreak + 1 : 1;
    if (_dailyStreak > dailyBestStreak) dailyBestStreak = _dailyStreak;
    dailyLastDate = todayKey;
    dailyTodayScore = 0;
    await _save();
  }

  // ---- Recording a finished run -------------------------------------------

  /// Folds one finished run (any mode) into the lifetime stats. The
  /// mode-specific arguments are only passed by the mode they belong to.
  static Future<void> recordRun({
    required int found,
    required int reactionMs,
    required int boardsClearedThisRun,
    required int bestComboThisRun,
    int? classicScore,
    int? classicLevel,
    bool classicWon = false,
    int? dailyScore,
    int? zenMs,
    int? timeAttackFound,
  }) async {
    gamesPlayed++;
    totalFound += found;
    totalReactionMs += reactionMs;
    boardsCleared += boardsClearedThisRun;
    if (bestComboThisRun > bestCombo) bestCombo = bestComboThisRun;
    if (classicScore != null && classicScore > classicHighScore) {
      classicHighScore = classicScore;
    }
    if (classicLevel != null && classicLevel > bestLevel) {
      bestLevel = classicLevel;
    }
    if (classicWon) classicWins++;
    if (dailyScore != null) {
      dailyTodayScore = dailyScore;
      if (dailyScore > dailyBestScore) dailyBestScore = dailyScore;
    }
    if (zenMs != null && (zenBestMs == 0 || zenMs < zenBestMs)) {
      zenBestMs = zenMs;
    }
    if (timeAttackFound != null && timeAttackFound > timeAttackBest) {
      timeAttackBest = timeAttackFound;
    }
    await _save();
  }
}
