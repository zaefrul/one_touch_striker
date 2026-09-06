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

  test('first aim shows a tap cue until the shot locks', () {
    final match = MatchModel();
    expect(match.showTapCue, isFalse);
    match.start();
    expect(match.showTapCue, isTrue);
    expect(match.shoot(), isTrue);
    expect(match.showTapCue, isFalse);
    match.finishShot(goal: true, text: 'GOAL');
    for (var frame = 0; frame < 70; frame++) {
      match.update(1 / 60);
    }
    expect(match.phase, MatchPhase.aiming);
    expect(match.showTapCue, isFalse);
    match.start();
    expect(match.showTapCue, isTrue);
  });

  test('third miss subtitle is that is all, not zero chances', () {
    final match = MatchModel()..start();
    match.finishShot(goal: false, text: 'MISS');
    expect(match.resultSubtitle, '2 CHANCES LEFT');
    match.finishShot(goal: false, text: 'MISS');
    expect(match.resultSubtitle, '1 CHANCE LEFT');
    match.finishShot(goal: false, text: 'MISS');
    expect(match.resultSubtitle, "THAT'S ALL");
    expect(match.lives, 0);
  });

  test('goal thresholds announce defender and streak unlocks', () {
    final match = MatchModel()..start();
    match.finishShot(goal: true, text: 'GOAL');
    match.finishShot(goal: true, text: 'GOAL');
    expect(match.unlockNote, isEmpty);
    match.finishShot(goal: true, text: 'GOAL');
    expect(match.unlockNote, 'MARKER ON');
    expect(match.resultSubtitle, '+1 POINTS · MARKER ON');
    match.finishShot(goal: true, text: 'GOAL');
    match.finishShot(goal: true, text: 'GOAL');
    expect(match.multiplier, 2);
    expect(match.unlockNote, '2× ON · NEXT SHOTS');
    expect(match.resultSubtitle, '+1 POINTS · 2× ON · NEXT SHOTS');
    for (var i = 0; i < 4; i++) {
      match.finishShot(goal: true, text: 'GOAL');
    }
    expect(match.goals, 9);
    expect(match.unlockNote, 'SECOND MARKER');
    expect(match.resultSubtitle, '+2 POINTS · SECOND MARKER');
  });

  test('a near-post miss is off the post, a far miss is just wide', () {
    final post = MatchModel()..start();
    post.phase = MatchPhase.flying;
    post.shotTargetX = 68;
    for (var i = 0; i < 40; i++) {
      post.update(1 / 60);
    }
    expect(post.message, 'OFF THE POST!');
    expect(post.lastWasPost, isTrue);
    expect(post.score, 0);

    final wide = MatchModel()..start();
    wide.phase = MatchPhase.flying;
    wide.shotTargetX = 30;
    for (var i = 0; i < 40; i++) {
      wide.update(1 / 60);
    }
    expect(wide.message, 'JUST WIDE!');
    expect(wide.lastWasPost, isFalse);
  });

  test('last chance is live only on the final aim', () {
    final match = MatchModel()..start();
    expect(match.lastChance, isFalse);
    match.finishShot(goal: false, text: 'MISS');
    match.finishShot(goal: false, text: 'MISS');
    expect(match.lives, 1);
    expect(match.lastChance, isFalse);
    for (var frame = 0; frame < 70; frame++) {
      match.update(1 / 60);
    }
    expect(match.phase, MatchPhase.aiming);
    expect(match.lastChance, isTrue);
  });

  test('highlight shots are detected from the locked target', () {
    final match = MatchModel()..start();
    match.shotTargetX = 90;
    expect(match.shotHeadsToCornerGoal, isTrue);
    expect(match.shotHeadsToPost, isFalse);
    match.shotTargetX = 68;
    expect(match.shotHeadsToCornerGoal, isFalse);
    expect(match.shotHeadsToPost, isTrue);
    match.shotTargetX = 200;
    expect(match.shotHeadsToCornerGoal, isFalse);
    expect(match.shotHeadsToPost, isFalse);
  });

  test('ending a run keeps the score and restart clears it', () {
    final match = MatchModel()..start();
    match.finishShot(goal: true, text: 'GOAL');
    match.endRun();
    expect(match.phase, MatchPhase.finished);
    expect(match.score, 1);
    expect(match.shoot(), isFalse);
    match.start();
    expect(match.score, 0);
    expect(match.phase, MatchPhase.aiming);
    expect(match.showTapCue, isTrue);
  });
}
