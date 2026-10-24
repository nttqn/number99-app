import 'package:flutter/material.dart';

import '../models/game_mode.dart';
import '../services/achievement_service.dart';
import '../services/leaderboard_service.dart';
import '../services/sound_service.dart';
import '../services/stats_service.dart';
import '../services/theme_service.dart';
import '../utils/responsive.dart';
import '../widgets/pill_button.dart';
import 'game_screen.dart';
import 'stats_screen.dart';
import 'themes_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  @override
  void initState() {
    super.initState();
    LeaderboardService.signIn().then((_) => AchievementService.syncAll());
  }

  Future<void> _play(GameMode mode) async {
    SoundService.playMenuConfirm();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => GameScreen(mode: mode)));
    // Stats changed during the run (high score, streak, theme unlocks).
    if (mounted) setState(() {});
  }

  Future<void> _push(Widget screen) async {
    SoundService.playMenuConfirm();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {});
  }

  Future<void> _openLeaderboard() async {
    SoundService.playMenuConfirm();
    final opened = await LeaderboardService.showLeaderboard();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Leaderboard not available — sign in with a Google account.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GameTheme>(
      valueListenable: ThemeService.current,
      builder: (context, theme, _) => _buildMenu(context, theme),
    );
  }

  Widget _buildMenu(BuildContext context, GameTheme theme) {
    final scale = uiScale(context);
    final streak = StatsService.dailyStreak;
    final dailyDone = StatsService.dailyPlayedToday;
    final dailyNote = dailyDone
        ? 'Done today: ${StatsService.dailyTodayScore} pts · 🔥 $streak'
        : streak > 0
        ? '🔥 $streak-day streak — keep it going!'
        : 'A new board every day';
    final buttonWidth = 260 * scale;
    return Scaffold(
      backgroundColor: theme.menuBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _NumberBadge(scale: scale, theme: theme),
                      SizedBox(height: 20 * scale),
                      Text(
                        '99 NUMBERS',
                        style: TextStyle(
                          fontSize: 34 * scale,
                          fontWeight: FontWeight.w900,
                          color: theme.title,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 6 * scale),
                      Text(
                        'Find the right number\nbefore time runs out!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15 * scale,
                          color: theme.title.withValues(alpha: 0.8),
                        ),
                      ),
                      SizedBox(height: 20 * scale),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20 * scale,
                          vertical: 10 * scale,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.emoji_events,
                              color: Colors.amber,
                              size: 22 * scale,
                            ),
                            SizedBox(width: 8 * scale),
                            Text(
                              'High Score: ${StatsService.classicHighScore}',
                              style: TextStyle(
                                fontSize: 16 * scale,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1B5E20),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24 * scale),
                      SizedBox(
                        width: buttonWidth,
                        child: PillButton(
                          label: 'PLAY',
                          color: Colors.green.shade600,
                          icon: Icons.play_arrow,
                          onPressed: () => _play(GameMode.classic),
                        ),
                      ),
                      SizedBox(height: 12 * scale),
                      SizedBox(
                        width: buttonWidth,
                        child: PillButton(
                          label: dailyDone
                              ? 'DAILY · PRACTICE'
                              : 'DAILY CHALLENGE',
                          color: const Color(0xFFF57C00),
                          icon: Icons.calendar_today,
                          onPressed: () => _play(GameMode.daily),
                        ),
                      ),
                      SizedBox(height: 4 * scale),
                      Text(
                        dailyNote,
                        style: TextStyle(
                          fontSize: 13 * scale,
                          fontWeight: FontWeight.w600,
                          color: theme.title,
                        ),
                      ),
                      SizedBox(height: 12 * scale),
                      SizedBox(
                        width: buttonWidth,
                        child: Row(
                          children: [
                            Expanded(
                              child: PillButton(
                                label: 'ZEN',
                                color: Colors.teal,
                                icon: Icons.self_improvement,
                                onPressed: () => _play(GameMode.zen),
                              ),
                            ),
                            SizedBox(width: 10 * scale),
                            Expanded(
                              child: PillButton(
                                label: '60s',
                                color: const Color(0xFFE53935),
                                icon: Icons.timer,
                                onPressed: () => _play(GameMode.timeAttack),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 4 * scale),
                      SizedBox(
                        width: buttonWidth,
                        child: Row(
                          children: [
                            Expanded(
                              child: _ModeBest(
                                text: StatsService.zenBestMs > 0
                                    ? 'Best ${formatMillis(StatsService.zenBestMs)}'
                                    : '1 → 99, no timer',
                                color: theme.title,
                              ),
                            ),
                            SizedBox(width: 10 * scale),
                            Expanded(
                              child: _ModeBest(
                                text: StatsService.timeAttackBest > 0
                                    ? 'Best ${StatsService.timeAttackBest}'
                                    : 'Time Attack',
                                color: theme.title,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20 * scale),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _RoundIconButton(
                            icon: Icons.leaderboard,
                            label: 'Ranks',
                            color: Colors.blueGrey.shade600,
                            textColor: theme.title,
                            onPressed: _openLeaderboard,
                          ),
                          SizedBox(width: 20 * scale),
                          _RoundIconButton(
                            icon: Icons.insights,
                            label: 'Stats',
                            color: const Color(0xFF5E35B1),
                            textColor: theme.title,
                            onPressed: () => _push(const StatsScreen()),
                          ),
                          SizedBox(width: 20 * scale),
                          _RoundIconButton(
                            icon: Icons.palette,
                            label: 'Themes',
                            color: const Color(0xFFD81B60),
                            textColor: theme.title,
                            onPressed: () => _push(const ThemesScreen()),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeBest extends StatelessWidget {
  const _ModeBest({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12 * uiScale(context),
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scale = uiScale(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Padding(
              padding: EdgeInsets.all(14 * scale),
              child: Icon(icon, color: Colors.white, size: 26 * scale),
            ),
          ),
        ),
        SizedBox(height: 4 * scale),
        Text(
          label,
          style: TextStyle(
            fontSize: 12 * scale,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.scale, required this.theme});

  final double scale;
  final GameTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110 * scale,
      height: 110 * scale,
      decoration: BoxDecoration(
        color: theme.targetBg,
        shape: BoxShape.circle,
        border: Border.all(color: theme.targetBorder, width: 6 * scale),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '99',
        style: TextStyle(
          fontSize: 44 * scale,
          fontWeight: FontWeight.w900,
          color: theme.targetText,
        ),
      ),
    );
  }
}
