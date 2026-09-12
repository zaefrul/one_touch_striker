import 'dart:math' as math;
import 'challenge_stage.dart';
import 'keeper_style.dart';
import 'keeper_skill.dart';
import 'keeper_controller.dart';
import 'showdown.dart';
import 'first_touch_guide.dart';
import 'shot_failure.dart';
import 'shot_curve.dart';
import 'knuckle_shot.dart';
import 'practice_drill.dart';

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
  bool _preparingShot = false;
  double _preparedAimX = ballStartX, _preparedSpin = 0;
  double shotSpin = 0;
  double _heldSeconds = 0;
  bool _movedShot = false;
  StrikeTiming shotTiming = StrikeTiming.tap;
  String lastTechnique = '', lastTechniqueAdvice = '';
  PracticeDrill? practice;
  int practiceHits = 0, practiceCleanStrikes = 0, _practiceTargetIndex = 0;
  bool lastPracticeHit = false;
  String lastPracticeNote = '';
  final List<PracticeShot> practiceShots = [];

  bool get isPreparingShot => _preparingShot;
  double get preparedSpin => _preparedSpin;
  double get heldSeconds => _heldSeconds;
  bool get canTimeKnuckle => _preparingShot && !_movedShot;
  bool get knuckleReady => canTimeKnuckle &&
      KnuckleShot.timingAt(_heldSeconds) == StrikeTiming.clean;
  bool get shotIsKnuckle => shotTiming == StrikeTiming.clean;
  String get preparedReleaseLabel => canTimeKnuckle
      ? KnuckleShot.releaseLabel(_heldSeconds) : ShotCurve.releaseLabel(_preparedSpin);
  double get previewTargetX => _preparingShot
      ? ShotCurve.targetFor(_preparedAimX, _preparedSpin) : aimX;
  double previewXAt(double progress) => ShotCurve.xAt(ballStartX,
      previewTargetX, _preparingShot ? _preparedSpin : 0.0, progress) +
      (knuckleReady ? KnuckleShot.offsetAt(progress) : 0);

  bool get isPractice => practice != null;
  bool get isClassic => !isChallenge && !isPractice;
  bool get hasKeeper => !isPractice || practice == PracticeDrill.knuckle;
  bool get usesProfessionalKeeper => isChallenge || (isPractice && hasKeeper);
  int get practiceBallsLeft => math.max(0,
      PracticeDrill.balls - resolvedShots - (phase == MatchPhase.flying ? 1 : 0));
  bool get practiceCompleted => isPractice && phase == MatchPhase.finished &&
      resolvedShots == PracticeDrill.balls;
  double get practiceTargetX => practice?.targetX(_practiceTargetIndex) ?? 200;
  String get shotOutcome => lastWasGoal ? 'Goal' : switch (lastFailure) {
    ShotFailure.keeper => 'Saved', ShotFailure.defender => 'Blocked',
    ShotFailure.post => 'Post', ShotFailure.wide => 'Wide', null => '',
  };
  String get shotExplanation => lastTechnique.isEmpty ? '' : '$lastTechnique · $shotOutcome';

  bool get isGuidedFirstMatch => _guidedFirstMatch;
  FirstTouchLesson get firstTouchLesson => onFire
      ? FirstTouchLesson.fire
      : goals == 0 ? FirstTouchLesson.aim : FirstTouchLesson.space;
  String get firstTouchHint => switch (phase) {
    MatchPhase.stageIntro => FirstTouchLesson.aim.instruction,
    MatchPhase.aiming => lastTechniqueAdvice.isNotEmpty ? lastTechniqueAdvice
        : lastFailure?.advice ?? firstTouchLesson.instruction,
    MatchPhase.flying => 'Shot released. Watch the ball follow the path you set.',
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

  int get lives => isPractice ? practiceBallsLeft : 3 - misses;
  int get level => stageIndex == null ? 1 + goals ~/ 3 : stageIndex! + 1;
  int get multiplier => isPractice ? 1
      : isChallenge ? (fireReady ? 2 : 1) : (streak >= 5 ? 2 : 1);
  bool get fireReady => isChallenge && fireCharge >= stage!.fireChargeGoals;
  KeeperStyle get keeperStyle => stage?.keeper ?? KeeperStyle.sweeper;
  KeeperSkill get keeperSkill => isPractice ? KeeperSkill.club
      : stage?.keeperSkill ?? KeeperSkill.academy;
  double get goalFeedbackDuration => lastWasCorner || lastWasFire ? 1.25 : .85;
  int get defenderCount =>
      isPractice ? (practice == PracticeDrill.curveWall ? 1 : 0)
          : stage?.defenders ?? (goals >= 9 ? 2 : (goals >= 3 ? 1 : 0));
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
      !isPractice && lives == 1 &&
      (phase == MatchPhase.aiming || phase == MatchPhase.flying);
  bool get shotHeadsToCornerGoal =>
      isOnTarget(shotTargetX) && isCornerTarget(shotTargetX);
  bool get shotHeadsToPost =>
      !isOnTarget(shotTargetX) && outsideGoal(shotTargetX) <= postClip;
  String get resultSubtitle {
    if (isPractice) return '${lastPracticeHit ? '+1 HIT' : 'NO DRILL POINT'} · '
        '$practiceHits/${PracticeDrill.balls} HITS';
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
      isPractice ? 1.0 : stage?.aimSpeed ?? (1.35 + math.min(goals, 18) * .055);
  double get _keeperSpeed =>
      isPractice ? .75 : stage?.keeperSpeed ?? (1.0 + math.min(goals, 18) * .06);
  double get aimX => 200 + 172 * math.sin(_aimAngle);
  double get _patrolKeeperX {
    return 200 + (isPractice ? 70 : stage?.keeperRange ?? 100) * keeperStyle.offset(_keeperAngle);
  }
  double get keeperX => usesProfessionalKeeper ? keeper.pose.x : _patrolKeeperX;
  double get keeperY => usesProfessionalKeeper ? keeper.pose.y : KeeperController.homeY;
  // Three rows stay well ahead of the launch point so the nearest defender
  // leaves room to read a lane. Earlier stages retain their original layout.
  double defenderY(int index) =>
      isPractice ? 324.0
          : defenderCount >= 3 ? 250.0 + index * 85 : 278.0 + index * 108;
  double defenderX(int index) {
    if (isPractice) return 200 + (practiceTargetX - 200) * .5 + 8 * math.sin(clock * .9);
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
    practice = null;
    _resetRun();
    phase = MatchPhase.aiming;
  }

  void prepareStage(int index, {bool guided = false}) {
    RangeError.checkValidIndex(index, challengeStages, 'index');
    practice = null;
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

  void startPractice(PracticeDrill drill) {
    stageIndex = null;
    practice = drill;
    _resetRun();
    phase = MatchPhase.aiming;
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
    practice = null;
    _resetRun();
    phase = MatchPhase.ready;
  }

  void _resetRun() {
    attemptId++;
    cancelShot();
    shotSpin = 0;
    lastTechnique = lastTechniqueAdvice = lastPracticeNote = '';
    practiceHits = practiceCleanStrikes = _practiceTargetIndex = 0;
    lastPracticeHit = false;
    practiceShots.clear();
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
    cancelShot();
    if (!isPlaying) {
      return;
    }
    // Ending during the final goal celebration must not discard a clear.
    if (objectiveMet) {
      phase = MatchPhase.stageCleared;
      return;
    }
    message = isPractice ? 'PRACTICE ENDED' : isChallenge ? 'STAGE ENDED' : 'FULL TIME';
    phase = MatchPhase.finished;
  }

  void resetBall() {
    cancelShot();
    shotSpin = 0;
    shotTiming = StrikeTiming.tap;
    if (isPractice) _practiceTargetIndex = math.min(resolvedShots, PracticeDrill.balls - 1);
    ballX = ballStartX;
    ballY = ballStartY;
    ballAngle = 0;
    shotIsFire = false;
    shotAgainstRush = false;
  }

  bool beginShot() {
    if (_preparingShot || phase != MatchPhase.aiming || timeExpired) return false;
    _preparedAimX = aimX;
    _preparedSpin = 0;
    _heldSeconds = 0;
    _movedShot = false;
    _preparingShot = true;
    return true;
  }

  void adjustCurve(double dragX, {double dragY = 0}) {
    if (_preparingShot && phase == MatchPhase.aiming && !timeExpired) {
      // Any deliberate movement opts out of timing for this entire hold,
      // including a drag that later returns to the centre.
      if (!dragX.isFinite || !dragY.isFinite ||
          dragX.abs() > ShotCurve.deadZone || dragY.abs() > ShotCurve.deadZone) {
        _movedShot = true;
      }
      _preparedSpin = ShotCurve.spinForDrag(dragX);
    }
  }

  void cancelShot() {
    _preparingShot = false;
    _preparedSpin = 0;
    _heldSeconds = 0;
    _movedShot = false;
  }

  bool releaseShot() {
    if (!_preparingShot) return false;
    final targetX = previewTargetX;
    final spin = _preparedSpin;
    final timing = _movedShot ? StrikeTiming.adjusted : KnuckleShot.timingAt(_heldSeconds);
    cancelShot();
    return _launchShot(targetX, spin, timing: timing);
  }

  /// Immediate straight shot for accessibility activation and model callers.
  /// A semantic activation cannot steal an existing physical pointer's draft.
  bool shoot() => !_preparingShot && _launchShot(aimX, 0);

  bool _launchShot(double targetX, double spin, {StrikeTiming timing = StrikeTiming.tap}) {
    if (phase != MatchPhase.aiming || timeExpired) {
      return false;
    }
    shotTargetX = targetX;
    shotSpin = spin;
    shotTiming = timing;
    shotIsFire = fireReady;
    shotAgainstRush = isChallenge && keeper.rushIncoming;
    if (usesProfessionalKeeper) keeper.beginShot();
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
          cancelShot();
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
    if (_preparingShot && phase == MatchPhase.aiming) {
      _heldSeconds = math.min(KnuckleShot.ringDuration, _heldSeconds + dt);
    }
    clock += motionDt;
    // Integrate phase rather than multiplying the entire elapsed clock by a
    // new speed. Scoring may accelerate players, but cannot teleport them.
    _aimAngle += motionDt * _aimSpeed;
    _keeperAngle += motionDt * _keeperSpeed;
    if (phase == MatchPhase.result) {
      if (usesProfessionalKeeper) {
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
        if (isPractice) {
          if (resolvedShots >= PracticeDrill.balls) {
            phase = MatchPhase.finished;
          } else {
            resetBall();
            phase = MatchPhase.aiming;
          }
          return;
        }
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
      if (usesProfessionalKeeper && phase == MatchPhase.aiming) {
        keeper.updateAiming(motionDt, _patrolKeeperX, clock);
      }
      return;
    }
    const speedY = 780.0;
    ballAngle += (shotIsKnuckle ? 1.2 : 16) * motionDt;
    ballY -= speedY * motionDt;
    final progress =
        ((ballStartY - ballY) / (ballStartY - goalY)).clamp(0.0, 1.0).toDouble();
    ballX = ShotCurve.xAt(ballStartX, shotTargetX, shotSpin, progress) +
        (shotIsKnuckle ? KnuckleShot.offsetAt(progress) : 0);
    if (usesProfessionalKeeper) {
      keeper.updateFlight(motionDt, _patrolKeeperX, clock,
          ballX: ballX, ballY: ballY, launchX: ballStartX, launchY: ballStartY);
    }
    for (var i = 0; i < defenderCount; i++) {
      if (hitsBox(defenderX(i), defenderY(i), 17, 13)) {
        finishShot(goal: false, blocked: true, text: 'BLOCKED!');
        return;
      }
    }
    final keeperHit = hasKeeper && (usesProfessionalKeeper
        ? keeper.pose.hitsBall(ballX, ballY, ballRadius)
        : hitsBox(keeperX, keeperY, 25, 12));
    if (keeperHit) {
      final saveText = !usesProfessionalKeeper ? 'SAVED!' : switch (keeper.action) {
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
    if (isPractice && (phase != MatchPhase.flying || resolvedShots >= PracticeDrill.balls)) return;
    lastWasGoal = goal;
    lastWasCorner = corner;
    lastWasPost = post;
    lastWasKeeperSave = !goal && keeperSave;
    lastFailure = goal ? null
        : keeperSave ? ShotFailure.keeper
            : blocked ? ShotFailure.defender
                : post ? ShotFailure.post : ShotFailure.wide;
    lastTechnique = shotIsKnuckle ? 'Clean knuckle'
        : shotSpin != 0
            ? '${shotSpin.abs() >= .75 ? 'Banana' : 'Curve'} ${shotSpin < 0 ? 'left' : 'right'}'
            : switch (shotTiming) {
                StrikeTiming.early => 'Released early', StrikeTiming.late => 'Released late',
                _ => 'Straight shot',
              };
    lastTechniqueAdvice = shotTiming == StrikeTiming.early || shotTiming == StrikeTiming.late
        ? 'For a knuckle, hold still and release while the marker is in the blue zone.' : '';
    lastPracticeHit = isPractice && goal &&
        practice!.targetContains(shotTargetX, _practiceTargetIndex) &&
        (practice != PracticeDrill.curveWall || shotSpin != 0) &&
        (practice != PracticeDrill.knuckle || shotIsKnuckle);
    if (usesProfessionalKeeper) {
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
      lastPoints = isPractice ? (lastPracticeHit ? 1 : 0) : (corner ? 3 : 1) * multiplier;
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
      if (isClassic && goals == 3) {
        unlockNote = 'MARKER ON';
      } else if (isClassic && goals == 9) {
        unlockNote = 'SECOND MARKER';
      }
      if (isClassic && streak == 5) {
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
    if (isPractice) {
      if (lastPracticeHit) practiceHits++;
      if (shotIsKnuckle) practiceCleanStrikes++;
      lastPracticeNote = lastPracticeHit ? 'Drill hit earned'
          : !goal ? 'No drill point'
              : practice == PracticeDrill.knuckle ? 'Goal scored; clean knuckle timing needed'
                  : practice == PracticeDrill.curveWall && shotSpin == 0 ? 'Goal scored; add curve to earn a hit'
                      : 'Goal scored outside the marked target';
      practiceShots.add(PracticeShot(explanation: shotExplanation,
          note: lastPracticeNote, hit: lastPracticeHit));
    }
    message = goal && lastWasFire
        ? (corner ? 'FIRE CORNER!' : 'FIRE GOAL!')
        : text;
    resultSerial++;
    resultTime = goal ? goalFeedbackDuration : (post ? 1.15 : 1.0);
    phase = MatchPhase.result;
  }
}
