import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../models/game_mode.dart';
import '../services/achievement_service.dart';
import '../services/admob_service.dart';
import '../services/haptic_service.dart';
import '../services/leaderboard_service.dart';
import '../services/music_service.dart';
import '../services/share_service.dart';
import '../services/sound_service.dart';
import '../services/stats_service.dart';
import '../services/theme_service.dart';
import '../utils/responsive.dart';
import '../widgets/level_announcement.dart';
import '../widgets/pill_button.dart';

const int _gridCols = 9;
const int _gridRows = 11;
const int _totalNumbers = _gridCols * _gridRows; // 99

// ---- Classic ----------------------------------------------------------------
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

// From level 6 the still-unfound numbers swap places every few finds, so a
// player can't rely on having scanned the board earlier in the level.
const int _shuffleFromLevel = 6;
const int _fastShuffleFromLevel = 9;
int _findsPerShuffle(int level) => level >= _fastShuffleFromLevel ? 3 : 5;

// ---- Daily ------------------------------------------------------------------
const double _dailyRoundSeconds = 10.0;
const int _dailyHints = 3;
const int _dailyHintPenalty = 10;

// ---- Zen / Time Attack --------------------------------------------------------
const int _zenHints = 3;
const int _zenHintPenaltyMs = 5000;
const int _zenWrongTapPenaltyMs = 1000;
const double _timeAttackSeconds = 60.0;
const double _timeAttackWrongTapPenalty = 1.0;

