import 'package:flutter/material.dart';
import '../game/challenge_stage.dart';
import '../game/match_model.dart';
import '../game/rival_ledger.dart';
import '../game/showdown.dart';
import '../game/star_rewards.dart';
import 'run_summary.dart';
import 'star_rewards_panel.dart';

/// These panels sit inside the game's scrollable overlay, including on small
/// phones and with larger accessibility text sizes.
class ChallengeMap extends StatelessWidget {
  const ChallengeMap({
    super.key,
    required this.progress,
    required this.rivals,
    required this.recordsAvailable,
    required this.onSelect,
    required this.onBack,
    required this.onRewards,
  });

  final ChallengeProgress progress;
  final RivalLedger rivals;
  final bool recordsAvailable;
  final ValueChanged<int> onSelect;
  final VoidCallback onBack;
  final VoidCallback onRewards;

  int? get _nextTrophyStage {
    for (var i = 0; i < challengeStages.length; i++) {
      final showdown = challengeStages[i].showdown;
      if (showdown != null && progress.isUnlocked(i) && !rivals.hasTrophy(showdown)) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Eyebrow('RIVAL CUP'),
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
          Wrap(alignment: WrapAlignment.center, spacing: 18,
            children: [
              for (final showdown in Showdown.values)
                Tooltip(message: '${showdown.title}: ${recordsAvailable && rivals.hasTrophy(showdown) ? 'won' : 'win this showdown'}',
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.emoji_events, size: 28,
                        color: recordsAvailable && rivals.hasTrophy(showdown)
                            ? const Color(0xffffc857) : Colors.white24),
                    Text('${showdown.index + 1}', style: const TextStyle(fontSize: 10, color: Colors.white60)),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(recordsAvailable ? '${rivals.trophiesWon}/${Showdown.values.length} showdown trophies'
              : 'Rival records unavailable', textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 10),
          NextRewardCard(stars: progress.totalStars, onOpen: onRewards),
          TextButton(onPressed: onRewards, child: const Text('STAR REWARDS')),
          const SizedBox(height: 10),
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
          if (progress.completed && recordsAvailable && _nextTrophyStage != null) ...[
            FilledButton(
              onPressed: () => onSelect(_nextTrophyStage!),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text('WIN ${challengeStages[_nextTrophyStage!].showdown!.title.toUpperCase()}  →')),
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
                record: recordsAvailable ? rivals.against(challengeStages[i].keeper).scoreline : 'Rival record unavailable',
                trophyWon: recordsAvailable && challengeStages[i].showdown != null &&
                    rivals.hasTrophy(challengeStages[i].showdown!),
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
    required this.rivals,
    required this.recordsAvailable,
    required this.onRewards,
    this.newRewards = const [],
    required this.onStart,
    required this.onRetry,
    required this.onNext,
    required this.onStages,
  });

  final MatchModel model;
  final ChallengeProgress progress;
  final RivalLedger rivals;
  final bool recordsAvailable;
  final List<StarReward> newRewards;
  final VoidCallback onRewards;
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
          ? 'STAGE ${model.level} / ${challengeStages.length} · ${stage.showdown?.title.toUpperCase() ?? stage.skill}'
          : cleared
              ? complete ? 'CHALLENGE COMPLETE' : 'STAGE ${model.level} CLEARED'
              : model.message == "TIME'S UP!" ? "TIME'S UP!" : 'GIVE IT ANOTHER SHOT'),
      const SizedBox(height: 16),
      Text(stage.name,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, height: 1.05)),
      const SizedBox(height: 18),
      Text(recordsAvailable ? '${stage.keeper.title} · ${rivals.against(stage.keeper).scoreline}'
          : 'Rival record unavailable', textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 12)),
      const Text('Record across all challenge stages', textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 10)),
      const SizedBox(height: 14),
      if (intro) ...[
        Text('VS ${stage.keeper.title.toUpperCase()}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(stage.keeper.kitColor),
                fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 8),
        Text(stage.keeper.hint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
        const SizedBox(height: 10),
        Text('${stage.keeperSkill.title.toUpperCase()} · ${stage.keeperSkill.abilities}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(stage.keeper.kitColor),
                fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(stage.keeperSkill.hint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
        const SizedBox(height: 18),
      ],
      if (cleared) ...[
        if (stage.showdown != null) ...[
          const Icon(Icons.emoji_events, size: 52, color: Color(0xffffc857)),
          Text(recordsAvailable && rivals.trophiesWon == Showdown.values.length
              ? 'RIVAL CUP WON!' : 'RIVAL DEFEATED!',
              style: const TextStyle(color: Color(0xffffc857), fontWeight: FontWeight.w900, fontSize: 20)),
          Text('${stage.showdown!.title} trophy', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 14),
        ],
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
          if (stage.showdown != null) ...[
            const SizedBox(height: 10),
            Text(intro ? stage.showdown!.rule : model.showdownStatus,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xffffc857), fontSize: 12, height: 1.4)),
          ],
        ]),
      ),
      const SizedBox(height: 16),
      Text(intro
          ? stage.brief
          : cleared
              ? complete
                  ? 'All ${challengeStages.length} stages conquered! You have ${progress.totalStars}/${challengeStages.length * 3} stars. Replay for missing stars and showdown trophies.'
                  : 'Next: ${challengeStages[model.stageIndex! + 1].name}.\n${challengeStages[model.stageIndex! + 1].brief}'
              : model.rematchHint,
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
      if (cleared && newRewards.isNotEmpty) ...[
        const SizedBox(height: 16),
        const Text('NEW LOOK UNLOCKED!',
            style: TextStyle(color: Color(0xffffc857), fontWeight: FontWeight.w900)),
        for (final reward in newRewards)
          Padding(padding: const EdgeInsets.only(top: 6),
              child: Text(reward.title, style: const TextStyle(fontWeight: FontWeight.w800))),
        TextButton(onPressed: onRewards, child: const Text('EQUIP YOUR REWARD')),
      ],
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
    required this.stars, required this.unlocked, required this.onTap,
    required this.record, required this.trophyWon});
  final ChallengeStage stage;
  final int number;
  final int stars;
  final bool unlocked;
  final VoidCallback onTap;
  final String record;
  final bool trophyWon;

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
                  if (stage.showdown != null)
                    Text('${trophyWon ? 'TROPHY WON' : 'SHOWDOWN'} · ${stage.showdown!.title}',
                        style: const TextStyle(fontSize: 10, color: Color(0xffffc857))),
                  const SizedBox(height: 3),
                  Text('${stage.objectiveLabel}${stage.timeLimit == null ? '' : ' · ${stage.timeLimit}s'}',
                      style: const TextStyle(fontSize: 12, color: Colors.white60)),
                  const SizedBox(height: 3),
                  Text('vs ${stage.keeper.title} · ${stage.keeperSkill.title}',
                      style: TextStyle(fontSize: 11,
                          color: unlocked ? Color(stage.keeper.kitColor) : Colors.white38)),
                  if (unlocked) ...[
                    const SizedBox(height: 3),
                    Text(record, style: const TextStyle(fontSize: 10, color: Colors.white54)),
                  ],
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
