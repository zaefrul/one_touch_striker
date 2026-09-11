import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_touch_striker/game/challenge_stage.dart';
import 'package:one_touch_striker/game/match_model.dart';
import 'package:one_touch_striker/game/shot_failure.dart';
import 'package:one_touch_striker/game/striker_audio.dart';
import 'package:one_touch_striker/game/striker_game.dart';
import 'package:one_touch_striker/main.dart';
import 'package:one_touch_striker/ui/run_summary.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// Prepared for the owner's local validation; not executed for publication.
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

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('first match starts directly, pauses and retries with its guide', (tester) async {
    await launch(tester);
    await tapText(tester, 'PLAY FIRST MATCH  →');
    final game = gameFor(tester);
    expect(game.model.phase, MatchPhase.aiming);
    expect(game.model.isGuidedFirstMatch, isTrue);
    expect(find.text('START STAGE  →'), findsNothing);
    expect(find.text('FOLLOW THE ARROW'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    final clock = game.model.clock;
    await tester.pump(const Duration(seconds: 1));
    expect(game.model.clock, clock);
    expect(game.model.misses, 0);
    await tapText(tester, 'END STAGE');
    expect(tester.getTopLeft(find.text('RETRY STAGE  ↻')).dy,
        lessThan(tester.getTopLeft(find.byType(RunSummary)).dy));
    await tapText(tester, 'RETRY STAGE  ↻');
    expect(game.model.isGuidedFirstMatch, isTrue);
    expect(game.model.lives, 3);
    expect(game.model.lastFailure, isNull);
  });

  testWidgets('miss advice remains visible after feedback while aiming again', (tester) async {
    await launch(tester);
    await tapText(tester, 'PLAY FIRST MATCH  →');
    final game = gameFor(tester);
    game.shoot();
    game.model.finishShot(goal: false, keeperSave: true, text: 'SAVED!');
    game.update(0);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(game.model.phase, MatchPhase.aiming);
    expect(find.text(ShotFailure.keeper.advice), findsOneWidget);
    expect(find.text('SAVED!'), findsNothing);
  });

  testWidgets('a first clear saves stars, shows its reward and retires the guide', (tester) async {
    await launch(tester);
    await tapText(tester, 'PLAY FIRST MATCH  →');
    final game = gameFor(tester);
    for (var shot = 0; shot < 3; shot++) {
      game.shoot();
      game.model.finishShot(goal: true, text: 'GOAL');
      game.update(0);
      for (var frame = 0; frame < 180 && game.model.phase == MatchPhase.result; frame++) {
        game.update(1 / 60);
      }
      await tester.pump();
    }
    expect(game.model.phase, MatchPhase.stageCleared);
    expect(find.text('NEW LOOK UNLOCKED!'), findsOneWidget);
    expect(find.text('Neon Ball'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
    expect((await SharedPreferencesAsync().getStringList(ChallengeProgress.storageKey))!.first, '3');
    await tester.pumpWidget(const SizedBox.shrink());
    await launch(tester);
    expect(find.text('PLAY FIRST MATCH  →'), findsNothing);
    await tapText(tester, 'CONTINUE · STAGE 2  →');
    expect(gameFor(tester).model.phase, MatchPhase.stageIntro);
    expect(gameFor(tester).model.isGuidedFirstMatch, isFalse);
    expect(find.text('START STAGE  →'), findsOneWidget);
  });

  testWidgets('completed saves offer rematches without restarting the guide', (tester) async {
    await SharedPreferencesAsync().setStringList(
        ChallengeProgress.storageKey, List.filled(12, '3'));
    await launch(tester);
    await tapText(tester, 'CHOOSE A REMATCH  →');
    expect(find.text('36/36 stars collected'), findsOneWidget);
    expect(find.text('WIN CORNER DUEL  →'), findsOneWidget);
    expect(gameFor(tester).model.isPlaying, isFalse);
  });
}
