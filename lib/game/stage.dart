import 'dart:math' as math;
import 'dart:ui';

enum StageId { pitch, village, stadium, national, world, orbit }

enum ObstacleKind {
  goat,
  cart,
  mascot,
  camera,
  steward,
  flag,
  press,
  banner,
  asteroid,
  satellite,
}

class ObstacleSpec {
  const ObstacleSpec({
    required this.kind,
    required this.blockText,
    required this.halfW,
    required this.halfH,
    required this.yBase,
    this.xAmp = 120,
    this.xSpeed = 1,
    this.xPhase = 0,
    this.yAmp = 0,
    this.ySpeed = 0,
  });

  final ObstacleKind kind;
  final String blockText;
  final double halfW;
  final double halfH;
  final double xAmp;
  final double xSpeed;
  final double xPhase;
  final double yBase;
  final double yAmp;
  final double ySpeed;

  double x(double clock, {double ampScale = 1, double speedScale = 1}) =>
      200 + xAmp * ampScale * math.sin(clock * xSpeed * speedScale + xPhase);
  double y(double clock, {double ampScale = 1, double speedScale = 1}) =>
      yBase + yAmp * ampScale * math.sin(clock * ySpeed * speedScale);
}

class StageSpec {
  const StageSpec({
    required this.id,
    required this.title,
    required this.banner,
    required this.tagline,
    required this.grass,
    required this.stripe,
    required this.line,
    required this.backdrop,
    required this.net,
    required this.obstacles,
  });

  final StageId id;
  final String title;
  final String banner;
  final String tagline;
  final Color grass;
  final Color stripe;
  final Color line;
  final Color backdrop;
  final Color net;
  final List<ObstacleSpec> obstacles;

  int get number => id.index + 1;

  static StageSpec forGoals(int goals) =>
      all[(goals ~/ 3).clamp(0, all.length - 1)];

  static const all = [
    StageSpec(
      id: StageId.pitch,
      title: 'LOCAL PARK',
      banner: 'LOCAL PARK',
      tagline: 'ONE TOUCH. MAKE IT COUNT.',
      grass: Color(0xff126a50),
      stripe: Color(0xff167456),
      line: Color(0x668bddad),
      backdrop: Color(0xff073c34),
      net: Color(0xff32635a),
      obstacles: [],
    ),
    StageSpec(
      id: StageId.village,
      title: 'VILLAGE SAND',
      banner: 'VILLAGE SAND',
      tagline: 'DUST AND GLORY.',
      grass: Color(0xffc4a15a),
      stripe: Color(0xffb8914a),
      line: Color(0x998a6a38),
      backdrop: Color(0xff5c3d24),
      net: Color(0xff8a7048),
      obstacles: [
        ObstacleSpec(
          kind: ObstacleKind.goat,
          blockText: 'GOAT!',
          halfW: 16,
          halfH: 10,
          yBase: 455,
          xAmp: 130,
          xSpeed: .85,
        ),
        ObstacleSpec(
          kind: ObstacleKind.cart,
          blockText: 'CART!',
          halfW: 18,
          halfH: 11,
          yBase: 330,
          xAmp: 100,
          xSpeed: 1.05,
          xPhase: 1.6,
        ),
      ],
    ),
    StageSpec(
      id: StageId.stadium,
      title: 'THE STADIUM',
      banner: 'THE STADIUM',
      tagline: 'THE CROWD IS IN.',
      grass: Color(0xff0d5c3a),
      stripe: Color(0xff107048),
      line: Color(0x99d4e8c8),
      backdrop: Color(0xff1a1a22),
      net: Color(0xff3d5c52),
      obstacles: [
        ObstacleSpec(
          kind: ObstacleKind.mascot,
          blockText: 'MASCOT!',
          halfW: 15,
          halfH: 15,
          yBase: 340,
          xAmp: 105,
          xSpeed: 1.15,
          yAmp: 16,
          ySpeed: 3.1,
        ),
        ObstacleSpec(
          kind: ObstacleKind.camera,
          blockText: 'CAMERA!',
          halfW: 20,
          halfH: 8,
          yBase: 205,
          xAmp: 140,
          xSpeed: .7,
        ),
      ],
    ),
    StageSpec(
      id: StageId.national,
      title: 'NATIONAL',
      banner: 'NATIONAL STADIUM',
      tagline: 'FOR THE BADGE.',
      grass: Color(0xff0a6b42),
      stripe: Color(0xff0c7a4c),
      line: Color(0xaad4b45a),
      backdrop: Color(0xff12161c),
      net: Color(0xff3a5848),
      obstacles: [
        ObstacleSpec(
          kind: ObstacleKind.steward,
          blockText: 'STEWARD!',
          halfW: 13,
          halfH: 15,
          yBase: 455,
          xAmp: 110,
          xSpeed: 1.2,
          xPhase: .4,
        ),
        ObstacleSpec(
          kind: ObstacleKind.flag,
          blockText: 'FLAG!',
          halfW: 20,
          halfH: 7,
          yBase: 205,
          xAmp: 148,
          xSpeed: .62,
        ),
      ],
    ),
    StageSpec(
      id: StageId.world,
      title: 'WORLD CUP',
      banner: 'WORLD STADIUM',
      tagline: 'ONE PLANET. ONE TAP.',
      grass: Color(0xff084a38),
      stripe: Color(0xff0a5844),
      line: Color(0xbbf0e6c8),
      backdrop: Color(0xff070b14),
      net: Color(0xff2a4a40),
      obstacles: [
        ObstacleSpec(
          kind: ObstacleKind.press,
          blockText: 'FLASH!',
          halfW: 12,
          halfH: 12,
          yBase: 198,
          xAmp: 78,
          xSpeed: 1.75,
        ),
        ObstacleSpec(
          kind: ObstacleKind.banner,
          blockText: 'BANNER!',
          halfW: 28,
          halfH: 8,
          yBase: 468,
          xAmp: 155,
          xSpeed: .52,
        ),
      ],
    ),
    StageSpec(
      id: StageId.orbit,
      title: 'ORBIT',
      banner: 'OUTER SPACE',
      tagline: 'NO AIR. STILL A GOAL.',
      grass: Color(0xff1a2240),
      stripe: Color(0xff222c52),
      line: Color(0x99d9ff6a),
      backdrop: Color(0xff05060c),
      net: Color(0xff3a4060),
      obstacles: [
        ObstacleSpec(
          kind: ObstacleKind.asteroid,
          blockText: 'ASTEROID!',
          halfW: 14,
          halfH: 14,
          yBase: 330,
          xAmp: 150,
          xSpeed: .9,
        ),
        ObstacleSpec(
          kind: ObstacleKind.asteroid,
          blockText: 'ASTEROID!',
          halfW: 11,
          halfH: 11,
          yBase: 230,
          xAmp: 118,
          xSpeed: 1.28,
          xPhase: 2.1,
        ),
        ObstacleSpec(
          kind: ObstacleKind.satellite,
          blockText: 'SATELLITE!',
          halfW: 18,
          halfH: 8,
          yBase: 468,
          xAmp: 140,
          xSpeed: .75,
          xPhase: 1.1,
        ),
      ],
    ),
  ];
}
