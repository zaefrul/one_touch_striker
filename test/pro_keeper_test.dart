import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:one_touch_striker/game/keeper_controller.dart';
import 'package:one_touch_striker/game/keeper_pose.dart';
import 'package:one_touch_striker/game/keeper_skill.dart';
import 'package:one_touch_striker/game/match_model.dart';

// Prepared regression cases for owner execution. No test/build was run here.
void observe(KeeperController keeper, double dt, double target) {
  const y = 350.0;
  keeper.updateFlight(dt, 200, 0,
      ballX: 200 + (target - 200) * (548 - y) / 448,
      ballY: y, launchX: 200, launchY: 548);
}

void settle(MatchModel match) {
  for (var i = 0; i < 180 && match.phase == MatchPhase.result; i++) {
    match.update(1 / 60);
  }
}

void main() {
  test('the keeper cannot read a direction before the reaction delay', () {
    final left = KeeperController()..reset(KeeperSkill.worldClass, 200)..beginShot();
    final right = KeeperController()..reset(KeeperSkill.worldClass, 200)..beginShot();
    observe(left, .16, 90);
    observe(right, .16, 310);
    expect(left.committed, isFalse);
    expect(right.committed, isFalse);
    expect(left.pose.x, right.pose.x);
    expect(left.pose.rotation, right.pose.rotation);
    observe(left, .02, 90);
    observe(right, .02, 310);
    expect(left.action, KeeperAction.dive);
    expect(right.action, KeeperAction.dive);
    expect(left.committedX, lessThan(200));
    expect(right.committedX, greaterThan(200));
    expect((left.pose.x - 200).abs(), lessThan(1));
    expect((right.pose.x - 200).abs(), lessThan(1));
  });

  test('a dive has finite reach and cannot retarget after committing', () {
    final keeper = KeeperController()..reset(KeeperSkill.club, 200)..beginShot();
    observe(keeper, .29, 90);
    final destination = keeper.committedX;
    expect(200 - destination, lessThanOrEqualTo(keeper.skill.diveReach));
    for (var i = 0; i < 100; i++) {
      observe(keeper, 1 / 240, 310);
    }
    expect(keeper.committedX, destination);
    expect(keeper.pose.x, closeTo(destination, 1e-8));
    expect(keeper.pose.x, greaterThan(90));
    expect(keeper.pose.rotation, lessThan(0));
  });

  test('the third shot warns of a rush and advances into a sliding block', () {
    final keeper = KeeperController()..reset(KeeperSkill.professional, 200);
    for (var shot = 0; shot < 2; shot++) {
      expect(keeper.rushIncoming, isFalse);
      keeper.beginShot();
      keeper.resolveShot(saved: false, targetX: 200);
      keeper.updateFeedback(1, 200, 0);
    }
    expect(keeper.rushIncoming, isTrue);
    keeper.updateAiming(.1, 200, 0);
    expect(keeper.cue, 'RUSH INCOMING');
    final advance = keeper.pose.y;
    expect(advance, greaterThan(KeeperController.homeY));
    keeper.beginShot();
    for (var i = 0; i < 144; i++) {
      observe(keeper, 1 / 240, 220);
    }
    expect(keeper.action, KeeperAction.slide);
    expect(keeper.pose.y, greaterThan(advance));
    expect(keeper.pose.y, lessThanOrEqualTo(KeeperController.homeY + keeper.skill.rushDistance));
  });

  test('the drawn glove still collides when the body is translated and rotated', () {
    final pose = KeeperPose()
      ..x = 265
      ..y = 151
      ..rotation = 1.18;
    pose.update(dive: 1);
    final glove = pose.segments[8];
    final x = pose.x + glove.ax * math.cos(pose.rotation) - glove.ay * math.sin(pose.rotation);
    final y = pose.y + glove.ax * math.sin(pose.rotation) + glove.ay * math.cos(pose.rotation);
    expect(pose.hitsBall(x, y, 8), isTrue);
    expect(pose.hitsBall(200, 126, 8), isFalse); // Old anchor is not a hitbox.
    expect(pose.hitsBall(pose.x - 60, pose.y + 60, 8), isFalse);
  });

  test('only an actual keeper save earns a taunt and feedback recovers the pose', () {
    final keeper = KeeperController()..reset(KeeperSkill.professional, 200)..beginShot();
    observe(keeper, .50, 90);
    keeper.resolveShot(saved: true, targetX: 90);
    keeper.updateFeedback(.7, 200, .7);
    expect(keeper.action, KeeperAction.taunt);
    expect(keeper.pose.rotation, 0);
    keeper.updateFeedback(.3, 200, 1);
    expect(keeper.action, KeeperAction.recover);
    keeper.resolveShot(saved: false, targetX: 90);
    keeper.updateFeedback(.7, 200, 1.7);
    expect(keeper.action, isNot(KeeperAction.taunt));
  });

  test('elite marking remembers resolved shots, and retry clears all tactics', () {
    final match = MatchModel()..prepareStage(9)..startStage();
    for (var shot = 0; shot < 2; shot++) {
      expect(match.shoot(), isTrue);
      match.shotTargetX = 90;
      match.finishShot(goal: true, text: 'GOAL');
      settle(match);
    }
    expect(match.keeper.markingOffset, lessThan(0));
    expect(match.keeper.rushIncoming, isTrue);
    match.shoot();
    match.endRun();
    match.retryStage();
    expect(match.keeper.skill, KeeperSkill.worldClass);
    expect(match.keeper.shots, 0);
    expect(match.keeper.rushIncoming, isFalse);
    expect(match.keeper.markingOffset, 0);
    expect(match.keeper.pose.rotation, 0);
    expect(match.keeper.pose.y, KeeperController.homeY);
    expect(match.lastWasKeeperSave, isFalse);
  });

  test('challenge dive and flight agree across 60 and 120 Hz frame partitions', () {
    MatchModel play(int hz) {
      final match = MatchModel()..prepareStage(3)..startStage()..shoot();
      match.shotTargetX = 90;
      for (var frame = 0; frame < hz ~/ 2; frame++) {
        match.update(1 / hz, cinematic: true);
      }
      return match;
    }
    final sixty = play(60), fast = play(120);
    expect(sixty.keeper.committed, isTrue);
    expect(sixty.phase, fast.phase);
    expect(sixty.keeperX, closeTo(fast.keeperX, .001));
    expect(sixty.keeperY, closeTo(fast.keeperY, .001));
    expect(sixty.keeper.pose.rotation, closeTo(fast.keeper.pose.rotation, .001));
    expect(sixty.ballX, closeTo(fast.ballX, .001));
    expect(sixty.ballY, closeTo(fast.ballY, .001));
  });
}
