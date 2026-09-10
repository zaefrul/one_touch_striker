import 'dart:math' as math;

enum KeeperPart { kit, shorts, glove, boot, skin }

/// A capsule is both a drawn body part and a collision shape. Endpoints are
/// keeper-local; a circle is a capsule whose endpoints coincide.
class KeeperSegment {
  KeeperSegment(this.part, this.radius);
  final KeeperPart part;
  final double radius;
  double ax = 0, ay = 0, bx = 0, by = 0;

  void set(double x1, double y1, double x2, double y2) {
    ax = x1; ay = y1; bx = x2; by = y2;
  }

  bool touches(double x, double y, double ballRadius) {
    final dx = bx - ax, dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;
    final t = lengthSquared == 0 ? 0.0 :
        (((x - ax) * dx + (y - ay) * dy) / lengthSquared).clamp(0.0, 1.0).toDouble();
    final nearX = ax + t * dx, nearY = ay + t * dy;
    final reach = radius + ballRadius;
    return (x - nearX) * (x - nearX) + (y - nearY) * (y - nearY) <= reach * reach;
  }
}

/// Reused joints; no per-substep list, Paint or Path allocation. Rendering
/// applies precisely this translation/rotation before drawing the segments.
class KeeperPose {
  double x = 200, y = 126, rotation = 0;
  double headY = -19;
  final List<KeeperSegment> segments = [
    KeeperSegment(KeeperPart.shorts, 4.5),
    KeeperSegment(KeeperPart.kit, 3.5),
    KeeperSegment(KeeperPart.boot, 4),
    KeeperSegment(KeeperPart.shorts, 4.5),
    KeeperSegment(KeeperPart.kit, 3.5),
    KeeperSegment(KeeperPart.boot, 4),
    KeeperSegment(KeeperPart.kit, 4),
    KeeperSegment(KeeperPart.kit, 4),
    KeeperSegment(KeeperPart.glove, 5),
    KeeperSegment(KeeperPart.kit, 4),
    KeeperSegment(KeeperPart.kit, 4),
    KeeperSegment(KeeperPart.glove, 5),
    KeeperSegment(KeeperPart.kit, 10),
    KeeperSegment(KeeperPart.skin, 8),
  ];

  void update({double dive = 0, double slide = 0, double taunt = 0,
      double crouch = 0, double stride = 0, double wave = 0}) {
    final shoulderY = -5.0 + crouch * 3 + slide * 4;
    headY = -19.0 + crouch * 3 + slide * 5;
    for (var side = 0; side < 2; side++) {
      final sign = side == 0 ? -1.0 : 1.0;
      final leg = side * 3;
      final kneeX = sign * (8 + slide * 9);
      final footX = sign * (10 + slide * (side == 0 ? 6 : 16));
      // One boot leads toward the ball in a slide; the other knee stays bent.
      final footY = 23.0 + sign * stride + dive * 4 + slide * (side == 0 ? 12 : 4);
      segments[leg].set(sign * 5, 9, kneeX, 16);
      segments[leg + 1].set(kneeX, 16, footX, footY);
      segments[leg + 2].set(footX - 2, footY, footX + 2, footY);

      final arm = 6 + side * 3;
      final elbowX = sign * (17 - dive * 5 + slide * 3);
      final elbowY = -1.0 - dive * 21 - taunt * 12 + slide * 8;
      final gloveX = sign * (25 - dive * 18 + slide * 2 + taunt * wave * 3);
      final gloveY = 3.0 - dive * 41 - taunt * (27 + sign * wave * 3) + slide * 10;
      segments[arm].set(sign * 8, shoulderY, elbowX, elbowY);
      segments[arm + 1].set(elbowX, elbowY, gloveX, gloveY);
      segments[arm + 2].set(gloveX, gloveY, gloveX, gloveY);
    }
    segments[12].set(0, -6.0 + crouch * 3, 0, 7);
    segments[13].set(0, headY, 0, headY);
  }

  bool hitsBall(double ballX, double ballY, double ballRadius) {
    final dx = ballX - x, dy = ballY - y;
    final cosine = math.cos(rotation), sine = math.sin(rotation);
    final localX = dx * cosine + dy * sine;
    final localY = -dx * sine + dy * cosine;
    for (final part in segments) {
      if (part.touches(localX, localY, ballRadius)) return true;
    }
    return false;
  }
}
