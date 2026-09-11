import 'dart:math' as math;
import 'challenge_stage.dart';
import 'keeper_style.dart';
import 'keeper_skill.dart';
import 'keeper_controller.dart';
import 'showdown.dart';
import 'first_touch_guide.dart';
import 'shot_failure.dart';

enum MatchPhase {
  ready,
  stageIntro,
  aiming,
  flying,
  result,
  stageCleared,
  finished,
}

/// Pure Dart simulation. Coordinates are in a 400 × 640 logical pitch.
/// Fixed substeps prevent fast shots tunnelling through moving defenders.
class MatchModel {
  static const width = 400.0;
  static const height = 640.0;
  static const goalY = 100.0;
  static const leftPost = 65.0;
  static const rightPost = 335.0;
  static const ballRadius = 8.0;
  static const ballStartX = 200.0;
  static const ballStartY = 548.0;
  static const cornerWidth = 45.0;
  static const postClip = 16.0;

  MatchPhase phase = MatchPhase.ready;
  int score = 0;
  int goals = 0;
  int misses = 0;
  int streak = 0;
  int longestStreak = 0;
  int lastPoints = 0;
  double clock = 0;
  double ballX = ballStartX;
  double ballY = ballStartY;
  double shotTargetX = 200;
  double resultTime = 0;
  String message = '';
  String unlockNote = '';
  bool lastWasGoal = false;
  bool lastWasCorner = false;
  bool lastWasPost = false;
  bool firstAim = true;
  int resultSerial = 0;
  int? stageIndex;
  int cornerGoals = 0;
  double secondsRemaining = 0;
  double _aimAngle = 0;
  double _keeperAngle = .8;
  double _motionScale = 1;
  double ballAngle = 0;
  int fireCharge = 0;
  bool shotIsFire = false;
  bool lastWasFire = false;
  bool justChargedFire = false;
  final KeeperController keeper = KeeperController();
  bool lastWasKeeperSave = false;
  int attemptId = 0;
  bool stageStarted = false;
  bool leftCornerScored = false, rightCornerScored = false;
  bool shotAgainstRush = false;
  int rushGoals = 0;
  bool _guidedFirstMatch = false;
  ShotFailure? lastFailure;

  bool get isGuidedFirstMatch => _guidedFirstMatch;
  FirstTouchLesson get firstTouchLesson => onFire
      ? FirstTouchLesson.fire
      : goals == 0 ? FirstTouchLesson.aim : FirstTouchLesson.space;
  String get firstTouchHint => switch (phase) {
    MatchPhase.stageIntro => FirstTouchLesson.aim.instruction,
    MatchPhase.aiming => lastFailure?.advice ?? firstTouchLesson.instruction,
    MatchPhase.flying => 'Your tap locked the target. Watch the ball follow that line.',
    MatchPhase.result => lastWasGoal
        ? justChargedFire ? 'Two in a row! Your next shot scores double if it goes in.'
            : 'Goal! Keep finding the open space to earn your first stars.'
        : shotAdvice,
    MatchPhase.stageCleared => 'First match cleared! Your stars unlock the next stage.',
    MatchPhase.finished => retryAdvice,
    MatchPhase.ready => '',
  };
  String get shotAdvice => lastFailure?.advice ?? '';
  String get retryAdvice {
    if (lastFailure != null) return lastFailure!.advice;
    if (timeExpired) return 'Keep your shots moving. A shot released before zero can still finish.';
    return stage?.tip ?? 'Watch the target dot and look for an open lane.';
  }

