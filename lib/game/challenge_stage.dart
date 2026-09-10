import 'keeper_style.dart';
import 'keeper_skill.dart';

enum StageObjective { goals, corners, points }

enum DefencePattern { sweep, crossing, staggered }

// Append new stages after these six: saved stars are keyed by list position.
const championStageStart = 6;

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
    this.keeper = KeeperStyle.sweeper,
    this.keeperSkill = KeeperSkill.academy,
    this.fireChargeGoals = 2,
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
  final KeeperStyle keeper;
  final KeeperSkill keeperSkill;
  final int fireChargeGoals;
  final int pitchColor;
  final int stripeColor;

  String get unit => switch (objective) {
        StageObjective.goals => 'goals',
        StageObjective.corners => 'corner goals',
        StageObjective.points => 'points',
      };

  String get objectiveLabel => 'Score $target $unit';
  String get fireChargeUnit =>
      objective == StageObjective.corners ? 'corner goal' : 'goal';
  String get fireRule =>
      '$fireChargeGoals $fireChargeUnit${fireChargeGoals == 1 ? '' : 's'} '
      'without a miss ${fireChargeGoals == 1 ? 'charges' : 'charge'} a Fire Shot. '
      'Your next goal scores 2× points; a miss resets charge.';
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
    keeper: KeeperStyle.sentinel,
    fireChargeGoals: 1,
    keeperSkill: KeeperSkill.club,
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
    keeper: KeeperStyle.sentinel,
    timeLimit: 25,
    keeperSkill: KeeperSkill.club,
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
    keeper: KeeperStyle.gambler,
    keeperSkill: KeeperSkill.professional,
    defenders: 2,
    defenderSpeed: 1.15,
    pattern: DefencePattern.crossing,
    pitchColor: 0xff70414e,
    stripeColor: 0xff7b4a57,
  ),
  ChallengeStage(
    name: "Captain's Finish",
    skill: 'MAKE EVERY SHOT COUNT',
    brief: 'Earn eight points against The Gambler and two defenders. Corners are worth three; a Fire corner is worth six.',
    tip: 'Two goals charge a Fire Shot. Read the offset defenders and aim for a corner to finish strongly.',
    objective: StageObjective.points,
    target: 8,
    aimSpeed: 1.60,
    keeperSpeed: 1.40,
    keeperRange: 108,
    keeper: KeeperStyle.gambler,
    keeperSkill: KeeperSkill.professional,
    defenders: 2,
    defenderSpeed: 1.25,
    timeLimit: 30,
    pitchColor: 0xff23496a,
    stripeColor: 0xff2b5576,
  ),
  ChallengeStage(
    name: 'Pressure Cooker',
    skill: 'KEEP YOUR COOL',
    brief: 'Five goals, two crossing defenders and a faster Sweeper. Keep finding the open lane before time runs out.',
    tip: 'Watch both lanes as the arrow returns. Take the open goal when a corner would cost too much time.',
    objective: StageObjective.goals,
    target: 5,
    aimSpeed: 1.70,
    keeperSpeed: 1.50,
    keeperRange: 108,
    keeperSkill: KeeperSkill.elite,
    defenders: 2,
    defenderSpeed: 1.40,
    pattern: DefencePattern.crossing,
    timeLimit: 26,
    pitchColor: 0xff70402e,
    stripeColor: 0xff7c4b36,
  ),
  ChallengeStage(
    name: 'Needle Threader',
    skill: 'FIND THE SMALL OPENING',
    brief: 'Land three corner goals past The Sentinel and two defenders. Only the glowing corners advance the stage.',
    tip: 'Use the untimed round to read all three opponents. Two corner goals charge a Fire Shot for your next shot.',
    objective: StageObjective.corners,
    target: 3,
    aimSpeed: 1.80,
    keeperSpeed: 1.55,
    keeperRange: 108,
    keeper: KeeperStyle.sentinel,
    keeperSkill: KeeperSkill.elite,
    defenders: 2,
    defenderSpeed: 1.40,
    pitchColor: 0xff433a70,
    stripeColor: 0xff4f467e,
  ),
  ChallengeStage(
    name: 'Triple Wall',
    skill: 'READ THREE LANES',
    brief: 'A third defender joins the pitch. Score five goals through a repeating wave of three moving lanes.',
    tip: 'Start with the defender nearest the ball, then check the two behind. The wave repeats; there is no timer to rush you.',
    objective: StageObjective.goals,
    target: 5,
    aimSpeed: 1.85,
    keeperSpeed: 1.60,
    keeperRange: 108,
    keeper: KeeperStyle.gambler,
    keeperSkill: KeeperSkill.elite,
    defenders: 3,
    defenderSpeed: 1.40,
    pattern: DefencePattern.staggered,
    pitchColor: 0xff245c62,
    stripeColor: 0xff2b6870,
  ),
  ChallengeStage(
    name: 'Sudden Rush',
    skill: 'TURN CHARGE INTO POINTS',
    brief: 'Earn twelve points in twenty-two active seconds. Two quick crossing defenders leave little time to hesitate.',
    tip: 'A Fire corner earns six points. Build charge with open goals, then look for the corner when the boost is ready.',
    objective: StageObjective.points,
    target: 12,
    aimSpeed: 1.95,
    keeperSpeed: 1.65,
    keeperRange: 110,
    keeperSkill: KeeperSkill.worldClass,
    defenders: 2,
    defenderSpeed: 1.60,
    pattern: DefencePattern.crossing,
    timeLimit: 22,
    pitchColor: 0xff754c22,
    stripeColor: 0xff81592b,
  ),
  ChallengeStage(
    name: 'Corner Siege',
    skill: 'STAY PRECISE UNDER PRESSURE',
    brief: 'Four corner goals through the triple wall. The Sentinel and the clock now test your precision together.',
    tip: 'The three-lane wave returns. Read the nearest defender first and choose a corner during the keeper\'s opposite-side hold.',
    objective: StageObjective.corners,
    target: 4,
    aimSpeed: 2.00,
    keeperSpeed: 1.75,
    keeperRange: 110,
    keeper: KeeperStyle.sentinel,
    keeperSkill: KeeperSkill.worldClass,
    defenders: 3,
    defenderSpeed: 1.50,
    pattern: DefencePattern.staggered,
    timeLimit: 32,
    pitchColor: 0xff613653,
    stripeColor: 0xff704061,
  ),
  ChallengeStage(
    name: "Champion's Gate",
    skill: 'MASTER THE WHOLE PITCH',
    brief: 'Earn eighteen points against the fastest Gambler and three defenders moving at different speeds. This is the final test.',
    tip: 'Keep your charge alive and spend Fire Shots on corners. Five consecutive corner goals earn eighteen points; open centre goals can keep you in the run.',
    objective: StageObjective.points,
    target: 18,
    aimSpeed: 2.10,
    keeperSpeed: 1.85,
    keeperRange: 110,
    keeper: KeeperStyle.gambler,
    keeperSkill: KeeperSkill.worldClass,
    defenders: 3,
    defenderSpeed: 1.65,
    timeLimit: 28,
    pitchColor: 0xff26335d,
    stripeColor: 0xff303f6d,
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
