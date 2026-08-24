import 'package:flutter/material.dart';

import 'screens/main_menu_screen.dart';
import 'services/admob_service.dart';
import 'services/sound_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AdmobService.init();
  SoundService.preload();
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
