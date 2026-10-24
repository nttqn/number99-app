import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'stats_service.dart';

class AchievementDef {
  const AchievementDef({
    required this.key,
    required this.title,
    required this.description,
    required this.androidId,
    required this.iosId,
    required this.isMet,
  });

  /// Local identifier, persisted in shared_preferences.
  final String key;
  final String title;
  final String description;

  /// Play Console achievement ID (CgkI...). `REPLACE_` = not created yet —
  /// the achievement still unlocks locally, it's just never sent.
  final String androidId;

  /// App Store Connect achievement ID.
  final String iosId;
  final bool Function() isMet;
}

/// Achievements are tracked locally first (shown on the Stats screen whether
/// or not the player ever signs in to Play Games / Game Center), and mirrored
/// to the platform when the platform ID is filled in. Every unlock is
/// derived from [StatsService] — call [evaluate] after stats change.
class AchievementService {
  static const _prefKey = 'achievements_unlocked';

  static final List<AchievementDef> all = [
    AchievementDef(
      key: 'first_clear',
      title: 'Full Board',
      description: 'Find all 99 numbers on one board.',
      androidId: 'CgkIst2gm-UKEAIQAg',
      iosId: 'first_clear',
      isMet: () => StatsService.boardsCleared >= 1,
    ),
    AchievementDef(
      key: 'level_4',
      title: 'Warming Up',
      description: 'Reach level 4 in Classic.',
      androidId: 'CgkIst2gm-UKEAIQAw',
      iosId: 'level_4',
      isMet: () => StatsService.bestLevel >= 4,
    ),
    AchievementDef(
      key: 'level_7',
      title: 'Sharp Eyes',
      description: 'Reach level 7 in Classic.',
      androidId: 'CgkIst2gm-UKEAIQBQ',
      iosId: 'level_7',
      isMet: () => StatsService.bestLevel >= 7,
    ),
    AchievementDef(
      key: 'champion',
      title: 'Champion',
      description: 'Clear level 11 and win Classic.',
      androidId: 'CgkIst2gm-UKEAIQCQ',
      iosId: 'champion',
      isMet: () => StatsService.classicWins >= 1,
    ),
    AchievementDef(
      key: 'combo_10',
      title: 'On Fire',
      description: 'Reach a 10x combo.',
      androidId: 'CgkIst2gm-UKEAIQBg',
      iosId: 'combo_10',
      isMet: () => StatsService.bestCombo >= 10,
    ),
    AchievementDef(
      key: 'streak_3',
      title: 'Daily Habit',
      description: 'Play the Daily Challenge 3 days in a row.',
      androidId: 'CgkIst2gm-UKEAIQDQ',
      iosId: 'streak_3',
      isMet: () => StatsService.dailyBestStreak >= 3,
    ),
    AchievementDef(
      key: 'streak_7',
      title: 'Week Warrior',
      description: 'Play the Daily Challenge 7 days in a row.',
      androidId: 'CgkIst2gm-UKEAIQDg',
      iosId: 'streak_7',
      isMet: () => StatsService.dailyBestStreak >= 7,
    ),
    AchievementDef(
      key: 'zen_180',
      title: 'Zen Master',
      description: 'Finish Zen in under 3 minutes.',
      androidId: 'CgkIst2gm-UKEAIQCA',
      iosId: 'zen_180',
      isMet: () =>
          StatsService.zenBestMs > 0 && StatsService.zenBestMs < 180000,
    ),
    AchievementDef(
      key: 'time_attack_40',
      title: 'Speed Demon',
      description: 'Find 40 numbers in one Time Attack run.',
      androidId: 'CgkIst2gm-UKEAIQBw',
      iosId: 'time_attack_40',
      isMet: () => StatsService.timeAttackBest >= 40,
    ),
    AchievementDef(
      key: 'games_100',
      title: 'Dedicated',
      description: 'Play 100 games.',
      androidId: 'CgkIst2gm-UKEAIQBA',
      iosId: 'games_100',
      isMet: () => StatsService.gamesPlayed >= 100,
    ),
  ];

  static final Set<String> _unlocked = {};

  static bool isUnlocked(AchievementDef a) => _unlocked.contains(a.key);

  static int get unlockedCount => _unlocked.length;

  static bool get _platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _unlocked.addAll(p.getStringList(_prefKey) ?? const []);
    } catch (_) {}
  }

  /// Unlocks every achievement whose condition is now met and returns the
  /// ones that are new, so the game-over screen can announce them.
  static Future<List<AchievementDef>> evaluate() async {
    final fresh = [
      for (final a in all)
        if (!_unlocked.contains(a.key) && a.isMet()) a,
    ];
    if (fresh.isEmpty) return fresh;
    _unlocked.addAll(fresh.map((a) => a.key));
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_prefKey, _unlocked.toList());
    } catch (_) {}
    for (final a in fresh) {
      _unlockOnPlatform(a);
    }
    return fresh;
  }

  /// Re-sends every locally unlocked achievement — covers ones earned while
  /// the player wasn't signed in. Unlocking an already-unlocked platform
  /// achievement is a harmless no-op.
  static void syncAll() {
    for (final a in all) {
      if (_unlocked.contains(a.key)) _unlockOnPlatform(a);
    }
  }

  static Future<void> _unlockOnPlatform(AchievementDef a) async {
    if (!_platformSupported) return;
    final id = defaultTargetPlatform == TargetPlatform.iOS
        ? a.iosId
        : a.androidId;
    if (id.startsWith('REPLACE_')) return;
    try {
      await Achievements.unlock(
        achievement: Achievement(
          androidID: a.androidId,
          iOSID: a.iosId,
          percentComplete: 100,
        ),
      );
    } catch (_) {
      // Not signed in / not configured — stays unlocked locally regardless.
    }
  }

  static Future<bool> showPlatformAchievements() async {
    if (!_platformSupported) return false;
    try {
      await GameAuth.signIn();
      await Achievements.showAchievements();
      return true;
    } catch (_) {
      return false;
    }
  }
}
