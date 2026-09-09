import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/admob_service.dart';
import '../services/leaderboard_service.dart';
import '../services/save_service.dart';
import '../services/sound_service.dart';
import '../utils/responsive.dart';
import '../widgets/level_announcement.dart';
import '../widgets/pill_button.dart';

const int _gridCols = 9;
const int _gridRows = 11;
const int _totalNumbers = _gridCols * _gridRows; // 99

// A level only advances once the whole 99-number board has been cleared —
// clearing it reshuffles a fresh board and continues at the next level,
// *except* on the final level (11, where the round countdown bottoms out
// at its 5s floor — see _roundSecondsForLevel), which is a real win instead.
// Round countdown shrinks a second per level; score-per-catch and the hint
// penalty both scale up with level; the hint budget shrinks — all
// deliberately, to keep the game getting harder rather than just faster.
const double _baseRoundSeconds = 15.0;
const double _minRoundSeconds = 5.0;
const int _baseMaxHints = 3;
const int _baseHintPenalty = 10;

// Level at which _roundSecondsForLevel first hits _minRoundSeconds:
// 15 - (11-1) = 5. Clearing this level's board is the win condition.
const int _maxLevel = 11;

double _roundSecondsForLevel(int level) =>
    max(_minRoundSeconds, _baseRoundSeconds - (level - 1));

double _scoreMultiplierForLevel(int level) => 1 + (level - 1) * 0.2;

int _maxHintsForLevel(int level) => max(0, _baseMaxHints - ((level - 1) ~/ 3));

