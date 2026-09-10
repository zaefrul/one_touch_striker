import 'package:flutter_test/flutter_test.dart';
import 'package:one_touch_striker/game/bonus.dart';
import 'package:one_touch_striker/progress/campaign.dart';
import 'package:one_touch_striker/progress/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late SharedPreferencesAsync prefs;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = SharedPreferencesAsync();
  });

  test('progress store restore after clear 1-1', () async {
    final store = ProgressStore(prefs: prefs);
    expect(store.unlocked(0, 0), isTrue);
    expect(store.unlocked(0, 1), isFalse);
    expect(store.bonusUnlocked(BallBonus.curve), isFalse);
    await store.recordStars(0, 0, 2);
    expect(store.stars(0, 0), 2);
    expect(store.unlocked(0, 1), isTrue);
    expect(store.continueTarget.code, '1-2');
    expect(store.venueUnlocked(1), isFalse);

    final again = ProgressStore(prefs: prefs);
    await again.restore();
    expect(again.stars(0, 0), 2);
    expect(again.unlocked(0, 1), isTrue);
    expect(again.totalStars, 2);
  });

  test('curve and super shoot unlock at 1-3 and 1-6', () async {
    final store = ProgressStore(prefs: prefs);
    expect(store.bonusUnlocked(BallBonus.straight), isTrue);
    expect(store.bonusUnlocked(BallBonus.curve), isFalse);
    expect(store.bonusUnlocked(BallBonus.superShoot), isFalse);
    await store.recordStars(0, 2, 1);
    expect(store.bonusUnlocked(BallBonus.curve), isTrue);
    expect(store.bonusUnlocked(BallBonus.superShoot), isFalse);
    await store.recordStars(0, 5, 1);
    expect(store.bonusUnlocked(BallBonus.superShoot), isTrue);
  });

  test('venue 2 unlocks after a star on 1-10', () async {
    final store = ProgressStore(prefs: prefs);
    await store.recordStars(0, 9, 1);
    expect(store.venueUnlocked(1), isTrue);
    expect(store.unlocked(1, 0), isTrue);
    expect(store.unlocked(1, 1), isFalse);
  });

  test('selected bonus persists when still unlocked', () async {
    final store = ProgressStore(prefs: prefs);
    await store.recordStars(0, 2, 1);
    await store.selectBonus(BallBonus.curve);
    expect(store.selectedBonus, BallBonus.curve);
    final again = ProgressStore(prefs: prefs);
    await again.restore();
    expect(again.selectedBonus, BallBonus.curve);
  });

  test('later substages raise the star bars', () {
    expect(Campaign.thresholds(0, 0), [3, 6, 9]);
    expect(Campaign.thresholds(0, 9)[0], greaterThan(3));
    expect(Campaign.thresholds(5, 9)[2], greaterThan(Campaign.thresholds(0, 0)[2]));
  });
}
