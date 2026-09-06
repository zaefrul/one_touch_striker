import 'package:flutter_test/flutter_test.dart';
import 'package:one_touch_striker/game/match_model.dart';

void main() {
  test('tap locks the target and repeated taps do not alter the shot', () {
    final match = MatchModel()..start();
    match.update(.08);
    final target = match.aimX;
    expect(match.shoot(), isTrue);
    match.update(.04);
    expect(match.shoot(), isFalse);
    expect(match.shotTargetX, target);
  });

  test('fifth consecutive goal enables double points on following shots', () {
    final match = MatchModel()..start();
    for (var i = 0; i < 5; i++) {
      match.finishShot(goal: true, text: 'GOAL');
    }
    expect(match.score, 5);
    expect(match.multiplier, 2);
    match.finishShot(goal: true, corner: true, text: 'CORNER');
    expect(match.score, 11);
    match.finishShot(goal: false, text: 'MISS');
    expect(match.streak, 0);
    expect(match.multiplier, 1);
  });

  test('three misses end a run after result feedback, restart resets state',
      () {
    final match = MatchModel()..start();
    for (var i = 0; i < 3; i++) {
      match.finishShot(goal: false, text: 'MISS');
      for (var frame = 0; frame < 70; frame++) {
        match.update(1 / 60);
      }
    }
    expect(match.phase, MatchPhase.finished);
    expect(match.shoot(), isFalse);
    match.start();
    expect(match.lives, 3);
    expect(match.score, 0);
    expect(match.phase, MatchPhase.aiming);
  });

  test('a wide shot cannot score', () {
    final match = MatchModel()..start();
    match.phase = MatchPhase.flying;
    match.shotTargetX = 30;
    for (var i = 0; i < 40; i++) {
      match.update(1 / 60);
    }
    expect(match.score, 0);
    expect(match.misses, 1);
    expect(match.message, 'JUST WIDE!');
  });

  test('corner with a clear path earns three points', () {
    final match = MatchModel()..start();
    match.phase = MatchPhase.flying;
    match.shotTargetX = 90;
    for (var i = 0; i < 40; i++) {
      match.update(1 / 60);
    }
    expect(match.score, 3);
    expect(match.lastWasCorner, isTrue);
  });

  test('keeper interception is detected on a crossing step', () {
    final match = MatchModel()..start();
    match.phase = MatchPhase.flying;
    // At t≈0.52 the keeper is near x=297; this trajectory intersects him.
    match.shotTargetX = 303;
    for (var i = 0; i < 40; i++) {
      match.update(1 / 60);
    }
    expect(match.message, 'SAVED!');
    expect(match.score, 0);
  });

  test('defenders unlock with goals and large frame gaps are bounded', () {
    final match = MatchModel()..start();
    match.goals = 3;
    expect(match.defenderCount, 1);
    match.goals = 9;
    expect(match.defenderCount, 2);
    match.shoot();
    match.update(30);
    expect(match.ballY, greaterThan(460));
  });
}
