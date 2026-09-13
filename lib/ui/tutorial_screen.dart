import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../game/match_model.dart';
import '../game/knuckle_shot.dart';
import '../game/striker_game.dart';
import '../game/tutorial_progress.dart';
import 'shot_gesture_surface.dart';

/// A separate playable arena shares the real input, trajectory and timing.
/// It has no reference to stars, rival records, best scores or save queues.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, required this.lessons, required this.onComplete,
      required this.onSkip, required this.onDone, this.onKick, this.fireStageIndex = 0});
  final List<TutorialLesson> lessons;
  final ValueChanged<TutorialLesson> onComplete;
  final VoidCallback onSkip, onDone;
  final VoidCallback? onKick;
  final int fireStageIndex;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final model = TutorialMatchModel();
  late final StrikerGame game;
  late final AnimationController _demo;
  late final Widget _pitch;
  int _index = 0;
  bool _passed = false, _released = false, _matched = false;
  bool _interacting = false, _paused = false, _resetting = false;
  bool _retryQueued = false, _leaving = false;
  TutorialLesson get lesson => widget.lessons[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    game = StrikerGame(model, onChanged: _refresh, onShotResult: _result);
    _pitch = GameWidget(game: game);
    _demo = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
    _resetLesson();
  }

  void _resetLesson() {
    _resetting = true;
    _passed = _released = _matched = _interacting = false;
    _retryQueued = false;
    if (lesson == TutorialLesson.fire) {
      game.prepareStage(widget.fireStageIndex);
      game.startStage();
      // Demonstrate an already earned bonus; never grant it to the real match.
      model.fireCharge = model.stage!.fireChargeGoals;
    } else if (lesson == TutorialLesson.aim) {
      game.startMatch();
    } else {
      game.startPractice(lesson.drill);
    }
    _resetting = false;
    game.matchPaused = _paused;
    if (!_paused) _demo.repeat();
  }

  void _refresh() {
    if (!mounted || _resetting || _leaving) return;
    if (!_passed && _released && !_retryQueued &&
        model.phase != MatchPhase.flying && model.phase != MatchPhase.result) {
      _retryQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _passed || _leaving) return;
        setState(_resetLesson);
      });
    }
    setState(() {});
  }

  bool _begin() {
    if (_passed || _paused || !game.beginShot()) return false;
    _demo.stop();
    setState(() => _interacting = true);
    return true;
  }

  void _release() {
    if (!game.releaseShot()) return;
    _released = true;
    _matched = lesson.accepts(model);
    widget.onKick?.call();
  }

  void _accessibleShot() {
    if (_passed || _paused || !game.shoot()) return;
    _released = true;
    _matched = lesson.accepts(model);
    _interacting = true;
    _demo.stop();
    widget.onKick?.call();
  }

  void _cancelGesture() {
    game.cancelShot();
    // Ownership can be cancelled during layout or disposal; repaint later.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _paused || _passed || _released || _leaving || model.isPreparingShot) return;
      setState(() => _interacting = false);
      _demo.repeat();
    });
  }

  void _result() {
    if (!mounted || _leaving) return;
    if (_released && _matched && !_passed) {
      _passed = true;
      game.matchPaused = true;
      _demo.stop();
      widget.onComplete(lesson);
    }
    setState(() {});
  }

  void _next() {
    if (_index == widget.lessons.length - 1) {
      _leave(skip: false);
      return;
    }
    setState(() {
      _index++;
      _resetLesson();
    });
  }

  void _leave({required bool skip}) {
    if (_leaving) return;
    _leaving = true;
    game.matchPaused = true;
    _demo.stop();
    if (skip) { widget.onSkip(); } else { widget.onDone(); }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      game.matchPaused = true; // Cancels the captured draft; release cannot fire.
      _demo.stop();
      if (mounted) setState(() => _paused = true);
    }
  }

  void _resume() {
    setState(() {
      _paused = false;
      _interacting = false;
      game.matchPaused = _passed;
      if (!_passed) _demo.repeat();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    game.matchPaused = true;
    game.pauseEngine();
    game.trace.dispose();
    _demo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final caption = lesson == TutorialLesson.fire
        ? '${model.stage!.fireChargeGoals} ${model.stage!.fireChargeUnit}'
          '${model.stage!.fireChargeGoals == 1 ? '' : 's'} in a row → Fire ×2'
        : 'Try the gesture on the pitch';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave(skip: true);
      },
      child: Scaffold(backgroundColor: const Color(0xff062d29), body: SafeArea(
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480),
          child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 8, 8, 0), child: Row(children: [
              Expanded(child: Text('LEARN BY PLAYING · ${_index + 1}/${widget.lessons.length}',
                  style: const TextStyle(color: Colors.white60, fontSize: 11))),
              TextButton(onPressed: () => _leave(skip: true), child: const Text('Skip tutorials')),
            ])),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(children: [
              Text(lesson.title, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(caption, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ])),
            const SizedBox(height: 8),
            Expanded(child: Stack(fit: StackFit.expand, children: [
              ShotGestureSurface(enabled: !_passed && !_paused && model.phase == MatchPhase.aiming,
                  onBegin: _begin, onDrag: (dx, dy) => game.adjustCurve(dx, dragY: dy),
                  onRelease: _release, onCancel: _cancelGesture,
                  onAccessibleShot: _accessibleShot, child: _pitch),
              if (!_interacting && !_passed && !_paused)
                IgnorePointer(child: ExcludeSemantics(child: AnimatedBuilder(animation: _demo,
                  builder: (_, child) => _HandDemo(lesson: lesson,
                      phase: reducedMotion ? .5 : _demo.value),
                ))),
              if (_passed)
                const IgnorePointer(child: Center(child: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xee062d29), shape: BoxShape.circle),
                  child: Padding(padding: EdgeInsets.all(18), child: Icon(Icons.check_rounded,
                      color: Color(0xffd9ff6a), size: 56)),
                ))),
              if (_paused)
                ColoredBox(color: const Color(0xcc062d29), child: Center(
                    child: FilledButton(onPressed: _resume, child: const Text('Resume lesson')))),
            ])),
            Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 16), child: Column(
              mainAxisSize: MainAxisSize.min, children: [
                Semantics(liveRegion: true, child: Text(_passed ? 'Gesture learned!' : lesson.prompt,
                    textAlign: TextAlign.center, style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xffd9ff6a)))),
                const SizedBox(height: 8),
                SizedBox(height: 48, width: double.infinity, child: _passed
                    ? FilledButton(onPressed: _paused ? null : _next,
                        child: Text(_index == widget.lessons.length - 1 ? 'LET’S PLAY' : 'NEXT LESSON'))
                    : const Center(child: Text('Free practice · No chances used',
                        style: TextStyle(color: Colors.white54, fontSize: 12)))),
              ],
            )),
          ]),
        )),
      )),
    );
  }
}

