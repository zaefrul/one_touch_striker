import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:one_touch_striker/game/match_model.dart';
import 'package:one_touch_striker/game/shot_trail.dart';

// Prepared for local execution by the owner; not run during publication.
void main() {
  test('a Classic goal changes speed without jumping player or arrow position', () {
    final match = MatchModel()..start();
    for (var i = 0; i < 120; i++) {
      match.update(.1);
    }
    final keeper = match.keeperX;
    final aim = match.aimX;
    match.finishShot(goal: true, text: 'GOAL');
    expect(match.keeperX, keeper);
    expect(match.aimX, aim);
    match.update(.001);
    expect((match.keeperX - keeper).abs(), lessThan(1));
    expect((match.aimX - aim).abs(), lessThan(1));
  });

  test('initial Classic movement retains its existing speed and phase', () {
    final match = MatchModel()..start();
    for (var i = 0; i < 30; i++) {
      match.update(1 / 60);
    }
    expect(match.aimX, closeTo(200 + 172 * math.sin(.5 * 1.35), 1e-8));
    expect(match.keeperX, closeTo(200 + 100 * math.sin(.5 + .8), 1e-8));
  });

  test('cinematic entry and recovery ease while timer and feedback use active time', () {
    final match = MatchModel()..prepareStage(3)..startStage();
    match.phase = MatchPhase.flying;
    match.shotTargetX = 90;
    match.ballY = 210;
    match.update(1 / 60, cinematic: true);
    expect(match.motionScale, greaterThan(.38));
    expect(match.motionScale, lessThan(1));
    expect(match.secondsRemaining, closeTo(25 - 1 / 60, 1e-8));
    final entryScale = match.motionScale;
    final remaining = match.secondsRemaining;
    final spin = match.ballAngle;
    match.finishShot(goal: true, text: 'GOAL');
    match.update(1 / 60, cinematic: true);
    expect(match.motionScale, greaterThan(entryScale));
    expect(match.motionScale, lessThan(1));
    expect(match.resultTime, closeTo(.85 - 1 / 60, 1e-8));
    expect(match.secondsRemaining, remaining);
    expect(match.ballAngle, spin);
  });

  test('cinematic trajectories agree across 60 Hz and 120 Hz frame partitions', () {
    MatchModel play(int hz) {
      final match = MatchModel()..start();
      match.phase = MatchPhase.flying;
      match.shotTargetX = 90;
      for (var i = 0; i < hz ~/ 2; i++) {
        match.update(1 / hz, cinematic: true);
      }
      return match;
    }
    final sixty = play(60);
    final fast = play(120);
    expect(sixty.phase, fast.phase);
    expect(sixty.ballX, closeTo(fast.ballX, .001));
    expect(sixty.ballY, closeTo(fast.ballY, .001));
    expect(sixty.keeperX, closeTo(fast.keeperX, .001));
  });

  test('longest streak and accuracy survive misses and reset for the next attempt', () {
    final match = MatchModel()..start();
    match.finishShot(goal: true, corner: true, text: 'CORNER');
    match.finishShot(goal: true, text: 'GOAL');
    match.finishShot(goal: false, text: 'MISS');
    match.finishShot(goal: true, text: 'GOAL');
    expect(match.streak, 1);
    expect(match.longestStreak, 2);
    expect(match.accuracy, 75);
    expect(match.resolvedShots, 4);
    expect(match.cornerGoals, 1);
    match.prepareStage(0);
    expect(match.longestStreak, 0);
    expect(match.accuracy, 0);
    expect(match.resolvedShots, 0);
    expect(match.ballAngle, 0);
  });

  test('trail duration and positions agree at 60, 90 and 120 Hz', () {
    ShotTrail sampleLine(int hz) {
      final trail = ShotTrail();
      for (var i = 0; i < hz ~/ 2; i++) {
        trail.sample(1 / hz, 200, 548 - 100 * i / hz,
            200, 548 - 100 * (i + 1) / hz);
      }
      return trail;
    }
    final sixty = sampleLine(60);
    for (final hz in [90, 120]) {
      final other = sampleLine(hz);
      expect(other.length, ShotTrail.capacity);
      for (var i = 0; i < sixty.length; i++) {
        expect(other.xAt(i), closeTo(sixty.xAt(i), 1e-8));
        expect(other.yAt(i), closeTo(sixty.yAt(i), 1e-8));
      }
    }
    expect(sixty.yAt(sixty.length - 1), closeTo(498.8, 1e-8));
  });

  test('trail keeps partial frame time and clears it between shots', () {
    final trail = ShotTrail();
    trail.sample(.006, 0, 0, 6, 6);
    expect(trail.length, 0);
    trail.sample(.006, 6, 6, 12, 12);
    expect(trail.length, 1);
    expect(trail.xAt(0), closeTo(12, 1e-8));
    trail.clear();
    trail.sample(.006, 0, 0, 6, 6);
    expect(trail.length, 0);
  });
}
