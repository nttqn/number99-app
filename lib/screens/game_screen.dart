import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/admob_service.dart';
import '../services/save_service.dart';
import '../widgets/pill_button.dart';

const int _gridCols = 9;
const int _gridRows = 11;
const int _totalNumbers = _gridCols * _gridRows; // 99
const double _roundSeconds = 10.0;
const int _maxHints = 3;
const int _hintPenalty = 10;

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late List<int> _board;
  final Set<int> _found = {};
  int _target = 1;
  double _timeLeft = _roundSeconds;
  int _score = 0;
  int _hintsLeft = _maxHints;
  Timer? _timer;
  bool _paused = false;
  bool _roundLocked = false;
  bool _hintUsedThisRound = false;
  bool _gameOver = false;
  bool _won = false;
  int? _hintIndex;
  int? _wrongFlashIndex;
  int? _correctFlashIndex;
  int _highScore = 0;

  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    _bannerAd = AdmobService.createBanner(onLoaded: () => setState(() {}));
    AdmobService.preloadInterstitial();
    SaveService.getHighScore().then((v) {
      if (mounted) setState(() => _highScore = v);
    });
    _newGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  void _newGame() {
    _board = List.generate(_totalNumbers, (i) => i + 1)..shuffle();
    _found.clear();
    _score = 0;
    _hintsLeft = _maxHints;
    _gameOver = false;
    _won = false;
    _hintIndex = null;
    _startRound();
  }

  void _startRound() {
    final remaining = _board.where((n) => !_found.contains(n)).toList();
    if (remaining.isEmpty) {
      _endGame(won: true);
      return;
    }
    remaining.shuffle();
    _target = remaining.first;
    _timeLeft = _roundSeconds;
    _roundLocked = false;
    _hintUsedThisRound = false;
    _hintIndex = null;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), _tick);
    if (mounted) setState(() {});
  }

  void _tick(Timer t) {
    if (_paused) return;
    setState(() {
      _timeLeft = max(0, _timeLeft - 0.1);
      if (_timeLeft <= 0) {
        t.cancel();
        _endGame(won: false);
      }
    });
  }

  void _onCellTap(int index) {
    if (_paused || _roundLocked || _gameOver) return;
    final value = _board[index];
    if (_found.contains(value)) return;

    if (value == _target) {
      _timer?.cancel();
      final gained = _hintUsedThisRound ? 0 : (10 + (_timeLeft / _roundSeconds * 90)).round();
      setState(() {
        _score += gained;
        _found.add(value);
        _roundLocked = true;
        _correctFlashIndex = index;
      });
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        setState(() => _correctFlashIndex = null);
        _startRound();
      });
    } else {
      setState(() => _wrongFlashIndex = index);
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        setState(() => _wrongFlashIndex = null);
      });
    }
  }

  void _useHint() {
    if (_hintsLeft <= 0 || _paused || _roundLocked || _gameOver) return;
    final idx = _board.indexOf(_target);
    setState(() {
      _hintsLeft -= 1;
      _hintIndex = idx;
      _hintUsedThisRound = true;
      _score = max(0, _score - _hintPenalty);
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      setState(() => _hintIndex = null);
    });
  }

  void _togglePause() {
    if (_gameOver) return;
    setState(() => _paused = !_paused);
  }

  Future<void> _endGame({required bool won}) async {
    _timer?.cancel();
    final isNewHigh = await SaveService.submitScore(_score);
    if (!mounted) return;
    setState(() {
      _gameOver = true;
      _won = won;
      if (isNewHigh) _highScore = _score;
    });
    AdmobService.showInterstitial();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFAEE7F0),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                if (_bannerAd != null)
                  SizedBox(
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
                _HudBar(timeLeft: _timeLeft, target: _target, score: _score),
                Expanded(child: _buildGrid()),
                _buildBottomBar(),
              ],
            ),
            if (_paused && !_gameOver) _PauseOverlay(onResume: _togglePause, onRestart: _newGame),
            if (_gameOver)
              _GameOverOverlay(
                won: _won,
                score: _score,
                highScore: _highScore,
                onRestart: _newGame,
                onExit: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    const spacing = 3.0;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Size each cell so the fixed 9x11 grid exactly fills the space
          // this Expanded gives it — a fixed childAspectRatio (the previous
          // approach) sizes rows off the available *width* only, so on a
          // screen where the HUD/ad-banner/bottom-bar leave less height
          // than that produces, the last row(s) render past the bottom of
          // this box and get clipped behind the button bar.
          final cellWidth = (constraints.maxWidth - spacing * (_gridCols - 1)) / _gridCols;
          final cellHeight = (constraints.maxHeight - spacing * (_gridRows - 1)) / _gridRows;
          return GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _totalNumbers,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _gridCols,
              childAspectRatio: cellWidth / cellHeight,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
            ),
            itemBuilder: (context, index) {
              final value = _board[index];
              final isFound = _found.contains(value);
              final isHint = _hintIndex == index;
              final isWrong = _wrongFlashIndex == index;
              final isCorrectFlash = _correctFlashIndex == index;
              return _NumberCell(
                value: value,
                found: isFound,
                hinted: isHint,
                wrongFlash: isWrong,
                correctFlash: isCorrectFlash,
                onTap: () => _onCellTap(index),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(color: Color(0xFFFCE4EC)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: PillButton(
              label: 'RESTART',
              color: const Color(0xFF4CAF50),
              icon: Icons.refresh,
              onPressed: _newGame,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PillButton(
              label: 'HINT',
              color: const Color(0xFFFFA000),
              icon: Icons.lightbulb,
              badge: _hintsLeft,
              onPressed: _hintsLeft > 0 ? _useHint : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PillButton(
              label: _paused ? 'RESUME' : 'PAUSE',
              color: const Color(0xFF43A047),
              icon: _paused ? Icons.play_arrow : Icons.pause,
              onPressed: _togglePause,
            ),
          ),
        ],
      ),
    );
  }
}

