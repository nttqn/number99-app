import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'stats_service.dart';

/// A full color set for the menu + game screen. The flash colors (wrong red,
/// correct green, hint yellow) are deliberately *not* themed — they're
/// gameplay signals and must read the same in every theme.
class GameTheme {
  const GameTheme({
    required this.id,
    required this.name,
    required this.unlockHint,
    required this.isUnlocked,
    required this.menuBg,
    required this.gameBg,
    required this.hud,
    required this.hudLabel,
    required this.time,
    required this.score,
    required this.level,
    required this.targetBg,
    required this.targetBorder,
    required this.targetText,
    required this.cell,
    required this.cellBorder,
    required this.cellText,
    required this.found,
    required this.foundIcon,
    required this.bottomBar,
    required this.title,
    required this.pauseBg,
  });

  final String id;
  final String name;

  /// Shown on a locked theme's card in the picker.
  final String unlockHint;
  final bool Function() isUnlocked;

  final Color menuBg;
  final Color gameBg;
  final Color hud;
  final Color hudLabel;
  final Color time;
  final Color score;
  final Color level;
  final Color targetBg;
  final Color targetBorder;
  final Color targetText;
  final Color cell;
  final Color cellBorder;
  final Color cellText;
  final Color found;
  final Color foundIcon;
  final Color bottomBar;

  /// Headline text on [menuBg] (title, high score, etc).
  final Color title;
  final Color pauseBg;
}

bool _always() => true;

class ThemeService {
  static const _prefKey = 'theme_id';

  static final List<GameTheme> all = [
    // The original look, matching the 2014 app's screenshot.
    const GameTheme(
      id: 'classic',
      name: 'Classic',
      unlockHint: '',
      isUnlocked: _always,
      menuBg: Color(0xFFBEE7B8),
      gameBg: Color(0xFFAEE7F0),
      hud: Color(0xFF9CCC65),
      hudLabel: Colors.white,
      time: Color(0xFFB71C1C),
      score: Color(0xFF1B5E20),
      level: Color(0xFF1B5E20),
      targetBg: Colors.white,
      targetBorder: Color(0xFF33691E),
      targetText: Color(0xFFD81B60),
      cell: Color(0xFF90CAF9),
      cellBorder: Color(0xFF1565C0),
      cellText: Colors.white,
      found: Color(0xFFE0E6E8),
      foundIcon: Color(0xFFB0BEC5),
      bottomBar: Color(0xFFFCE4EC),
      title: Color(0xFF1B5E20),
      pauseBg: Color(0xFF1B5E20),
    ),
    GameTheme(
      id: 'ocean',
      name: 'Ocean',
      unlockHint: 'Reach level 4 in Classic',
      isUnlocked: () => StatsService.bestLevel >= 4,
      menuBg: const Color(0xFFB3E5FC),
      gameBg: const Color(0xFFE1F5FE),
      hud: const Color(0xFF0277BD),
      hudLabel: const Color(0xFFB3E5FC),
      time: const Color(0xFFFFF59D),
      score: Colors.white,
      level: Colors.white,
      targetBg: Colors.white,
      targetBorder: const Color(0xFF01579B),
      targetText: const Color(0xFF00838F),
      cell: const Color(0xFF26C6DA),
      cellBorder: const Color(0xFF00838F),
      cellText: Colors.white,
      found: const Color(0xFFCFD8DC),
      foundIcon: const Color(0xFF90A4AE),
      bottomBar: const Color(0xFFB2EBF2),
      title: const Color(0xFF01579B),
      pauseBg: const Color(0xFF01579B),
    ),
    GameTheme(
      id: 'night',
      name: 'Night',
      unlockHint: 'Reach level 7 in Classic',
      isUnlocked: () => StatsService.bestLevel >= 7,
      menuBg: const Color(0xFF1A1F2B),
      gameBg: const Color(0xFF121621),
      hud: const Color(0xFF263248),
      hudLabel: const Color(0xFF90A4C8),
      time: const Color(0xFFFF8A80),
      score: const Color(0xFF80CBC4),
      level: const Color(0xFF90A4C8),
      targetBg: const Color(0xFF0D1018),
      targetBorder: const Color(0xFF5C6BC0),
      targetText: const Color(0xFFFFD54F),
      cell: const Color(0xFF2C3A57),
      cellBorder: const Color(0xFF5C6BC0),
      cellText: const Color(0xFFE8EAF6),
      found: const Color(0xFF1A2030),
      foundIcon: const Color(0xFF37474F),
      bottomBar: const Color(0xFF1A1F2B),
      title: const Color(0xFFE8EAF6),
      pauseBg: const Color(0xFF0D1018),
    ),
    GameTheme(
      id: 'sakura',
      name: 'Sakura',
      unlockHint: '7-day Daily Challenge streak',
      isUnlocked: () => StatsService.dailyBestStreak >= 7,
      menuBg: const Color(0xFFFCE4EC),
      gameBg: const Color(0xFFFFF0F5),
      hud: const Color(0xFFF48FB1),
      hudLabel: Colors.white,
      time: const Color(0xFF880E4F),
      score: const Color(0xFF880E4F),
      level: const Color(0xFF880E4F),
      targetBg: Colors.white,
      targetBorder: const Color(0xFFAD1457),
      targetText: const Color(0xFFC2185B),
      cell: const Color(0xFFF8BBD0),
      cellBorder: const Color(0xFFEC407A),
      cellText: const Color(0xFF880E4F),
      found: const Color(0xFFF3E5F5),
      foundIcon: const Color(0xFFCE93D8),
      bottomBar: const Color(0xFFF8BBD0),
      title: const Color(0xFFAD1457),
      pauseBg: const Color(0xFFAD1457),
    ),
    GameTheme(
      id: 'neon',
      name: 'Neon',
      unlockHint: 'Win Classic (clear level 11)',
      isUnlocked: () => StatsService.classicWins >= 1,
      menuBg: const Color(0xFF0B0B1A),
      gameBg: const Color(0xFF07070F),
      hud: const Color(0xFF140A2E),
      hudLabel: const Color(0xFF00E5FF),
      time: const Color(0xFFFF4081),
      score: const Color(0xFF76FF03),
      level: const Color(0xFF00E5FF),
      targetBg: Colors.black,
      targetBorder: const Color(0xFFE040FB),
      targetText: const Color(0xFF00E5FF),
      cell: const Color(0xFF0F1B2E),
      cellBorder: const Color(0xFF00E5FF),
      cellText: const Color(0xFF00E5FF),
      found: const Color(0xFF0B0B14),
      foundIcon: const Color(0xFF263238),
      bottomBar: const Color(0xFF140A2E),
      title: const Color(0xFF00E5FF),
      pauseBg: const Color(0xFF07070F),
    ),
  ];

  static final ValueNotifier<GameTheme> current = ValueNotifier<GameTheme>(
    all.first,
  );

  /// Call after [StatsService.load] — the saved theme is only applied if
  /// it's still unlocked.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_prefKey);
      final saved = all.where((t) => t.id == id && t.isUnlocked());
      if (saved.isNotEmpty) current.value = saved.first;
    } catch (_) {}
  }

  static Future<void> select(GameTheme theme) async {
    if (!theme.isUnlocked()) return;
    current.value = theme;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, theme.id);
    } catch (_) {}
  }
}
