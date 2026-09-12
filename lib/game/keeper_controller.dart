import 'dart:math' as math;
import 'keeper_pose.dart';
import 'keeper_skill.dart';

enum KeeperAction { patrol, set, dive, slide, recover, taunt }

/// Observes the visible ball only after the reaction delay. Each save commits
/// once to a bounded destination; it never snaps to the shot or retargets.
class KeeperController {
  static const homeY = 126.0;
  static const actionDuration = .28;
  final KeeperPose pose = KeeperPose();
  KeeperSkill skill = KeeperSkill.academy;
  KeeperAction action = KeeperAction.patrol;
  int shots = 0;
  double _flightTime = 0, _feedbackTime = 0;
  double _fromX = 200, _fromY = homeY, _endX = 200, _endY = homeY;
  double _fromRotation = 0, _fromDive = 0, _fromSlide = 0;
  double _dive = 0, _slide = 0, _direction = 1;
  double _markTarget = 0, _markOffset = 0;
  double _stride = 0;
  double _velocityX = 0, _plantVelocityX = 0;
  bool _committed = false, _rushShot = false, _saved = false;

  bool get rushIncoming => skill.canSlide && (shots + 1) % 3 == 0;
  bool get committed => _committed;
  double get committedX => _endX;
  double get markingOffset => _markOffset;
  double get parryDirection => _direction;

  String get cue => switch (action) {
        KeeperAction.set => _rushShot ? 'RUSH INCOMING' : 'FEET SET',
        KeeperAction.dive => 'FULL STRETCH',
        KeeperAction.slide => 'RUSH & SLIDE',
        KeeperAction.taunt => 'NOT THIS TIME!',
        KeeperAction.recover => '',
        KeeperAction.patrol => rushIncoming ? 'RUSH INCOMING' :
            _markOffset < -5 ? 'COVERING LEFT' :
            _markOffset > 5 ? 'COVERING RIGHT' : '',
      };

  void reset(KeeperSkill nextSkill, double startX) {
    skill = nextSkill;
    action = KeeperAction.patrol;
    shots = 0;
    _flightTime = _feedbackTime = 0;
    _fromX = _endX = pose.x = startX;
    _fromY = _endY = pose.y = homeY;
    _fromRotation = pose.rotation = 0;
    _fromDive = _fromSlide = _dive = _slide = 0;
    _markTarget = _markOffset = 0;
    _stride = 0;
    _velocityX = _plantVelocityX = 0;
    _committed = _rushShot = _saved = false;
    _direction = 1;
    pose.update();
  }

  void _followPatrol(double dt, double patrolX, {double advance = 0}) {
    _markOffset = _towards(_markOffset, _markTarget, 24 * dt);
    final targetX = (patrolX + _markOffset).clamp(78.0, 322.0).toDouble();
    final previousX = pose.x;
    pose.x = _towards(pose.x, targetX, skill.shuffleSpeed * dt);
    _velocityX = dt > 0 ? (pose.x - previousX) / dt : 0;
    pose.y = _towards(pose.y, homeY + advance, 70 * dt);
  }

  void updateAiming(double dt, double patrolX, double clock) {
    action = KeeperAction.patrol;
    _followPatrol(dt, patrolX, advance: rushIncoming ? 8 : 0);
    pose.rotation = 0;
    _dive = _slide = 0;
    _stride += (math.sin(clock * 10) * 2 - _stride) * (1 - math.exp(-30 * dt));
    pose.update(crouch: rushIncoming ? .35 : 0, stride: _stride);
  }

  void beginShot() {
    _rushShot = rushIncoming;
    shots++;
    _flightTime = 0;
    _committed = false;
    _plantVelocityX = _velocityX;
    action = skill.canDive ? KeeperAction.set : KeeperAction.patrol;
  }