  int get lives => 3 - misses;
  int get level => stageIndex == null ? 1 + goals ~/ 3 : stageIndex! + 1;
  int get multiplier => isChallenge ? (fireReady ? 2 : 1) : (streak >= 5 ? 2 : 1);
  bool get fireReady => isChallenge && fireCharge >= stage!.fireChargeGoals;
  KeeperStyle get keeperStyle => stage?.keeper ?? KeeperStyle.sweeper;
  KeeperSkill get keeperSkill => stage?.keeperSkill ?? KeeperSkill.academy;
  double get goalFeedbackDuration => lastWasCorner || lastWasFire ? 1.25 : .85;
  int get defenderCount =>
      stage?.defenders ?? (goals >= 9 ? 2 : (goals >= 3 ? 1 : 0));
  ChallengeStage? get stage =>
      stageIndex == null ? null : challengeStages[stageIndex!];
  bool get isChallenge => stageIndex != null;
  bool get isPlaying =>
      phase == MatchPhase.aiming ||
      phase == MatchPhase.flying ||
      phase == MatchPhase.result;
  bool get isTimed => stage?.timeLimit != null;
  bool get timeExpired => isTimed && secondsRemaining <= 0;
  int get timerSeconds => secondsRemaining.ceil();
  int get objectiveProgress => stage?.showdown == Showdown.cornerDuel
      ? (leftCornerScored ? 1 : 0) + (rightCornerScored ? 1 : 0)
      : switch (stage?.objective) {
        StageObjective.goals => goals,
        StageObjective.corners => cornerGoals,
        StageObjective.points => score,
        null => 0,
      };
  bool get showdownMet => switch (stage?.showdown) {
        Showdown.cornerDuel => leftCornerScored && rightCornerScored,
        Showdown.fireFinish => lastWasGoal && lastWasFire,
        Showdown.rushHour => rushGoals > 0,
        Showdown.championFinal => lastWasGoal && lastWasFire && lastWasCorner,
        null => true,
      };
  bool get objectiveMet =>
      isChallenge && objectiveProgress >= stage!.target && showdownMet;
  String get showdownStatus => switch (stage?.showdown) {
        Showdown.cornerDuel => leftCornerScored && rightCornerScored
            ? 'BOTH CORNERS SCORED'
            : leftCornerScored ? 'NEXT: RIGHT CORNER'
                : rightCornerScored ? 'NEXT: LEFT CORNER' : 'SCORE LEFT + RIGHT CORNERS',
        Showdown.fireFinish => objectiveMet ? 'FIRE FINISH COMPLETE' : 'FINISH WITH A FIRE GOAL',
        Showdown.rushHour => rushGoals > 0 ? 'RUSH GOAL COMPLETE' : 'RUSH GOAL 0/1 · EVERY THIRD SHOT',
        Showdown.championFinal => objectiveMet ? 'FIRE CORNER FINISH COMPLETE' : 'FINISH WITH A FIRE CORNER',
        null => '',
      };
  String get rematchHint {
    if (stage == null) return '';
    if (stage!.showdown == Showdown.cornerDuel && !showdownMet) {
      return leftCornerScored ? 'One right-corner goal was still needed.'
          : rightCornerScored ? 'One left-corner goal was still needed.'
              : 'Next attempt: land one goal in each corner.';
    }
    if (objectiveProgress >= stage!.target && !showdownMet) {
      return switch (stage!.showdown) {
        Showdown.fireFinish => 'You reached the points target. A Fire goal was still needed to finish.',
        Showdown.rushHour => 'You scored enough goals. A goal past the rush was still needed.',
        Showdown.championFinal => 'You reached the points target. A Fire corner was still needed to finish.',
        _ => stage!.tip,
      };
    }
    final remaining = math.max(0, stage!.target - objectiveProgress);
    final unit = remaining == 1 ? switch (stage!.objective) {
      StageObjective.goals => 'goal',
      StageObjective.corners => 'corner goal',
      StageObjective.points => 'point',
    } : stage!.unit;
    return '$remaining more $unit ${remaining == 1 ? 'was' : 'were'} needed.'
        '${stage!.showdown == null ? '' : ' ${stage!.showdown!.shortRule}'}';
  }
  int get earnedStars => phase == MatchPhase.stageCleared ? lives : 0;
  bool get isFinalStage => stageIndex == challengeStages.length - 1;
  int get accuracy =>
      goals + misses == 0 ? 0 : (100 * goals / (goals + misses)).round();
  int get resolvedShots => goals + misses;
  double get motionScale => _motionScale;
  bool get showTapCue => phase == MatchPhase.aiming &&
      (firstAim || (isGuidedFirstMatch && goals == 0));
  bool get onFire => isChallenge
      ? (phase == MatchPhase.flying ? shotIsFire : fireReady)
      : multiplier == 2;
  bool get lastChance =>
      lives == 1 &&
      (phase == MatchPhase.aiming || phase == MatchPhase.flying);
  bool get shotHeadsToCornerGoal =>
      isOnTarget(shotTargetX) && isCornerTarget(shotTargetX);
  bool get shotHeadsToPost =>
      !isOnTarget(shotTargetX) && outsideGoal(shotTargetX) <= postClip;
  String get resultSubtitle {
    if (lastWasGoal) {
      final points = '+$lastPoints POINTS';
      return unlockNote.isEmpty ? points : '$points · $unlockNote';
    }
    if (lives <= 0) {
      return "THAT'S ALL";
    }
    return lives == 1 ? '1 CHANCE LEFT' : '$lives CHANCES LEFT';
  }
  double get _aimSpeed =>
      stage?.aimSpeed ?? (1.35 + math.min(goals, 18) * .055);
  double get _keeperSpeed =>
      stage?.keeperSpeed ?? (1.0 + math.min(goals, 18) * .06);
  double get aimX => 200 + 172 * math.sin(_aimAngle);
  double get _patrolKeeperX {
    return 200 + (stage?.keeperRange ?? 100) * keeperStyle.offset(_keeperAngle);
  }
  double get keeperX => isChallenge ? keeper.pose.x : _patrolKeeperX;
  double get keeperY => isChallenge ? keeper.pose.y : KeeperController.homeY;
  // Three rows stay well ahead of the launch point so the nearest defender
  // leaves room to read a lane. Earlier stages retain their original layout.
  double defenderY(int index) =>
      defenderCount >= 3 ? 250.0 + index * 85 : 278.0 + index * 108;
  double defenderX(int index) {
    final current = stage;
    if (current != null && current.pattern == DefencePattern.staggered) {
      return 200 +
          120 * math.sin(clock * current.defenderSpeed +
              index * 2 * math.pi / current.defenders);
    }
    if (current != null && current.pattern == DefencePattern.crossing) {
      return 200 +
          120 * math.sin(clock * current.defenderSpeed + index * math.pi);
    }
    return 200 + 120 * math.sin(clock *
        ((current?.defenderSpeed ?? 1.05) + index * .25) + index * 2.2);
  }

