import 'package:flutter_test/flutter_test.dart';
import 'package:one_touch_striker/game/challenge_stage.dart';
import 'package:one_touch_striker/game/match_model.dart';

// Author-provided regression cases for the owner's local validation.
// No tests or builds were executed when publishing this milestone.
void settleShot(MatchModel match) {
  for (var i = 0; i < 180 && match.phase == MatchPhase.result; i++) {
    match.update(1 / 60);
  }
}

void main() {
  test('briefing waits for start and retry restores the same stage', () {
    final match = MatchModel()..prepareStage(3);
    match.update(.1);
    expect(match.secondsRemaining, 25);
    expect(match.shoot(), isFalse);
    match.startStage();
    match.update(.1);
    expect(match.secondsRemaining, closeTo(24.9, 1e-8));
    match.finishShot(goal: false, text: 'MISS');
    match.prepareStage(3);
    expect(match.phase, MatchPhase.stageIntro);
    expect(match.stageIndex, 3);
    expect(match.secondsRemaining, 25);
    expect(match.lives, 3);
    expect(match.score, 0);
    expect(match.firstAim, isTrue);
  });

  test('corner objective ignores centre goals and clears on two corners', () {
    final match = MatchModel()..prepareStage(2)..startStage();
    match.finishShot(goal: true, text: 'GOAL');
    settleShot(match);
    expect(match.objectiveProgress, 0);
    expect(match.phase, MatchPhase.aiming);
    expect(match.score, 1);
    expect(match.lives, 3);
    for (var i = 0; i < 2; i++) {
      match.finishShot(goal: true, corner: true, text: 'CORNER');
      settleShot(match);
    }
    expect(match.phase, MatchPhase.stageCleared);
    expect(match.earnedStars, 3);
    expect(match.shoot(), isFalse);
    final clock = match.clock;
    match.update(.1);
    expect(match.clock, clock);
  });

  test('stars count remaining chances and third miss never clears a stage', () {
    final match = MatchModel()..prepareStage(0)..startStage();
    match.finishShot(goal: false, text: 'MISS');
    settleShot(match);
    for (var i = 0; i < 3; i++) {
      match.finishShot(goal: true, text: 'GOAL');
      settleShot(match);
    }
    expect(match.phase, MatchPhase.stageCleared);
    expect(match.earnedStars, 2);

    match.prepareStage(0);
    match.startStage();
    for (var i = 0; i < 3; i++) {
      match.finishShot(goal: false, text: 'MISS');
      settleShot(match);
    }
    expect(match.phase, MatchPhase.finished);
    expect(match.earnedStars, 0);
  });

  test('stage defence stays fixed instead of unlocking Classic defenders', () {
    final match = MatchModel()..prepareStage(2)..startStage();
    match.goals = 12;
    expect(match.defenderCount, 0);
    expect(match.level, 3);
    match.prepareStage(4);
    match.startStage();
    match.update(.1);
    expect(match.defenderCount, 2);
    expect(match.defenderX(0) + match.defenderX(1), closeTo(400, 1e-8));
  });

  test('time expiry while aiming ends the stage without consuming a life', () {
    final match = MatchModel()..prepareStage(3)..startStage();
    match.secondsRemaining = .01;
    match.update(.05);
    expect(match.phase, MatchPhase.finished);
    expect(match.message, "TIME'S UP!");
    expect(match.shoot(), isFalse);
    expect(match.misses, 0);
  });

  test('slow motion consumes active time while feedback consumes none', () {
    final match = MatchModel()..prepareStage(3)..startStage();
    match.shoot();
    match.update(.1, timeScale: .38);
    expect(match.secondsRemaining, closeTo(24.9, 1e-8));
    expect(match.clock, closeTo(.038, 1e-8));
    match.finishShot(goal: true, text: 'GOAL');
    final remaining = match.secondsRemaining;
    match.update(.1);
    expect(match.secondsRemaining, remaining);
  });

  test('a shot released before zero can score the winning goal', () {
    final match = MatchModel()..prepareStage(3)..startStage();
    match.goals = 3;
    match.secondsRemaining = .001;
    expect(match.shoot(), isTrue);
    // A clear left-corner trajectory near the end of its flight.
    match.shotTargetX = 90;
    match.ballY = MatchModel.goalY + 10;
    match.ballX = 90;
    match.update(.05);
    settleShot(match);
    expect(match.phase, MatchPhase.stageCleared);
    expect(match.secondsRemaining, 0);
    expect(match.goals, 4);
  });

  test('a non-winning buzzer shot resolves before the timeout screen', () {
    final match = MatchModel()..prepareStage(3)..startStage();
    match.secondsRemaining = .001;
    match.shoot();
    match.shotTargetX = 90;
    match.ballY = MatchModel.goalY + 10;
    match.ballX = 90;
    match.update(.05);
    expect(match.phase, MatchPhase.result);
    expect(match.goals, 1);
    settleShot(match);
    expect(match.phase, MatchPhase.finished);
    expect(match.message, "TIME'S UP!");
  });

  test('ending during a winning celebration preserves the clear', () {
    final match = MatchModel()..prepareStage(0)..startStage();
    match.goals = 2;
    match.finishShot(goal: true, text: 'GOAL');
    match.endRun();
    expect(match.phase, MatchPhase.stageCleared);
    expect(match.earnedStars, 3);
  });

  test('the final stage measures points, then Classic resets stage rules', () {
    final match = MatchModel()..prepareStage(5)..startStage();
    for (var i = 0; i < 3; i++) {
      match.finishShot(goal: true, corner: true, text: 'CORNER');
      settleShot(match);
    }
    expect(match.goals, 3);
    expect(match.score, 9);
    expect(match.phase, MatchPhase.stageCleared);
    expect(match.isFinalStage, isTrue);
    match.start();
    expect(match.isChallenge, isFalse);
    expect(match.isTimed, isFalse);
    expect(match.defenderCount, 0);
    expect(match.score, 0);
    expect(match.cornerGoals, 0);
    expect(match.phase, MatchPhase.aiming);
  });

  test('unlocks and best stars survive a save round trip without downgrading', () {
    final progress = ChallengeProgress();
    expect(progress.unlockedCount, 1);
    expect(progress.recordClear(1, 3), isFalse);
    expect(progress.recordClear(0, 2), isTrue);
    expect(progress.unlockedCount, 2);
    expect(progress.recordClear(0, 1), isFalse);
    progress.recordClear(1, 3);
    final restored = ChallengeProgress()..mergeSaved(progress.encode());
    expect(restored.totalStars, 5);
    expect(restored.unlockedCount, 3);
    expect(restored.starsFor(0), 2);
    restored.mergeSaved(['1', '1']);
    expect(restored.totalStars, 5);
  });

  test('invalid saves cannot skip locks and all clears finish the campaign', () {
    final progress = ChallengeProgress()..mergeSaved(['3', 'bad', '3']);
    expect(progress.unlockedCount, 2);
    expect(progress.starsFor(2), 0);
    for (var i = 0; i < challengeStages.length; i++) {
      progress.recordClear(i, 3);
    }
    expect(progress.completed, isTrue);
    expect(progress.totalStars, 18);
    expect(progress.unlockedCount, 6);
    expect(progress.isUnlocked(6), isFalse);
  });
}
