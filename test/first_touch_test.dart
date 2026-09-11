import 'package:flutter_test/flutter_test.dart';
import 'package:one_touch_striker/game/challenge_stage.dart';
import 'package:one_touch_striker/game/first_touch_guide.dart';
import 'package:one_touch_striker/game/keeper_style.dart';
import 'package:one_touch_striker/game/match_model.dart';
import 'package:one_touch_striker/game/rival_ledger.dart';
import 'package:one_touch_striker/game/shot_failure.dart';

// Regression sources prepared for local execution; not run for publication.
void settle(MatchModel match) {
  for (var i = 0; i < 180 && match.phase == MatchPhase.result; i++) {
    match.update(1 / 60);
  }
}

void goal(MatchModel match) {
  expect(match.shoot(), isTrue);
  // Inject a resolved outcome to exercise guidance and progression only.
  match.finishShot(goal: true, text: 'GOAL');
  settle(match);
}

void main() {
  test('guidance does not change trajectories, keeper movement or outcomes', () {
    final guided = MatchModel()..prepareStage(0, guided: true)..startStage();
    final ordinary = MatchModel()..prepareStage(0)..startStage();
    for (var i = 0; i < 20; i++) {
      guided.update(1 / 60);
      ordinary.update(1 / 60);
    }
    expect(guided.shoot(), isTrue);
    expect(ordinary.shoot(), isTrue);
    final locked = guided.shotTargetX;
    expect(guided.shoot(), isFalse);
    for (var i = 0; i < 120; i++) {
      guided.update(1 / 60, cinematic: true);
      ordinary.update(1 / 60, cinematic: true);
      expect(guided.shotTargetX, locked);
      expect(guided.ballX, ordinary.ballX);
      expect(guided.ballY, ordinary.ballY);
      expect(guided.keeperX, ordinary.keeperX);
      expect(guided.phase, ordinary.phase);
      expect(guided.score, ordinary.score);
      expect(guided.misses, ordinary.misses);
    }
  });

  test('a guided clear uses normal Fire, stars, unlocks and rival counting', () {
    final match = MatchModel()..prepareStage(0, guided: true)..startStage();
    expect(match.firstTouchLesson, FirstTouchLesson.aim);
    goal(match);
    expect(match.firstTouchLesson, FirstTouchLesson.space);
    goal(match);
    expect(match.firstTouchLesson, FirstTouchLesson.fire);
    expect(match.fireReady, isTrue);
    goal(match);
    expect(match.phase, MatchPhase.stageCleared);
    expect(match.score, 4);
    expect(match.earnedStars, 3);
    final progress = ChallengeProgress();
    expect(progress.recordClear(0, match.earnedStars), isTrue);
    expect(progress.nextStageIndex, 1);
    final ledger = RivalLedger();
    expect(ledger.recordResult(match), isTrue);
    expect(ledger.recordResult(match), isFalse);
    expect(ledger.against(KeeperStyle.sweeper).wins, 1);
    match.retryStage();
    expect(match.isGuidedFirstMatch, isFalse);
    expect(match.score, 0);
    expect(match.lives, 3);
  });

  test('failed first shots retain the cue and retry clears stale advice', () {
    final match = MatchModel()..prepareStage(0, guided: true)..startStage();
    for (var i = 0; i < 3; i++) {
      expect(match.shoot(), isTrue);
      match.finishShot(goal: false, post: true, text: 'ANY DISPLAY TEXT');
      settle(match);
      expect(match.lastFailure, ShotFailure.post);
      if (i < 2) {
        expect(match.firstAim, isFalse);
        expect(match.showTapCue, isTrue);
        expect(match.firstTouchHint, ShotFailure.post.advice);
      }
    }
    expect(match.phase, MatchPhase.finished);
    match.retryStage();
    expect(match.isGuidedFirstMatch, isTrue);
    expect(match.lastFailure, isNull);
    expect(match.showTapCue, isTrue);
    expect(match.firstTouchHint, FirstTouchLesson.aim.instruction);
    match.prepareStage(1, guided: true);
    expect(match.isGuidedFirstMatch, isFalse);
    match.prepareStage(0, guided: true);
    match.start();
    expect(match.isGuidedFirstMatch, isFalse);
  });

  test('goal-line resolution distinguishes post and wide with actual coordinates', () {
    for (final (target, failure) in [
      (25.0, ShotFailure.wide), (72.0, ShotFailure.post),
    ]) {
      final match = MatchModel()..start()..shoot();
      match.shotTargetX = target;
      match.ballY = MatchModel.goalY + .1;
      match.update(.01);
      expect(match.lastFailure, failure);
      expect(match.misses, 1);
      settle(match);
      expect(match.shotAdvice, failure.advice);
      goal(match);
      expect(match.lastFailure, isNull);
    }
  });

  test('collision resolution distinguishes keeper contact from a defender', () {
    final keeper = MatchModel()..start()..shoot();
    final progress = (MatchModel.ballStartY - keeper.keeperY) /
        (MatchModel.ballStartY - MatchModel.goalY);
    keeper.shotTargetX = MatchModel.ballStartX +
        (keeper.keeperX - MatchModel.ballStartX) / progress;
    keeper.ballY = keeper.keeperY + .01;
    keeper.update(.0001);
    expect(keeper.lastFailure, ShotFailure.keeper);

    final defender = MatchModel()..start();
    defender.goals = 3;
    defender.shoot();
    defender.ballY = defender.defenderY(0) + .01;
    defender.update(.0001);
    expect(defender.lastFailure, ShotFailure.defender);
    expect(defender.lastWasKeeperSave, isFalse);
  });
}