int _hintPenaltyForLevel(int level) => _baseHintPenalty + (level - 1) * 5;

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late List<int> _board;
  final Set<int> _found = {};
  int _target = 1;
  int _level = 1;
  double _timeLeft = _baseRoundSeconds;
  int _score = 0;
  int _hintsLeft = _baseMaxHints;
  Timer? _timer;
  bool _paused = false;
  bool _roundLocked = false;
  bool _hintUsedThisRound = false;
  bool _gameOver = false;
  bool _won = false;
  int? _hintIndex;
  int? _wrongFlashIndex;
  int? _correctFlashIndex;
  int? _announcementLevel;
  int _highScore = 0;

  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    _bannerAd = AdmobService.createBanner(onLoaded: () => setState(() {}));
    AdmobService.preloadInterstitial();
    LeaderboardService.signIn();
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
    _level = 1;
    _hintsLeft = _maxHintsForLevel(1);
    _paused = false;
    _gameOver = false;
    _won = false;
    _hintIndex = null;
    _announcementLevel = 1;
    _startRound();
  }

  void _startRound() {
    if (_found.length >= _totalNumbers) {
      // Board cleared. On the final level that's a win; otherwise it
      // advances the level and deals a fresh, fully-reshuffled board so a
      // player can't just memorize positions over a long session.
      if (_level >= _maxLevel) {
        _endGame(won: true);
        return;
      }
      _level++;
      _board = List.generate(_totalNumbers, (i) => i + 1)..shuffle();
      _found.clear();
      _hintsLeft = min(_hintsLeft, _maxHintsForLevel(_level));
      _announcementLevel = _level;
    }
    final remaining = _board.where((n) => !_found.contains(n)).toList()
      ..shuffle();
    _target = remaining.first;
    _timeLeft = _roundSecondsForLevel(_level);
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
    SoundService.playSelect();

    if (value == _target) {
      _timer?.cancel();
      final gained = _hintUsedThisRound
          ? 0
          : ((10 + (_timeLeft / _roundSecondsForLevel(_level) * 90)) *
                    _scoreMultiplierForLevel(_level))
                .round();
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
    SoundService.playHint();
    final idx = _board.indexOf(_target);
    setState(() {
      _hintsLeft -= 1;
      _hintIndex = idx;
      _hintUsedThisRound = true;
      _score = max(0, _score - _hintPenaltyForLevel(_level));
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
    if (won) {
      SoundService.playMenuConfirm();
    } else {
      SoundService.playFail();
    }
    final isNewHigh = await SaveService.submitScore(_score);
    if (!mounted) return;
    setState(() {
      _gameOver = true;
      _won = won;
      if (isNewHigh) _highScore = _score;
    });
    LeaderboardService.submitScore(_score);
    AdmobService.showInterstitial();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // The back button must never exit mid-round: that would either quit
      // straight past a running countdown or (worse) let a player back out
      // to peek-then-return, same cheat risk as the pause screen's board
      // visibility. Back always toggles pause instead of popping, and only
      // pops for real once the game has actually ended.
      canPop: _gameOver,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        SoundService.playMenuBack();
        _togglePause();
      },
      child: Scaffold(
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
                  _HudBar(
                    timeLeft: _timeLeft,
                    target: _target,
                    score: _score,
                    level: _level,
                  ),
                  Expanded(child: _buildGrid()),
                  _buildBottomBar(),
                ],
              ),
              if (_announcementLevel != null)
                LevelAnnouncement(
                  key: ValueKey(_announcementLevel),
                  text: 'LEVEL $_announcementLevel',
                  onComplete: () {
                    if (mounted) setState(() => _announcementLevel = null);
                  },
                ),
              if (_paused && !_gameOver)
                _PauseOverlay(
                  onResume: () {
                    SoundService.playMenuBack();
                    _togglePause();
                  },
                  onRestart: () {
                    SoundService.playMenuConfirm();
                    _newGame();
                  },
                  onExit: () {
                    SoundService.playMenuConfirm();
                    Navigator.of(context).pop();
                  },
                ),
              if (_gameOver)
                _GameOverOverlay(
                  won: _won,
                  score: _score,
                  level: _level,
                  highScore: _highScore,
                  onRestart: () {
                    SoundService.playMenuConfirm();
                    _newGame();
                  },
                  onExit: () {
                    SoundService.playMenuConfirm();
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
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
          final cellWidth =
              (constraints.maxWidth - spacing * (_gridCols - 1)) / _gridCols;
          final cellHeight =
              (constraints.maxHeight - spacing * (_gridRows - 1)) / _gridRows;
          // Font/border/icon sized off the *actual* rendered cell (not a
          // global screen-size scale factor) so digits stay legible whether
          // the grid is squeezed onto a small phone or given a whole iPad's
          // worth of space to spread out in — cells that are physically
          // bigger get bigger numbers automatically.
          final cellMin = min(cellWidth, cellHeight);
          final cellFontSize = (cellMin * 0.42).clamp(12.0, 40.0);
          final cellBorderWidth = (cellMin * 0.045).clamp(2.0, 5.0);
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
                fontSize: cellFontSize,
                borderWidth: cellBorderWidth,
                onTap: () => _onCellTap(index),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBottomBar() {
    final scale = uiScale(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16 * scale,
        vertical: 14 * scale,
      ),
      decoration: const BoxDecoration(color: Color(0xFFFCE4EC)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: PillButton(
              label: 'RESTART',
              color: const Color(0xFF4CAF50),
              icon: Icons.refresh,
              onPressed: () {
                SoundService.playMenuConfirm();
                _newGame();
              },
            ),
          ),
          SizedBox(width: 10 * scale),
          Expanded(
            child: PillButton(
              label: 'HINT',
              color: const Color(0xFFFFA000),
              icon: Icons.lightbulb,
              badge: _hintsLeft,
              onPressed: _hintsLeft > 0 ? _useHint : null,
            ),
          ),
          SizedBox(width: 10 * scale),
          Expanded(
            child: PillButton(
              label: _paused ? 'RESUME' : 'PAUSE',
              color: const Color(0xFF43A047),
              icon: _paused ? Icons.play_arrow : Icons.pause,
              onPressed: () {
                if (_paused) {
                  SoundService.playMenuBack();
                } else {
                  SoundService.playMenuConfirm();
                }
                _togglePause();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HudBar extends StatelessWidget {
  const _HudBar({
    required this.timeLeft,
    required this.target,
    required this.score,
    required this.level,
  });

  final double timeLeft;
  final int target;
  final int score;
  final int level;

  @override
  Widget build(BuildContext context) {
    final urgent = timeLeft <= 3;
    final scale = uiScale(context);
    return Container(
      color: const Color(0xFF9CCC65),
      padding: EdgeInsets.symmetric(
        vertical: 10 * scale,
        horizontal: 12 * scale,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              children: [
                Text(
                  'TIME',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14 * scale,
                    color: Colors.white,
                  ),
                ),
                Text(
                  timeLeft.ceil().toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 26 * scale,
                    color: urgent ? Colors.red : const Color(0xFFB71C1C),
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'LV $level',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12 * scale,
                  color: const Color(0xFF1B5E20),
                ),
              ),
              SizedBox(height: 2 * scale),
              Container(
                width: 78 * scale,
                height: 78 * scale,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF33691E),
                    width: 4 * scale,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  '$target',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 30 * scale,
                    color: const Color(0xFFD81B60),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'SCORE',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14 * scale,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '$score',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 26 * scale,
                    color: const Color(0xFF1B5E20),
                  ),
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
    required this.fontSize,
    required this.borderWidth,
    required this.onTap,
  });

  final int value;
  final bool found;
  final bool hinted;
  final bool wrongFlash;
  final bool correctFlash;
  final double fontSize;
  final double borderWidth;
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
          border: Border.all(color: border, width: borderWidth),
        ),
        alignment: Alignment.center,
        child: found
            ? Icon(
                Icons.check,
                size: fontSize * 1.05,
                color: const Color(0xFFB0BEC5),
              )
            : Text(
                '$value',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: fontSize,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({
    required this.onResume,
    required this.onRestart,
    required this.onExit,
  });

  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final scale = uiScale(context);
    return Container(
      // Fully opaque — unlike the game-over overlay, this one must hide the
      // board completely. A translucent pause screen would let a player
      // pause mid-round to study the grid at their leisure and beat the
      // timer, which defeats the whole "find it before time runs out" rule.
      color: const Color(0xFF1B5E20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pause_circle_filled,
              color: Colors.white,
              size: 64 * scale,
            ),
            SizedBox(height: 12 * scale),
            Text(
              'PAUSED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28 * scale,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 16 * scale),
            ValueListenableBuilder<bool>(
              valueListenable: SoundService.enabledNotifier,
              builder: (context, enabled, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    enabled ? Icons.volume_up : Icons.volume_off,
                    color: Colors.white70,
                    size: 24 * scale,
                  ),
                  SizedBox(width: 8 * scale),
                  Text(
                    'Sound',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14 * scale,
                    ),
                  ),
                  SizedBox(width: 8 * scale),
                  // Not scaled with the rest of the overlay: Transform.scale
                  // enlarges the Switch visually without reserving the extra
                  // layout space, which overlapped the "Sound" label on a
                  // tablet-sized `scale` — its default size is already a
                  // comfortable tap target on any screen.
                  Switch(value: enabled, onChanged: SoundService.setEnabled),
                ],
              ),
            ),
            SizedBox(height: 8 * scale),
            SizedBox(
              width: 200 * scale,
              child: PillButton(
                label: 'RESUME',
                color: Colors.green,
                icon: Icons.play_arrow,
                onPressed: onResume,
              ),
            ),
            SizedBox(height: 12 * scale),
            SizedBox(
              width: 200 * scale,
              child: PillButton(
                label: 'RESTART',
                color: Colors.orange,
                icon: Icons.refresh,
                onPressed: onRestart,
              ),
            ),
            SizedBox(height: 12 * scale),
            SizedBox(
              width: 200 * scale,
              child: PillButton(
                label: 'MENU',
                color: Colors.blueGrey,
                icon: Icons.home,
                onPressed: onExit,
              ),
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
    required this.level,
    required this.highScore,
    required this.onRestart,
    required this.onExit,
  });

  final bool won;
  final int score;
  final int level;
  final int highScore;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final scale = uiScale(context);
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: EdgeInsets.symmetric(
            vertical: 28 * scale,
            horizontal: 24 * scale,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                won ? Icons.emoji_events : Icons.timer_off,
                color: won ? Colors.amber : Colors.redAccent,
                size: 56 * scale,
              ),
              SizedBox(height: 12 * scale),
              Text(
                won ? 'YOU WIN!' : "TIME'S UP!",
                style: TextStyle(
                  fontSize: 24 * scale,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8 * scale),
              Text(
                'Level reached: $level',
                style: TextStyle(fontSize: 16 * scale),
              ),
              Text('Score: $score', style: TextStyle(fontSize: 18 * scale)),
              Text(
                'High Score: $highScore',
                style: TextStyle(
                  fontSize: 14 * scale,
                  color: Colors.grey.shade600,
                ),
              ),
              SizedBox(height: 20 * scale),
              SizedBox(
                width: 200 * scale,
                child: PillButton(
                  label: 'RESTART',
                  color: Colors.green,
                  icon: Icons.refresh,
                  onPressed: onRestart,
                ),
              ),
              SizedBox(height: 10 * scale),
              SizedBox(
                width: 200 * scale,
                child: PillButton(
                  label: 'MENU',
                  color: Colors.blueGrey,
                  icon: Icons.home,
                  onPressed: onExit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
