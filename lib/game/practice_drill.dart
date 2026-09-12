enum PracticeDrill {
  corners('corner_practice', 'Corner Practice',
      'Hit the marked corner. The target alternates left and right after each ball.'),
  curveWall('curve_wall', 'Bend Around the Wall',
      'Use a curve to beat the moving defender and hit the marked target.'),
  knuckle('knuckle_timing', 'Knuckle Timing',
      'Hold still. Release in the blue zone. A clean knuckle plus a goal earns a hit.');

  const PracticeDrill(this.id, this.title, this.rule);
  final String id, title, rule;
  static const balls = 5;
  static const targetHalfWidth = 18.0;

  bool get hasTarget => this != knuckle;
  double targetX(int ballIndex) => ballIndex.isEven ? 91 : 309;
  bool targetContains(double x, int ballIndex) =>
      !hasTarget || (x - targetX(ballIndex)).abs() <= targetHalfWidth;
}

class PracticeShot {
  const PracticeShot({required this.explanation, required this.note, required this.hit});
  final String explanation, note;
  final bool hit;
}
