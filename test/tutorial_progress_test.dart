import 'package:flutter_test/flutter_test.dart';
import 'package:one_touch_striker/game/knuckle_shot.dart';
import 'package:one_touch_striker/game/match_model.dart';
import 'package:one_touch_striker/game/tutorial_progress.dart';

// Prepared for local execution. No tests run as part of publication.
void main() {
  test('completed and skipped lessons survive relaunch independently of stars', () {
    final progress = TutorialProgress()..complete(TutorialLesson.aim)..skipAll();
    final restored = TutorialProgress();
    expect(restored.restore(progress.encode()), isTrue);
    for (final lesson in TutorialLesson.values) {
      expect(restored.needs(lesson), isFalse);
    }
    restored.complete(TutorialLesson.knuckle); // A replay can replace a skip.
    final again = TutorialProgress()..restore(restored.encode());
    expect(again.needs(TutorialLesson.knuckle), isFalse);
    expect(TutorialProgress().needs(TutorialLesson.knuckle), isTrue);
  });

  test('unsupported or damaged lesson saves are reported for preservation', () {
    expect(TutorialProgress().restore('{"version":2}'), isFalse);
    expect(TutorialProgress().restore('broken'), isFalse);
    expect(TutorialProgress().restore('{"version":1,"completed":[],"skipped":[]}'), isTrue);
  });

  test('a correct curve gesture still completes when the real path is blocked', () {
    final model = MatchModel()..start()..beginShot()..adjustCurve(-65)..releaseShot();
    model.finishShot(goal: false, blocked: true, text: 'BLOCKED');
    expect(TutorialLesson.curveLeft.accepts(model), isTrue);
    expect(TutorialLesson.curveRight.accepts(model), isFalse);
    expect(TutorialLesson.banana.accepts(model), isFalse);
    expect(model.lastWasGoal, isFalse);
  });

  test('every timing revolution agrees with readiness and the released shot', () {
    for (final rate in [30, 60, 120]) {
      final model = MatchModel()..start()..beginShot();
      for (var frame = 0; frame < rate * 4; frame++) {
        model.update(1 / rate);
      }
      for (var frame = 0; frame < rate * .65; frame++) {
        model.update(1 / rate);
      }
      expect(model.heldSeconds, greaterThan(4));
      expect(model.timingPhase, inInclusiveRange(.64, .69));
      expect(model.knuckleReady, isTrue);
      expect(model.resolvedShots, 0);
      expect(model.releaseShot(), isTrue);
      expect(model.shotTiming, StrikeTiming.clean);
      expect(model.releaseShot(), isFalse);
    }
  });

  test('dragging opts out of knuckle timing on subsequent revolutions too', () {
    final model = MatchModel()..start()..beginShot();
    model.adjustCurve(60);
    model.adjustCurve(0);
    for (var frame = 0; frame < 219; frame++) { model.update(1 / 60); }
    expect(model.timingPhase, closeTo(.65, 1e-6));
    expect(model.canTimeKnuckle, isFalse);
    expect(model.knuckleReady, isFalse);
    model.releaseShot();
    expect(model.shotTiming, StrikeTiming.adjusted);
    expect(model.shotSpin, 0);
  });
}
