/// Set by the simulation at contact or the goal line, rather than inferred
/// from translated result text. Advice remains available during the next aim.
enum ShotFailure {
  wide('The target was outside the posts. Aim further inside or use less bend.'),
  post('The target was too close to the post. Leave a little space inside it.'),
  keeper('The keeper reached that lane. Look for space away from his gloves.'),
  defender('A defender blocked that path. Wait for an opening or bend around him.');

  const ShotFailure(this.advice);
  final String advice;
}
