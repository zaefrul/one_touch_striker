import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:one_touch_striker/game/knuckle_shot.dart';
import 'package:one_touch_striker/game/match_model.dart';
import 'package:one_touch_striker/game/practice_drill.dart';
import 'package:one_touch_striker/game/shot_failure.dart';
import 'package:one_touch_striker/game/striker_game.dart';

// Source cases for local execution; no tests were run for publication.
void advance(MatchModel match, double seconds) {
  for (var remaining = seconds; remaining > 1e-9;) {
    final step = math.min(.05, remaining);
    match.update(step);
    remaining -= step;
  }
}

void finishFlight(MatchModel match) {
  for (var frame = 0; frame < 240 && match.phase == MatchPhase.flying; frame++) {
    match.update(1 / 240);
  }
}

// A fixed contact fixture: the original centre line misses this defender,
// while the late wobble enters its real collision box. No outcome is injected.
class LateWallMatch extends MatchModel {
  @override
  int get defenderCount => 1;
  @override
  double defenderX(int index) => 232;
  @override
  double defenderY(int index) => 279;
  @override
  bool get hasKeeper => false;
}

void main() {
  test('release timing selects a shot; waiting never fires or repeats the window', () {
    for (final entry in <double, StrikeTiming>{
      .1: StrikeTiming.tap, .4: StrikeTiming.early,
      .64: StrikeTiming.clean, .9: StrikeTiming.late, 2: StrikeTiming.late,
    }.entries) {
      final match = MatchModel()..start()..beginShot();
      advance(match, entry.key);
      expect(match.phase, MatchPhase.aiming);
      expect(match.ballY, MatchModel.ballStartY);
      expect(match.resolvedShots, 0);
      expect(match.previewTargetX, 200);
      expect(match.aimX, isNot(200));
      expect(match.releaseShot(), isTrue);
      expect(match.shotTiming, entry.value);
      expect(match.shotIsKnuckle, entry.value == StrikeTiming.clean);
      expect(match.shotSpin, 0);
      expect(match.releaseShot(), isFalse);
    }
  });

  test('jitter allows timing; deliberate movement opts out until a new press', () {
    final jitter = MatchModel()..start()..beginShot();
    jitter.adjustCurve(8, dragY: -8);
    advance(jitter, .64);
    expect(jitter.knuckleReady, isTrue);
    jitter.releaseShot();
    expect(jitter.shotIsKnuckle, isTrue);

    for (final vertical in [false, true]) {
      final moved = MatchModel()..start()..beginShot();
      moved.adjustCurve(vertical ? 0 : 20, dragY: vertical ? 20 : 0);
      moved.adjustCurve(0);
      advance(moved, .64);
      expect(moved.knuckleReady, isFalse);
      moved.releaseShot();
      expect(moved.shotTiming, StrikeTiming.adjusted);
      expect(moved.shotSpin, 0);
      moved.start();
      moved.beginShot();
      advance(moved, .64);
      expect(moved.knuckleReady, isTrue);
    }
  });

  test('preview, flight and endpoint agree on a repeatable bounded wobble', () {
    final first = MatchModel()..startPractice(PracticeDrill.corners)..beginShot();
    final repeat = MatchModel()..startPractice(PracticeDrill.corners)..beginShot();
    advance(first, .64);
    advance(repeat, .64);
    final preview = first.previewXAt(.64);
    first.releaseShot();
    repeat.releaseShot();
    advance(first, (MatchModel.ballStartY - MatchModel.goalY) * .64 / 780);
    advance(repeat, (MatchModel.ballStartY - MatchModel.goalY) * .64 / 780);
    expect(first.ballX, closeTo(preview, 1e-6));
    expect(first.ballX, greaterThan(200));
    expect(first.ballX, repeat.ballX);
    expect(first.ballY, repeat.ballY);
    for (var sample = 0; sample <= 100; sample++) {
      expect(KnuckleShot.offsetAt(sample / 100).abs(),
          lessThanOrEqualTo(KnuckleShot.maxWobble));
    }
    expect(KnuckleShot.offsetAt(.2), 0);
    expect(KnuckleShot.offsetAt(.6), greaterThan(0));
    expect(KnuckleShot.offsetAt(.85), lessThan(0));
    finishFlight(first);
    expect(first.lastWasGoal, isTrue);
    expect(first.ballX, closeTo(first.shotTargetX, 1e-6));
    expect(first.ballAngle, lessThan(1));
  });

  test('the wobbling ball can be blocked where the straight trajectory misses', () {
    final knuckle = LateWallMatch()..start()..beginShot();
    advance(knuckle, .64);
    knuckle.releaseShot();
    finishFlight(knuckle);
    expect(knuckle.lastFailure, ShotFailure.defender);
    expect(knuckle.hitsBox(232, 279, 17, 13), isTrue);
    expect(knuckle.shotExplanation, 'Clean knuckle · Blocked');

    final straight = LateWallMatch()..start();
    straight.shoot();
    finishFlight(straight);
    expect(straight.lastWasGoal, isTrue);
  });

  test('clean execution and goal outcome remain independent of Fire scoring', () {
    final match = MatchModel()..prepareStage(0)..startStage();
    match.fireCharge = match.stage!.fireChargeGoals;
    match.beginShot();
    advance(match, .64);
    match.releaseShot();
    expect(match.shotIsKnuckle, isTrue);
    expect(match.shotIsFire, isTrue);
    // Inject only the scoring outcome to isolate technique and bonus accounting.
    match.finishShot(goal: false, keeperSave: true, text: 'SAVED!');
    expect(match.shotExplanation, 'Clean knuckle · Saved');
    expect(match.score, 0);
    expect(match.fireCharge, 0);
    expect(match.misses, 1);

    final early = MatchModel()..start()..beginShot();
    advance(early, .4);
    early.releaseShot();
    early.finishShot(goal: true, text: 'GOAL');
    expect(early.shotExplanation, 'Released early · Goal');
    advance(early, 1);
    expect(early.lastTechniqueAdvice, contains('blue zone'));
  });

  test('timeout and pause discard the timing attempt without using a ball', () {
    final timed = MatchModel()..prepareStage(3)..startStage();
    timed.secondsRemaining = .4;
    timed.beginShot();
    advance(timed, .6);
    expect(timed.phase, MatchPhase.finished);
    expect(timed.releaseShot(), isFalse);
    expect(timed.resolvedShots, 0);

    final match = MatchModel();
    var changes = 0;
    final game = StrikerGame(match, onChanged: () => changes++, onShotResult: () {});
    game.startPractice(PracticeDrill.knuckle);
    final beforeHold = changes;
    game.beginShot();
    for (var frame = 0; frame < 6; frame++) { game.update(.1); }
    expect(match.knuckleReady, isTrue);
    expect(changes, beforeHold); // No per-frame Flutter rebuild for the ring.
    game.matchPaused = true;
    game.matchPaused = false;
    expect(game.releaseShot(), isFalse);
    expect(match.practiceBallsLeft, 5);
    game.beginShot();
    expect(match.heldSeconds, 0);
  });
}
