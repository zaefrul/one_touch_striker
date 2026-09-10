import '../game/bonus.dart';
import '../game/stage.dart';

class SubstageRef {
  const SubstageRef(this.venue, this.sub);
  final int venue;
  final int sub;

  StageSpec get stage => StageSpec.all[venue];
  int get intensity => sub + 1;
  int get venueNumber => venue + 1;
  int get subNumber => sub + 1;
  String get code => '$venueNumber-$subNumber';
  String get title => '${stage.title}  $code';

  SubstageRef? get next {
    if (sub < Campaign.substagesPerVenue - 1) {
      return SubstageRef(venue, sub + 1);
    }
    if (venue < Campaign.venues - 1) {
      return SubstageRef(venue + 1, 0);
    }
    return null;
  }

  List<int> get thresholds => Campaign.thresholds(venue, sub);
}

class Campaign {
  static const venues = 6;
  static const substagesPerVenue = 10;
  static const shotsMax = 5;
  static const maxStars = venues * substagesPerVenue * 3;

  static SubstageRef ref(int venue, int sub) => SubstageRef(venue, sub);

  static StageSpec venue(int index) => StageSpec.all[index];

  static List<int> thresholds(int venue, int sub) {
    final one = 3 + sub ~/ 3 + venue;
    final two = (6 + sub ~/ 2 + venue).clamp(one + 2, 14);
    final three = (9 + sub + venue).clamp(two + 2, 18);
    return [one, two, three];
  }

  static bool bonusUnlockedAt(BallBonus bonus, int Function(int, int) stars) {
    return switch (bonus) {
      BallBonus.straight => true,
      BallBonus.curve => stars(0, 2) >= 1,
      BallBonus.superShoot => stars(0, 5) >= 1,
    };
  }
}
