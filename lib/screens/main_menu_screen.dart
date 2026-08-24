import 'package:flutter/material.dart';

import '../services/leaderboard_service.dart';
import '../services/save_service.dart';
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
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
    _loadHighScore();
  }

  Future<void> _openLeaderboard() async {
    final opened = await LeaderboardService.showLeaderboard();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bảng xếp hạng chưa khả dụng — cần đăng nhập tài khoản Google.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFBEE7B8),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _NumberBadge(),
                const SizedBox(height: 24),
                const Text(
                  '99 NUMBERS',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1B5E20),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tìm đúng số theo yêu cầu\ntrước khi hết giờ!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.green.shade900),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.amber, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Điểm cao: $_highScore',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: 220,
                  child: PillButton(
                    label: 'CHƠI NGAY',
                    color: Colors.green.shade600,
                    icon: Icons.play_arrow,
                    onPressed: _play,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 220,
                  child: PillButton(
                    label: 'BẢNG XẾP HẠNG',
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
    );
  }
}

class _NumberBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF2E7D32), width: 6),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      alignment: Alignment.center,
      child: const Text(
        '99',
        style: TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w900,
          color: Color(0xFFD81B60),
        ),
      ),
    );
  }
}
