import 'dart:math' as math;
import 'dart:ui' hide TextStyle;
import 'package:flame/game.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;
import 'match_model.dart';
import 'stage.dart';

class StrikerGame extends FlameGame {
  StrikerGame(this.model,
      {required this.onChanged, required this.onShotResult});
  final MatchModel model;
  final void Function() onChanged;
  final void Function() onShotResult;
  bool matchPaused = false;
  int _serial = 0;
  MatchPhase _previous = MatchPhase.ready;
  final List<Offset> _trail = [];
  double _trailTime = 0;
  double _kickTime = 0;
  Picture? _fieldPicture;
  StageId? _drawnStage;
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

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Lay out the finite set of labels before the first playable frame.
    for (final number in ['1', '4', '5']) {
      _painterFor(number, 11, const Color(0xff123c33), 0);
    }
    _painterFor('TAP', 12, const Color(0xffd9ff6a), 2.5);
    _painterFor('ON FIRE', 13, const Color(0xffd9ff6a), 3);
    _painterFor('LAST CHANCE', 12, const Color(0xffff777a), 2);
    _prepareField();
  }

  void _prepareField() {
    if (_fieldPicture != null && _drawnStage == model.stage.id) {
      return;
    }
    _fieldPicture?.dispose();
    // Keep logical vector commands so resizing does not blur the pitch.
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    _pitch(canvas);
    _goal(canvas);
    _label(canvas, model.stage.tagline, 200, 619, 10, model.stage.line,
        spacing: 2);
    _fieldPicture = recorder.endRecording();
    _drawnStage = model.stage.id;
  }

  @override
  void onRemove() {
    _fieldPicture?.dispose();
    _fieldPicture = null;
    _drawnStage = null;
    for (final painter in _labelCache.values) {
      painter.dispose();
    }
    _labelCache.clear();
    super.onRemove();
  }

  @override
  Color backgroundColor() => model.stage.backdrop;

  void startMatch() {
    model.start();
    matchPaused = false;
    _kickTime = 0;
    _trail.clear();
    _fieldPicture?.dispose();
    _fieldPicture = null;
    _drawnStage = null;
    onChanged();
  }

  void shoot() {
    if (!matchPaused && model.shoot()) {
      _kickTime = .14;
      _trail.clear();
      onChanged();
    }
  }

  void endRun() {
    if (model.phase == MatchPhase.ready ||
        model.phase == MatchPhase.finished) {
      return;
    }
    model.endRun();
    matchPaused = false;
    _kickTime = 0;
    _trail.clear();
    onChanged();
  }

  double _dramaScale() {
    if (model.phase != MatchPhase.flying) {
      return 1;
    }
    if (model.ballY > MatchModel.goalY + 115) {
      return 1;
    }
    if (model.shotHeadsToCornerGoal || model.shotHeadsToPost) {
      return .38;
    }
    return 1;
  }

  double get _flightT {
    return ((MatchModel.ballStartY - model.ballY) /
            (MatchModel.ballStartY - MatchModel.goalY))
        .clamp(0.0, 1.0);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (matchPaused) {
      return;
    }
    if (_kickTime > 0) {
      _kickTime = math.max(0, _kickTime - dt);
    }
    model.update(dt * _dramaScale());
    if (model.phase == MatchPhase.flying) {
      _trailTime += dt;
      if (_trailTime >= .012) {
        _trailTime = 0;
        _trail.add(Offset(model.ballX, model.ballY));
        if (_trail.length > 14) {
          _trail.removeAt(0);
        }
      }
    } else {
      _trail.clear();
    }
    if (_serial != model.resultSerial) {
      _serial = model.resultSerial;
      onShotResult();
    }
    if (_previous != model.phase) {
      _previous = model.phase;
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
    canvas.drawPicture(_fieldPicture!);
    _stakes(canvas);
    final flight = _flightT;
    for (final obstacle in model.activeObstacles) {
      _obstacle(canvas, obstacle, model.obstacleX(obstacle),
          model.obstacleY(obstacle));
    }
    for (var i = 0; i < model.defenderCount; i++) {
      final lean = model.phase == MatchPhase.flying
          ? (model.ballX - model.defenderX(i)) * .08 * flight
          : 0.0;
      _player(canvas, model.defenderX(i) + lean, model.defenderY(i),
          const Color(0xffff686b), '${4 + i}');
    }
    final keeper = _keeperDraw();
    _player(canvas, keeper.dx, keeper.dy, const Color(0xffffc857), '1',
        keeper: true);
    if (model.phase == MatchPhase.aiming || model.phase == MatchPhase.ready) {
      _aim(canvas);
    }
    final trailPaints = model.onFire ? _fireTrailPaints : _trailPaints;
    for (var i = 0; i < _trail.length; i++) {
      canvas.drawCircle(_trail[i], 2.2 + i * .7, trailPaints[i]);
    }
    _ball(canvas);
    if (model.phase == MatchPhase.result && model.lastWasGoal) {
      _celebrate(canvas);
    } else if (model.phase == MatchPhase.result && model.lastWasPost) {
      _postSpark(canvas);
    }
    canvas.restore();
  }

  Offset _keeperDraw() {
    var x = model.keeperX;
    var y = model.keeperY;
    if (model.phase == MatchPhase.flying ||
        (model.phase == MatchPhase.result && !model.lastWasGoal)) {
      final t = _flightT;
      x += (model.shotTargetX - model.keeperX) * .5 * t;
      y += 8 * t;
    }
    return Offset(x, y);
  }

  void _stakes(Canvas c) {
    final live = model.phase == MatchPhase.aiming ||
        model.phase == MatchPhase.flying;
    if (!live) {
      return;
    }
    if (model.onFire) {
      final pulse = .16 + .1 * math.sin(model.clock * 6);
      c.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(12, 12, 376, 590), const Radius.circular(24)),
          Paint()
            ..color = Color.fromRGBO(217, 255, 106, pulse)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4);
      _label(c, 'ON FIRE', 200, 16, 13, const Color(0xffd9ff6a), spacing: 3);
    } else if (model.lastChance) {
      c.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(12, 12, 376, 590), const Radius.circular(24)),
          Paint()
            ..color = const Color(0x55ff777a)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
      _label(c, 'LAST CHANCE', 200, 16, 12, const Color(0xffff777a), spacing: 2);
    }
  }

  void _pitch(Canvas c) {
    final theme = model.stage;
    final rect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 12, 376, 590), const Radius.circular(24));
    _decorBehind(c, theme);
    c.drawRRect(rect, Paint()..color = theme.grass);
    c.save();
    c.clipRRect(rect);
    for (var i = 0; i < 9; i++) {
      if (i.isEven) {
        c.drawRect(Rect.fromLTWH(12, 12 + i * 70, 376, 70),
            Paint()..color = theme.stripe);
      }
    }
    if (theme.id == StageId.orbit) {
      for (var i = 0; i < 28; i++) {
        c.drawCircle(Offset(24 + (i * 47) % 352, 20 + (i * 73) % 560),
            .8 + (i % 3) * .4, Paint()..color = const Color(0x66ffffff));
      }
    }
    c.restore();
    final line = Paint()
      ..color = theme.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = theme.id == StageId.village ? 1.1 : 1.5;
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(28, 100, 344, 484), const Radius.circular(2)),
        line);
    c.drawRect(const Rect.fromLTWH(63, 100, 274, 155), line);
    c.drawRect(const Rect.fromLTWH(118, 100, 164, 67), line);
    c.drawArc(const Rect.fromLTWH(132, 180, 136, 136), 0, math.pi, false, line);
    c.drawLine(const Offset(28, 436), const Offset(372, 436), line);
    c.drawCircle(const Offset(200, 436), 57, line);
    c.drawCircle(const Offset(200, 216), 3, Paint()..color = theme.line);
    _decorStands(c, theme);
    _label(c, theme.title, 200, 36, 11, theme.line, spacing: 3);
  }

  void _decorBehind(Canvas c, StageSpec theme) {
    if (theme.id == StageId.village) {
      c.drawRect(const Rect.fromLTWH(0, 40, 14, 80),
          Paint()..color = const Color(0xff6b8f3a));
      c.drawRect(const Rect.fromLTWH(386, 50, 14, 70),
          Paint()..color = const Color(0xff6b8f3a));
      c.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(8, 70, 18, 16), const Radius.circular(2)),
          Paint()..color = const Color(0xff8b4a2b));
    }
    if (theme.id == StageId.orbit) {
      c.drawCircle(
          const Offset(48, 80), 16, Paint()..color = const Color(0xff3d6ea8));
      c.drawCircle(
          const Offset(52, 76), 5, Paint()..color = const Color(0xff7cb07a));
    }
  }

  void _decorStands(Canvas c, StageSpec theme) {
    if (theme.id == StageId.pitch || theme.id == StageId.village) {
      return;
    }
    final fill = theme.id == StageId.world || theme.id == StageId.orbit
        ? const Color(0x33101828)
        : const Color(0x44202838);
    c.drawRect(const Rect.fromLTWH(12, 108, 14, 460), Paint()..color = fill);
    c.drawRect(const Rect.fromLTWH(374, 108, 14, 460), Paint()..color = fill);
    if (theme.id == StageId.national || theme.id == StageId.world) {
      final flag = Paint()..color = const Color(0xffd9ff6a);
      c.drawRect(const Rect.fromLTWH(14, 120, 8, 6), flag);
      c.drawRect(const Rect.fromLTWH(378, 120, 8, 6), flag);
    }
  }

  void _goal(Canvas c) {
    final theme = model.stage;
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(60, 51, 280, 55), const Radius.circular(6)),
        Paint()..color = const Color(0xff082f2c));
    final net = Paint()
      ..color = theme.net
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

  void _player(Canvas c, double x, double y, Color kit, String number,
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
    final paint = Paint()
      ..color = const Color(0xffd9ff6a)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (double d = 24; d < 152; d += 15) {
      c.drawLine(Offset(200 + ux * d, 548 + uy * d),
          Offset(200 + ux * (d + 6), 548 + uy * (d + 6)), paint);
    }
    final tip = Offset(200 + ux * 167, 548 + uy * 167);
    c.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(tip.dx - ux * 13 - uy * 7, tip.dy - uy * 13 + ux * 7)
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(tip.dx - ux * 13 + uy * 7, tip.dy - uy * 13 - ux * 7),
        paint);
    c.drawCircle(
        Offset(model.aimX, 100), 5, Paint()..color = const Color(0xffd9ff6a));
    c.drawCircle(
        const Offset(200, 548),
        (model.showTapCue ? 24 : 20) + math.sin(model.clock * 3) * 2,
        Paint()
          ..color = const Color(0x55d9ff6a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    if (model.showTapCue) {
      _label(c, 'TAP', 200, 575, 12, const Color(0xffd9ff6a), spacing: 2.5);
    }
  }

  void _ball(Canvas c) {
    final p = Offset(model.ballX, model.ballY);
    var squashX = 1.0;
    var squashY = 1.0;
    if (_kickTime > 0) {
      final u = (_kickTime / .14).clamp(0.0, 1.0);
      squashX = 1 + .45 * u;
      squashY = 1 - .35 * u;
    }
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(squashX, squashY);
    c.translate(-p.dx, -p.dy);
    c.drawOval(
        Rect.fromCenter(center: p + const Offset(2, 7), width: 20, height: 9),
        Paint()..color = const Color(0x55000000));
    c.drawCircle(p, 8, Paint()..color = const Color(0xfff8faed));
    final spin = model.phase == MatchPhase.flying ? 16.0 : 0.0;
    final patch = Path();
    for (var i = 0; i < 5; i++) {
      final a = i * math.pi * 2 / 5 + model.clock * spin;
      final x = p.dx + math.cos(a) * 3.5;
      final y = p.dy + math.sin(a) * 3.5;
      if (i == 0) {
        patch.moveTo(x, y);
      } else {
        patch.lineTo(x, y);
      }
    }
    c.drawPath(patch..close(), Paint()..color = const Color(0xff233e37));
    c.restore();
  }

  void _celebrate(Canvas c) {
    final duration = model.lastWasCorner ? 1.25 : .85;
    final t = (duration - model.resultTime).clamp(0.0, duration);
    if (model.lastWasCorner && t < .2) {
      c.drawRect(
          const Rect.fromLTWH(60, 51, 280, 55),
          Paint()
            ..color = Color.fromRGBO(255, 255, 255, .35 * (1 - t / .2)));
    }
    final count = model.lastWasCorner ? 40 : 24;
    final spread = model.lastWasCorner ? 1.35 : 1.0;
    for (var i = 0; i < count; i++) {
      final angle = i * 2.399;
      final r = t * (75 + (i % 5) * 20) * spread;
      final p = Offset(model.ballX + math.cos(angle) * r,
          98 + math.sin(angle) * r + t * t * 80);
      c.drawCircle(p, model.lastWasCorner ? 3.2 : 2.5, _confettiPaints[i % 3]);
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

  void _obstacle(Canvas c, ObstacleSpec spec, double x, double y) {
    c.drawOval(
        Rect.fromCenter(center: Offset(x + 2, y + 10), width: 36, height: 12),
        Paint()..color = const Color(0x33000000));
    switch (spec.kind) {
      case ObstacleKind.goat:
        c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 28, height: 16),
            Paint()..color = const Color(0xffe8d4b0));
        c.drawCircle(
            Offset(x + 12, y - 4), 6, Paint()..color = const Color(0xffd9c49a));
        break;
      case ObstacleKind.cart:
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset(x, y), width: 30, height: 16),
                const Radius.circular(3)),
            Paint()..color = const Color(0xff8b4a2b));
        c.drawCircle(
            Offset(x - 8, y + 8), 5, Paint()..color = const Color(0xff2a2a2a));
        c.drawCircle(
            Offset(x + 8, y + 8), 5, Paint()..color = const Color(0xff2a2a2a));
        break;
      case ObstacleKind.mascot:
        c.drawCircle(Offset(x, y), 16, Paint()..color = const Color(0xffff8a3c));
        c.drawCircle(
            Offset(x, y - 2), 7, Paint()..color = const Color(0xfffff3d6));
        break;
      case ObstacleKind.camera:
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset(x, y), width: 34, height: 12),
                const Radius.circular(3)),
            Paint()..color = const Color(0xff2b2b2b));
        c.drawCircle(Offset(x + 10, y), 5, Paint()..color = const Color(0xff89c4ff));
        break;
      case ObstacleKind.steward:
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset(x, y + 2), width: 24, height: 22),
                const Radius.circular(6)),
            Paint()..color = const Color(0xffff8c1a));
        c.drawCircle(
            Offset(x, y - 14), 8, Paint()..color = const Color(0xffd99c71));
        break;
      case ObstacleKind.flag:
        c.drawLine(
            Offset(x - 16, y + 8),
            Offset(x - 16, y - 10),
            Paint()
              ..color = const Color(0xffeef8df)
              ..strokeWidth = 2);
        c.drawRect(Rect.fromLTWH(x - 16, y - 10, 28, 12),
            Paint()..color = const Color(0xffff4d4d));
        break;
      case ObstacleKind.press:
        c.drawCircle(Offset(x, y), 8, Paint()..color = const Color(0xff1c1c1c));
        c.drawCircle(
            Offset(x, y), 14, Paint()..color = const Color(0x55fff4c2));
        break;
      case ObstacleKind.banner:
        c.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset(x, y), width: 52, height: 12),
                const Radius.circular(2)),
            Paint()..color = const Color(0xffd9ff6a));
        break;
      case ObstacleKind.asteroid:
        c.drawCircle(Offset(x, y), spec.halfW,
            Paint()..color = const Color(0xff8a8478));
        c.drawCircle(Offset(x - 4, y - 3), 3,
            Paint()..color = const Color(0xff6d685e));
        break;
      case ObstacleKind.satellite:
        c.drawRect(Rect.fromCenter(center: Offset(x, y), width: 14, height: 10),
            Paint()..color = const Color(0xffd0d6e0));
        c.drawRect(
            Rect.fromCenter(center: Offset(x - 16, y), width: 12, height: 8),
            Paint()..color = const Color(0xff6ec6ff));
        c.drawRect(
            Rect.fromCenter(center: Offset(x + 16, y), width: 12, height: 8),
            Paint()..color = const Color(0xff6ec6ff));
        break;
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
