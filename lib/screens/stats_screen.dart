import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/game_mode.dart';
import '../services/achievement_service.dart';
import '../services/sound_service.dart';
import '../services/stats_service.dart';
import '../services/theme_service.dart';
import '../utils/responsive.dart';
import '../widgets/pill_button.dart';

/// Lifetime stats + the local achievement list (locked ones shown greyed
/// out with their condition, so players know what to go for).
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  Future<void> _openPlatformAchievements(BuildContext context) async {
    SoundService.playMenuConfirm();
    final opened = await AchievementService.showPlatformAchievements();
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Achievements not available — sign in first.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeService.current.value;
    final scale = uiScale(context);
    final avg = StatsService.averageReactionMs;
    final stats = <(IconData, String, String)>[
      (Icons.sports_esports, 'Games played', '${StatsService.gamesPlayed}'),
      (
        Icons.emoji_events,
        'Classic high score',
        '${StatsService.classicHighScore}',
      ),
      (Icons.trending_up, 'Best Classic level', '${StatsService.bestLevel}'),
      (Icons.workspace_premium, 'Classic wins', '${StatsService.classicWins}'),
      (Icons.grid_on, 'Full boards cleared', '${StatsService.boardsCleared}'),
      (Icons.check_circle, 'Numbers found', '${StatsService.totalFound}'),
      (
        Icons.bolt,
        'Average reaction',
        avg == 0 ? '—' : '${(avg / 1000).toStringAsFixed(2)}s',
      ),
      (Icons.local_fire_department, 'Best combo', 'x${StatsService.bestCombo}'),
      (
        Icons.calendar_today,
        'Daily streak (best)',
        '${StatsService.dailyStreak} (${StatsService.dailyBestStreak})',
      ),
      (Icons.star, 'Best Daily score', '${StatsService.dailyBestScore}'),
      (
        Icons.self_improvement,
        'Best Zen time',
        StatsService.zenBestMs == 0
            ? '—'
            : formatMillis(StatsService.zenBestMs),
      ),
      (Icons.timer, 'Best Time Attack', '${StatsService.timeAttackBest}'),
    ];
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    return Scaffold(
      backgroundColor: theme.menuBg,
      appBar: AppBar(
        backgroundColor: theme.hud,
        foregroundColor: theme.hudLabel,
        title: const Text(
          'STATS',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(16 * scale),
        children: [
          _Card(
            child: Column(
              children: [
                for (final (icon, label, value) in stats)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 6 * scale),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          size: 20 * scale,
                          color: Colors.green.shade700,
                        ),
                        SizedBox(width: 12 * scale),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(fontSize: 15 * scale),
                          ),
                        ),
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: 15 * scale,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 20 * scale),
          Text(
            'ACHIEVEMENTS  ${AchievementService.unlockedCount}/${AchievementService.all.length}',
            style: TextStyle(
              fontSize: 18 * scale,
              fontWeight: FontWeight.w900,
              color: theme.title,
            ),
          ),
          SizedBox(height: 10 * scale),
          _Card(
            child: Column(
              children: [
                for (final a in AchievementService.all)
                  _AchievementRow(achievement: a, scale: scale),
              ],
            ),
          ),
          SizedBox(height: 16 * scale),
          Center(
            child: SizedBox(
              width: 260 * scale,
              child: PillButton(
                label: ios ? 'GAME CENTER' : 'PLAY GAMES',
                color: Colors.blueGrey.shade600,
                icon: Icons.military_tech,
                onPressed: () => _openPlatformAchievements(context),
              ),
            ),
          ),
          SizedBox(height: 16 * scale),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({required this.achievement, required this.scale});

  final AchievementDef achievement;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final unlocked = AchievementService.isUnlocked(achievement);
    return Opacity(
      opacity: unlocked ? 1 : 0.45,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8 * scale),
        child: Row(
          children: [
            Icon(
              unlocked ? Icons.military_tech : Icons.lock,
              size: 28 * scale,
              color: unlocked ? Colors.amber.shade700 : Colors.grey,
            ),
            SizedBox(width: 12 * scale),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.title,
                    style: TextStyle(
                      fontSize: 15 * scale,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    achievement.description,
                    style: TextStyle(
                      fontSize: 13 * scale,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
