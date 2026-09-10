/// Stable IDs are stored as trophies; changing stage names does not lose them.
enum Showdown {
  cornerDuel('Corner Duel', 'Score in both corners.',
      'Score once in each glowing corner. Repeating a side earns points but does not advance the duel.'),
  fireFinish('Fire Finish', 'Finish with a Fire goal.',
      'Reach the points target with a Fire goal as your finishing shot. A Fire corner scores six points.'),
  rushHour('Rush Hour', 'Beat the rush at least once.',
      'Reach the goal target and score at least once against a rushing keeper. Watch for RUSH INCOMING before every third shot.'),
  championFinal('Champion Final', 'Finish with a Fire corner.',
      'Reach the points target with a Fire corner as your finishing shot. Ordinary goals can build your charge.');

  const Showdown(this.title, this.shortRule, this.rule);
  final String title;
  final String shortRule;
  final String rule;
}