  void start() {
    stageIndex = null;
    _resetRun();
    phase = MatchPhase.aiming;
  }

  void prepareStage(int index, {bool guided = false}) {
    RangeError.checkValidIndex(index, challengeStages, 'index');
    stageIndex = index;
    _resetRun();
    _guidedFirstMatch = guided && index == 0;
    secondsRemaining = stage!.timeLimit?.toDouble() ?? 0;
    phase = MatchPhase.stageIntro;
  }

  void startStage() {
    if (phase == MatchPhase.stageIntro) {
      stageStarted = true;
      phase = MatchPhase.aiming;
    }
  }

  void retryStage() {
    final index = stageIndex;
    if (index == null ||
        (phase != MatchPhase.finished && phase != MatchPhase.stageCleared)) {
      return;
    }
    // A first clear completes the guide. Failed attempts retain the coaching.
    final guided = isGuidedFirstMatch && phase != MatchPhase.stageCleared;
    prepareStage(index, guided: guided);
    startStage();
  }

  void returnToMenu() {
    stageIndex = null;
    _resetRun();
    phase = MatchPhase.ready;
  }

  void _resetRun() {
    attemptId++;
    _guidedFirstMatch = false;
    lastFailure = null;
    stageStarted = false;
    leftCornerScored = rightCornerScored = shotAgainstRush = false;
    rushGoals = 0;
    score = goals = misses = streak = lastPoints = 0;
    longestStreak = 0;
    cornerGoals = 0;
    clock = 0;
    _aimAngle = 0;
    _keeperAngle = .8;
    keeper.reset(keeperSkill, _patrolKeeperX);
    _motionScale = 1;
    resultTime = 0;
    secondsRemaining = 0;
    shotTargetX = 200;
    message = '';
    unlockNote = '';
    lastWasGoal = lastWasCorner = lastWasPost = false;
    lastWasKeeperSave = false;
    fireCharge = 0;
    shotIsFire = lastWasFire = justChargedFire = false;
    firstAim = true;
    resetBall();
  }

  void endRun() {
    if (!isPlaying) {
      return;
    }
    // Ending during the final goal celebration must not discard a clear.
    if (objectiveMet) {
      phase = MatchPhase.stageCleared;
      return;
    }
    message = isChallenge ? 'STAGE ENDED' : 'FULL TIME';
    phase = MatchPhase.finished;
  }

  void resetBall() {
    ballX = ballStartX;
    ballY = ballStartY;
    ballAngle = 0;
    shotIsFire = false;
    shotAgainstRush = false;
  }

  bool shoot() {
    if (phase != MatchPhase.aiming || timeExpired) {
      return false;
    }
    shotTargetX = aimX;
    shotIsFire = fireReady;
    shotAgainstRush = isChallenge && keeper.rushIncoming;
    if (isChallenge) keeper.beginShot();
    firstAim = false;
    phase = MatchPhase.flying;
    return true;
  }

