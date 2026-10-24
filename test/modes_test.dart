import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:number99/models/game_mode.dart';
import 'package:number99/screens/game_screen.dart';
import 'package:number99/services/achievement_service.dart';
import 'package:number99/services/stats_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

int _daysAgo(int n) {
  final now = DateTime.now();
  return StatsService.dateKey(DateTime(now.year, now.month, now.day - n));
}

void main() {
  test('formatMillis', () {
    expect(formatMillis(0), '0:00.0');
    expect(formatMillis(83456), '1:23.4');
    expect(formatMillis(600000), '10:00.0');
  });

  group('daily streak', () {
    test('continues from yesterday', () async {
      SharedPreferences.setMockInitialValues({
        'daily_last_date': _daysAgo(1),
        'daily_streak': 4,
        'daily_best_streak': 4,
      });
      await StatsService.load();
      expect(StatsService.dailyPlayedToday, isFalse);
      expect(StatsService.dailyStreak, 4);
      await StatsService.startDailyAttempt();
      expect(StatsService.dailyPlayedToday, isTrue);
      expect(StatsService.dailyStreak, 5);
      expect(StatsService.dailyBestStreak, 5);
    });

    test('breaks after a missed day', () async {
      SharedPreferences.setMockInitialValues({
        'daily_last_date': _daysAgo(2),
        'daily_streak': 6,
        'daily_best_streak': 6,
      });
      await StatsService.load();
      expect(StatsService.dailyStreak, 0);
      await StatsService.startDailyAttempt();
      expect(StatsService.dailyStreak, 1);
      expect(StatsService.dailyBestStreak, 6);
    });
  });

  test('achievements unlock from stats once', () async {
    SharedPreferences.setMockInitialValues({'stats_best_level': 7});
    await StatsService.load();
    await AchievementService.load();
    final fresh = await AchievementService.evaluate();
    expect(
      fresh.map((a) => a.key),
      containsAll(<String>['level_4', 'level_7']),
    );
    expect(await AchievementService.evaluate(), isEmpty);
  });

  testWidgets('zen: tapping 1 then a wrong cell', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await StatsService.load();
    await tester.pumpWidget(
      const MaterialApp(home: GameScreen(mode: GameMode.zen)),
    );
    final grid = find.byType(GridView);
    Finder cell(String n) => find.descendant(of: grid, matching: find.text(n));

    expect(find.text('0/99'), findsOneWidget);
    await tester.tap(cell('1'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('1/99'), findsOneWidget);

    // Target is now 2; tapping 50 is wrong and costs Zen a second.
    await tester.tap(cell('50'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('1/99'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
