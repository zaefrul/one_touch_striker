import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:one_touch_striker/game/keeper_style.dart';
import 'package:one_touch_striker/game/match_model.dart';

// Prepared for the owner's local validation; not executed during publication.
void settle(MatchModel match) {
  for (var i = 0; i < 30 && match.phase == MatchPhase.result; i++) {
    match.update(.1);
  }
}

void score(MatchModel match, {bool corner = false}) {
  expect(match.shoot(), isTrue);
  match.finishShot(goal: true, corner: corner, text: 'GOAL');
  settle(match);
}

void main() {
  test('the opening stage pays off on the third goal, not the charging goal', () {
    final match = MatchModel()..prepareStage(0)..startStage();
    score(match);
    expect(match.fireCharge, 1);
    expect(match.fireReady, isFalse);
    score(match);
    expect(match.score, 2);
    expect(match.lastPoints, 1);
    expect(match.justChargedFire, isTrue);
    expect(match.fireReady, isTrue);
    score(match);
    expect(match.score, 4);
    expect(match.lastPoints, 2);
    expect(match.lastWasFire, isTrue);
    expect(match.message, 'FIRE GOAL!');
    expect(match.fireCharge, 0);
    expect(match.phase, MatchPhase.stageCleared);
    expect(match.earnedStars, 3);
  });

  test('the corner stage charges from a corner and pays off before it ends', () {
    final match = MatchModel()..prepareStage(2)..startStage();
    score(match);
    expect(match.fireCharge, 0);
    expect(match.objectiveProgress, 0);
    score(match, corner: true);
    expect(match.fireReady, isTrue);
    expect(match.objectiveProgress, 1);
    score(match, corner: true);
    expect(match.lastPoints, 6);
    expect(match.score, 10);
    expect(match.cornerGoals, 2);
    expect(match.phase, MatchPhase.stageCleared);
  });

  test('a Fire Shot can be saved and consumes both charge and one chance', () {
    final match = MatchModel()..prepareStage(0)..startStage();
    score(match);
    score(match);
    expect(match.shoot(), isTrue);
    expect(match.shotIsFire, isTrue);
    // Put its actual trajectory through the keeper's collision anchor.
    match.shotTargetX = match.keeperX;
    match.ballY = match.keeperY + .1;
    match.update(.001);
    expect(match.message, 'SAVED!');
    expect(match.lastWasFire, isTrue);
    expect(match.lastWasGoal, isFalse);
    expect(match.score, 2);
    expect(match.lives, 2);
    expect(match.fireCharge, 0);
    expect(match.streak, 0);
    settle(match);
    expect(match.fireReady, isFalse);
    expect(match.shotIsFire, isFalse);
  });

  test('an ordinary miss removes partial charge', () {
    final match = MatchModel()..prepareStage(0)..startStage();
    score(match);
    match.shoot();
    match.finishShot(goal: false, post: true, text: 'OFF THE POST!');
    settle(match);
    expect(match.fireCharge, 0);
    score(match);
    expect(match.fireCharge, 1);
    expect(match.fireReady, isFalse);
  });

  test('a Fire corner buzzer shot can win the eight-point final', () {
    final match = MatchModel()..prepareStage(5)..startStage();
    score(match);
    score(match);
    match.secondsRemaining = .001;
    expect(match.shoot(), isTrue);
    // Choose the corner away from the keeper's current side; this case tests
    // buzzer scoring, while the separate interception case covers saves.
    match.shotTargetX = match.keeperX < 200 ? 310 : 90;
    match.ballY = MatchModel.goalY + 10;
    match.update(.1, cinematic: true);
    settle(match);
    expect(match.secondsRemaining, 0);
    expect(match.lastPoints, 6);
    expect(match.score, 8);
    expect(match.phase, MatchPhase.stageCleared);
  });

  test('retry starts the same timed stage immediately with a fresh attempt', () {
    final match = MatchModel()..prepareStage(3)..startStage();
    score(match);
    score(match);
    match.update(.1);
    match.endRun();
    match.retryStage();
    expect(match.phase, MatchPhase.aiming);
    expect(match.stageIndex, 3);
    expect(match.secondsRemaining, 25);
    expect(match.score, 0);
    expect(match.lives, 3);
    expect(match.fireCharge, 0);
    expect(match.shotIsFire, isFalse);
    expect(match.lastWasFire, isFalse);
    expect(match.longestStreak, 0);
    expect(match.resultTime, 0);
    expect(match.firstAim, isTrue);
  });

  test('keeper motion stays bounded and continuous at hold and cycle seams', () {
    for (final keeper in KeeperStyle.values) {
      for (var i = 0; i <= 1000; i++) {
        expect(keeper.offset(i * math.pi / 250), inInclusiveRange(-1.0, 1.0));
      }
      for (final angle in [0.0, math.pi / 4, math.pi, 5 * math.pi / 4, 2 * math.pi]) {
        expect(keeper.offset(angle - .000001),
            closeTo(keeper.offset(angle + .000001), .00001));
      }
    }
    expect(KeeperStyle.sentinel.offset(0), 1);
    expect(KeeperStyle.sentinel.offset(math.pi / 8), 1);
    expect(KeeperStyle.sentinel.offset(math.pi), -1);
    expect(KeeperStyle.sentinel.offset(9 * math.pi / 8), -1);
    // Sampled right-side occupancy is greater than left-side occupancy.
    final rightSamples = List.generate(1000,
        (i) => KeeperStyle.gambler.offset(i * math.pi / 500))
        .where((offset) => offset > 0).length;
    expect(rightSamples, greaterThan(500));
  });
}