  void update(double dt, {double timeScale = 1, bool cinematic = false}) {
    if (!isPlaying) {
      return;
    }
    // Ignore long wall-clock gaps (app suspension, debugger, frame stalls).
    var remaining = dt.clamp(0.0, .1).toDouble();
    while (remaining > 0 && isPlaying) {
      final step = math.min(remaining, 1 / 240);
      // Charge active time before applying cinematic slow motion. Briefings,
      // goal feedback, and pauses do not consume the stage clock.
      if (isTimed &&
          (phase == MatchPhase.aiming || phase == MatchPhase.flying)) {
        secondsRemaining = math.max(0, secondsRemaining - step);
        if (timeExpired && phase == MatchPhase.aiming) {
          message = "TIME'S UP!";
          phase = MatchPhase.finished;
          return;
        }
      }
      _easeMotion(step, cinematic);
      tick(step * timeScale, motionScale: _motionScale);
      remaining -= step;
    }
  }

  void _easeMotion(double dt, bool cinematic) {
    if (!cinematic) {
      _motionScale = 1;
      return;
    }
    var target = 1.0;
    if (phase == MatchPhase.flying &&
        (shotIsFire || shotHeadsToCornerGoal || shotHeadsToPost)) {
      final approach = ((goalY + 140 - ballY) / 90).clamp(0.0, 1.0);
      final eased = approach * approach * (3 - 2 * approach);
      target = 1.0 - .62 * eased;
    }
    if ((target - _motionScale).abs() < .0001) {
      _motionScale = target;
      return;
    }
    // Ease into the close-up and back out during feedback. Substep integration
    // keeps the transition independent of the display's refresh rate.
    _motionScale += (target - _motionScale) * (1 - math.exp(-16 * dt));
  }

  void tick(double dt, {double motionScale = 1}) {
    if (!isPlaying) {
      return;
    }
    final motionDt = dt * motionScale;
    clock += motionDt;
    // Integrate phase rather than multiplying the entire elapsed clock by a
    // new speed. Scoring may accelerate players, but cannot teleport them.
    _aimAngle += motionDt * _aimSpeed;
    _keeperAngle += motionDt * _keeperSpeed;
    if (phase == MatchPhase.result) {
      if (isChallenge) {
        keeper.updateFeedback(dt, _patrolKeeperX, clock);
        if (lastWasKeeperSave) {
          // The saved ball is parried away during feedback; it cannot score
          // again or remain suspended beside a keeper who is getting up.
          ballX += keeper.parryDirection * 90 * dt;
          ballY += 65 * dt;
          ballAngle += 10 * dt;
        }
      }
      resultTime -= dt;
      if (resultTime <= 0) {
        // A shot released before zero may still clear the stage.
        if (objectiveMet) {
          phase = MatchPhase.stageCleared;
        } else if (misses >= 3 || timeExpired) {
          if (timeExpired) {
            message = "TIME'S UP!";
          }
          phase = MatchPhase.finished;
        } else {
          resetBall();
          phase = MatchPhase.aiming;
        }
      }
      return;
    }
    if (phase != MatchPhase.flying) {
      if (isChallenge && phase == MatchPhase.aiming) {
        keeper.updateAiming(motionDt, _patrolKeeperX, clock);
      }
      return;
    }
    const speedY = 780.0;
    ballAngle += 16 * motionDt;
    ballY -= speedY * motionDt;
    final progress =
        ((ballStartY - ballY) / (ballStartY - goalY)).clamp(0.0, 1.0);
    ballX = ballStartX + (shotTargetX - ballStartX) * progress;
    if (isChallenge) {
      keeper.updateFlight(motionDt, _patrolKeeperX, clock,
          ballX: ballX, ballY: ballY, launchX: ballStartX, launchY: ballStartY);
    }
    for (var i = 0; i < defenderCount; i++) {
      if (hitsBox(defenderX(i), defenderY(i), 17, 13)) {
        finishShot(goal: false, blocked: true, text: 'BLOCKED!');
        return;
      }
    }
    final keeperHit = isChallenge
        ? keeper.pose.hitsBall(ballX, ballY, ballRadius)
        : hitsBox(keeperX, keeperY, 25, 12);
    if (keeperHit) {
      final saveText = !isChallenge ? 'SAVED!' : switch (keeper.action) {
        KeeperAction.dive => 'DIVING SAVE!',
        KeeperAction.slide => 'SLIDING SAVE!',
        _ => 'SAVED!',
      };
      finishShot(goal: false, keeperSave: true, text: saveText);
      return;
    }
    if (ballY <= goalY) {
      ballY = goalY;
      if (!isOnTarget(shotTargetX)) {
        final post = outsideGoal(shotTargetX) <= postClip;
        finishShot(
            goal: false,
            post: post,
            text: post ? 'OFF THE POST!' : 'JUST WIDE!');
      } else {
        final corner = isCornerTarget(shotTargetX);
        finishShot(
            goal: true,
            corner: corner,
            text: corner ? 'TOP CORNER!' : 'GOOOAL!');
      }
    }
  }

