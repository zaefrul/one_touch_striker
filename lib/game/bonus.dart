enum BallBonus { straight, curve, superShoot }

extension BallBonusLabel on BallBonus {
  String get title => switch (this) {
        BallBonus.straight => 'STRAIGHT',
        BallBonus.curve => 'CURVE',
        BallBonus.superShoot => 'SUPER SHOOT',
      };

  String get label => title;

  String get blurb => switch (this) {
        BallBonus.straight => 'The ball flies true to the lock.',
        BallBonus.curve => 'Bends mid-flight, still lands on the lock.',
        BallBonus.superShoot => 'Faster strike. Movers have less time.',
      };

  String get unlockHint => switch (this) {
        BallBonus.straight => 'Always ready.',
        BallBonus.curve => 'Unlock at 1-3 with 1 star.',
        BallBonus.superShoot => 'Unlock at 1-6 with 1 star.',
      };
}

int starsFor(int score, List<int> thresholds) {
  if (thresholds.length < 3) {
    return 0;
  }
  if (score >= thresholds[2]) {
    return 3;
  }
  if (score >= thresholds[1]) {
    return 2;
  }
  if (score >= thresholds[0]) {
    return 1;
  }
  return 0;
}
