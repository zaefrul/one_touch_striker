import 'dart:math' as math;
import 'dart:ui' hide TextStyle;
import 'package:flame/game.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;
import 'challenge_stage.dart';
import 'match_model.dart';
import 'keeper_style.dart';
import 'keeper_controller.dart';
import 'keeper_pose.dart';
import 'star_rewards.dart';
import 'playtest_trace.dart';
import 'shot_trail.dart';
import 'shot_curve.dart';

class StrikerGame extends FlameGame {
  StrikerGame(this.model,
      {required this.onChanged, required this.onShotResult});
  final MatchModel model;
  final void Function() onChanged;
  final void Function() onShotResult;
  final PlaytestTrace trace = PlaytestTrace();
  bool _matchPaused = false;

  bool get matchPaused => _matchPaused;
  set matchPaused(bool value) {
    if (_matchPaused != value) {
      if (value) model.cancelShot();
      _matchPaused = value;
      _syncTrace();
    }
  }

  int _serial = 0;
  MatchPhase _previous = MatchPhase.ready;
  int _previousSeconds = 0;
  final ShotTrail _trail = ShotTrail();
  double _kickTime = 0;
  Picture? _fieldPicture;
  int? _fieldStageIndex;
  final List<Picture> _playerPictures = [];
  // Include Classic's two defenders and every configured challenge defender.
  // Precache once so entering a triple-wall stage needs no new player artwork.
  static final int _cachedDefenderCount = challengeStages.fold<int>(
      2, (count, stage) => math.max(count, stage.defenders));
  final Map<(String, double, Color, double), TextPainter> _labelCache = {};
  final List<Paint> _trailPaints = List.generate(
    14,
    (i) => Paint()..color = Color.fromRGBO(233, 255, 177, .06 + i * .05),
  );
  final List<Paint> _fireTrailPaints = List.generate(
    14,
    (i) => Paint()..color = Color.fromRGBO(217, 255, 106, .08 + i * .055),
  );
  final List<Paint> _confettiPaints = [
    Paint()..color = const Color(0xffd9ff6a),
    Paint()..color = const Color(0xffffc857),
    Paint()..color = const Color(0xffefffe2),
  ];
  final Paint _postSparkPaint = Paint()..color = const Color(0xfffff4c2);
  final Paint _aimPaint = Paint()
    ..color = const Color(0xffd9ff6a)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;
  final Paint _aimDotPaint = Paint()..color = const Color(0xffd9ff6a);
  final Paint _wideDotPaint = Paint()..color = const Color(0xffff777a);
  final Paint _spinTrackPaint = Paint()
    ..color = const Color(0x66efffe2)
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;
  final Paint _spinFillPaint = Paint()
    ..color = const Color(0xffd9ff6a)
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round;
  final Paint _aimRingPaint = Paint()
    ..color = const Color(0x55d9ff6a)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final Paint _fireBorderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4;
  final Paint _lastChancePaint = Paint()
    ..color = const Color(0x55ff777a)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  final Paint _ballShadowPaint = Paint()..color = const Color(0x55000000);
  final Paint _keeperShadowPaint = Paint()..color = const Color(0x44000000);
  final Paint _keeperCuePaint = Paint()..color = const Color(0xee082f2c);
  final Paint _keeperHairPaint = Paint()
    ..color = const Color(0xff24372d)
    ..strokeWidth = 3
    ..style = PaintingStyle.stroke;
  final List<Paint> _keeperPartPaints = [
    for (final color in [0xffffc857, 0xff173a39, 0xfffff5df, 0xff132d30, 0xffd99c71])
      Paint()
        ..color = Color(color)
        ..strokeCap = StrokeCap.round,
  ];
  final Paint _ballPaint = Paint()..color = const Color(0xfff8faed);
  final Paint _fireBallPaint = Paint()..color = const Color(0x55ffc857);
  final Paint _ballPatchPaint = Paint()..color = const Color(0xff233e37);
  final Paint _goalFlashPaint = Paint();
  final Path _aimPath = Path();
  final Path _ballPatch = _makeBallPatch();
  final Path _championPatch = _makeChampionPatch();
  StarReward _ballSkin = StarReward.classicBall;
  StarReward _netSkin = StarReward.standardNet;
  StarReward _pitchSkin = StarReward.dayPitch;
  final Paint _neonHaloPaint = Paint()..color = const Color(0x44d9ff6a);
  final Paint _lockedTargetPaint = Paint()
    ..color = const Color(0xbbeef8df)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final RRect _pitchBorder = RRect.fromRectAndRadius(
      const Rect.fromLTWH(12, 12, 376, 590), const Radius.circular(24));
  final List<Offset> _confettiVelocities = List.generate(40, (i) {
    final speed = 75.0 + (i % 5) * 20;
    return Offset(math.cos(i * 2.399) * speed, math.sin(i * 2.399) * speed);
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Lay out the finite set of labels before the first playable frame.
    _painterFor('1', 11, const Color(0xff123c33), 0);
    for (var i = 0; i < _cachedDefenderCount; i++) {
      _painterFor('${i + 4}', 11, const Color(0xff123c33), 0);
    }
    _painterFor('TAP', 12, const Color(0xffd9ff6a), 2.5);
    for (final cue in ShotCurve.releaseLabels) {
      _painterFor(cue, 10, const Color(0xffd9ff6a), 1);
    }
    _painterFor('ON FIRE', 13, const Color(0xffd9ff6a), 3);
    _painterFor('FIRE SHOT', 13, const Color(0xffd9ff6a), 3);
    _painterFor('LAST CHANCE', 12, const Color(0xffff777a), 2);
    for (final cue in ['RUSH INCOMING', 'FEET SET', 'FULL STRETCH',
        'RUSH & SLIDE', 'COVERING LEFT', 'COVERING RIGHT',
        'TRY AGAIN!', 'NOT THIS TIME!', 'MY BOX!']) {
      _painterFor(cue, 10, const Color(0xffffe6a0), 1);
    }
    _preparePlayers();
    _prepareField();
    _syncTrace();
  }

  void _preparePlayers() {
    if (_playerPictures.isNotEmpty) {
      return;
    }
    for (final keeper in KeeperStyle.values) {
      final recorder = PictureRecorder();
      _drawPlayerArt(Canvas(recorder), 0, 0, Color(keeper.kitColor), '1', keeper: true);
      _playerPictures.add(recorder.endRecording());
    }
    for (var i = 0; i < _cachedDefenderCount; i++) {
      final recorder = PictureRecorder();
      _drawPlayerArt(Canvas(recorder), 0, 0, const Color(0xffff686b), '${i + 4}');
      _playerPictures.add(recorder.endRecording());
    }
  }

  void _prepareField() {
    if (_fieldPicture != null && _fieldStageIndex == model.stageIndex) {
      return;
    }
    _fieldPicture?.dispose();
    _fieldStageIndex = model.stageIndex;
    // Keep logical vector commands so resizing does not blur the pitch.
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    _pitch(canvas);
    _goal(canvas);
    _label(canvas, model.isChallenge
        ? '${model.keeperSkill.title.toUpperCase()} · ${model.keeperStyle.title.toUpperCase()}'
        : 'ONE TOUCH. MAKE IT COUNT.', 200, 619, 10,
        const Color(0xff75b3a1), spacing: 2);
    _fieldPicture = recorder.endRecording();
  }

  @override
  void onRemove() {
    _fieldPicture?.dispose();
    _fieldPicture = null;
    for (final picture in _playerPictures) {
      picture.dispose();
    }
    _playerPictures.clear();
    for (final painter in _labelCache.values) {
      painter.dispose();
    }
    _labelCache.clear();
    trace.dispose();
    super.onRemove();
  }

  @override
  Color backgroundColor() => const Color(0xff073c34);

  void applyCosmetics(CosmeticSelection selection) {
    final fieldChanged = _netSkin != selection.net || _pitchSkin != selection.pitch;
    _ballSkin = selection.ball;
    _netSkin = selection.net;
    _pitchSkin = selection.pitch;
    _ballPaint.color = Color(_ballSkin.primary);
    _ballPatchPaint.color = Color(_ballSkin.secondary);
    if (fieldChanged) {
      _fieldPicture?.dispose();
      _fieldPicture = null;
    }
  }

  void startMatch() {
    trace.event('classic.start-or-restart');
    model.start();
    _resetPresentation();
  }

  void prepareStage(int index, {bool guided = false}) {
    trace.event('stage.prepare', {'stage': index + 1});
    model.prepareStage(index, guided: guided);
    _resetPresentation();
  }

  void startStage() {
    trace.event('stage.start');
    model.startStage();
    _resetPresentation();
  }

  void retryStage() {
    if (model.phase != MatchPhase.finished &&
        model.phase != MatchPhase.stageCleared) return;
    trace.event('stage.retry', {'stage': model.level});
    model.retryStage();
    _resetPresentation();
  }

  void returnToMenu() {
    trace.event('menu');
    model.returnToMenu();
    _resetPresentation();
  }

  void _resetPresentation() {
    matchPaused = false;
    _kickTime = 0;
    _trail.clear();
    _previous = model.phase;
    _serial = model.resultSerial;
    _previousSeconds = model.timerSeconds;
    _syncTrace();
    onChanged();
  }

  bool beginShot() {
    if (matchPaused || !model.beginShot()) return false;
    trace.event('shot.prepare');
    return true;
  }

  void adjustCurve(double dragX) {
    if (!matchPaused) model.adjustCurve(dragX);
  }

  // No Flutter notification: safe when a pointer is cancelled during layout,
  // pause, or widget disposal. The existing game loop paints the next state.
  void cancelShot() => model.cancelShot();

  bool releaseShot() => _acceptShot(!matchPaused && model.releaseShot());

  bool shoot() => _acceptShot(!matchPaused && model.shoot());

  bool _acceptShot(bool accepted) {
    if (accepted) {
      _kickTime = .14;
      _trail.clear();
      _previous = model.phase;
      trace.event('shot.released', {'shot': model.resolvedShots + 1,
          'spin': model.shotSpin});
      _syncTrace();
      onChanged();
      return true;
    }
    return false;
  }

  void endRun() {
    if (!model.isPlaying) {
      return;
    }
    model.endRun();
    matchPaused = false;
    _kickTime = 0;
    _trail.clear();
    _previous = model.phase;
    trace.event('run.ended');
    _syncTrace();
    onChanged();
  }

  void _syncTrace() {
    if (!PlaytestTrace.enabled) {
      return;
    }
    final label = matchPaused
        ? 'paused'
        : switch (model.phase) {
            MatchPhase.aiming =>
              model.firstAim ? 'aiming.first' : 'aiming.repeat',
            MatchPhase.flying =>
              model.resolvedShots == 0 ? 'shot.first' : 'shot.repeat',
            MatchPhase.result =>
              model.lastWasGoal ? 'feedback.goal' : 'feedback.miss',
            MatchPhase.finished => 'results',
            MatchPhase.stageCleared => 'stage.cleared',
            MatchPhase.stageIntro => 'stage.briefing',
            MatchPhase.ready => 'menu',
          };
    trace.phase(label, {
      'mode': model.isChallenge ? 'challenge' : 'classic',
      'level': model.level,
      'resolvedShots': model.resolvedShots,
    });
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (matchPaused) {
      return;
    }
    final frameDt = dt.clamp(0.0, .1).toDouble();
    final fromX = model.ballX;
    final fromY = model.ballY;
    final wasFlying = model.phase == MatchPhase.flying;
    if (_kickTime > 0) {
      _kickTime = math.max(0, _kickTime - frameDt);
    }
    model.update(frameDt, cinematic: true);
    if (wasFlying && model.phase == MatchPhase.flying) {
      _trail.sample(frameDt, fromX, fromY, model.ballX, model.ballY);
    } else {
      _trail.clear();
    }
    final shotChanged = _serial != model.resultSerial;
    final phaseChanged = _previous != model.phase;
    final clockChanged = _previousSeconds != model.timerSeconds;
    _serial = model.resultSerial;
    _previous = model.phase;
    _previousSeconds = model.timerSeconds;
    if (phaseChanged) {
      _syncTrace();
    }
    // A shot-result callback already refreshes Flutter. Keep one notification
    // per event and no HUD rebuilds for ordinary animation frames.
    if (shotChanged) {
      onShotResult();
    } else if (phaseChanged || clockChanged) {
      onChanged();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final scale = math.min(size.x / 400, size.y / 640);
    if (scale <= 0) {
      return;
    }
    canvas.save();
    canvas.translate((size.x - 400 * scale) / 2, (size.y - 640 * scale) / 2);
    canvas.scale(scale);
    _prepareField();
    _preparePlayers();
    canvas.drawPicture(_fieldPicture!);
    _stakes(canvas);
    for (var i = 0; i < model.defenderCount; i++) {
      _player(canvas, model.defenderX(i), model.defenderY(i), KeeperStyle.values.length + i);
    }
    if (model.isChallenge) {
      _professionalKeeper(canvas);
      _keeperCue(canvas);
    } else {
      _player(canvas, model.keeperX, model.keeperY, model.keeperStyle.index);
    }
    if (model.phase == MatchPhase.aiming || model.phase == MatchPhase.ready) {
      _aim(canvas);
    } else if (model.phase == MatchPhase.flying || model.phase == MatchPhase.result) {
      // Keep the accepted target visible even when the keeper/defender stops
      // the ball early. This records aim, not a prediction of a goal.
      _targetDot(canvas, model.shotTargetX, locked: true);
    }
    final trailPaints = model.onFire ? _fireTrailPaints : _trailPaints;
    for (var i = 0; i < _trail.length; i++) {
      canvas.drawCircle(Offset(_trail.xAt(i), _trail.yAt(i)),
          2.2 + i * .7, trailPaints[i]);
    }
    _ball(canvas);
    if (model.phase == MatchPhase.result && model.lastWasGoal) {
      _celebrate(canvas);
    } else if (model.phase == MatchPhase.result && model.lastWasPost) {
      _postSpark(canvas);
    }
    canvas.restore();
  }

  void _stakes(Canvas c) {
    final live = model.phase == MatchPhase.aiming ||
        model.phase == MatchPhase.flying;
    if (!live) {
      return;
    }
    if (model.onFire) {
      final pulse = .16 + .1 * math.sin(model.clock * 6);
      _fireBorderPaint.color = Color.fromRGBO(217, 255, 106, pulse);
      c.drawRRect(_pitchBorder, _fireBorderPaint);
      _label(c, model.isChallenge ? 'FIRE SHOT' : 'ON FIRE',
          200, 16, 13, const Color(0xffd9ff6a), spacing: 3);
    } else if (model.lastChance) {
      c.drawRRect(_pitchBorder, _lastChancePaint);
      _label(c, 'LAST CHANCE', 200, 16, 12, const Color(0xffff777a), spacing: 2);
    }
  }

  void _pitch(Canvas c) {
    final rect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 12, 376, 590), const Radius.circular(24));
    final night = _pitchSkin == StarReward.nightPitch;
    c.drawRRect(rect, Paint()..color = Color(night
        ? _pitchSkin.primary : model.stage?.pitchColor ?? 0xff126a50));
    c.save();
    c.clipRRect(rect);
    for (var i = 0; i < 9; i++) {
      if (i.isEven) {
        c.drawRect(Rect.fromLTWH(12, 12 + i * 70, 376, 70),
            Paint()..color = Color(night
                ? _pitchSkin.secondary : model.stage?.stripeColor ?? 0xff167456));
      }
    }
    c.restore();
    if (night) {
      // Decorative floodlights are recorded with the static pitch, never in
      // the per-frame animation path or collision model.
      final glow = Paint()..color = const Color(0x447edfff);
      final lamp = Paint()..color = const Color(0xffd6f7ff);
      for (final x in [28.0, 372.0]) {
        c.drawCircle(Offset(x, 72), 15, glow);
        c.drawRRect(RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, 72), width: 14, height: 6),
            const Radius.circular(2)), lamp);
      }
    }
    final line = Paint()
      ..color = const Color(0x668bddad)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(28, 100, 344, 484), const Radius.circular(2)),
        line);
    c.drawRect(const Rect.fromLTWH(63, 100, 274, 155), line);
    c.drawRect(const Rect.fromLTWH(118, 100, 164, 67), line);
    c.drawArc(const Rect.fromLTWH(132, 180, 136, 136), 0, math.pi, false, line);
    c.drawLine(const Offset(28, 436), const Offset(372, 436), line);
    c.drawCircle(const Offset(200, 436), 57, line);
    c.drawCircle(
        const Offset(200, 216), 3, Paint()..color = const Color(0xff8bddad));
    _label(c, model.stage?.name.toUpperCase() ?? 'STRIKER ARENA',
        200, 36, 11, const Color(0xff9bd7b6),
        spacing: 3);
  }

  void _goal(Canvas c) {
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(60, 51, 280, 55), const Radius.circular(6)),
        Paint()..color = const Color(0xff082f2c));
    final net = Paint()
      ..color = Color(_netSkin.primary)
      ..strokeWidth = .8;
    for (double x = 65; x <= 335; x += 15) {
      c.drawLine(Offset(x, 55), Offset(x, 100), net);
    }
    for (double y = 55; y < 100; y += 11) {
      c.drawLine(Offset(65, y), Offset(335, y), net);
    }
    final glow = Paint()..color = const Color(0x66d9ff6a);
    c.drawRect(const Rect.fromLTWH(73, 58, 37, 42), glow);
    c.drawRect(const Rect.fromLTWH(290, 58, 37, 42), glow);
    _label(c, '+3', 91, 72, 13, const Color(0xffe1ff8d));
    _label(c, '+3', 309, 72, 13, const Color(0xffe1ff8d));
    final frame = Paint()
      ..color = Color(_netSkin.secondary)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    c.drawPath(
        Path()
          ..moveTo(65, 103)
          ..lineTo(65, 54)
          ..lineTo(335, 54)
          ..lineTo(335, 103),
        frame);
  }

  void _player(Canvas c, double x, double y, int pictureIndex) {
    c.save();
    c.translate(x, y);
    c.drawPicture(_playerPictures[pictureIndex]);
    c.restore();
  }

  void _professionalKeeper(Canvas c) {
    final pose = model.keeper.pose;
    c.drawOval(Rect.fromCenter(center: Offset(pose.x + 2, pose.y + 15),
        width: 44 + 12 * pose.rotation.abs(), height: 13), _keeperShadowPaint);
    _keeperPartPaints[KeeperPart.kit.index].color = Color(model.keeperStyle.kitColor);
    c.save();
    c.translate(pose.x, pose.y);
    c.rotate(pose.rotation);
    for (final part in pose.segments) {
      final paint = _keeperPartPaints[part.part.index]..strokeWidth = part.radius * 2;
      if (part.ax == part.bx && part.ay == part.by) {
        c.drawCircle(Offset(part.ax, part.ay), part.radius, paint);
      } else {
        c.drawLine(Offset(part.ax, part.ay), Offset(part.bx, part.by), paint);
      }
    }
    // Hair and shirt number sit inside the shared head/torso shapes. Body
    // segments, gloves and boots have exactly the radii used for ball contact.
    c.drawArc(Rect.fromCircle(center: Offset(0, pose.headY), radius: 6.5),
        math.pi, math.pi, false, _keeperHairPaint);
    _label(c, '1', 0, -3, 11, const Color(0xff123c33));
    c.restore();
  }

  void _keeperCue(Canvas c) {
    if (!model.isPlaying) return;
    final cue = model.keeper.action == KeeperAction.taunt
        ? switch (model.keeperStyle) {
            KeeperStyle.sweeper => 'TRY AGAIN!',
            KeeperStyle.sentinel => 'NOT THIS TIME!',
            KeeperStyle.gambler => 'MY BOX!',
          }
        : model.keeper.cue;
    if (cue.isEmpty) return;
    // Keep the cue in the centre of the net, away from both corner targets.
    c.drawRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(126, 69, 148, 22), const Radius.circular(6)), _keeperCuePaint);
    _label(c, cue, 200, 74, 10, const Color(0xffffe6a0), spacing: 1);
  }

  void _drawPlayerArt(Canvas c, double x, double y, Color kit, String number,
      {bool keeper = false}) {
    c.drawOval(
        Rect.fromCenter(center: Offset(x + 2, y + 12), width: 42, height: 14),
        Paint()..color = const Color(0x33000000));
    if (keeper) {
      c.drawLine(
          Offset(x - 25, y),
          Offset(x + 25, y),
          Paint()
            ..color = kit
            ..strokeWidth = 10
            ..strokeCap = StrokeCap.round);
      c.drawCircle(
          Offset(x - 25, y), 5, Paint()..color = const Color(0xfff4f4e7));
      c.drawCircle(
          Offset(x + 25, y), 5, Paint()..color = const Color(0xfff4f4e7));
    }
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, y + 2), width: 30, height: 25),
            const Radius.circular(8)),
        Paint()..color = kit);
    _label(c, number, x, y - 3, 11, const Color(0xff123c33));
    c.drawCircle(
        Offset(x, y - 15), 9, Paint()..color = const Color(0xffd99c71));
    c.drawArc(
        Rect.fromCircle(center: Offset(x, y - 16), radius: 9),
        math.pi,
        math.pi,
        false,
        Paint()
          ..color = const Color(0xff24372d)
          ..strokeWidth = 5
          ..style = PaintingStyle.stroke);
  }

  void _aim(Canvas c) {
    if (model.isPreparingShot) {
      _preparedAim(c);
      return;
    }
    final dx = model.aimX - 200;
    const dy = 100 - 548.0;
    final length = math.sqrt(dx * dx + dy * dy);
    final ux = dx / length;
    final uy = dy / length;
    for (double d = 24; d < 152; d += 15) {
      c.drawLine(Offset(200 + ux * d, 548 + uy * d),
          Offset(200 + ux * (d + 6), 548 + uy * (d + 6)), _aimPaint);
    }
    final tip = Offset(200 + ux * 167, 548 + uy * 167);
    _aimPath
      ..reset()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - ux * 13 - uy * 7, tip.dy - uy * 13 + ux * 7)
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - ux * 13 + uy * 7, tip.dy - uy * 13 - ux * 7);
    c.drawPath(_aimPath, _aimPaint);
    _targetDot(c, model.aimX);
    c.drawCircle(
        const Offset(200, 548),
        (model.showTapCue ? 24 : 20) + math.sin(model.clock * 3) * 2,
        _aimRingPaint);
    if (model.showTapCue) {
      _label(c, 'TAP', 200, 575, 12, const Color(0xffd9ff6a), spacing: 2.5);
    }
  }

  void _preparedAim(Canvas c) {
    // Sample only the first part of the same trajectory used for collisions.
    // Reuse the path and finite label cache; dragging adds no HUD rebuilds.
    _aimPath.reset();
    for (var i = 1; i <= 16; i++) {
      final p = i / 25;
      final x = model.previewXAt(p);
      final y = MatchModel.ballStartY + (MatchModel.goalY - MatchModel.ballStartY) * p;
      if (i == 1) { _aimPath.moveTo(x, y); } else { _aimPath.lineTo(x, y); }
    }
    final x = model.previewXAt(.64);
    const y = MatchModel.ballStartY + (MatchModel.goalY - MatchModel.ballStartY) * .64;
    final dx = x - model.previewXAt(.60);
    const dy = (MatchModel.goalY - MatchModel.ballStartY) * .04;
    final length = math.sqrt(dx * dx + dy * dy);
    final ux = dx / length, uy = dy / length;
    _aimPath
      ..moveTo(x - ux * 13 - uy * 7, y - uy * 13 + ux * 7)
      ..lineTo(x, y)
      ..lineTo(x - ux * 13 + uy * 7, y - uy * 13 - ux * 7);
    c.drawPath(_aimPath, _aimPaint);
    _targetDot(c, model.previewTargetX);
    c.drawCircle(const Offset(200, 548), 25, _aimRingPaint);
    _label(c, ShotCurve.releaseLabel(model.preparedSpin),
        200, 575, 10, const Color(0xffd9ff6a), spacing: 1);
    c.drawLine(const Offset(152, 602), const Offset(248, 602), _spinTrackPaint);
    c.drawLine(const Offset(200, 597), const Offset(200, 607), _spinTrackPaint);
    if (model.preparedSpin != 0) {
      c.drawLine(const Offset(200, 602),
          Offset(200 + model.preparedSpin * 48, 602), _spinFillPaint);
    }
  }

  void _targetDot(Canvas c, double targetX, {bool locked = false}) {
    final visibleX = targetX.clamp(24.0, 376.0).toDouble();
    if (locked) {
      c.drawCircle(Offset(visibleX, MatchModel.goalY), 10, _lockedTargetPaint);
    } else {
      c.drawCircle(Offset(visibleX, MatchModel.goalY), 5,
          MatchModel.isOnTarget(targetX) ? _aimDotPaint : _wideDotPaint);
    }
    // An off-pitch target gets an outward marker; only this UI marker is
    // clamped. The actual ball can still travel wide beyond the visible field.
    if (visibleX != targetX) {
      final direction = targetX < visibleX ? -1.0 : 1.0;
      _aimPath
        ..reset()
        ..moveTo(visibleX, MatchModel.goalY - 6)
        ..lineTo(visibleX + direction * 7, MatchModel.goalY)
        ..lineTo(visibleX, MatchModel.goalY + 6);
      c.drawPath(_aimPath, _lockedTargetPaint);
    }
  }

  void _ball(Canvas c) {
    var squashX = 1.0;
    var squashY = 1.0;
    if (_kickTime > 0) {
      final u = (1 - _kickTime / .14).clamp(0.0, 1.0);
      final pulse = math.sin(math.pi * u);
      squashX = 1 + .45 * pulse;
      squashY = 1 - .35 * pulse;
    }
    c.save();
    c.translate(model.ballX, model.ballY);
    c.scale(squashX, squashY);
    if ((model.phase == MatchPhase.aiming && model.fireReady) ||
        (model.phase == MatchPhase.flying && model.shotIsFire)) {
      c.drawCircle(Offset.zero, 13, _fireBallPaint);
    }
    c.drawOval(const Rect.fromLTWH(-8, 2.5, 20, 9), _ballShadowPaint);
    if (_ballSkin == StarReward.neonBall) {
      c.drawCircle(Offset.zero, 10, _neonHaloPaint);
    }
    c.drawCircle(Offset.zero, 8, _ballPaint);
    c.rotate(model.ballAngle);
    c.drawPath(_ballSkin == StarReward.championBall ? _championPatch : _ballPatch,
        _ballPatchPaint);
    c.restore();
  }

  static Path _makeBallPatch() {
    final patch = Path();
    for (var i = 0; i < 5; i++) {
      final a = i * math.pi * 2 / 5;
      final x = math.cos(a) * 3.5;
      final y = math.sin(a) * 3.5;
      if (i == 0) {
        patch.moveTo(x, y);
      } else {
        patch.lineTo(x, y);
      }
    }
    return patch..close();
  }

  static Path _makeChampionPatch() {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final angle = i * math.pi / 5 - math.pi / 2;
      final radius = i.isEven ? 4.5 : 2.0;
      final x = math.cos(angle) * radius, y = math.sin(angle) * radius;
      if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }
    return path..close();
  }

  void _celebrate(Canvas c) {
    final duration = model.goalFeedbackDuration;
    final highlight = model.lastWasCorner || model.lastWasFire;
    final t = (duration - model.resultTime).clamp(0.0, duration);
    if (highlight && t < .2) {
      _goalFlashPaint.color = Color.fromRGBO(255, 255, 255, .35 * (1 - t / .2));
      c.drawRect(const Rect.fromLTWH(60, 51, 280, 55), _goalFlashPaint);
    }
    final count = highlight ? 40 : 24;
    final spread = highlight ? 1.35 : 1.0;
    for (var i = 0; i < count; i++) {
      final velocity = _confettiVelocities[i];
      final p = Offset(model.ballX + velocity.dx * t * spread,
          98 + velocity.dy * t * spread + t * t * 80);
      c.drawCircle(p, highlight ? 3.2 : 2.5, _confettiPaints[i % 3]);
    }
  }

  void _postSpark(Canvas c) {
    final t = (1.15 - model.resultTime).clamp(0.0, 1.15);
    final x = model.shotTargetX < 200
        ? MatchModel.leftPost
        : MatchModel.rightPost;
    for (var i = 0; i < 12; i++) {
      final angle = i * 0.7 + t * 4;
      final r = 8 + t * (18 + (i % 4) * 6);
      c.drawCircle(Offset(x + math.cos(angle) * r, 100 + math.sin(angle) * r * .45),
          2.2, _postSparkPaint);
    }
  }

  void _label(
      Canvas c, String text, double x, double y, double fontSize, Color color,
      {double spacing = 0}) {
    final painter = _painterFor(text, fontSize, color, spacing);
    painter.paint(c, Offset(x - painter.width / 2, y));
  }

  TextPainter _painterFor(
      String text, double fontSize, Color color, double spacing) {
    return _labelCache.putIfAbsent((text, fontSize, color, spacing), () {
      return TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: spacing,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }
}
