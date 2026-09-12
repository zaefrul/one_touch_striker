import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_touch_striker/game/challenge_stage.dart';
import 'package:one_touch_striker/game/match_model.dart';
import 'package:one_touch_striker/game/practice_drill.dart';
import 'package:one_touch_striker/game/practice_progress.dart';
import 'package:one_touch_striker/game/rival_ledger.dart';
import 'package:one_touch_striker/game/star_rewards.dart';
import 'package:one_touch_striker/game/striker_audio.dart';
import 'package:one_touch_striker/game/striker_game.dart';
import 'package:one_touch_striker/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// Prepared for local execution; no widget tests or app runs were executed here.
Future<void> tapText(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> launch(WidgetTester tester) async {
  await tester.pumpWidget(StrikerApp(audio: StrikerAudio.silent()));
  await tester.pump(const Duration(milliseconds: 50));
}

StrikerGame gameFor(WidgetTester tester) => tester.widget<GameWidget<StrikerGame>>(
    find.byType(GameWidget<StrikerGame>)).game!;

// Inject goal outcomes to isolate the screen, scoring and storage integration.
void resolveCornerBall(StrikerGame game, {required bool hit}) {
  expect(game.shoot(), isTrue);
  game.model.shotTargetX = hit ? game.model.practiceTargetX : 200;
  game.model.finishShot(goal: true, text: 'GOAL');
  game.update(0);
  for (var frame = 0; frame < 180 && game.model.phase == MatchPhase.result; frame++) {
    game.update(1 / 60);
  }
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('five-ball best survives retry and relaunch without changing campaign or Classic', (tester) async {
    final prefs = SharedPreferencesAsync();
    final rivals = RivalLedger().encode();
    final cosmetics = CosmeticSelection()..equip(StarReward.neonBall, 3);
    final equipped = cosmetics.encode();
    await prefs.setInt('best_score', 2);
    await prefs.setStringList(ChallengeProgress.storageKey, ['3']);
    await prefs.setString(RivalLedger.storageKey, rivals);
    await prefs.setString(CosmeticSelection.storageKey, equipped);
    await launch(tester);
    await tapText(tester, 'PRACTICE ARENA');
    for (final drill in PracticeDrill.values) {
      expect(find.text(drill.title), findsOneWidget);
    }
    await tapText(tester, 'PLAY CORNER PRACTICE  →');
    final game = gameFor(tester);
    expect(game.model.isPractice, isTrue);
    for (var ball = 0; ball < 5; ball++) {
      resolveCornerBall(game, hit: ball < 3);
    }
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('DRILL COMPLETE'), findsOneWidget);
    expect(find.text('NEW PRACTICE BEST!'), findsOneWidget);
    final saved = PracticeProgress();
    expect(saved.restore(await prefs.getString(PracticeProgress.storageKey)), isTrue);
    expect(saved.bestFor(PracticeDrill.corners), 3);
    expect(await prefs.getInt('best_score'), 2);
    expect(await prefs.getStringList(ChallengeProgress.storageKey), ['3']);
    expect(await prefs.getString(RivalLedger.storageKey), rivals);
    expect(await prefs.getString(CosmeticSelection.storageKey), equipped);

    await tapText(tester, 'RETRY DRILL  ↻');
    expect(game.model.phase, MatchPhase.aiming);
    expect(game.model.practiceHits, 0);
    expect(game.model.practiceBallsLeft, 5);
    for (var ball = 0; ball < 5; ball++) {
      resolveCornerBall(game, hit: ball < 3);
    }
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('NEW PRACTICE BEST!'), findsNothing);
    await tapText(tester, 'CHOOSE A DRILL');
    expect(find.text('Best 3/5'), findsOneWidget);
    await tapText(tester, 'BACK HOME');
    expect(find.text('CONTINUE · STAGE 2  →'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await launch(tester);
    await tapText(tester, 'PRACTICE ARENA');
    expect(find.text('Best 3/5'), findsOneWidget);
  });

  testWidgets('ending a paused partial drill keeps its notes without recording a best', (tester) async {
    await launch(tester);
    await tapText(tester, 'PRACTICE ARENA');
    await tapText(tester, 'PLAY CORNER PRACTICE  →');
    final game = gameFor(tester);
    resolveCornerBall(game, hit: true);
    await tester.pump();
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    final clock = game.model.clock;
    await tester.pump(const Duration(seconds: 1));
    expect(game.model.clock, clock);
    await tapText(tester, 'END DRILL');
    expect(find.text('PRACTICE ENDED'), findsOneWidget);
    expect(find.text('Finish all five balls to record a best.'), findsOneWidget);
    expect(find.text('1. Straight shot · Goal'), findsOneWidget);
    expect(await SharedPreferencesAsync().getString(PracticeProgress.storageKey), isNull);
    await tapText(tester, 'RETRY DRILL  ↻');
    expect(game.model.practiceShots, isEmpty);
    expect(game.model.practiceBallsLeft, 5);
  });

  testWidgets('unknown saved practice version stays intact while session play remains available', (tester) async {
    const futureSave = '{"version":2,"best":{"corner_practice":5}}';
    final prefs = SharedPreferencesAsync();
    await prefs.setString(PracticeProgress.storageKey, futureSave);
    await launch(tester);
    await tapText(tester, 'PRACTICE ARENA');
    await tapText(tester, 'PLAY CORNER PRACTICE  →');
    final game = gameFor(tester);
    for (var ball = 0; ball < 5; ball++) {
      resolveCornerBall(game, hit: true);
    }
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('NEW SESSION BEST!'), findsOneWidget);
    expect(find.text('PRACTICE BEST SAVING UNAVAILABLE'), findsOneWidget);
    expect(await prefs.getString(PracticeProgress.storageKey), futureSave);
    await tapText(tester, 'CHOOSE A DRILL');
    expect(find.text('Session best 5/5'), findsOneWidget);
  });
}
