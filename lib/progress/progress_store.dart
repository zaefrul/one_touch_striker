import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../game/bonus.dart';
import 'campaign.dart';

class ProgressStore {
  ProgressStore({SharedPreferencesAsync? prefs})
      : _prefs = prefs ?? SharedPreferencesAsync();

  static const storageKey = 'campaign_progress';

  final SharedPreferencesAsync _prefs;
  final Map<String, int> _stars = {};
  BallBonus selectedBonus = BallBonus.straight;

  int stars(int venue, int sub) => _stars[_key(venue, sub)] ?? 0;

  int get totalStars {
    var sum = 0;
    for (final value in _stars.values) {
      sum += value;
    }
    return sum;
  }

  bool venueUnlocked(int venue) {
    if (venue <= 0) {
      return true;
    }
    return stars(venue - 1, Campaign.substagesPerVenue - 1) >= 1;
  }

  bool unlocked(int venue, int sub) {
    if (!venueUnlocked(venue)) {
      return false;
    }
    if (sub <= 0) {
      return true;
    }
    return stars(venue, sub - 1) >= 1;
  }

  bool bonusUnlocked(BallBonus bonus) =>
      Campaign.bonusUnlockedAt(bonus, stars);

  SubstageRef get continueTarget {
    for (var venue = 0; venue < Campaign.venues; venue++) {
      if (!venueUnlocked(venue)) {
        break;
      }
      for (var sub = 0; sub < Campaign.substagesPerVenue; sub++) {
        if (unlocked(venue, sub) && stars(venue, sub) == 0) {
          return SubstageRef(venue, sub);
        }
      }
    }
    for (var venue = Campaign.venues - 1; venue >= 0; venue--) {
      if (!venueUnlocked(venue)) {
        continue;
      }
      for (var sub = Campaign.substagesPerVenue - 1; sub >= 0; sub--) {
        if (unlocked(venue, sub)) {
          return SubstageRef(venue, sub);
        }
      }
    }
    return const SubstageRef(0, 0);
  }

  Future<void> restore() async {
    try {
      final raw = await _prefs.getString(storageKey);
      if (raw == null || raw.isEmpty) {
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return;
      }
      final saved = Map<String, Object?>.from(decoded);
      final starMap = saved['stars'];
      if (starMap is Map) {
        _stars
          ..clear()
          ..addEntries(starMap.entries.map((entry) =>
              MapEntry(entry.key.toString(), (entry.value as num).toInt())));
      }
      final bonusName = saved['bonus'] as String?;
      selectedBonus = BallBonus.values.firstWhere(
        (bonus) => bonus.name == bonusName,
        orElse: () => BallBonus.straight,
      );
      if (!bonusUnlocked(selectedBonus)) {
        selectedBonus = BallBonus.straight;
      }
    } catch (_) {
      _stars.clear();
      selectedBonus = BallBonus.straight;
    }
  }

  Future<void> recordStars(int venue, int sub, int earned) async {
    final key = _key(venue, sub);
    final current = _stars[key] ?? 0;
    if (earned > current) {
      _stars[key] = earned.clamp(0, 3);
      await _persist();
    }
  }

  Future<void> selectBonus(BallBonus bonus) async {
    if (!bonusUnlocked(bonus)) {
      return;
    }
    selectedBonus = bonus;
    await _persist();
  }

  Future<void> _persist() async {
    await _prefs.setString(
      storageKey,
      jsonEncode({
        'stars': _stars,
        'bonus': selectedBonus.name,
      }),
    );
  }

  static String _key(int venue, int sub) => '$venue-$sub';
}
