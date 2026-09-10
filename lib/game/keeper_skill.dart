/// Challenge-only progression. Values are initial tuning for device playtests.
/// Distances are logical pitch units; delays use the ball's simulation clock.
enum KeeperSkill {
  academy('Academy', 'Footwork',
      'Learns the basics: watch the side-to-side footwork and find the gap.',
      reactionDelay: .30, diveReach: 0, shuffleSpeed: 150),
  club('Club', 'Diving saves',
      'Sets his feet, then dives after the ball leaves your foot. Shoot into the space he cannot reach.',
      reactionDelay: .28, diveReach: 28, shuffleSpeed: 210),
  professional('Professional', 'Dives · slides · taunts',
      'Every third shot brings a signalled rush and slide. Wide shots can beat the rush; a save earns a taunt.',
      reactionDelay: .24, diveReach: 36, shuffleSpeed: 240, rushDistance: 24),
  elite('Elite', 'Marks your last side',
      'Also shades the side of your last shot. Change corners and watch for the RUSH INCOMING cue.',
      reactionDelay: .20, diveReach: 44, shuffleSpeed: 270,
      rushDistance: 32, markingReach: 16),
  worldClass('World Class', 'Fast reactions · full reach',
      'Reacts sooner, covers your last side and commits further. His reach is still limited; use the opposite opening.',
      reactionDelay: .17, diveReach: 52, shuffleSpeed: 300,
      rushDistance: 40, markingReach: 24);

  const KeeperSkill(this.title, this.abilities, this.hint, {
    required this.reactionDelay,
    required this.diveReach,
    required this.shuffleSpeed,
    this.rushDistance = 0,
    this.markingReach = 0,
  });

  final String title;
  final String abilities;
  final String hint;
  final double reactionDelay;
  final double diveReach;
  final double shuffleSpeed;
  final double rushDistance;
  final double markingReach;
  bool get canDive => diveReach > 0;
  bool get canSlide => rushDistance > 0;
  bool get canTaunt => canSlide;
}
