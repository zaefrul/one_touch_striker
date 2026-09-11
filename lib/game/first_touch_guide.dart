/// Coaching changes the instructions, never the shot or keeper simulation.
enum FirstTouchLesson {
  aim('FOLLOW THE ARROW',
      'Tap anywhere on the pitch to lock the arrow. Its dot shows where the ball will go.'),
  space('FIND THE OPEN SPACE',
      'Watch the keeper, then the target dot. Two goals without a miss charge a Fire Shot.'),
  fire('YOUR FIRE SHOT IS READY',
      'This shot scores double if it goes in. Look for an open lane and time your tap.');

  const FirstTouchLesson(this.title, this.instruction);
  final String title;
  final String instruction;
}
