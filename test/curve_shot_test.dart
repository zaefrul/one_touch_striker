import 'package:flutter_test/flutter_test.dart';
import 'package:one_touch_striker/game/match_model.dart';
import 'package:one_touch_striker/game/shot_failure.dart';
import 'package:one_touch_striker/game/striker_game.dart';

// Regression sources for local execution. Not run for source publication.
void finishFlight(MatchModel match) {
  for (var i = 0; i < 180 && match.phase == MatchPhase.flying; i++) {
    match.update(1 / 240);
  }
}

void main() {
  test('press locks direction while the world moves; only release launches', () {
    final match = MatchModel()..prepareStage(0)..startStage();
    final initial = match.aimX;
    final keeperX = match.keeperX;
    expect(match.beginShot(), isTrue);
    expect(match.beginShot(), isFalse);
    for (var i = 0; i < 4; i++) { match.update(.1); }
    expect(match.phase, MatchPhase.aiming);
    expect(match.previewTargetX, initial);
    expect(match.aimX, isNot(initial));
    expect(match.keeperX, isNot(keeperX));
    expect(match.ballY, MatchModel.ballStartY);
    expect(match.keeper.shots, 0);
    expect(match.shoot(), isFalse);
    expect(match.releaseShot(), isTrue);
    expect(match.shotTargetX, initial);
    expect(match.keeper.shots, 1);
    expect(match.releaseShot(), isFalse);
    expect(match.beginShot(), isFalse);
  });

  test('jitter stays straight, drag reverses smoothly and moving back removes bend', () {
    final match = MatchModel()..start()..beginShot();
    match.adjustCurve(10);
    expect(match.preparedSpin, 0);
    expect(match.previewTargetX, 200);
    match.adjustCurve(57);
    expect(match.preparedSpin, closeTo(.5, 1e-9));
    expect(match.previewTargetX, closeTo(255, 1e-9));
    match.adjustCurve(-100);
    expect(match.preparedSpin, -1);
    expect(match.previewTargetX, 90);
    match.adjustCurve(1000);
    expect(match.preparedSpin, 1);
    match.adjustCurve(0);
    expect(match.preparedSpin, 0);
    match.releaseShot();
    match.adjustCurve(-100);
    expect(match.shotSpin, 0);
    expect(match.shotTargetX, 200);
  });

  test('a quick release follows the existing straight simulation', () {
    final tap = MatchModel()..start()..beginShot()..releaseShot();
    final original = MatchModel()..start()..shoot();
    for (var i = 0; i < 180; i++) {
      tap.update(1 / 240);
      original.update(1 / 240);
      expect(tap.ballX, original.ballX);
      expect(tap.ballY, original.ballY);
      expect(tap.phase, original.phase);
      expect(tap.score, original.score);
      expect(tap.misses, original.misses);
    }
  });

  test('opposite bends physically depart from the launch line and match the preview', () {
    for (final direction in [-1.0, 1.0]) {
      final match = MatchModel()..start()..beginShot();
      match.adjustCurve(direction * 100);
      final previewHalfway = match.previewXAt(.5);
      final previewTarget = match.previewTargetX;
      expect(previewHalfway, closeTo(200 + direction * 27.5, 1e-9));
      match.releaseShot();
      match.update(.1);
      match.update(.1);
      match.update(224 / 780 - .2);
      expect(match.ballY, closeTo(324, 1e-6));
      expect(match.ballX, closeTo(previewHalfway, 1e-6));
      expect(match.shotTargetX, previewTarget);
      match.adjustCurve(-direction * 100);
      expect(match.shotSpin, direction);
    }
  });

  test('defenders contact the curved ball rather than its old straight line', () {
    final match = MatchModel()..start();
    match.goals = 3;
    match.beginShot();
    match.adjustCurve(100);
    match.releaseShot();
    finishFlight(match);
    expect(match.lastFailure, ShotFailure.defender);
    expect(match.ballX, greaterThan(230));
    expect(match.hitsBox(match.defenderX(0), match.defenderY(0), 17, 13), isTrue);
    // A centre-line shot at this same instant lies outside the defender's reach.
    expect((match.defenderX(0) - 200).abs(), greaterThan(17 + MatchModel.ballRadius));
  });

  test('a curved corner uses normal scoring and excess bend really goes wide', () {
    final corner = MatchModel()..start()..beginShot()..adjustCurve(-100)..releaseShot();
    finishFlight(corner);
    expect(corner.lastWasCorner, isTrue);
    expect(corner.score, 3);
    expect(corner.ballX, closeTo(90, 1e-6));

    final wide = MatchModel()..start();
    for (var i = 0; i < 10; i++) { wide.update(.1); }
    wide.beginShot();
    wide.adjustCurve(100);
    expect(wide.previewTargetX, greaterThan(MatchModel.width));
    wide.releaseShot();
    finishFlight(wide);
    expect(wide.lastFailure, ShotFailure.wide);
    expect(wide.misses, 1);
    expect(wide.ballX, closeTo(wide.shotTargetX, 1e-6));
  });

  test('timeout cancels a hold but a shot released before zero keeps flying', () {
    final held = MatchModel()..prepareStage(3)..startStage();
    held.secondsRemaining = .01;
    held.beginShot();
    held.adjustCurve(100);
    held.update(.02);
    expect(held.phase, MatchPhase.finished);
    expect(held.isPreparingShot, isFalse);
    expect(held.releaseShot(), isFalse);
    expect(held.keeper.shots, 0);
    expect(held.misses, 0);

    final released = MatchModel()..prepareStage(3)..startStage();
    released.secondsRemaining = .01;
    released.beginShot();
    released.adjustCurve(-100);
    released.releaseShot();
    released.update(.02);
    expect(released.timeExpired, isTrue);
    expect(released.phase, MatchPhase.flying);
    expect(released.keeper.shots, 1);
  });

  test('pausing discards a draft and cannot release it after resume', () {
    final match = MatchModel();
    var changes = 0;
    final game = StrikerGame(match, onChanged: () => changes++, onShotResult: () {});
    game.startMatch();
    final before = changes;
    game.beginShot();
    game.adjustCurve(100);
    expect(changes, before); // Pointer movement does not rebuild the HUD.
    game.matchPaused = true;
    expect(match.isPreparingShot, isFalse);
    game.matchPaused = false;
    expect(game.releaseShot(), isFalse);
    expect(match.phase, MatchPhase.aiming);
    expect(match.misses, 0);
    game.beginShot();
    expect(match.preparedSpin, 0);
    game.returnToMenu();
    expect(match.isPreparingShot, isFalse);
  });
}
