import 'dart:async';

import 'package:flutter/material.dart';

import 'screens/main_menu_screen.dart';
import 'services/achievement_service.dart';
import 'services/admob_service.dart';
import 'services/haptic_service.dart';
import 'services/music_service.dart';
import 'services/sound_service.dart';
import 'services/stats_service.dart';
import 'services/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AdmobService.init();
  SoundService.preload();
  MusicService.init();
  // The menu reads stats/theme synchronously, so load them before the first
  // frame — but with a timeout: a hung SharedPreferences.getInstance() (see
  // the shared_preferences_android pin in pubspec.yaml) must never leave
  // the app stuck on the splash screen. Defaults are used if it trips.
  try {
    await Future.wait([
      StatsService.load().then((_) => ThemeService.load()),
      AchievementService.load(),
      HapticService.load(),
    ]).timeout(const Duration(seconds: 3));
  } catch (_) {}
  runApp(const Number99App());
}

class Number99App extends StatelessWidget {
  const Number99App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '99 Numbers',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: const MainMenuScreen(),
    );
  }
}
