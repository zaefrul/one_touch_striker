import 'package:flutter/material.dart';
import '../game/challenge_stage.dart';
import '../game/match_model.dart';
import 'run_summary.dart';

/// These panels sit inside the game's scrollable overlay, including on small
/// phones and with larger accessibility text sizes.
class ChallengeMap extends StatelessWidget {
  const ChallengeMap({
    super.key,
    required this.progress,
    required this.onSelect,
    required this.onBack,
  });

  final ChallengeProgress progress;
  final ValueChanged<int> onSelect;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Eyebrow('BEAT THE KEEPER'),
          const SizedBox(height: 12),
          Text('${challengeStages.length} stages.\nEarn your stars.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, height: 1.1)),
          const SizedBox(height: 12),
          Text('${progress.totalStars}/${challengeStages.length * 3} stars collected',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          const Text('Clear a stage to unlock the next.\nFewer misses earn more stars. Retry any unlocked stage.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, height: 1.5, fontSize: 12)),
          const SizedBox(height: 18),
          if (!progress.completed) ...[
            FilledButton(
              onPressed: () => onSelect(progress.nextStageIndex),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text('PLAY STAGE ${progress.nextStageIndex + 1}  →'),
              ),
            ),
            const SizedBox(height: 14),
          ],
          for (var i = 0; i < challengeStages.length; i++) ...[
            if (i == 0 || i == championStageStart)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 14),
                child: _Eyebrow(i == 0 ? 'THE CLIMB' : 'CHAMPION STAGES · HARD'),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StageCard(
                stage: challengeStages[i],
                number: i + 1,
                stars: progress.starsFor(i),
                unlocked: progress.isUnlocked(i),
                onTap: () => onSelect(i),
              ),
            ),
          ],
          TextButton(onPressed: onBack, child: const Text('BACK TO HOME')),
        ],
      );
}

class StagePanel extends StatelessWidget {
  const StagePanel({
    super.key,
    required this.model,
    required this.progress,
    required this.onStart,
    required this.onRetry,
    required this.onNext,
    required this.onStages,
  });

  final MatchModel model;
  final ChallengeProgress progress;
  final VoidCallback onStart;
  final VoidCallback onRetry;
  final VoidCallback onNext;
  final VoidCallback onStages;

