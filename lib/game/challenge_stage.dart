enum StageObjective { goals, corners, points }

enum DefencePattern { sweep, crossing }

/// Each stage introduces a different skill. Balance values live here so they
/// can be tuned after device playtests without changing the match rules.
class ChallengeStage {
  const ChallengeStage({
    required this.name,
    required this.skill,
    required this.brief,
    required this.tip,
    required this.objective,
    required this.target,
    required this.aimSpeed,
    required this.keeperSpeed,
    required this.keeperRange,
    required this.pitchColor,
    required this.stripeColor,
    this.defenders = 0,
    this.defenderSpeed = 1.05,
    this.pattern = DefencePattern.sweep,
    this.timeLimit,
    this.keeperTempo = 0,
  });

  final String name;
  final String skill;
  final String brief;
  final String tip;
  final StageObjective objective;
  final int target;
  final double aimSpeed;
  final double keeperSpeed;
  final double keeperRange;
  final int defenders;
  final double defenderSpeed;
  final DefencePattern pattern;
  final int? timeLimit;
  final double keeperTempo;
  final int pitchColor;
  final int stripeColor;

  String get unit => switch (objective) {
        StageObjective.goals => 'goals',
        StageObjective.corners => 'corner goals',
        StageObjective.points => 'points',
      };

  String get objectiveLabel => 'Score $target $unit';
  String get rulesLabel => timeLimit == null
      ? '3 chances · No timer'
      : '3 chances · $timeLimit active seconds';
}

const challengeStages = [
  ChallengeStage(
    name: 'First Touch',
    skill: 'FIND YOUR RHYTHM',
    brief: 'Read the arrow and find the open net. Three goals get you started.',
    tip: 'Tap when the arrow points away from the keeper. Touch position does not steer the ball.',
    objective: StageObjective.goals,
    target: 3,
    aimSpeed: 1.10,
    keeperSpeed: .75,
    keeperRange: 75,
    pitchColor: 0xff126a50,
    stripeColor: 0xff167456,
  ),
  ChallengeStage(
    name: 'Moving Wall',
    skill: 'READ THE GAP',
    brief: 'A defender patrols the pitch. Wait for a clear shooting lane.',
    tip: 'Watch where the defender is moving, then send the ball through the gap.',
    objective: StageObjective.goals,
    target: 3,
    aimSpeed: 1.25,
    keeperSpeed: .90,
    keeperRange: 90,
    defenders: 1,
    defenderSpeed: 1.10,
    pitchColor: 0xff145d70,
    stripeColor: 0xff196b7a,
  ),
  ChallengeStage(
    name: 'Corner Artist',
    skill: 'PICK YOUR SPOT',
    brief: 'Only goals into the two glowing corners advance this stage.',
    tip: 'Wait until the aiming dot enters a glowing corner. Centre goals earn points but do not fill the objective.',
    objective: StageObjective.corners,
    target: 2,
    aimSpeed: 1.40,
    keeperSpeed: 1.10,
    keeperRange: 100,
    pitchColor: 0xff4d456e,
    stripeColor: 0xff584f7b,
  ),
  ChallengeStage(
    name: 'Beat the Clock',
    skill: 'KEEP THE TEMPO',
    brief: 'Score four goals before the clock runs out. Decide quickly, shoot cleanly.',
    tip: 'Keep your rhythm. A shot released before zero still gets to finish.',
    objective: StageObjective.goals,
    target: 4,
    aimSpeed: 1.50,
    keeperSpeed: 1.25,
    keeperRange: 105,
    timeLimit: 25,
    pitchColor: 0xff73552d,
    stripeColor: 0xff806136,
  ),
  ChallengeStage(
    name: 'Double Trouble',
    skill: 'SPLIT THE DEFENCE',
    brief: 'Two defenders cross in opposite directions. Find a route past both.',
    tip: 'Look at both defenders before you tap. Their crossing pattern repeats, so you can learn the opening.',
    objective: StageObjective.goals,
    target: 4,
    aimSpeed: 1.50,
    keeperSpeed: 1.30,
    keeperRange: 105,
    defenders: 2,
    defenderSpeed: 1.15,
    pattern: DefencePattern.crossing,
    pitchColor: 0xff70414e,
    stripeColor: 0xff7b4a57,
  ),
  ChallengeStage(
    name: "Captain's Finish",
    skill: 'MAKE EVERY SHOT COUNT',
    brief: 'Earn eight points against two defenders and a keeper who changes pace. Corners are worth three.',
    tip: 'A few corner goals can beat the clock. Watch the keeper slow down and speed up before you commit.',
    objective: StageObjective.points,
    target: 8,
    aimSpeed: 1.60,
    keeperSpeed: 1.40,
    keeperRange: 108,
    keeperTempo: .35,
    defenders: 2,
    defenderSpeed: 1.25,
    timeLimit: 30,
    pitchColor: 0xff23496a,
    stripeColor: 0xff2b5576,
  ),
];

/// Save only personal-best medals. Unlocks follow completed stages, so malformed
/// or old storage cannot unlock a stage without its preceding clear.
class ChallengeProgress {
  static const storageKey = 'challenge_stars_v1';
  final List<int> _stars = List.filled(challengeStages.length, 0);

  int starsFor(int index) => _stars[index];
  int get totalStars => _stars.fold(0, (total, stars) => total + stars);
  bool get completed => _stars.every((stars) => stars > 0);

  int get unlockedCount {
    final firstUncleared = _stars.indexOf(0);
    return firstUncleared < 0 ? _stars.length : firstUncleared + 1;
  }

  int get nextStageIndex => unlockedCount - 1;
  bool isUnlocked(int index) => index >= 0 && index < unlockedCount;

  bool recordClear(int index, int stars) {
    if (!isUnlocked(index) || stars < 1 || stars > 3 || stars <= _stars[index]) {
      return false;
    }
    _stars[index] = stars;
    return true;
  }

  void mergeSaved(List<String>? saved) {
    if (saved == null) {
      return;
    }
    for (var i = 0; i < _stars.length && i < saved.length; i++) {
      final stars = int.tryParse(saved[i]);
      if (stars == null || stars < 1 || stars > 3) {
        break;
      }
      recordClear(i, stars);
    }
  }

  List<String> encode() => _stars.map((stars) => '$stars').toList();
}