class _HudBar extends StatelessWidget {
  const _HudBar({required this.timeLeft, required this.target, required this.score});

  final double timeLeft;
  final int target;
  final int score;

  @override
  Widget build(BuildContext context) {
    final urgent = timeLeft <= 3;
    return Container(
      color: const Color(0xFF9CCC65),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              children: [
                const Text('TIME', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white)),
                Text(
                  timeLeft.ceil().toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    color: urgent ? Colors.red : const Color(0xFFB71C1C),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF33691E), width: 4),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 3)),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '$target',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 30, color: Color(0xFFD81B60)),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                const Text('SCORE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white)),
                Text(
                  '$score',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: Color(0xFF1B5E20)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberCell extends StatelessWidget {
  const _NumberCell({
    required this.value,
    required this.found,
    required this.hinted,
    required this.wrongFlash,
    required this.correctFlash,
    required this.onTap,
  });

  final int value;
  final bool found;
  final bool hinted;
  final bool wrongFlash;
  final bool correctFlash;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color bg = const Color(0xFF90CAF9);
    Color border = const Color(0xFF1565C0);
    if (found) {
      bg = const Color(0xFFE0E6E8);
      border = const Color(0xFFE0E6E8);
    } else if (wrongFlash) {
      bg = const Color(0xFFEF5350);
      border = const Color(0xFFB71C1C);
    } else if (correctFlash) {
      bg = const Color(0xFF66BB6A);
      border = const Color(0xFF2E7D32);
    } else if (hinted) {
      bg = const Color(0xFFFFF176);
      border = const Color(0xFFF57F17);
    }
    return GestureDetector(
      onTap: found ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border, width: 2),
        ),
        alignment: Alignment.center,
        child: found
            ? const Icon(Icons.check, size: 16, color: Color(0xFFB0BEC5))
            : Text(
                '$value',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({required this.onResume, required this.onRestart});

  final VoidCallback onResume;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('TẠM DỪNG', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              child: PillButton(label: 'TIẾP TỤC', color: Colors.green, icon: Icons.play_arrow, onPressed: onResume),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 200,
              child: PillButton(label: 'CHƠI LẠI', color: Colors.orange, icon: Icons.refresh, onPressed: onRestart),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({
    required this.won,
    required this.score,
    required this.highScore,
    required this.onRestart,
    required this.onExit,
  });

  final bool won;
  final int score;
  final int highScore;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                won ? Icons.emoji_events : Icons.timer_off,
                color: won ? Colors.amber : Colors.redAccent,
                size: 56,
              ),
              const SizedBox(height: 12),
              Text(
                won ? 'HOÀN THÀNH!' : 'HẾT GIỜ!',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text('Điểm: $score', style: const TextStyle(fontSize: 18)),
              Text('Điểm cao nhất: $highScore', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(height: 20),
              SizedBox(
                width: 200,
                child: PillButton(label: 'CHƠI LẠI', color: Colors.green, icon: Icons.refresh, onPressed: onRestart),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 200,
                child: PillButton(label: 'VỀ MENU', color: Colors.blueGrey, icon: Icons.home, onPressed: onExit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