  static bool isOnTarget(double x) =>
      x >= leftPost + ballRadius && x <= rightPost - ballRadius;

  static bool isCornerTarget(double x) =>
      x <= leftPost + cornerWidth || x >= rightPost - cornerWidth;

  static double outsideGoal(double x) {
    final leftEdge = leftPost + ballRadius;
    final rightEdge = rightPost - ballRadius;
    if (x < leftEdge) {
      return leftEdge - x;
    }
    if (x > rightEdge) {
      return x - rightEdge;
    }
    return 0;
  }

  bool hitsBox(double x, double y, double halfW, double halfH) {
    final nearX = ballX.clamp(x - halfW, x + halfW);
    final nearY = ballY.clamp(y - halfH, y + halfH);
    final dx = ballX - nearX;
    final dy = ballY - nearY;
    return dx * dx + dy * dy <= ballRadius * ballRadius;
  }

  void finishShot(
      {required bool goal,
      bool corner = false,
      bool post = false,
      bool keeperSave = false,
      bool blocked = false,
      required String text}) {
    lastWasGoal = goal;
    lastWasCorner = corner;
    lastWasPost = post;
    lastWasKeeperSave = !goal && keeperSave;
    lastFailure = goal ? null
        : keeperSave ? ShotFailure.keeper
            : blocked ? ShotFailure.defender
                : post ? ShotFailure.post : ShotFailure.wide;
    if (isChallenge) {
      keeper.resolveShot(saved: lastWasKeeperSave, targetX: shotTargetX);
    }
    // Charge cannot change during flight. Resolve the boost before updating
    // charge so the goal that arms a Fire Shot still earns normal points.
    lastWasFire = fireReady;
    justChargedFire = false;
    lastPoints = 0;
    unlockNote = '';
    if (goal) {
      // Classic's fifth goal and a challenge's charging goal arm NEXT shots.
      lastPoints = (corner ? 3 : 1) * multiplier;
      score += lastPoints;
      goals++;
      if (corner) {
        cornerGoals++;
        if (isOnTarget(shotTargetX)) {
          if (shotTargetX <= leftPost + cornerWidth) leftCornerScored = true;
          if (shotTargetX >= rightPost - cornerWidth) rightCornerScored = true;
        }
      }
      if (shotAgainstRush) rushGoals++;
      streak++;
      longestStreak = math.max(longestStreak, streak);
      if (!isChallenge && goals == 3) {
        unlockNote = 'MARKER ON';
      } else if (!isChallenge && goals == 9) {
        unlockNote = 'SECOND MARKER';
      }
      if (!isChallenge && streak == 5) {
        unlockNote = '2× ON · NEXT SHOTS';
      }
      if (isChallenge) {
        if (lastWasFire) {
          fireCharge = 0;
        } else if (stage!.objective != StageObjective.corners || corner) {
          fireCharge++;
          justChargedFire = fireReady && !objectiveMet && !timeExpired;
        }
        unlockNote = objectiveMet
            ? 'STAGE CLEAR!'
            : stage!.showdown != null && objectiveProgress >= stage!.target
                ? showdownStatus
                : justChargedFire
                    ? 'FIRE SHOT READY · NEXT SHOT 2×'
                    : stage!.objective == StageObjective.corners && !corner
                        ? 'CORNERS ADVANCE THE STAGE'
                        : '$objectiveProgress/${stage!.target} ${stage!.unit.toUpperCase()}';
      }
    } else {
      misses++;
      streak = 0;
      fireCharge = 0;
    }
    message = goal && lastWasFire
        ? (corner ? 'FIRE CORNER!' : 'FIRE GOAL!')
        : text;
    resultSerial++;
    resultTime = goal ? goalFeedbackDuration : (post ? 1.15 : 1.0);
    phase = MatchPhase.result;
  }
}
