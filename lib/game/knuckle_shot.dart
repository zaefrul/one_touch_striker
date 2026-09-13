import 'dart:math' as math;

enum StrikeTiming { tap, early, clean, late, adjusted }

/// Initial arcade tuning. Timing uses active simulation time, before cinematic
/// slow motion. The window repeats each revolution; only release can launch a shot.
abstract final class KnuckleShot {
  static const tapLimit = .20;
  static const sweetStart = .55;
  static const sweetEnd = .73;
  static const ringDuration = 1.0;
  static const maxWobble = 14.0;

  static double phaseAt(double seconds) => seconds % ringDuration;

  static StrikeTiming timingAt(double seconds) {
    // A quick tap only exists at the start of a hold, not after every wrap.
    if (seconds < tapLimit) return StrikeTiming.tap;
    final phase = phaseAt(seconds);
    return phase < sweetStart ? StrikeTiming.early
        : phase <= sweetEnd ? StrikeTiming.clean : StrikeTiming.late;
  }

  static const releaseLabels = ['RELEASE', 'WAIT FOR ZONE',
      'KNUCKLE · RELEASE', 'WAIT FOR NEXT ZONE'];

  static String releaseLabel(double seconds) => switch (timingAt(seconds)) {
    StrikeTiming.tap => releaseLabels[0],
    StrikeTiming.early => releaseLabels[1],
    StrikeTiming.clean => releaseLabels[2],
    _ => releaseLabels[3],
  };

  /// A bounded, repeatable late wobble. It starts and ends on the intended
  /// straight line, so it cannot rescue an off-target aim or guarantee a goal.
  static double offsetAt(double progress) {
    if (progress <= .45 || progress >= 1) return 0;
    final u = (progress - .45) / .55;
    return maxWobble * math.sin(2 * math.pi * u) * math.sin(math.pi * u);
  }
}
