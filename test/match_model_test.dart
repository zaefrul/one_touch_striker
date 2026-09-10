import 'package:flutter_test/flutter_test.dart';
import 'package:one_touch_striker/game/bonus.dart';
import 'package:one_touch_striker/game/match_model.dart';
import 'package:one_touch_striker/game/stage.dart';
import 'package:one_touch_striker/progress/campaign.dart';

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

  test('third consecutive goal enables double points on following shots', () {
    final match = MatchModel()..start();
    for (var i = 0; i < 3; i++) {
      match.finishShot(goal: true, text: 'GOAL');
    }
    expect(match.score, 3);
    expect(match.multiplier, 2);
    expect(match.unlockNote, '2× ON · NEXT SHOTS');
    match.finishShot(goal: true, corner: true, text: 'CORNER');
    expect(match.score, 9);
    match.finishShot(goal: false, text: 'MISS');
    expect(match.streak, 0);
    expect(match.multiplier, 1);
  });

  test('five shots end a substage after result feedback, restart resets state',
      () {
    final match = MatchModel()..start();
    for (var i = 0; i < 5; i++) {
      match.finishShot(goal: false, text: 'MISS');
      for (var frame = 0; frame < 70; frame++) {
        match.update(1 / 60);
      }
    }
    expect(match.phase, MatchPhase.finished);
    expect(match.shotsTaken, 5);
    expect(match.shoot(), isFalse);
    match.start();
    expect(match.shotsTaken, 0);
    expect(match.shotsLeft, 5);
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
    match.shotTargetX = 303;
    for (var i = 0; i < 40; i++) {
      match.update(1 / 60);
    }
    expect(match.message, 'SAVED!');
    expect(match.score, 0);
  });

  test('defenders follow intensity, not goals, and large frames are bounded',
      () {
    final park = MatchModel(intensity: 1)..start();
    expect(park.defenderCount, 0);
    expect(MatchModel(intensity: 5).defenderCount, 1);
    expect(MatchModel(intensity: 9).defenderCount, 2);
    final village = MatchModel(stage: StageSpec.all[1], intensity: 3);
    expect(village.defenderCount, 1);
    expect(MatchModel(stage: StageSpec.all[1], intensity: 8).defenderCount, 2);
    park.shoot();
    park.update(30);
    expect(park.ballY, greaterThan(460));
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

  test('miss subtitles count remaining shots, last shot is that is all', () {
    final match = MatchModel()..start();
    match.finishShot(goal: false, text: 'MISS');
    expect(match.resultSubtitle, '4 SHOTS LEFT');
    match.finishShot(goal: false, text: 'MISS');
    expect(match.resultSubtitle, '3 SHOTS LEFT');
    match.finishShot(goal: false, text: 'MISS');
    expect(match.resultSubtitle, '2 SHOTS LEFT');
    match.finishShot(goal: false, text: 'MISS');
    expect(match.resultSubtitle, '1 SHOT LEFT');
    match.finishShot(goal: false, text: 'MISS');
    expect(match.resultSubtitle, "THAT'S ALL");
    expect(match.shotsLeft, 0);
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
    for (var i = 0; i < 4; i++) {
      match.finishShot(goal: false, text: 'MISS');
    }
    expect(match.shotsLeft, 1);
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

  test('village goat blocks a central shot', () {
    final match = MatchModel(stage: StageSpec.all[1], intensity: 1)..start();
    match.clock = 0;
    match.phase = MatchPhase.flying;
    match.shotTargetX = 200;
    for (var i = 0; i < 40; i++) {
      match.update(1 / 60);
    }
    expect(match.message, 'GOAT!');
    expect(match.score, 0);
  });

  test('orbit asteroid blocks a central shot', () {
    final match = MatchModel(stage: StageSpec.all[5], intensity: 1)..start();
    match.clock = -((548 - 330) / match.speedY);
    match.phase = MatchPhase.flying;
    match.shotTargetX = 200;
    for (var i = 0; i < 40; i++) {
      match.update(1 / 60);
    }
    expect(match.message, 'ASTEROID!');
    expect(match.score, 0);
  });

  test('ending a substage keeps the score and restart clears it', () {
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

  test('curve bends mid-flight and still misses a known wide target', () {
    final match = MatchModel(bonus: BallBonus.curve)..start();
    match.phase = MatchPhase.flying;
    match.shotTargetX = 30;
    var bent = false;
    for (var i = 0; i < 40; i++) {
      match.update(1 / 60);
      final progress =
          ((MatchModel.ballStartY - match.ballY) / (MatchModel.ballStartY - MatchModel.goalY))
              .clamp(0.0, 1.0);
      final straight =
          MatchModel.ballStartX + (30 - MatchModel.ballStartX) * progress;
      if ((match.ballX - straight).abs() > 8) {
        bent = true;
      }
    }
    expect(bent, isTrue);
    expect(match.score, 0);
    expect(match.message, 'JUST WIDE!');
  });

  test('super shoot reaches the goal in fewer ticks than straight', () {
    MatchModel fly(BallBonus bonus) {
      final match = MatchModel(bonus: bonus)..start();
      match.phase = MatchPhase.flying;
      match.shotTargetX = 90;
      return match;
    }

    final straight = fly(BallBonus.straight);
    var straightTicks = 0;
    while (straight.phase == MatchPhase.flying && straightTicks < 80) {
      straight.update(1 / 60);
      straightTicks++;
    }
    final speedy = fly(BallBonus.superShoot);
    var superTicks = 0;
    while (speedy.phase == MatchPhase.flying && superTicks < 80) {
      speedy.update(1 / 60);
      superTicks++;
    }
    expect(MatchModel(bonus: BallBonus.superShoot).speedY,
        greaterThan(MatchModel().speedY));
    expect(superTicks, lessThan(straightTicks));
    expect(speedy.phase, isNot(MatchPhase.flying));
  });

  test('star thresholds award 0 to 3 and venue 1-1 is 3 / 6 / 9', () {
    expect(const SubstageRef(0, 0).thresholds, [3, 6, 9]);
    expect(starsFor(0, const [3, 6, 9]), 0);
    expect(starsFor(3, const [3, 6, 9]), 1);
    expect(starsFor(5, const [3, 6, 9]), 1);
    expect(starsFor(6, const [3, 6, 9]), 2);
    expect(starsFor(9, const [3, 6, 9]), 3);
    expect(starsFor(20, const [3, 6, 9]), 3);
  });

  test('one star unlocks the next substage and later venues wait for 1-10', () {
    expect(starsFor(3, Campaign.thresholds(0, 0)), 1);
    final next = const SubstageRef(0, 0).next;
    expect(next?.code, '1-2');
    expect(const SubstageRef(0, 9).next?.code, '2-1');
    expect(const SubstageRef(5, 9).next, isNull);
  });
}
