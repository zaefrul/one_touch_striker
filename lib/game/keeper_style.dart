import 'dart:math' as math;

/// Repeating patrol preferences. Challenge keepers add delayed reactions to the
/// visible flight in KeeperController; Classic uses these offsets directly.
enum KeeperStyle {
  sweeper(
    'The Sweeper',
    'Sweeps from side to side. Aim into the space he leaves.',
    0xffffc857,
  ),
  sentinel(
    'The Sentinel',
    'Pauses at each side, then crosses. Read the pause before you shoot.',
    0xff8ddfff,
  ),
  gambler(
    'The Gambler',
    'Guards the right for longer. Watch his brief trip to the left.',
    0xffffa3d5,
  );

  const KeeperStyle(this.title, this.hint, this.kitColor);
  final String title;
  final String hint;
  final int kitColor;

  /// Offset in [-1, 1], with continuous position and velocity at cycle seams.
  double offset(double angle) {
    switch (this) {
      case KeeperStyle.sweeper:
        return math.sin(angle);
      case KeeperStyle.sentinel:
        final cycle = (angle % (2 * math.pi)) / (2 * math.pi);
        if (cycle < .125) return 1;
        if (cycle < .5) return 1 - 2 * _ease((cycle - .125) / .375);
        if (cycle < .625) return -1;
        return -1 + 2 * _ease((cycle - .625) / .375);
      case KeeperStyle.gambler:
        final visit = (1 - math.cos(angle)) / 2;
        return 1 - 2 * visit * visit * visit;
    }
  }

  static double _ease(double t) => t * t * (3 - 2 * t);
}
