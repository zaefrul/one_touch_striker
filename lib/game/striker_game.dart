import 'dart:math' as math;
import 'dart:ui' hide TextStyle;
import 'package:flame/game.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle;
import 'match_model.dart';

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

  @override
  Color backgroundColor() => const Color(0xff073c34);

  void startMatch() {
    model.start();
    matchPaused = false;
    _trail.clear();
    onChanged();
  }

  void shoot() {
    if (!matchPaused && model.shoot()) {
      _trail.clear();
      onChanged();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (matchPaused) {
      return;
    }
    model.update(dt);
    if (model.phase == MatchPhase.flying) {
      _trailTime += dt;
      if (_trailTime >= .016) {
        _trailTime = 0;
        _trail.add(Offset(model.ballX, model.ballY));
        if (_trail.length > 9) {
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
    _pitch(canvas);
    _goal(canvas);
    for (var i = 0; i < model.defenderCount; i++) {
      _player(canvas, model.defenderX(i), model.defenderY(i),
          const Color(0xffff686b), '${4 + i}');
    }
    _player(canvas, model.keeperX, model.keeperY, const Color(0xffffc857), '1',
        keeper: true);
    if (model.phase == MatchPhase.aiming || model.phase == MatchPhase.ready) {
      _aim(canvas);
    }
    for (var i = 0; i < _trail.length; i++) {
      canvas.drawCircle(_trail[i], 2 + i * .65,
          Paint()..color = Color.fromRGBO(233, 255, 177, .05 + i * .055));
    }
    _ball(canvas);
    if (model.phase == MatchPhase.result && model.lastWasGoal) {
      _celebrate(canvas);
    }
    _label(canvas, 'ONE TOUCH. MAKE IT COUNT.', 200, 619, 10,
        const Color(0xff75b3a1),
        spacing: 2);
    canvas.restore();
  }

  void _pitch(Canvas c) {
    final rect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 12, 376, 590), const Radius.circular(24));
    c.drawRRect(rect, Paint()..color = const Color(0xff126a50));
    c.save();
    c.clipRRect(rect);
    for (var i = 0; i < 9; i++) {
      if (i.isEven) {
        c.drawRect(Rect.fromLTWH(12, 12 + i * 70, 376, 70),
            Paint()..color = const Color(0xff167456));
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
    _label(c, 'STRIKER ARENA', 200, 36, 11, const Color(0xff9bd7b6),
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
        20 + math.sin(model.clock * 3) * 2,
        Paint()
          ..color = const Color(0x55d9ff6a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  void _ball(Canvas c) {
    final p = Offset(model.ballX, model.ballY);
    c.drawOval(
        Rect.fromCenter(center: p + const Offset(2, 7), width: 20, height: 9),
        Paint()..color = const Color(0x55000000));
    c.drawCircle(p, 8, Paint()..color = const Color(0xfff8faed));
    final patch = Path();
    for (var i = 0; i < 5; i++) {
      final a = i * math.pi * 2 / 5 +
          model.clock * (model.phase == MatchPhase.flying ? 12 : 0);
      final x = p.dx + math.cos(a) * 3.5;
      final y = p.dy + math.sin(a) * 3.5;
      if (i == 0) {
        patch.moveTo(x, y);
      } else {
        patch.lineTo(x, y);
      }
    }
    c.drawPath(patch..close(), Paint()..color = const Color(0xff233e37));
  }

  void _celebrate(Canvas c) {
    final t = .85 - model.resultTime;
    for (var i = 0; i < 24; i++) {
      final angle = i * 2.399;
      final r = t * (75 + (i % 5) * 20);
      final p = Offset(model.ballX + math.cos(angle) * r,
          98 + math.sin(angle) * r + t * t * 80);
      c.drawCircle(
          p,
          2.5,
          Paint()
            ..color = [
              const Color(0xffd9ff6a),
              const Color(0xffffc857),
              const Color(0xffefffe2)
            ][i % 3]);
    }
  }

  void _label(
      Canvas c, String text, double x, double y, double fontSize, Color color,
      {double spacing = 0}) {
    final painter = TextPainter(
        text: TextSpan(
            text: text,
            style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: spacing)),
        textDirection: TextDirection.ltr)
      ..layout();
    painter.paint(c, Offset(x - painter.width / 2, y));
  }
}
