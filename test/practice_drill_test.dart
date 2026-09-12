import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_touch_striker/game/match_model.dart';
import 'package:one_touch_striker/game/practice_drill.dart';
import 'package:one_touch_striker/game/practice_progress.dart';
import 'package:one_touch_striker/game/rival_ledger.dart';

// Source-only cases. Scoring outcomes below are injected to exercise drill
// rules; real contact and trajectories are covered in the shot source cases.
void nextBall(MatchModel match) {
  for (var frame = 0; frame < 40 && match.phase == MatchPhase.result; frame++) {
    match.update(.05);
  }
}

void aimAtTarget(MatchModel match) {
  expect(match.shoot(), isTrue);
  match.shotTargetX = match.practiceTargetX;
}

void main() {
  test('all five balls count after misses, with one result per released ball', () {
    final match = MatchModel()..startPractice(PracticeDrill.corners);
    match.beginShot();
    match.cancelShot();
    expect(match.practiceBallsLeft, 5);
    for (var ball = 0; ball < 5; ball++) {
      expect(match.phase, MatchPhase.aiming);
      expect(match.practiceBallsLeft, 5 - ball);
      match.shoot();
      expect(match.practiceBallsLeft, 4 - ball);
      match.finishShot(goal: false, text: 'WIDE');
      match.finishShot(goal: true, text: 'DUPLICATE');
      expect(match.resolvedShots, ball + 1);
      expect(match.practiceShots.length, ball + 1);
      expect(match.practiceShots.last.hit, isFalse);
      nextBall(match);
    }
    expect(match.phase, MatchPhase.finished);
    expect(match.practiceCompleted, isTrue);
    expect(match.practiceBallsLeft, 0);
    expect(match.practiceHits, 0);
    expect(match.shoot(), isFalse);
  });

  test('marked target stays through feedback and alternates on the next ball', () {
    final match = MatchModel()..startPractice(PracticeDrill.corners);
    expect(match.hasKeeper, isFalse);
    expect(match.defenderCount, 0);
    expect(match.practiceTargetX, 91);
    aimAtTarget(match);
    match.finishShot(goal: true, corner: true, text: 'GOAL');
    expect(match.practiceHits, 1);
    expect(match.lastPoints, 1);
    expect(match.practiceTargetX, 91);
    nextBall(match);
    expect(match.practiceTargetX, 309);
    match.shoot();
    match.shotTargetX = 91;
    match.finishShot(goal: true, corner: true, text: 'GOAL');
    expect(match.goals, 2);
    expect(match.practiceHits, 1);
    expect(match.lastPracticeNote, contains('outside the marked target'));
  });

  test('wall drill needs a curve, a goal and the marked target together', () {
    final match = MatchModel()..startPractice(PracticeDrill.curveWall);
    expect(match.hasKeeper, isFalse);
    expect(match.defenderCount, 1);
    aimAtTarget(match);
    match.finishShot(goal: true, text: 'GOAL');
    expect(match.practiceHits, 0);
    expect(match.lastPracticeNote, contains('add curve'));
    nextBall(match);
    match.beginShot();
    match.adjustCurve(100);
    match.releaseShot();
    match.shotTargetX = match.practiceTargetX;
    match.finishShot(goal: true, text: 'GOAL');
    expect(match.practiceHits, 1);
    nextBall(match);
    match.beginShot();
    match.adjustCurve(-100);
    match.releaseShot();
    match.shotTargetX = 200;
    match.finishShot(goal: true, text: 'GOAL');
    expect(match.practiceHits, 1);
  });

  test('knuckle drill records clean execution even when the keeper saves', () {
    final match = MatchModel()..startPractice(PracticeDrill.knuckle);
    expect(match.usesProfessionalKeeper, isTrue);
    expect(match.defenderCount, 0);
    match.shoot();
    match.finishShot(goal: true, text: 'GOAL');
    expect(match.practiceHits, 0);
    for (final saved in [true, false]) {
      nextBall(match);
      match.beginShot();
      for (var frame = 0; frame < 6; frame++) { match.update(.1); }
      match.releaseShot();
      match.finishShot(goal: !saved, keeperSave: saved, text: saved ? 'SAVED' : 'GOAL');
    }
    expect(match.practiceCleanStrikes, 2);
    expect(match.practiceHits, 1);
    expect(match.practiceShots[1].explanation, 'Clean knuckle · Saved');
    expect(match.practiceShots[2].explanation, 'Clean knuckle · Goal');
    expect(match.onFire, isFalse);
    expect(match.isTimed, isFalse);
  });

  test('abandoned drills do not complete; replay and mode changes reset the attempt', () {
    final match = MatchModel()..startPractice(PracticeDrill.corners);
    aimAtTarget(match);
    match.finishShot(goal: true, text: 'GOAL');
    match.endRun();
    expect(match.practiceCompleted, isFalse);
    expect(RivalLedger().recordResult(match), isFalse);
    match.startPractice(PracticeDrill.corners);
    expect(match.practiceHits, 0);
    expect(match.practiceShots, isEmpty);
    expect(match.practiceBallsLeft, 5);
    match.prepareStage(0);
    expect(match.isPractice, isFalse);
    expect(match.isChallenge, isTrue);
    match.startPractice(PracticeDrill.curveWall);
    match.start();
    expect(match.isClassic, isTrue);
    expect(match.practice, isNull);
    expect(match.defenderCount, 0);
    expect(match.lastTechnique, isEmpty);
  });

  test('practice bests persist independently, never decrease and reject invalid scores', () {
    final progress = PracticeProgress();
    expect(progress.record(PracticeDrill.corners, 3), isTrue);
    expect(progress.record(PracticeDrill.corners, 2), isFalse);
    expect(progress.record(PracticeDrill.corners, 3), isFalse);
    expect(progress.record(PracticeDrill.corners, 6), isFalse);
    expect(progress.record(PracticeDrill.knuckle, -1), isFalse);
    final restored = PracticeProgress();
    expect(restored.restore(progress.encode()), isTrue);
    expect(restored.bestFor(PracticeDrill.corners), 3);
    expect(restored.bestFor(PracticeDrill.knuckle), 0);
    restored.record(PracticeDrill.corners, 5);
    expect(restored.restore(progress.encode()), isTrue);
    expect(restored.bestFor(PracticeDrill.corners), 5);
  });

  test('malformed and future saves are rejected without partially changing bests', () {
    for (final source in [
      '{broken', '[]', '{"version":2,"best":{}}',
      jsonEncode({'version': 1, 'best': {'corner_practice': 5, 'curve_wall': null}}),
      jsonEncode({'version': 1, 'best': {'corner_practice': 5, 'curve_wall': 6}}),
    ]) {
      final progress = PracticeProgress()..record(PracticeDrill.corners, 2);
      expect(progress.restore(source), isFalse);
      expect(progress.bestFor(PracticeDrill.corners), 2);
    }
    expect(PracticeProgress().restore(null), isTrue);
  });
}