/// Animated finger and drag trail share the pitch's aspect-fit coordinates.
class _HandDemo extends StatelessWidget {
  const _HandDemo({required this.lesson, required this.phase});
  final TutorialLesson lesson;
  final double phase;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, constraints) {
    final size = constraints.biggest;
    final scale = math.min(size.width / 400, size.height / 640);
    final origin = Offset((size.width - 400 * scale) / 2, (size.height - 640 * scale) / 2);
    final direction = lesson == TutorialLesson.curveLeft ? -1.0 : 1.0;
    final drag = switch (lesson) {
      TutorialLesson.curveLeft || TutorialLesson.curveRight => 65.0,
      TutorialLesson.banana => 105.0,
      _ => 0.0,
    };
    final movement = ((phase - .2) / .45).clamp(0.0, 1.0);
    final point = origin + Offset(200 + direction * drag * movement, 510) * scale;
    final opacity = phase > .82 ? ((1 - phase) / .18).clamp(0.0, 1.0).toDouble() : .85;
    return Stack(children: [
      if (lesson == TutorialLesson.knuckle)
        Positioned.fill(child: CustomPaint(painter: _TimingDemo(
            scale: scale, origin: origin,
            seconds: ((phase - .12) * 2.4).clamp(0.0, 1.64).toDouble()))),
      if (drag > 0)
        Positioned(left: origin.dx + (direction < 0 ? 200 - drag : 200) * scale,
          top: origin.dy + 518 * scale, width: drag * scale, height: 3,
          child: const ColoredBox(color: Color(0x887edfff))),
      Positioned(left: point.dx - 10 * scale, top: point.dy - 8 * scale,
        child: Opacity(opacity: opacity,
          child: Icon(Icons.touch_app_rounded, size: 44 * scale, color: Colors.white))),
    ]);
  });
}

class _TimingDemo extends CustomPainter {
  const _TimingDemo({required this.scale, required this.origin, required this.seconds});
  final double scale, seconds;
  final Offset origin;
  @override
  void paint(Canvas canvas, Size size) {
    final centre = origin + const Offset(200, 548) * scale;
    final radius = 32 * scale;
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 4 * scale;
    canvas.drawCircle(centre, radius, paint..color = const Color(0x667edfff));
    canvas.drawArc(Rect.fromCircle(center: centre, radius: radius),
        -math.pi / 2 + 2 * math.pi * KnuckleShot.sweetStart / KnuckleShot.ringDuration,
        2 * math.pi * (KnuckleShot.sweetEnd - KnuckleShot.sweetStart) / KnuckleShot.ringDuration,
        false, paint..color = const Color(0xff7edfff));
    final angle = -math.pi / 2 + 2 * math.pi * KnuckleShot.phaseAt(seconds) / KnuckleShot.ringDuration;
    canvas.drawCircle(centre + Offset(math.cos(angle), math.sin(angle)) * radius,
        5 * scale, paint..style = PaintingStyle.fill..color = Colors.white);
  }
  @override
  bool shouldRepaint(covariant _TimingDemo oldDelegate) =>
      seconds != oldDelegate.seconds || scale != oldDelegate.scale || origin != oldDelegate.origin;
}
