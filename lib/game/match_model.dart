import 'dart:math' as math;

enum MatchPhase { ready, aiming, flying, result, finished }

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

  MatchPhase phase = MatchPhase.ready;
  int score = 0;
  int goals = 0;
  int misses = 0;
  int streak = 0;
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
  bool firstAim = true;
  int resultSerial = 0;

  int get lives => 3 - misses;
  int get level => 1 + goals ~/ 3;
  int get multiplier => streak >= 5 ? 2 : 1;
  int get defenderCount => goals >= 9 ? 2 : (goals >= 3 ? 1 : 0);
  bool get showTapCue => firstAim && phase == MatchPhase.aiming;
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
  double get aimX =>
      200 + 172 * math.sin(clock * (1.35 + math.min(goals, 18) * .055));
  double get keeperX =>
      200 + 100 * math.sin(clock * (1.0 + math.min(goals, 18) * .06) + .8);
  double get keeperY => 126;
  double defenderY(int index) => 278.0 + index * 108;
  double defenderX(int index) =>
      200 + 120 * math.sin(clock * (1.05 + index * .25) + index * 2.2);

  void start() {
    score = goals = misses = streak = lastPoints = 0;
    clock = 0;
    message = '';
    unlockNote = '';
    lastWasGoal = lastWasCorner = false;
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
    // Ignore long wall-clock gaps (app suspension, debugger, frame stalls).
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
        if (misses >= 3) {
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
    const speedY = 780.0;
    ballY -= speedY * dt;
    final progress =
        ((ballStartY - ballY) / (ballStartY - goalY)).clamp(0.0, 1.0);
    ballX = ballStartX + (shotTargetX - ballStartX) * progress;
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
      final inside = shotTargetX >= leftPost + ballRadius &&
          shotTargetX <= rightPost - ballRadius;
      if (!inside) {
        finishShot(goal: false, text: 'JUST WIDE!');
      } else {
        final corner =
            shotTargetX <= leftPost + 45 || shotTargetX >= rightPost - 45;
        finishShot(
            goal: true,
            corner: corner,
            text: corner ? 'TOP CORNER!' : 'GOOOAL!');
      }
    }
  }

  bool hitsBox(double x, double y, double halfW, double halfH) {
    final nearX = ballX.clamp(x - halfW, x + halfW);
    final nearY = ballY.clamp(y - halfH, y + halfH);
    final dx = ballX - nearX;
    final dy = ballY - nearY;
    return dx * dx + dy * dy <= ballRadius * ballRadius;
  }

  void finishShot(
      {required bool goal, bool corner = false, required String text}) {
    lastWasGoal = goal;
    lastWasCorner = corner;
    lastPoints = 0;
    unlockNote = '';
    if (goal) {
      // The fifth goal activates the multiplier for subsequent shots.
      lastPoints = (corner ? 3 : 1) * multiplier;
      score += lastPoints;
      goals++;
      streak++;
      if (goals == 3) {
        unlockNote = 'MARKER ON';
      } else if (goals == 9) {
        unlockNote = 'SECOND MARKER';
      }
      if (streak == 5) {
        unlockNote = '2× ON · NEXT SHOTS';
      }
    } else {
      misses++;
      streak = 0;
    }
    message = text;
    resultSerial++;
    resultTime = goal ? .85 : 1.0;
    phase = MatchPhase.result;
  }
}
