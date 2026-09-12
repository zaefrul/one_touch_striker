import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import '../game/match_model.dart';

/// One captured pointer owns a shot from press to release. These callbacks
/// update simulation state without rebuilding Flutter during pointer movement.
class ShotGestureSurface extends StatefulWidget {
  const ShotGestureSurface({super.key, required this.enabled,
      required this.onBegin, required this.onDrag, required this.onRelease,
      required this.onCancel, required this.onAccessibleShot, required this.child});

  final bool enabled;
  final bool Function() onBegin;
  final void Function(double dragX, double dragY) onDrag;
  final VoidCallback onRelease, onCancel, onAccessibleShot;
  final Widget child;

  @override
  State<ShotGestureSurface> createState() => _ShotGestureSurfaceState();
}

class _ShotGestureSurfaceState extends State<ShotGestureSurface> {
  int? _pointer;
  Offset _origin = Offset.zero;
  double _scale = 1;
  Rect _pitchBounds = Rect.zero;
  Size? _viewport;

  void _cancel() {
    if (_pointer == null) return;
    _pointer = null;
    widget.onCancel();
  }

  @override
  void didUpdateWidget(covariant ShotGestureSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    // onCancel only clears the draft in the simulation; it must not setState.
    if (!widget.enabled) _cancel();
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  void _down(PointerDownEvent event, Size viewport) {
    if (!widget.enabled || _pointer != null ||
        event.buttons != kPrimaryButton) return;
    final scale = math.min(viewport.width / MatchModel.width,
        viewport.height / MatchModel.height);
    if (!scale.isFinite || scale <= 0) return;
    final bounds = Rect.fromLTWH(
        (viewport.width - MatchModel.width * scale) / 2,
        (viewport.height - MatchModel.height * scale) / 2,
        MatchModel.width * scale, MatchModel.height * scale);
    if (!bounds.contains(event.localPosition) || !widget.onBegin()) return;
    _pointer = event.pointer;
    _origin = event.localPosition;
    _scale = scale;
    _pitchBounds = bounds;
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    if (!widget.enabled || !_pitchBounds.contains(event.localPosition)) {
      _cancel();
      return;
    }
    final delta = (event.localPosition - _origin) / _scale;
    widget.onDrag(delta.dx, delta.dy);
  }

  void _up(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    if (!widget.enabled || !_pitchBounds.contains(event.localPosition)) {
      _cancel();
      return;
    }
    // Include the final position even if the platform omitted a last move.
    final delta = (event.localPosition - _origin) / _scale;
    widget.onDrag(delta.dx, delta.dy);
    _pointer = null;
    widget.onRelease();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    final viewport = constraints.biggest;
    // Resizing or rotating must not reinterpret an in-progress drag.
    if (_viewport != null && _viewport != viewport) _cancel();
    _viewport = viewport;
    return ExcludeSemantics(
      excluding: !widget.enabled,
      child: Semantics(
        label: 'Football pitch. Touch to lock the arrow, drag sideways to bend, '
            'then release to shoot. Hold still and release in the blue timing zone for a knuckle. '
            'Activate for a straight shot in the arrow direction.',
        button: true,
        onTap: widget.enabled ? widget.onAccessibleShot : null,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) => _down(event, viewport),
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: (event) {
            if (event.pointer == _pointer) _cancel();
          },
          child: widget.child,
        ),
      ),
    );
  });
}
