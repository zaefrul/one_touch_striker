import 'dart:math' as math;
import 'bonus.dart';
import 'stage.dart';

enum MatchPhase { ready, aiming, flying, result, finished }

/// Pure Dart simulation. Coordinates are in a 400 × 640 logical pitch.
/// Fixed substeps prevent fast shots tunnelling through moving defenders.
class MatchModel {
  MatchModel({
    StageSpec? stage,
    this.intensity = 1,
    this.bonus = BallBonus.straight,
    this.shotsMax = 5,
  }) : stage = stage ?? StageSpec.all.first;

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
  static const straightSpeedY = 780.0;
  static const superSpeedY = 1100.0;
  static const curveBend = 42.0;

  StageSpec stage;
  int intensity;
  BallBonus bonus;
  int shotsMax;

  MatchPhase phase = MatchPhase.ready;
  int score = 0;
  int goals = 0;
  int misses = 0;
  int streak = 0;
  int lastPoints = 0;
  int shotsTaken = 0;
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

  int get shotsLeft => (shotsMax - shotsTaken).clamp(0, shotsMax);
  int get lives => shotsLeft;
  int get level => intensity;
  int get multiplier => streak >= 3 ? 2 : 1;
  int get defenderCount {
    if (stage.id == StageId.pitch) {
      if (intensity >= 9) {
        return 2;
      }
      if (intensity >= 5) {
        return 1;
      }
      return 0;
    }
    if (intensity >= 8) {
      return 2;
    }
    if (intensity >= 3) {
      return 1;
    }
    return 0;
  }

  List<ObstacleSpec> get activeObstacles {
    if (stage.obstacles.isEmpty) {
      return const [];
    }
    final count = math.min(stage.obstacles.length, 1 + (intensity - 1) ~/ 4);
    return stage.obstacles.take(count).toList();
  }

  double get _ampScale => 0.85 + intensity * .03;
  double get _speedScale => 0.8 + intensity * .05;
  double get speedY =>
      bonus == BallBonus.superShoot ? superSpeedY : straightSpeedY;

  bool get showTapCue => firstAim && phase == MatchPhase.aiming;
  bool get onFire => multiplier == 2;
  bool get lastChance =>
      shotsLeft == 1 &&
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
    if (shotsTaken >= shotsMax) {
      return "THAT'S ALL";
    }
    return shotsLeft == 1 ? '1 SHOT LEFT' : '$shotsLeft SHOTS LEFT';
  }

  double get aimX =>
      200 + 172 * math.sin(clock * (1.35 + math.min(intensity, 10) * .055));
  double get keeperX =>
      200 + 100 * math.sin(clock * (1.0 + math.min(intensity, 10) * .06) + .8);
  double get keeperY => 126;
  double defenderY(int index) => 278.0 + index * 108;
  double defenderX(int index) =>
      200 + 120 * math.sin(clock * (1.05 + index * .25) + index * 2.2);

  double obstacleX(ObstacleSpec obstacle) =>
      obstacle.x(clock, ampScale: _ampScale, speedScale: _speedScale);
  double obstacleY(ObstacleSpec obstacle) =>
      obstacle.y(clock, ampScale: _ampScale, speedScale: _speedScale);

  void configure({
    required StageSpec stage,
    required int intensity,
    required BallBonus bonus,
  }) {
    this.stage = stage;
    this.intensity = intensity;
    this.bonus = bonus;
  }

  void start() {
    score = goals = misses = streak = lastPoints = shotsTaken = 0;
    clock = 0;
    message = '';
    unlockNote = '';
    lastWasGoal = lastWasCorner = lastWasPost = false;
    firstAim = true;
    resetBall();
    phase = MatchPhase.aiming;
  }

  void endRun() {
    if (phase == MatchPhase.ready || phase == MatchPhase.finished) {
      return;
    }
    phase = MatchPhase.finished;
  }

  void resetBall() {
    ballX = ballStartX;
    ballY = ballStartY;
  }

  bool shoot() {
    if (phase != MatchPhase.aiming) {
      return false;
    }
    shotTargetX = aimX;
    firstAim = false;
    phase = MatchPhase.flying;
    return true;
  }

  void update(double dt) {
    if (phase == MatchPhase.ready || phase == MatchPhase.finished) {
      return;
    }
    var remaining = dt.clamp(0.0, .1).toDouble();
    while (remaining > 0) {
      final step = math.min(remaining, 1 / 240);
      tick(step);
      remaining -= step;
    }
  }

  void tick(double dt) {
    clock += dt;
    if (phase == MatchPhase.result) {
      resultTime -= dt;
      if (resultTime <= 0) {
        if (shotsTaken >= shotsMax) {
          phase = MatchPhase.finished;
        } else {
          resetBall();
          phase = MatchPhase.aiming;
        }
      }
      return;
    }
    if (phase != MatchPhase.flying) {
      return;
    }
    ballY -= speedY * dt;
    final progress =
        ((ballStartY - ballY) / (ballStartY - goalY)).clamp(0.0, 1.0);
    ballX = ballStartX + (shotTargetX - ballStartX) * progress;
    if (bonus == BallBonus.curve) {
      final side = shotTargetX >= 200 ? -1.0 : 1.0;
      ballX += math.sin(progress * math.pi) * curveBend * side;
    }
    for (final obstacle in activeObstacles) {
      if (hitsBox(obstacleX(obstacle), obstacleY(obstacle), obstacle.halfW,
          obstacle.halfH)) {
        finishShot(goal: false, text: obstacle.blockText);
        return;
      }
    }
    for (var i = 0; i < defenderCount; i++) {
      if (hitsBox(defenderX(i), defenderY(i), 17, 13)) {
        finishShot(goal: false, text: 'BLOCKED!');
        return;
      }
    }
    if (hitsBox(keeperX, keeperY, 25, 12)) {
      finishShot(goal: false, text: 'SAVED!');
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
      required String text}) {
    lastWasGoal = goal;
    lastWasCorner = corner;
    lastWasPost = post;
    lastPoints = 0;
    unlockNote = '';
    shotsTaken++;
    if (goal) {
      lastPoints = (corner ? 3 : 1) * multiplier;
      score += lastPoints;
      goals++;
      streak++;
      if (streak == 3) {
        unlockNote = '2× ON · NEXT SHOTS';
      }
    } else {
      misses++;
      streak = 0;
    }
    message = text;
    resultSerial++;
    resultTime = goal ? (corner ? 1.25 : .85) : (post ? 1.15 : 1.0);
    phase = MatchPhase.result;
  }
}
