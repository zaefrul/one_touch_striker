import 'package:flutter/material.dart';
import '../game/match_model.dart';
import '../game/showdown.dart';
import 'theme.dart';

/// The briefing and HUD use the same rules, including compound showdowns.
class StageObjectiveView extends StatelessWidget {
  const StageObjectiveView({super.key, required this.model, this.intro = false});
  final MatchModel model;
  final bool intro;

  @override
  Widget build(BuildContext context) {
    final stage = model.stage!;
    final progress = model.objectiveProgress.clamp(0, stage.target);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(intro ? stage.objectiveLabel
          : stage.showdown == Showdown.cornerDuel ? 'Score in both corners'
              : '$progress/${stage.target} ${stage.unit}',
          textAlign: TextAlign.center,
          style: (intro ? StrikerText.headline : StrikerText.title).copyWith(
              fontSize: intro ? 28 : 17, color: StrikerColors.gold)),
      if (stage.showdown == Showdown.cornerDuel) ...[
        const SizedBox(height: 8),
        Wrap(alignment: WrapAlignment.center, spacing: 18, runSpacing: 4, children: [
          _condition('Left corner', model.leftCornerScored, Icons.north_west),
          _condition('Right corner', model.rightCornerScored, Icons.north_east),
        ]),
      ] else if (stage.extraObjectiveLabel != null) ...[
        const SizedBox(height: 8),
        _condition(stage.extraObjectiveLabel!, stage.showdown == Showdown.rushHour
            ? model.rushGoals > 0 : model.objectiveMet, Icons.flag_outlined),
      ],
      if (intro) ...[
        const SizedBox(height: 14),
        Wrap(alignment: WrapAlignment.center, spacing: 18, runSpacing: 6, children: [
          const _RuleBadge(Icons.favorite_outline, '3 chances'),
          _RuleBadge(Icons.timer_outlined,
              stage.timeLimit == null ? 'No timer' : '${stage.timeLimit}s'),
        ]),
      ],
    ]);
  }

  Widget _condition(String label, bool complete, IconData pending) => Semantics(
    label: '$label. ${complete ? 'Complete' : 'Required'}',
    child: ExcludeSemantics(child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(complete ? Icons.check_circle : pending, size: 17,
          color: complete ? StrikerColors.gold : StrikerColors.cyan),
      const SizedBox(width: 6),
      Flexible(child: Text(label, textAlign: TextAlign.center, style: StrikerText.caption)),
    ])),
  );
}

class _RuleBadge extends StatelessWidget {
  const _RuleBadge(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 16, color: StrikerColors.muted),
    const SizedBox(width: 5),
    Text(label, style: StrikerText.caption),
  ]);
}
