import 'package:flutter/material.dart';
import '../game/match_model.dart';
import '../game/showdown.dart';

/// The briefing and HUD use the same rules, including compound showdowns.
class StageObjectiveView extends StatelessWidget {
  const StageObjectiveView({super.key, required this.model, this.intro = false});
  final MatchModel model;
  final bool intro;

  @override
  Widget build(BuildContext context) {
    final stage = model.stage!;
    final accent = Theme.of(context).colorScheme.primary;
    final progress = model.objectiveProgress.clamp(0, stage.target);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(intro ? stage.objectiveLabel
          : stage.showdown == Showdown.cornerDuel ? 'Score in both corners'
              : '$progress/${stage.target} ${stage.unit}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: intro ? 28 : 17, fontWeight: FontWeight.w900,
              height: 1.1, color: accent)),
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
          color: complete ? const Color(0xffd9ff6a) : const Color(0xffffc857)),
      const SizedBox(width: 6),
      Flexible(child: Text(label, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Colors.white70))),
    ])),
  );
}

class _RuleBadge extends StatelessWidget {
  const _RuleBadge(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 16, color: Colors.white60),
    const SizedBox(width: 5),
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
  ]);
}
