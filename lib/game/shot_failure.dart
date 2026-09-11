/// Set by the simulation at contact or the goal line, rather than inferred
/// from translated result text. Advice remains available during the next aim.
enum ShotFailure {
  wide('The target dot was outside the posts. Tap when it is inside the goal.'),
  post('The target was too close to the post. Leave a little space inside it.'),
  keeper('The keeper reached that lane. Look for space away from his gloves.'),
  defender('A defender blocked that lane. Watch for an opening before tapping.');

  const ShotFailure(this.advice);
  final String advice;
}
