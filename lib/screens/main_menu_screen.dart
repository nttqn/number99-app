import 'package:flutter/material.dart';

import '../services/leaderboard_service.dart';
import '../services/save_service.dart';
import '../services/sound_service.dart';
import '../utils/responsive.dart';
import '../widgets/pill_button.dart';
import 'game_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  int _highScore = 0;

  @override
  void initState() {
    super.initState();
    _loadHighScore();
    LeaderboardService.signIn();
  }

  Future<void> _loadHighScore() async {
    final v = await SaveService.getHighScore();
    if (mounted) setState(() => _highScore = v);
  }

  Future<void> _play() async {
    SoundService.playMenuConfirm();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const GameScreen()));
    _loadHighScore();
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
    final scale = uiScale(context);
    return Scaffold(
      backgroundColor: const Color(0xFFBEE7B8),
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
                      _NumberBadge(scale: scale),
                      SizedBox(height: 24 * scale),
                      Text(
                        '99 NUMBERS',
                        style: TextStyle(
                          fontSize: 34 * scale,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1B5E20),
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 8 * scale),
                      Text(
                        'Find the right number\nbefore time runs out!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15 * scale,
                          color: Colors.green.shade900,
                        ),
                      ),
                      SizedBox(height: 28 * scale),
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
                              'High Score: $_highScore',
                              style: TextStyle(
                                fontSize: 16 * scale,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1B5E20),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 32 * scale),
                      SizedBox(
                        width: 220 * scale,
                        child: PillButton(
                          label: 'PLAY',
                          color: Colors.green.shade600,
                          icon: Icons.play_arrow,
                          onPressed: _play,
                        ),
                      ),
                      SizedBox(height: 12 * scale),
                      SizedBox(
                        width: 220 * scale,
                        child: PillButton(
                          label: 'LEADERBOARD',
                          color: Colors.blueGrey.shade600,
                          icon: Icons.leaderboard,
                          onPressed: _openLeaderboard,
                        ),
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

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110 * scale,
      height: 110 * scale,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF2E7D32), width: 6 * scale),
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
          color: const Color(0xFFD81B60),
        ),
      ),
    );
  }
}
