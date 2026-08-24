import 'package:shared_preferences/shared_preferences.dart';

class SaveService {
  static const _highScoreKey = 'high_score';

  static Future<int> getHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_highScoreKey) ?? 0;
  }

  /// Saves [score] as the new high score if it beats the stored one.
  /// Returns true when a new high score was set.
  static Future<bool> submitScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_highScoreKey) ?? 0;
    if (score <= current) return false;
    await prefs.setInt(_highScoreKey, score);
    return true;
  }
}
