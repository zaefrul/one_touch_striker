/// Arcade sidespin, shared by the aim preview and the physical ball path.
/// Distances use the game's logical pitch units, independent of screen size.
abstract final class ShotCurve {
  static const deadZone = 14.0;
  static const fullDrag = 100.0;
  static const maxBend = 110.0;

  static double spinForDrag(double dragX) {
    if (!dragX.isFinite || dragX.abs() <= deadZone) return 0;
    final amount = ((dragX.abs() - deadZone) / (fullDrag - deadZone))
        .clamp(0.0, 1.0).toDouble();
    return dragX.sign * amount;
  }

  static double targetFor(double initialTargetX, double spin) =>
      initialTargetX + maxBend * spin;

  /// The initial direction is targetX - maxBend * spin. Curvature grows with
  /// progress squared, reaching targetX exactly at the goal line. Targets are
  /// deliberately not clamped into the goal: too much spin can go wide.
  static double xAt(double startX, double targetX, double spin, double progress) {
    final p = progress.clamp(0.0, 1.0).toDouble();
    return startX + (targetX - startX) * p - maxBend * spin * p * (1 - p);
  }

  static const releaseLabels = ['STRAIGHT · RELEASE', 'CURVE LEFT · RELEASE',
      'CURVE RIGHT · RELEASE', 'BANANA LEFT · RELEASE', 'BANANA RIGHT · RELEASE'];

  static String releaseLabel(double spin) => spin == 0 ? releaseLabels[0]
      : spin.abs() < .75 ? releaseLabels[spin < 0 ? 1 : 2]
          : releaseLabels[spin < 0 ? 3 : 4];
}
