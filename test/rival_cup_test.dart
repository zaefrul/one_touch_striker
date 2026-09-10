import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_touch_striker/game/challenge_stage.dart';
import 'package:one_touch_striker/game/keeper_style.dart';
import 'package:one_touch_striker/game/match_model.dart';
import 'package:one_touch_striker/game/rival_ledger.dart';
import 'package:one_touch_striker/game/showdown.dart';
import 'package:one_touch_striker/game/star_rewards.dart';

// Prepared for the owner's local validation; not executed for publication.
// Inject resolved outcomes to isolate rules from physical shooting difficulty.
void settle(MatchModel match) {
  for (var frame = 0; frame < 180 && match.phase == MatchPhase.result; frame++) {
    match.update(1 / 60);
  }
}

void shot(MatchModel match, {bool goal = true, double target = 200}) {
  expect(match.shoot(), isTrue);
  match.shotTargetX = target;
  match.finishShot(goal: goal,
      corner: goal && MatchModel.isCornerTarget(target), text: goal ? 'GOAL' : 'MISS');
  settle(match);
}

void main() {
  test('repeating one corner scores points but cannot win Corner Duel', () {
    final match = MatchModel()..prepareStage(2)..startStage();
    shot(match, target: 90);
    shot(match, target: 90);
    expect(match.score, 9);
    expect(match.cornerGoals, 2);
    expect(match.objectiveProgress, 1);
    expect(match.phase, MatchPhase.aiming);
    expect(match.showdownStatus, 'NEXT: RIGHT CORNER');
    shot(match, target: 310);
    expect(match.phase, MatchPhase.stageCleared);
    expect(match.objectiveProgress, 2);
    match.retryStage();
    expect(match.leftCornerScored, isFalse);
    expect(match.rightCornerScored, isFalse);
  });

  test('Fire Finish needs a boosted finishing goal after reaching eight points', () {
    final match = MatchModel()..prepareStage(5)..startStage();
    for (var i = 0; i < 3; i++) { shot(match); }
    shot(match, target: 90);
    shot(match, target: 310);
    expect(match.score, 10);
    expect(match.fireReady, isTrue);
    expect(match.phase, MatchPhase.aiming);
    expect(match.objectiveMet, isFalse);
    shot(match);
    expect(match.score, 12);
    expect(match.lastWasFire, isTrue);
    expect(match.phase, MatchPhase.stageCleared);
  });

  test('Rush Hour requires a goal on a signalled third shot', () {
    final match = MatchModel()..prepareStage(8)..startStage();
    for (var i = 1; i <= 7; i++) {
      expect(match.keeper.rushIncoming, i % 3 == 0);
      shot(match, goal: i % 3 != 0);
    }
    expect(match.goals, 5);
    expect(match.rushGoals, 0);
    expect(match.phase, MatchPhase.aiming);
    expect(match.rematchHint, contains('goal past the rush'));
    shot(match);
    shot(match);
    expect(match.rushGoals, 1);
    expect(match.phase, MatchPhase.stageCleared);
    expect(match.earnedStars, 1);
    match.retryStage();
    expect(match.rushGoals, 0);
    expect(match.keeper.rushIncoming, isFalse);
  });

  test('Champion Final requires a Fire corner after the points threshold', () {
    final match = MatchModel()..prepareStage(11)..startStage();
    for (var i = 0; i < 5; i++) { shot(match, target: 90); }
    expect(match.score, 18);
    expect(match.phase, MatchPhase.aiming);
    shot(match); // A Fire centre goal cannot finish the final.
    expect(match.score, 20);
    expect(match.lastWasFire, isTrue);
    expect(match.phase, MatchPhase.aiming);
    shot(match);
    shot(match);
    expect(match.shoot(), isTrue);
    match.shotTargetX = 310;
    match.finishShot(goal: true, corner: true, text: 'CORNER');
    // End from pause during winning feedback still awards this clear.
    match.endRun();
    expect(match.phase, MatchPhase.stageCleared);
    expect(match.score, 28);
    final ledger = RivalLedger();
    expect(ledger.recordResult(match), isTrue);
    expect(ledger.hasTrophy(Showdown.championFinal), isTrue);
  });

  test('a numeric target alone does not defeat a showdown at timeout', () {
    final match = MatchModel()..prepareStage(5)..startStage();
    for (var i = 0; i < 3; i++) { shot(match); }
    shot(match, target: 90);
    shot(match, target: 310);
    match.secondsRemaining = .001;
    match.update(.01);
    expect(match.phase, MatchPhase.finished);
    expect(match.earnedStars, 0);
    final ledger = RivalLedger()..recordResult(match);
    expect(ledger.against(KeeperStyle.gambler).losses, 1);
    expect(ledger.hasTrophy(Showdown.fireFinish), isFalse);
  });

  test('results count once, including rematches without new stars', () {
    final match = MatchModel()..prepareStage(2)..startStage();
    final ledger = RivalLedger();
    final progress = ChallengeProgress()..mergeSaved(['3', '3']);
    shot(match, target: 90);
    shot(match, target: 310);
    expect(progress.recordClear(2, match.earnedStars), isTrue);
    expect(ledger.recordResult(match), isTrue);
    expect(ledger.recordResult(match), isFalse);
    expect(ledger.against(KeeperStyle.sentinel).wins, 1);
    expect(ledger.trophiesWon, 1);
    match.retryStage();
    shot(match, target: 310);
    shot(match, target: 90);
    expect(progress.recordClear(2, match.earnedStars), isFalse);
    expect(ledger.recordResult(match), isTrue);
    expect(ledger.against(KeeperStyle.sentinel).wins, 2);
    expect(ledger.trophiesWon, 1);

    final restored = RivalLedger();
    expect(restored.restore(ledger.encode()), isTrue);
    expect(restored.hasTrophy(Showdown.cornerDuel), isTrue);
    // Attempt IDs restart with a new screen; saved totals must still advance.
    final newSession = MatchModel()..prepareStage(2)..startStage()..endRun();
    expect(restored.recordResult(newSession), isTrue);
    expect(restored.against(KeeperStyle.sentinel).scoreline, 'You 2 · Keeper 1');
  });

  test('briefing cancellation and Classic do not change rival records', () {
    final match = MatchModel()..prepareStage(0)..endRun();
    final ledger = RivalLedger();
    expect(ledger.recordResult(match), isFalse);
    match.returnToMenu();
    expect(ledger.recordResult(match), isFalse);
    match.start();
    match.endRun();
    expect(ledger.recordResult(match), isFalse);
    match.prepareStage(0);
    match.startStage();
    expect(ledger.recordResult(match), isFalse);
    match.endRun();
    expect(ledger.recordResult(match), isTrue);
    expect(ledger.recordResult(match), isFalse);
    expect(ledger.against(KeeperStyle.sweeper).losses, 1);
  });

  test('bad record data is reported without inventing trophies or totals', () {
    final ledger = RivalLedger();
    expect(ledger.restore('{broken'), isFalse);
    expect(ledger.restore('{"version":2,"keepers":{}}'), isFalse);
    expect(ledger.restore(jsonEncode({
      'version': 1,
      'keepers': {'sweeper': {'wins': -2, 'losses': '12'},
        'gambler': {'wins': 9999999, 'losses': 1}},
      'trophies': ['unknownShowdown'],
    })), isTrue);
    expect(ledger.against(KeeperStyle.sweeper).scoreline, 'You 0 · Keeper 0');
    expect(ledger.against(KeeperStyle.gambler).wins, 999999);
    expect(ledger.trophiesWon, 0);
  });

  test('existing stars unlock cosmetics without being spent or awarding wins', () {
    final progress = ChallengeProgress()..mergeSaved(List.filled(12, '3'));
    final ledger = RivalLedger()..restore(null);
    final looks = CosmeticSelection();
    expect(looks.equip(StarReward.championBall, progress.totalStars), isTrue);
    expect(looks.equip(StarReward.goldNet, progress.totalStars), isTrue);
    expect(looks.equip(StarReward.nightPitch, progress.totalStars), isTrue);
    expect(progress.totalStars, 36);
    expect(progress.completed, isTrue);
    expect(ledger.trophiesWon, 0);
    expect(ledger.against(KeeperStyle.gambler).wins, 0);
    final restored = CosmeticSelection();
    expect(restored.restore(looks.encode(), progress.totalStars), isTrue);
    expect(restored.ball, StarReward.championBall);
    expect(restored.net, StarReward.goldNet);
    expect(restored.pitch, StarReward.nightPitch);
  });

  test('locked or wrong-slot saved equipment falls back to defaults', () {
    final looks = CosmeticSelection();
    expect(looks.equip(StarReward.neonBall, 2), isFalse);
    expect(looks.restore(jsonEncode({'version': 1, 'ball': 'championBall',
      'net': 'neonBall', 'pitch': 'missingPitch'}), 3), isTrue);
    expect(looks.ball, StarReward.classicBall);
    expect(looks.net, StarReward.standardNet);
    expect(looks.pitch, StarReward.dayPitch);
    expect(looks.equip(StarReward.neonBall, 3), isTrue);
    expect(looks.restore('{broken', 3), isFalse);
    expect(looks.ball, StarReward.neonBall);
  });

  test('reward notices occur only when best-star totals cross a milestone', () {
    expect(rewardsEarnedBetween(0, 3), [StarReward.neonBall]);
    expect(rewardsEarnedBetween(3, 3), isEmpty);
    expect(rewardsEarnedBetween(8, 10), [StarReward.retroBall]);
    expect(rewardsEarnedBetween(17, 19), [StarReward.goldNet]);
    expect(rewardsEarnedBetween(26, 28), [StarReward.nightPitch]);
    expect(rewardsEarnedBetween(35, 36), [StarReward.championBall]);
    expect(nextStarReward(3), StarReward.retroBall);
    expect(nextStarReward(36), isNull);
  });
}