// ---- Combo --------------------------------------------------------------------
// A catch within this long of the target appearing (and without a hint)
// extends the combo; anything slower, a hint or a wrong tap resets it. In
// Classic/Daily each combo step past the first adds 5% to the catch's score,
// capped at +50%.
const int _comboWindowMs = 2500;
const int _maxComboBonusSteps = 10;

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.mode = GameMode.classic});

  final GameMode mode;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  GameMode get _mode => widget.mode;

  late List<int> _board;
  final Set<int> _found = {};

  /// Daily only: the day's fixed target order (same for every player).
  List<int> _dailyOrder = const [];
  int _target = 1;
  int _level = 1;

  /// The per-number countdown in Classic/Daily; the whole-run clock in Time
  /// Attack. Unused in Zen.
  double _timeLeft = 0;

  /// Zen: time spent so far, plus time added for hints and wrong taps.
  int _elapsedMs = 0;
  int _penaltyMs = 0;

  /// Points in Classic/Daily; numbers found in Time Attack; unused in Zen.
  int _score = 0;
  int _hintsLeft = 0;
  Timer? _ticker;
  bool _paused = false;
  bool _adShowing = false;
  bool _reviveOffer = false;
  bool _revived = false;
  bool _usedRewardedThisRun = false;
  bool _rewardedHintThisBoard = false;
  bool _roundLocked = false;
  bool _hintUsedThisRound = false;
  bool _gameOver = false;
  bool _won = false;
  bool _newBest = false;

  /// Daily only: whether this is today's one counted attempt (vs practice).
  bool _dailyCounted = false;
  int? _hintIndex;
  int? _wrongFlashIndex;
  int? _correctFlashIndex;
  String? _announcement;
  int _announcementId = 0;
  int _sinceTargetMs = 0;
  int _runFound = 0;
  int _runReactionMs = 0;
  int _runBoardsCleared = 0;
  int _combo = 0;
  int _bestComboThisRun = 0;
  int _findsSinceShuffle = 0;
  List<AchievementDef> _newAchievements = const [];

  BannerAd? _bannerAd;

  int get _zenTotalMs => _elapsedMs + _penaltyMs;

  double get _roundSeconds => _mode == GameMode.daily
      ? _dailyRoundSeconds
      : _roundSecondsForLevel(_level);

  bool get _frozen => _paused || _adShowing || _reviveOffer || _gameOver;

  /// Out of hints, and a rewarded ad could buy one more (once per board).
  bool get _canWatchForHint =>
      (_mode == GameMode.classic || _mode == GameMode.zen) &&
      _hintsLeft <= 0 &&
      !_rewardedHintThisBoard &&
      AdmobService.rewardedReady;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bannerAd = AdmobService.createBanner(onLoaded: () => setState(() {}));
    AdmobService.preloadInterstitial();
    if (_mode == GameMode.classic || _mode == GameMode.zen) {
      AdmobService.preloadRewarded();
    }
    LeaderboardService.signIn();
    MusicService.playGame();
    _newGame();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), _tick);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Leaving the app mid-round (home button, incoming call) pauses instead
    // of letting the clock run out in the background. A rewarded ad also
    // backgrounds the Flutter activity, hence the _adShowing exception.
    if (state != AppLifecycleState.resumed && !_frozen) {
      setState(() => _paused = true);
    }
  }

  List<int> _freshBoard([Random? rng]) =>
      List.generate(_totalNumbers, (i) => i + 1)..shuffle(rng);

  void _announce(String text) {
    _announcement = text;
    _announcementId++;
  }

  void _newGame() {
    _dailyCounted = _mode == GameMode.daily && !StatsService.dailyPlayedToday;
    if (_dailyCounted) StatsService.startDailyAttempt();
    if (_mode == GameMode.daily) {
      // Same seed for everyone on the same calendar day → same board and
      // same target order, so the daily leaderboard compares like for like.
      final rng = Random(StatsService.todayKey);
      _board = _freshBoard(rng);
      _dailyOrder = _freshBoard(rng);
    } else {
      _board = _freshBoard();
    }
    _found.clear();
    _score = 0;
    _level = 1;
    _elapsedMs = 0;
    _penaltyMs = 0;
    _timeLeft = _mode == GameMode.timeAttack ? _timeAttackSeconds : 0;
    _hintsLeft = switch (_mode) {
      GameMode.classic => _maxHintsForLevel(1),
      GameMode.daily => _dailyHints,
      GameMode.zen => _zenHints,
      GameMode.timeAttack => 0,
    };
    _paused = false;
    _adShowing = false;
    _reviveOffer = false;
    _revived = false;
    _usedRewardedThisRun = false;
    _rewardedHintThisBoard = false;
    _gameOver = false;
    _won = false;
    _newBest = false;
    _hintIndex = null;
    _runFound = 0;
    _runReactionMs = 0;
    _runBoardsCleared = 0;
    _combo = 0;
    _bestComboThisRun = 0;
    _findsSinceShuffle = 0;
    _newAchievements = const [];
    _announce(switch (_mode) {
      GameMode.classic => 'LEVEL 1',
      GameMode.daily => _dailyCounted ? 'DAILY\nCHALLENGE' : 'PRACTICE',
      GameMode.zen => 'ZEN\n1 → 99',
      GameMode.timeAttack => '60 SECONDS',
    });
    _startRound();
  }

  void _startRound() {
    if (_found.length >= _totalNumbers) {
      _runBoardsCleared++;
      switch (_mode) {
        case GameMode.classic:
          // On the final level a clear is a win; otherwise it advances the
          // level and deals a fresh, fully-reshuffled board so a player
          // can't just memorize positions over a long session.
          if (_level >= _maxLevel) {
            _endGame(won: true);
            return;
          }
          _level++;
          _board = _freshBoard();
          _found.clear();
          _hintsLeft = min(_hintsLeft, _maxHintsForLevel(_level));
          _rewardedHintThisBoard = false;
          _findsSinceShuffle = 0;
          _announce(
            _level == _shuffleFromLevel
                ? 'LEVEL $_level\nSHUFFLE!'
                : 'LEVEL $_level',
          );
        case GameMode.daily || GameMode.zen:
          _endGame(won: true);
          return;
        case GameMode.timeAttack:
          _board = _freshBoard();
          _found.clear();
          _announce('NEW BOARD');
      }
    }
    _target = switch (_mode) {
      GameMode.daily => _dailyOrder[_found.length],
      GameMode.zen => _found.length + 1,
      _ => (_board.where((n) => !_found.contains(n)).toList()..shuffle()).first,
    };
    if (_mode == GameMode.classic || _mode == GameMode.daily) {
      _timeLeft = _roundSeconds;
    }
    _sinceTargetMs = 0;
    _roundLocked = false;
    _hintUsedThisRound = false;
    _hintIndex = null;
    if (mounted) setState(() {});
  }

  void _tick(Timer t) {
    if (_frozen) return;
    var timedOut = false;
    setState(() {
      switch (_mode) {
        case GameMode.classic || GameMode.daily:
          // The per-number countdown holds during the short correct-catch
          // lock, same as before modes existed.
          if (_roundLocked) return;
          _sinceTargetMs += 100;
          _timeLeft = max(0, _timeLeft - 0.1);
          timedOut = _timeLeft <= 0;
        case GameMode.zen:
          _elapsedMs += 100;
          _sinceTargetMs += 100;
        case GameMode.timeAttack:
          _sinceTargetMs += 100;
          _timeLeft = max(0, _timeLeft - 0.1);
          timedOut = _timeLeft <= 0;
      }
    });
    if (!timedOut) return;
    if (_mode == GameMode.classic && !_revived && AdmobService.rewardedReady) {
      SoundService.playGameOver();
      HapticService.wrong();
      setState(() => _reviveOffer = true);
    } else {
      _endGame(won: false);
    }
  }

  void _onCellTap(int index) {
    if (_frozen || _roundLocked) return;
    final value = _board[index];
    if (_found.contains(value)) return;

    if (value == _target) {
      SoundService.playSelect();
      final reactionMs = _sinceTargetMs;
      final fast = !_hintUsedThisRound && reactionMs <= _comboWindowMs;
      final combo = fast ? _combo + 1 : 0;
      var gained = 0;
      if (_mode == GameMode.timeAttack) {
        gained = 1;
      } else if (_mode != GameMode.zen && !_hintUsedThisRound) {
        final levelMultiplier = _mode == GameMode.classic
            ? _scoreMultiplierForLevel(_level)
            : 1.0;
        final comboBonus = combo >= 2
            ? 1 + 0.05 * min(combo - 1, _maxComboBonusSteps)
            : 1.0;
        gained =
            ((10 + (_timeLeft / _roundSeconds * 90)) *
                    levelMultiplier *
                    comboBonus)
                .round();
      }
      if (combo >= 5 && combo % 5 == 0) {
        HapticService.comboMilestone();
      } else {
        HapticService.correct();
      }
      setState(() {
        _score += gained;
        _found.add(value);
        _combo = combo;
        _bestComboThisRun = max(_bestComboThisRun, combo);
        _runFound++;
        _runReactionMs += reactionMs;
        _roundLocked = true;
        _correctFlashIndex = index;
      });
      final lockMs = _mode == GameMode.zen || _mode == GameMode.timeAttack
          ? 150
          : 350;
      Future.delayed(Duration(milliseconds: lockMs), () {
        if (!mounted || _gameOver) return;
        setState(() => _correctFlashIndex = null);
        _maybeShuffle();
        _startRound();
      });
    } else {
      SoundService.playWrong();
      HapticService.wrong();
      setState(() {
        _combo = 0;
        _wrongFlashIndex = index;
        if (_mode == GameMode.zen) _penaltyMs += _zenWrongTapPenaltyMs;
        if (_mode == GameMode.timeAttack) {
          _timeLeft = max(0, _timeLeft - _timeAttackWrongTapPenalty);
        }
      });
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        setState(() => _wrongFlashIndex = null);
      });
    }
  }

  /// Classic level 6+: permutes the still-unfound numbers among the
  /// still-unfound cells every [_findsPerShuffle] finds. Found cells keep
  /// their place, so the board's "holes" don't move.
  void _maybeShuffle() {
    if (_mode != GameMode.classic || _level < _shuffleFromLevel) return;
    if (_found.length >= _totalNumbers) return;
    if (++_findsSinceShuffle < _findsPerShuffle(_level)) return;
    _findsSinceShuffle = 0;
    final cells = [
      for (var i = 0; i < _totalNumbers; i++)
        if (!_found.contains(_board[i])) i,
    ];
    if (cells.length < 2) return;
    final values = [for (final i in cells) _board[i]]..shuffle();
    for (var k = 0; k < cells.length; k++) {
      _board[cells[k]] = values[k];
    }
  }

  void _useHint() {
    if (_frozen || _roundLocked) return;
    if (_hintsLeft <= 0) {
      if (_canWatchForHint) _watchAdForHint();
      return;
    }
    SoundService.playHint();
    final idx = _board.indexOf(_target);
    setState(() {
      _hintsLeft -= 1;
      _hintIndex = idx;
      _hintUsedThisRound = true;
      _combo = 0;
      switch (_mode) {
        case GameMode.classic:
          _score = max(0, _score - _hintPenaltyForLevel(_level));
        case GameMode.daily:
          _score = max(0, _score - _dailyHintPenalty);
        case GameMode.zen:
          _penaltyMs += _zenHintPenaltyMs;
        case GameMode.timeAttack:
          break;
      }
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      setState(() => _hintIndex = null);
    });
  }

  Future<void> _watchAdForHint() async {
    SoundService.playMenuConfirm();
    setState(() => _adShowing = true);
    final earned = await AdmobService.showRewarded();
    if (!mounted) return;
    setState(() {
      _adShowing = false;
      if (earned) {
        _hintsLeft += 1;
        _rewardedHintThisBoard = true;
        _usedRewardedThisRun = true;
      }
    });
  }

  Future<void> _revive() async {
    SoundService.playMenuConfirm();
    setState(() => _adShowing = true);
    final earned = await AdmobService.showRewarded();
    if (!mounted) return;
    if (earned) {
      setState(() {
        _adShowing = false;
        _reviveOffer = false;
        _revived = true;
        _usedRewardedThisRun = true;
        _timeLeft = _roundSeconds;
        _sinceTargetMs = 0;
        _combo = 0;
      });
    } else {
      setState(() {
        _adShowing = false;
        _reviveOffer = false;
      });
      _endGame(won: false, sfx: false);
    }
  }

  void _declineRevive() {
    SoundService.playMenuBack();
    setState(() => _reviveOffer = false);
    _endGame(won: false, sfx: false);
  }

  void _togglePause() {
    if (_gameOver || _reviveOffer) return;
    setState(() => _paused = !_paused);
  }

  bool _isNewBest(bool won) => switch (_mode) {
    GameMode.classic => _score > StatsService.classicHighScore,
    GameMode.daily => _dailyCounted && _score > StatsService.dailyBestScore,
    GameMode.zen =>
      won &&
          (StatsService.zenBestMs == 0 || _zenTotalMs < StatsService.zenBestMs),
    GameMode.timeAttack => _score > StatsService.timeAttackBest,
  };

  Future<void> _recordRun(bool won) async {
    final counted = _mode != GameMode.daily || _dailyCounted;
    await StatsService.recordRun(
      found: _runFound,
      reactionMs: _runReactionMs,
      boardsClearedThisRun: _runBoardsCleared,
      bestComboThisRun: _bestComboThisRun,
      classicScore: _mode == GameMode.classic ? _score : null,
      classicLevel: _mode == GameMode.classic ? _level : null,
      classicWon: _mode == GameMode.classic && won,
      dailyScore: _mode == GameMode.daily && _dailyCounted ? _score : null,
      zenMs: _mode == GameMode.zen && won ? _zenTotalMs : null,
      timeAttackFound: _mode == GameMode.timeAttack ? _score : null,
    );
    if (!counted) return;
    switch (_mode) {
      case GameMode.classic:
        LeaderboardService.submitScore(Board.classic, _score);
      case GameMode.daily:
        LeaderboardService.submitScore(Board.daily, _score);
      case GameMode.zen:
        if (won) LeaderboardService.submitScore(Board.zen, _zenTotalMs);
      case GameMode.timeAttack:
        LeaderboardService.submitScore(Board.timeAttack, _score);
    }
  }

  Future<void> _endGame({required bool won, bool sfx = true}) async {
    if (_gameOver) return;
    final newBest = _isNewBest(won);
    if (sfx) {
      // Time Attack always "ends on time", so it only celebrates a new best.
      if (won || (_mode == GameMode.timeAttack && newBest)) {
        SoundService.playWin();
      } else {
        SoundService.playGameOver();
      }
    }
    setState(() {
      _gameOver = true;
      _won = won;
      _newBest = newBest;
    });
    await _recordRun(won);
    final fresh = await AchievementService.evaluate();
    if (!mounted) return;
    setState(() => _newAchievements = fresh);
    // A player who just sat through a rewarded ad this run doesn't also get
    // an interstitial on top of it.
    if (!_usedRewardedThisRun) AdmobService.showInterstitial();
  }

  /// Leaving or restarting today's counted Daily attempt mid-run still
  /// records what was scored — the attempt was already used up when it
  /// started (see StatsService.startDailyAttempt).
  void _abandonCountedDaily() {
    if (_gameOver || !_dailyCounted) return;
    _recordRun(false);
    AchievementService.evaluate();
    _dailyCounted = false;
  }

  void _restart() {
    SoundService.playMenuConfirm();
    _abandonCountedDaily();
    _newGame();
  }

  void _exitToMenu() {
    SoundService.playMenuConfirm();
    _abandonCountedDaily();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeService.current.value;
    return PopScope(
      // The back button must never exit mid-round: that would either quit
      // straight past a running countdown or (worse) let a player back out
      // to peek-then-return, same cheat risk as the pause screen's board
      // visibility. Back always toggles pause instead of popping (or
      // declines a revive offer), and only pops for real once the game has
      // actually ended.
      canPop: _gameOver,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _adShowing) return;
        if (_reviveOffer) {
          _declineRevive();
          return;
        }
        SoundService.playMenuBack();
        _togglePause();
      },
      child: Scaffold(
        backgroundColor: theme.gameBg,
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
                  _buildHud(theme),
                  Expanded(child: _buildGrid(theme)),
                  _buildBottomBar(theme),
                ],
              ),
              if (_announcement != null)
                LevelAnnouncement(
                  key: ValueKey(_announcementId),
                  text: _announcement!,
                  onComplete: () {
                    if (mounted) setState(() => _announcement = null);
                  },
                ),
              if (_paused && !_gameOver)
                _PauseOverlay(
                  background: theme.pauseBg,
                  onResume: () {
                    SoundService.playMenuBack();
                    _togglePause();
                  },
                  // A counted Daily attempt can't be restarted — it would
                  // just turn into practice; MENU still records it.
                  onRestart: _dailyCounted ? null : _restart,
                  onExit: _exitToMenu,
                ),
              if (_reviveOffer)
                _ReviveOverlay(
                  background: theme.pauseBg,
                  busy: _adShowing,
                  onContinue: _revive,
                  onDecline: _declineRevive,
                ),
              if (_gameOver) _buildResults(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHud(GameTheme theme) {
    final (
      String centerLabel,
      String rightLabel,
      String rightValue,
    ) = switch (_mode) {
      GameMode.classic => ('LV $_level', 'SCORE', '$_score'),
      GameMode.daily => (
        _dailyCounted ? 'DAILY' : 'PRACTICE',
        'SCORE',
        '$_score',
      ),
      GameMode.zen => ('ZEN', 'FOUND', '${_found.length}/99'),
      GameMode.timeAttack => ('60s', 'FOUND', '$_score'),
    };
    final timeValue = _mode == GameMode.zen
        ? formatMillis(_zenTotalMs)
        : _timeLeft.ceil().toString();
    final urgent = switch (_mode) {
      GameMode.zen => false,
      GameMode.timeAttack => _timeLeft <= 10,
      _ => _timeLeft <= 3,
    };
    return _HudBar(
      theme: theme,
      timeValue: timeValue,
      urgent: urgent,
      centerLabel: centerLabel,
      target: _target,
      rightLabel: rightLabel,
      rightValue: rightValue,
      combo: _combo,
    );
  }

  Widget _buildGrid(GameTheme theme) {
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
              return _NumberCell(
                theme: theme,
                value: value,
                found: _found.contains(value),
                hinted: _hintIndex == index,
                wrongFlash: _wrongFlashIndex == index,
                correctFlash: _correctFlashIndex == index,
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

  Widget _buildBottomBar(GameTheme theme) {
    final scale = uiScale(context);
    final adHint = _canWatchForHint;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16 * scale,
        vertical: 14 * scale,
      ),
      decoration: BoxDecoration(color: theme.bottomBar),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: PillButton(
              label: 'RESTART',
              color: const Color(0xFF4CAF50),
              icon: Icons.refresh,
              onPressed: _dailyCounted ? null : _restart,
            ),
          ),
          SizedBox(width: 10 * scale),
          Expanded(
            child: PillButton(
              label: adHint ? '+1 HINT' : 'HINT',
              color: adHint ? const Color(0xFF8E24AA) : const Color(0xFFFFA000),
              icon: adHint ? Icons.ondemand_video : Icons.lightbulb,
              badge: adHint ? null : _hintsLeft,
              onPressed: _hintsLeft > 0 || adHint ? _useHint : null,
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

  Widget _buildResults() {
    final zenTime = formatMillis(_zenTotalMs);
    final (IconData icon, Color iconColor, String title) = switch (_mode) {
      GameMode.classic when _won => (
        Icons.emoji_events,
        Colors.amber,
        'YOU WIN!',
      ),
      GameMode.daily when _won => (
        Icons.emoji_events,
        Colors.amber,
        'BOARD CLEARED!',
      ),
      GameMode.zen => (Icons.self_improvement, Colors.teal, 'FINISHED!'),
      GameMode.timeAttack => (Icons.timer, Colors.amber, "TIME'S UP!"),
      _ => (Icons.timer_off, Colors.redAccent, "TIME'S UP!"),
    };
    final lines = switch (_mode) {
      GameMode.classic => [
        'Level reached: $_level',
        'Score: $_score',
        'High Score: ${StatsService.classicHighScore}',
      ],
      GameMode.daily => [
        'Score: $_score',
        'Found: $_runFound/99',
        // _dailyCounted is only recomputed on the next _newGame, so it's
        // still true on the counted attempt's own result screen.
        if (_dailyCounted)
          'Streak: ${StatsService.dailyStreak} day${StatsService.dailyStreak == 1 ? '' : 's'}'
        else
          "Practice — today's score: ${StatsService.dailyTodayScore}",
      ],
      GameMode.zen => [
        'Time: $zenTime',
        'Best: ${formatMillis(StatsService.zenBestMs)}',
      ],
      GameMode.timeAttack => [
        'Found: $_score',
        'Best: ${StatsService.timeAttackBest}',
      ],
    };
    return _GameOverOverlay(
      icon: icon,
      iconColor: iconColor,
      title: title,
      lines: lines,
      newBest: _newBest,
      achievements: _newAchievements,
      restartLabel: _mode == GameMode.daily ? 'PRACTICE' : 'RESTART',
      onShare: _share,
      onRestart: _restart,
      onExit: _exitToMenu,
    );
  }

  void _share(Rect? origin) {
    SoundService.playMenuConfirm();
    final date = StatsService.todayKey.toString();
    final dateStr =
        '${date.substring(0, 4)}-${date.substring(4, 6)}-${date.substring(6)}';
    final streak = StatsService.dailyStreak;
    final zenTime = formatMillis(_zenTotalMs);
    final (
      String headline,
      String caption,
      String detail,
      String text,
    ) = switch (_mode) {
      GameMode.classic => (
        '$_score',
        'POINTS',
        _won ? 'Cleared all 11 levels!' : 'Reached level $_level',
        'I scored $_score points in 99 Numbers '
            '(${_won ? 'cleared all 11 levels' : 'level $_level'})! '
            'Can you beat me?',
      ),
      GameMode.daily => (
        '$_score',
        'POINTS',
        'Daily $dateStr · $streak-day streak',
        'Daily Challenge $dateStr: $_score points in 99 Numbers '
            '($streak-day streak). Same board for everyone today — '
            'can you beat me?',
      ),
      GameMode.zen => (
        zenTime,
        'TO FIND 1 → 99',
        'Zen mode',
        'I found every number from 1 to 99 in $zenTime in 99 Numbers! '
            'Can you beat me?',
      ),
      GameMode.timeAttack => (
        '$_score',
        'NUMBERS IN 60 SECONDS',
        'Time Attack',
        'I found $_score numbers in 60 seconds in 99 Numbers! '
            'Can you beat me?',
      ),
    };
    ShareService.shareResult(
      modeTitle: _mode.title,
      headline: headline,
      caption: caption,
      detail: detail,
      text: text,
      origin: origin,
    );
  }
}

class _HudBar extends StatelessWidget {
  const _HudBar({
    required this.theme,
    required this.timeValue,
    required this.urgent,
    required this.centerLabel,
    required this.target,
    required this.rightLabel,
    required this.rightValue,
    required this.combo,
  });

  final GameTheme theme;
  final String timeValue;
  final bool urgent;
  final String centerLabel;
  final int target;
  final String rightLabel;
  final String rightValue;
  final int combo;

  @override
  Widget build(BuildContext context) {
    final scale = uiScale(context);
    Widget column(String label, String value, Color color, {Widget? below}) =>
        Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14 * scale,
                color: theme.hudLabel,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 26 * scale,
                  color: color,
                ),
              ),
            ),
            // Fixed height so the HUD doesn't jump when a combo appears.
            SizedBox(height: 16 * scale, child: below),
          ],
        );
    return Container(
      color: theme.hud,
      padding: EdgeInsets.symmetric(
        vertical: 10 * scale,
        horizontal: 12 * scale,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: column('TIME', timeValue, urgent ? Colors.red : theme.time),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12 * scale,
                  color: theme.level,
                ),
              ),
              SizedBox(height: 2 * scale),
              Container(
                width: 78 * scale,
                height: 78 * scale,
                decoration: BoxDecoration(
                  color: theme.targetBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.targetBorder,
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
                    color: theme.targetText,
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: column(
              rightLabel,
              rightValue,
              theme.score,
              below: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: combo >= 2
                    ? Text(
                        'COMBO x$combo',
                        key: ValueKey(combo),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12 * scale,
                          color: theme.targetText,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberCell extends StatelessWidget {
  const _NumberCell({
    required this.theme,
    required this.value,
    required this.found,
    required this.hinted,
    required this.wrongFlash,
    required this.correctFlash,
    required this.fontSize,
    required this.borderWidth,
    required this.onTap,
  });

  final GameTheme theme;
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
    Color bg = theme.cell;
    Color border = theme.cellBorder;
    if (found) {
      bg = theme.found;
      border = theme.found;
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
    final textColor = wrongFlash || correctFlash
        ? Colors.white
        : hinted
        ? const Color(0xFF5D4037)
        : theme.cellText;
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
        // Keyed by value: a cell whose number changes (the level-6+
        // shuffle, a fresh board) or gets found pops instead of silently
        // swapping digits.
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: found
              ? Icon(
                  Icons.check,
                  key: ValueKey('found$value'),
                  size: fontSize * 1.05,
                  color: theme.foundIcon,
                )
              : Text(
                  '$value',
                  key: ValueKey(value),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: fontSize,
                    color: textColor,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.notifier,
    required this.onChanged,
    required this.label,
    required this.onIcon,
    required this.offIcon,
  });

  final ValueNotifier<bool> notifier;
  final ValueChanged<bool> onChanged;
  final String label;
  final IconData onIcon;
  final IconData offIcon;

  @override
  Widget build(BuildContext context) {
    final scale = uiScale(context);
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (context, enabled, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled ? onIcon : offIcon,
            color: Colors.white70,
            size: 24 * scale,
          ),
          SizedBox(width: 8 * scale),
          SizedBox(
            width: 80 * scale,
            child: Text(
              label,
              style: TextStyle(color: Colors.white70, fontSize: 14 * scale),
            ),
          ),
          // Not scaled with the rest of the overlay: Transform.scale
          // enlarges the Switch visually without reserving the extra layout
          // space, which overlapped the label on a tablet-sized `scale` —
          // its default size is already a comfortable tap target on any
          // screen.
          Switch(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({
    required this.background,
    required this.onResume,
    required this.onRestart,
    required this.onExit,
  });

  final Color background;
  final VoidCallback onResume;
  final VoidCallback? onRestart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final scale = uiScale(context);
    return Container(
      // Fully opaque — unlike the game-over overlay, this one must hide the
      // board completely. A translucent pause screen would let a player
      // pause mid-round to study the grid at their leisure and beat the
      // timer, which defeats the whole "find it before time runs out" rule.
      color: background,
      child: Center(
        child: SingleChildScrollView(
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
              _ToggleRow(
                notifier: MusicService.enabledNotifier,
                onChanged: MusicService.setEnabled,
                label: 'Music',
                onIcon: Icons.music_note,
                offIcon: Icons.music_off,
              ),
              _ToggleRow(
                notifier: SoundService.enabledNotifier,
                onChanged: SoundService.setEnabled,
                label: 'Sound',
                onIcon: Icons.volume_up,
                offIcon: Icons.volume_off,
              ),
              _ToggleRow(
                notifier: HapticService.enabledNotifier,
                onChanged: HapticService.setEnabled,
                label: 'Vibration',
                onIcon: Icons.vibration,
                offIcon: Icons.mobile_off,
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
      ),
    );
  }
}

class _ReviveOverlay extends StatelessWidget {
  const _ReviveOverlay({
    required this.background,
    required this.busy,
    required this.onContinue,
    required this.onDecline,
  });

  final Color background;

  /// The rewarded ad is on its way up — buttons disabled meanwhile.
  final bool busy;
  final VoidCallback onContinue;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final scale = uiScale(context);
    // Opaque for the same reason as the pause overlay: the countdown is
    // stopped while this is up, so the board must not be visible.
    return Container(
      color: background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_off, color: Colors.white, size: 64 * scale),
            SizedBox(height: 12 * scale),
            Text(
              "TIME'S UP!",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28 * scale,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8 * scale),
            Text(
              'Watch a short ad to keep going?',
              style: TextStyle(color: Colors.white70, fontSize: 15 * scale),
            ),
            SizedBox(height: 20 * scale),
            SizedBox(
              width: 220 * scale,
              child: PillButton(
                label: 'CONTINUE',
                color: const Color(0xFF8E24AA),
                icon: Icons.ondemand_video,
                onPressed: busy ? null : onContinue,
              ),
            ),
            SizedBox(height: 12 * scale),
            SizedBox(
              width: 220 * scale,
              child: PillButton(
                label: 'NO THANKS',
                color: Colors.blueGrey,
                onPressed: busy ? null : onDecline,
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
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.lines,
    required this.newBest,
    required this.achievements,
    required this.restartLabel,
    required this.onShare,
    required this.onRestart,
    required this.onExit,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> lines;
  final bool newBest;
  final List<AchievementDef> achievements;
  final String restartLabel;
  final void Function(Rect? origin) onShare;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final scale = uiScale(context);
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: EdgeInsets.symmetric(
              vertical: 24 * scale,
              horizontal: 24 * scale,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: iconColor, size: 56 * scale),
                SizedBox(height: 12 * scale),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 24 * scale,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (newBest) ...[
                  SizedBox(height: 6 * scale),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12 * scale,
                      vertical: 4 * scale,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'NEW BEST!',
                      style: TextStyle(
                        fontSize: 13 * scale,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 8 * scale),
                for (final (i, line) in lines.indexed)
                  Text(
                    line,
                    style: TextStyle(
                      fontSize: (i == 0 ? 18 : 15) * scale,
                      color: i == lines.length - 1 && lines.length > 1
                          ? Colors.grey.shade600
                          : null,
                    ),
                  ),
                for (final a in achievements) ...[
                  SizedBox(height: 8 * scale),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.military_tech,
                        color: Colors.amber.shade700,
                        size: 22 * scale,
                      ),
                      SizedBox(width: 6 * scale),
                      Flexible(
                        child: Text(
                          'Achievement: ${a.title}',
                          style: TextStyle(
                            fontSize: 14 * scale,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: 20 * scale),
                SizedBox(
                  width: 200 * scale,
                  child: Builder(
                    // Its own context, so the share sheet's iPad popover can
                    // anchor to this button.
                    builder: (buttonContext) => PillButton(
                      label: 'SHARE',
                      color: const Color(0xFF1E88E5),
                      icon: Icons.share,
                      onPressed: () {
                        final box =
                            buttonContext.findRenderObject() as RenderBox?;
                        onShare(
                          box == null
                              ? null
                              : box.localToGlobal(Offset.zero) & box.size,
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(height: 10 * scale),
                SizedBox(
                  width: 200 * scale,
                  child: PillButton(
                    label: restartLabel,
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
      ),
    );
  }
}