  void updateFlight(double dt, double patrolX, double clock,
      {required double ballX, required double ballY,
      required double launchX, required double launchY}) {
    _flightTime += dt;
    _stride *= math.exp(-30 * dt);
    if (!skill.canDive) {
      _followPatrol(dt, patrolX);
      _stride += (math.sin(clock * 10) * 2 - _stride) * (1 - math.exp(-30 * dt));
      pose.update(stride: _stride);
      return;
    }
    if (!_committed) {
      // Brake existing footwork continuously while setting for the shot.
      // This uses prior motion only, with no access to the flight direction.
      final decay = math.exp(-35 * dt);
      pose.x = (pose.x + _plantVelocityX * (1 - decay) / 35)
          .clamp(78.0, 322.0).toDouble();
      _plantVelocityX *= decay;
    }
    if (!_committed && _flightTime < skill.reactionDelay) {
      // Set the feet before pushing off; do not inspect the shot direction.
      pose.update(crouch: _rushShot ? .35 : .35 * _flightTime / skill.reactionDelay,
          stride: _stride);
      return;
    }
    if (!_committed) {
      final travelled = launchY - ballY;
      if (travelled <= 1) return;
      _committed = true;
      _fromX = pose.x;
      _fromY = pose.y;
      _endY = homeY + (_rushShot ? skill.rushDistance : 0);
      // Extrapolate the visible travel so far, without access to the intended
      // target or spin. A late bend can beat this committed early estimate.
      final observedX = launchX +
          (ballX - launchX) * (launchY - _endY) / travelled;
      final reach = skill.diveReach * (_rushShot ? .6 : 1);
      final delta = (observedX - pose.x).clamp(-reach, reach).toDouble();
      _endX = (pose.x + delta).clamp(65.0, 335.0).toDouble();
      _direction = delta < 0 ? -1 : 1;
      action = _rushShot ? KeeperAction.slide : KeeperAction.dive;
    }
    final u = _ease((_flightTime - skill.reactionDelay) / actionDuration);
    pose.x = _fromX + (_endX - _fromX) * u;
    pose.y = _fromY + (_endY - _fromY) * u;
    pose.rotation = _direction * (_rushShot ? .32 : 1.18) * u;
    _dive = _rushShot ? 0 : u;
    _slide = _rushShot ? u : 0;
    pose.update(dive: _dive, slide: _slide, crouch: .35 * (1 - u), stride: _stride);
  }

  void resolveShot({required bool saved, required double targetX}) {
    _saved = saved;
    _feedbackTime = 0;
    _fromRotation = pose.rotation;
    _fromDive = _dive;
    _fromSlide = _slide;
    _markTarget = ((targetX - 200) / 110).clamp(-1.0, 1.0).toDouble() * skill.markingReach;
    action = KeeperAction.recover;
  }

  void updateFeedback(double dt, double patrolX, double clock) {
    _feedbackTime += dt;
    _stride *= math.exp(-30 * dt);
    // Brief landing, then a smooth return to the ready stance. Taunting uses
    // the existing miss feedback; it adds no delay or input lock of its own.
    final recovery = _ease((_feedbackTime - .10) / .38);
    if (_feedbackTime > .10) _followPatrol(dt, patrolX);
    pose.rotation = _fromRotation * (1 - recovery);
    _dive = _fromDive * (1 - recovery);
    _slide = _fromSlide * (1 - recovery);
    final tauntTime = ((_feedbackTime - .48) / .5).clamp(0.0, 1.0);
    final taunt = _saved && skill.canTaunt ? math.sin(math.pi * tauntTime) : 0.0;
    action = taunt > .01 ? KeeperAction.taunt : KeeperAction.recover;
    pose.update(dive: _dive, slide: _slide, taunt: taunt, stride: _stride,
        wave: math.sin(clock * 15));
  }

  static double _ease(double value) {
    final t = value.clamp(0.0, 1.0).toDouble();
    return t * t * (3 - 2 * t);
  }

  static double _towards(double value, double target, double distance) =>
      value + (target - value).clamp(-distance, distance);
}
