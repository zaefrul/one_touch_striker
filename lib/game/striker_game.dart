import 'dart:math' as math;
import 'dart:ui' hide TextStyle;
import 'package:flame/game.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;
import 'match_model.dart';
import 'keeper_style.dart';
import 'playtest_trace.dart';
import 'shot_trail.dart';

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
  final Paint _ballPaint = Paint()..color = const Color(0xfff8faed);
  final Paint _fireBallPaint = Paint()..color = const Color(0x55ffc857);
  final Paint _ballPatchPaint = Paint()..color = const Color(0xff233e37);
  final Paint _goalFlashPaint = Paint();
  final Path _aimPath = Path();
  final Path _ballPatch = _makeBallPatch();
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
    for (final number in ['1', '4', '5']) {
      _painterFor(number, 11, const Color(0xff123c33), 0);
    }
    _painterFor('TAP', 12, const Color(0xffd9ff6a), 2.5);
    _painterFor('ON FIRE', 13, const Color(0xffd9ff6a), 3);
    _painterFor('FIRE SHOT', 13, const Color(0xffd9ff6a), 3);
    _painterFor('LAST CHANCE', 12, const Color(0xffff777a), 2);
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
    for (var i = 0; i < 2; i++) {
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
        ? 'VS ${model.keeperStyle.title.toUpperCase()}'
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

  void startMatch() {
    trace.event('classic.start-or-restart');
    model.start();
    _resetPresentation();
  }

  void prepareStage(int index) {
    trace.event('stage.prepare', {'stage': index + 1});
    model.prepareStage(index);
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

  bool shoot() {
    if (!matchPaused && model.shoot()) {
      _kickTime = .14;
      _trail.clear();
      _previous = model.phase;
      trace.event('tap.accepted', {'shot': model.resolvedShots + 1});
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
    // Render at the same anchors used by collision detection. Translating a
    // player toward the shot only in render made visible gaps misleading.
    _player(canvas, model.keeperX, model.keeperY, model.keeperStyle.index);
    if (model.phase == MatchPhase.aiming || model.phase == MatchPhase.ready) {
      _aim(canvas);
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
    c.drawRRect(rect, Paint()..color = Color(model.stage?.pitchColor ?? 0xff126a50));
    c.save();
    c.clipRRect(rect);
    for (var i = 0; i < 9; i++) {
      if (i.isEven) {
        c.drawRect(Rect.fromLTWH(12, 12 + i * 70, 376, 70),
            Paint()..color = Color(model.stage?.stripeColor ?? 0xff167456));
      }
    }
    c.restore();
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
      ..color = const Color(0xff32635a)
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
      ..color = const Color(0xffeef8df)
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
    c.drawCircle(Offset(model.aimX, 100), 5, _aimDotPaint);
    c.drawCircle(
        const Offset(200, 548),
        (model.showTapCue ? 24 : 20) + math.sin(model.clock * 3) * 2,
        _aimRingPaint);
    if (model.showTapCue) {
      _label(c, 'TAP', 200, 575, 12, const Color(0xffd9ff6a), spacing: 2.5);
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
    c.drawCircle(Offset.zero, 8, _ballPaint);
    c.rotate(model.ballAngle);
    c.drawPath(_ballPatch, _ballPatchPaint);
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