  @override
  Widget build(BuildContext context) {
    final stage = model.stage!;
    final intro = model.phase == MatchPhase.stageIntro;
    final cleared = model.phase == MatchPhase.stageCleared;
    final complete = cleared && model.isFinalStage;
    final accent = Theme.of(context).colorScheme.primary;
    final rematchTarget = progress.starsFor(model.stageIndex!) < 3
        ? 'Rematch target: clear with no misses for 3 stars.'
        : 'Rematch target: another perfect clear.';
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _Eyebrow(intro
          ? 'STAGE ${model.level} / ${challengeStages.length} · ${stage.skill}'
          : cleared
              ? complete ? 'CHALLENGE COMPLETE' : 'STAGE ${model.level} CLEARED'
              : model.message == "TIME'S UP!" ? "TIME'S UP!" : 'GIVE IT ANOTHER SHOT'),
      const SizedBox(height: 16),
      Text(stage.name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, height: 1.05)),
      const SizedBox(height: 18),
      if (intro) ...[
        Text('VS ${stage.keeper.title.toUpperCase()}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(stage.keeper.kitColor),
                fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 8),
        Text(stage.keeper.hint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
        const SizedBox(height: 18),
      ],
      if (cleared) ...[
        StageStars(model.earnedStars, size: 44),
        const SizedBox(height: 12),
        Text(model.earnedStars == 3 ? 'PERFECT CLEAR!' : 'STAGE COMPLETE!',
            style: TextStyle(color: accent, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 10),
      ],
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(stage.pitchColor).withValues(alpha: .65),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: .3)),
        ),
        child: Column(children: [
          Text(stage.objectiveLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          Text(intro
              ? stage.rulesLabel
              : '${model.objectiveProgress}/${stage.target} ${stage.unit} · ${model.misses} misses',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ]),
      ),
      const SizedBox(height: 16),
      Text(intro
          ? stage.brief
          : cleared
              ? complete
                  ? 'All ${challengeStages.length} stages conquered! You have ${progress.totalStars}/${challengeStages.length * 3} stars. Replay your favourites to earn the rest.'
                  : 'Next: ${challengeStages[model.stageIndex! + 1].name}.\n${challengeStages[model.stageIndex! + 1].brief}'
              : stage.tip,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, height: 1.6, fontSize: 14)),
      const SizedBox(height: 12),
      if (intro)
        Column(children: [
          Text(stage.fireRule,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xffffc857), fontSize: 12, height: 1.5)),
          const SizedBox(height: 10),
          Text(stage.timeLimit == null
              ? 'No rush. Every attempt starts with three chances.'
              : 'The clock runs only while aiming or shooting. Pausing freezes it; a shot released before zero can finish.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.5)),
        ])
      else
        RunSummary(model: model),
      const SizedBox(height: 22),
      if (!intro && !cleared) ...[
        Text(rematchTarget,
            textAlign: TextAlign.center,
            style: TextStyle(color: accent, fontSize: 12, height: 1.4)),
        const SizedBox(height: 10),
      ],
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: intro ? onStart : cleared ? onNext : onRetry,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(intro
                ? 'START STAGE  →'
                : cleared
                    ? complete ? 'EXPLORE STAGES  →' : 'NEXT STAGE  →'
                    : 'RETRY STAGE  ↻',
                style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
        ),
      ),
      if (cleared) ...[
        const SizedBox(height: 14),
        Text(rematchTarget,
            textAlign: TextAlign.center,
            style: TextStyle(color: accent, fontSize: 12, height: 1.4)),
        TextButton(onPressed: onRetry,
            child: Text(model.earnedStars < 3 ? 'RETRY FOR THREE STARS' : 'PLAY THIS STAGE AGAIN')),
      ],
      TextButton(onPressed: onStages, child: const Text('STAGE SELECT')),
      if (intro || (cleared && model.earnedStars < 3))
        const Text('Stars: 0 misses = 3 · 1 miss = 2 · 2 misses = 1',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 11)),
    ]);
  }
}

class StageStars extends StatelessWidget {
  const StageStars(this.stars, {super.key, this.size = 19});
  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$stars of 3 stars',
        child: ExcludeSemantics(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < 3; i++)
              Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: size,
                  color: i < stars ? const Color(0xffffc857) : Colors.white24),
          ]),
        ),
      );
}

class _StageCard extends StatelessWidget {
  const _StageCard({required this.stage, required this.number,
    required this.stars, required this.unlocked, required this.onTap});
  final ChallengeStage stage;
  final int number;
  final int stars;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        label: unlocked ? 'Stage $number. ${stage.name}' : 'Stage $number locked. Clear stage ${number - 1} to unlock.',
        child: Material(
          color: unlocked ? Color(stage.pitchColor).withValues(alpha: .65) : Colors.white.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: unlocked ? onTap : null,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                SizedBox(width: 30, child: unlocked
                    ? Text('$number', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900))
                    : const Icon(Icons.lock_outline, size: 22, color: Colors.white38)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(stage.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                      color: unlocked ? Colors.white : Colors.white54)),
                  const SizedBox(height: 3),
                  Text('${stage.objectiveLabel}${stage.timeLimit == null ? '' : ' · ${stage.timeLimit}s'}',
                      style: const TextStyle(fontSize: 12, color: Colors.white60)),
                  const SizedBox(height: 3),
                  Text('vs ${stage.keeper.title}',
                      style: TextStyle(fontSize: 11,
                          color: unlocked ? Color(stage.keeper.kitColor) : Colors.white38)),
                  const SizedBox(height: 6),
                  StageStars(stars, size: 17),
                ])),
                if (unlocked) const Icon(Icons.chevron_right, color: Colors.white54),
              ]),
            ),
          ),
        ),
      );
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: TextAlign.center,
      style: TextStyle(color: Theme.of(context).colorScheme.primary,
          fontSize: 10, letterSpacing: 1.8, fontWeight: FontWeight.bold));
}
