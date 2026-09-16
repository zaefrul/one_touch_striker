import 'package:flutter/material.dart';
import '../game/match_model.dart';
import 'theme.dart';
import 'widgets.dart';

/// Live coaching for the guided first match. It sits over the bottom strip of
/// the pitch, below the ball, and only reads the model: the shot, keeper and
/// scoring are untouched. Hidden while a shot is being held so the release
/// label and spin track stay visible.
class FirstTouchCoach extends StatelessWidget {
  const FirstTouchCoach({super.key, required this.model});
  final MatchModel model;

  static bool shouldShow(MatchModel model, {required bool paused}) =>
      model.isGuidedFirstMatch && model.isPlaying && !paused && !model.isPreparingShot &&
      model.firstTouchHint.isNotEmpty;

  String get title {
    if (model.phase == MatchPhase.flying) return 'SHOT AWAY';
    if (model.phase == MatchPhase.result) {
      return model.lastWasGoal ? (model.justChargedFire ? 'FIRE CHARGED' : 'GOAL!') : 'NEXT TIME';
    }
    if (model.lastFailure != null || model.lastTechniqueAdvice.isNotEmpty) return 'FIX THE NEXT ONE';
    return model.firstTouchLesson.title;
  }

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
          child: Semantics(
            liveRegion: true,
            label: '$title. ${model.firstTouchHint}',
            child: ExcludeSemantics(
              child: Panel(
                key: const ValueKey('first_touch_coach'),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                color: StrikerColors.ink.withValues(alpha: .86),
                borderColor: StrikerColors.gold.withValues(alpha: .35),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(title, style: StrikerText.eyebrow),
                  const SizedBox(height: 2),
                  Text(model.firstTouchHint, textAlign: TextAlign.center,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: StrikerColors.text, fontSize: 11, height: 1.25,
                          fontFamily: StrikerFonts.body)),
                ]),
              ),
            ),
          ),
        ),
      );
}
