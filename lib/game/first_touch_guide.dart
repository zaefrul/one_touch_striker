/// Coaching changes the instructions, never the shot or keeper simulation.
enum FirstTouchLesson {
  aim('FOLLOW THE ARROW',
      'Touch locks the arrow. Release to shoot; drag sideways first to bend the ball.'),
  space('FIND THE OPEN SPACE',
      'Watch the keeper, then the target dot. Two goals without a miss charge a Fire Shot.'),
  fire('YOUR FIRE SHOT IS READY',
      'This shot scores double if it goes in. Find an open lane, then release your shot.');

  const FirstTouchLesson(this.title, this.instruction);
  final String title;
  final String instruction;
}
