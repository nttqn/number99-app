import 'package:flutter/material.dart';

import '../services/sound_service.dart';
import '../services/theme_service.dart';
import '../utils/responsive.dart';

/// Theme picker: each card is a mini preview (HUD strip + a few cells) in
/// that theme's colors; locked ones show what unlocks them.
class ThemesScreen extends StatelessWidget {
  const ThemesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scale = uiScale(context);
    return ValueListenableBuilder<GameTheme>(
      valueListenable: ThemeService.current,
      builder: (context, current, _) => Scaffold(
        backgroundColor: current.menuBg,
        appBar: AppBar(
          backgroundColor: current.hud,
          foregroundColor: current.hudLabel,
          title: const Text(
            'THEMES',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: GridView.count(
          padding: EdgeInsets.all(16 * scale),
          crossAxisCount: 2,
          mainAxisSpacing: 14 * scale,
          crossAxisSpacing: 14 * scale,
          childAspectRatio: 0.8,
          children: [
            for (final t in ThemeService.all)
              _ThemeCard(
                theme: t,
                selected: t.id == current.id,
                unlocked: t.isUnlocked(),
                scale: scale,
                onTap: () {
                  if (!t.isUnlocked()) {
                    SoundService.playMenuBack();
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(content: Text('Locked — ${t.unlockHint}')),
                      );
                    return;
                  }
                  SoundService.playMenuConfirm();
                  ThemeService.select(t);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.selected,
    required this.unlocked,
    required this.scale,
    required this.onTap,
  });

  final GameTheme theme;
  final bool selected;
  final bool unlocked;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.gameBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.amber : Colors.black12,
            width: selected ? 4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              children: [
                Container(
                  height: 34 * scale,
                  color: theme.hud,
                  alignment: Alignment.center,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10 * scale),
                    decoration: BoxDecoration(
                      color: theme.targetBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.targetBorder, width: 2),
                    ),
                    child: Text(
                      '42',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16 * scale,
                        color: theme.targetText,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(8 * scale),
                    child: GridView.count(
                      crossAxisCount: 3,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (final n in const [17, 42, 8, 63, 0, 91])
                          Container(
                            decoration: BoxDecoration(
                              color: n == 0 ? theme.found : theme.cell,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: n == 0 ? theme.found : theme.cellBorder,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: n == 0
                                ? Icon(
                                    Icons.check,
                                    size: 14 * scale,
                                    color: theme.foundIcon,
                                  )
                                : Text(
                                    '$n',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13 * scale,
                                      color: theme.cellText,
                                    ),
                                  ),
                          ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: theme.bottomBar,
                  padding: EdgeInsets.symmetric(vertical: 8 * scale),
                  child: Text(
                    theme.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15 * scale,
                      color: theme.title,
                    ),
                  ),
                ),
              ],
            ),
            if (!unlocked)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.55),
                  padding: EdgeInsets.all(10 * scale),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock, color: Colors.white, size: 30 * scale),
                      SizedBox(height: 6 * scale),
                      Text(
                        theme.unlockHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12 * scale,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (selected)
              Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  Icons.check_circle,
                  color: Colors.amber,
                  size: 24 * scale,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
