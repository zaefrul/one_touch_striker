import 'package:flutter/material.dart';
import '../game/challenge_stage.dart';
import '../game/first_touch_guide.dart';
import '../game/match_model.dart';
import '../game/rival_ledger.dart';
import '../game/showdown.dart';
import '../game/star_rewards.dart';
import 'run_summary.dart';
import 'star_rewards_panel.dart';
import 'stage_objective.dart';
import 'theme.dart';
import 'widgets.dart';

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
          const Eyebrow('RIVAL CUP'),
          const SizedBox(height: 12),
          Text('${challengeStages.length} stages.\nEarn your stars.',
              textAlign: TextAlign.center, style: StrikerText.headline),
          const SizedBox(height: 12),
          Text('${progress.totalStars}/${challengeStages.length * 3} stars collected',
              textAlign: TextAlign.center, style: StrikerText.body),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.totalStars / (challengeStages.length * 3),
              minHeight: 6,
              color: StrikerColors.gold,
              backgroundColor: StrikerColors.outline,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Clear a stage to unlock the next.\nFewer misses earn more stars. Retry any unlocked stage.',
              textAlign: TextAlign.center, style: StrikerText.caption),
          const SizedBox(height: 18),
          Wrap(alignment: WrapAlignment.center, spacing: 18,
            children: [
              for (final showdown in Showdown.values)
                Tooltip(message: '${showdown.title}: ${recordsAvailable && rivals.hasTrophy(showdown) ? 'won' : 'win this showdown'}',
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.emoji_events, size: 28,
                        color: recordsAvailable && rivals.hasTrophy(showdown)
                            ? StrikerColors.gold : StrikerColors.faint),
                    Text('${showdown.index + 1}', style: StrikerText.statLabel),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(recordsAvailable ? '${rivals.trophiesWon}/${Showdown.values.length} showdown trophies'
              : 'Rival records unavailable', textAlign: TextAlign.center,
              style: StrikerText.caption),
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
              SectionHeader(i == 0 ? 'THE CLIMB' : 'CHAMPION STAGES · HARD'),
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
    if (intro) return _StageBriefing(model: model, rivals: rivals,
        recordsAvailable: recordsAvailable, onStart: onStart, onStages: onStages);
    final cleared = model.phase == MatchPhase.stageCleared;
    final complete = cleared && model.isFinalStage;
    final rematchTarget = progress.starsFor(model.stageIndex!) < 3
        ? 'Rematch target: clear with no misses for 3 stars.'
        : 'Rematch target: another perfect clear.';
    final primaryAction = PrimaryButton(
          onPressed: intro ? onStart : cleared ? onNext : onRetry,
          label: intro
                ? 'START STAGE  →'
                : cleared
                    ? complete ? 'EXPLORE STAGES  →' : 'NEXT STAGE  →'
                    : 'RETRY STAGE  ↻',
      );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Eyebrow(intro
          ? 'STAGE ${model.level} / ${challengeStages.length} · ${stage.showdown?.title.toUpperCase() ?? stage.skill}'
          : cleared
              ? complete ? 'CHALLENGE COMPLETE' : 'STAGE ${model.level} CLEARED'
              : model.message == "TIME'S UP!" ? "TIME'S UP!" : 'GIVE IT ANOTHER SHOT'),
      const SizedBox(height: 16),
      Text(stage.name, textAlign: TextAlign.center, style: StrikerText.headline),
      const SizedBox(height: 18),
      Text(recordsAvailable ? '${stage.keeper.title} · ${rivals.against(stage.keeper).scoreline}'
          : 'Rival record unavailable', textAlign: TextAlign.center,
          style: StrikerText.caption),
      const Text('Record across all challenge stages', textAlign: TextAlign.center,
          style: TextStyle(color: StrikerColors.faint, fontSize: 10, fontFamily: StrikerFonts.body)),
      const SizedBox(height: 14),
      if (intro) ...[
        Text('VS ${stage.keeper.title.toUpperCase()}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(stage.keeper.kitColor),
                fontFamily: StrikerFonts.display,
                fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 8),
        Text(stage.keeper.hint, textAlign: TextAlign.center, style: StrikerText.body.copyWith(fontSize: 13)),
        const SizedBox(height: 10),
        Text('${stage.keeperSkill.title.toUpperCase()} · ${stage.keeperSkill.abilities}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(stage.keeper.kitColor),
                fontSize: 12, fontWeight: FontWeight.w800, fontFamily: StrikerFonts.body)),
        const SizedBox(height: 6),
        Text(stage.keeperSkill.hint, textAlign: TextAlign.center, style: StrikerText.caption),
        const SizedBox(height: 18),
      ],
      if (cleared) ...[
        if (stage.showdown != null) ...[
          const Icon(Icons.emoji_events, size: 52, color: StrikerColors.gold),
          Text(recordsAvailable && rivals.trophiesWon == Showdown.values.length
              ? 'RIVAL CUP WON!' : 'RIVAL DEFEATED!',
              style: const TextStyle(color: StrikerColors.gold, fontWeight: FontWeight.w900, fontSize: 20,
                  fontFamily: StrikerFonts.display)),
          Text('${stage.showdown!.title} trophy', style: StrikerText.caption),
          const SizedBox(height: 14),
        ],
        StageStars(model.earnedStars, size: 44),
        const SizedBox(height: 12),
        Text(model.earnedStars == 3 ? 'PERFECT CLEAR!' : 'STAGE COMPLETE!',
            style: const TextStyle(color: StrikerColors.gold, fontWeight: FontWeight.w900, letterSpacing: 1,
                fontFamily: StrikerFonts.display)),
        const SizedBox(height: 10),
        if (model.isGuidedFirstMatch) ...[
          const Text(
              'First match cleared! Stars unlock the Rival Cup. Practice Arena teaches curve and knuckle shots. Classic is an endless score chase.',
              textAlign: TextAlign.center, style: StrikerText.body),
          const SizedBox(height: 10),
        ],
      ],
      if (cleared && newRewards.isNotEmpty) ...[
        const SizedBox(height: 16),
        const Text('NEW LOOK UNLOCKED!',
            style: TextStyle(color: StrikerColors.gold, fontWeight: FontWeight.w900,
                fontFamily: StrikerFonts.display)),
        for (final reward in newRewards)
          Padding(padding: const EdgeInsets.only(top: 6),
              child: Text(reward.title, style: const TextStyle(fontWeight: FontWeight.w800,
                  fontFamily: StrikerFonts.body, color: StrikerColors.text))),
        TextButton(onPressed: onRewards, child: const Text('EQUIP YOUR REWARD')),
      ],
      if (!intro) ...[
        if (!cleared) ...[
          Text(model.retryAdvice, textAlign: TextAlign.center,
              style: const TextStyle(color: StrikerColors.gold, fontSize: 13, height: 1.4,
                  fontFamily: StrikerFonts.body)),
          const SizedBox(height: 12),
        ],
        primaryAction,
        const SizedBox(height: 18),
      ],
      Panel(
        color: Color(stage.pitchColor).withValues(alpha: .65),
        borderColor: StrikerColors.gold.withValues(alpha: .3),
        child: Column(children: [
          Text(stage.objectiveLabel, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  fontFamily: StrikerFonts.display, color: StrikerColors.text)),
          const SizedBox(height: 7),
          Text(intro
              ? stage.rulesLabel
              : '${model.objectiveProgress}/${stage.target} ${stage.unit} · ${model.misses} misses',
              textAlign: TextAlign.center, style: StrikerText.body.copyWith(fontSize: 13)),
          if (stage.showdown != null) ...[
            const SizedBox(height: 10),
            Text(intro ? stage.showdown!.rule : model.showdownStatus,
                textAlign: TextAlign.center,
                style: const TextStyle(color: StrikerColors.gold, fontSize: 12, height: 1.4,
                    fontFamily: StrikerFonts.body)),
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
          textAlign: TextAlign.center, style: StrikerText.body),
      const SizedBox(height: 12),
      if (intro)
        Column(children: [
          Text(stage.fireRule, textAlign: TextAlign.center,
              style: const TextStyle(color: StrikerColors.gold, fontSize: 12, height: 1.5,
                  fontFamily: StrikerFonts.body)),
          const SizedBox(height: 10),
          Text(stage.timeLimit == null
              ? 'No rush. Every attempt starts with three chances.'
              : 'The clock runs only while aiming or shooting. Pausing freezes it; a shot released before zero can finish.',
              textAlign: TextAlign.center, style: StrikerText.caption),
        ])
      else
        RunSummary(model: model),
      const SizedBox(height: 22),
      if (!intro && !cleared) ...[
        Text(rematchTarget, textAlign: TextAlign.center,
            style: const TextStyle(color: StrikerColors.gold, fontSize: 12, height: 1.4,
                fontFamily: StrikerFonts.body)),
        const SizedBox(height: 10),
      ],
      if (intro) primaryAction,
      if (cleared) ...[
        const SizedBox(height: 14),
        Text(rematchTarget, textAlign: TextAlign.center,
            style: const TextStyle(color: StrikerColors.gold, fontSize: 12, height: 1.4,
                fontFamily: StrikerFonts.body)),
        TextButton(onPressed: onRetry,
            child: Text(model.earnedStars < 3 ? 'RETRY FOR THREE STARS' : 'PLAY THIS STAGE AGAIN')),
      ],
      TextButton(onPressed: onStages, child: const Text('STAGE SELECT')),
      if (intro || (cleared && model.earnedStars < 3))
        const Text('Stars: 0 misses = 3 · 1 miss = 2 · 2 misses = 1',
            textAlign: TextAlign.center, style: StrikerText.caption),
    ]);
  }
}

class _StageBriefing extends StatelessWidget {
  const _StageBriefing({required this.model, required this.rivals,
      required this.recordsAvailable, required this.onStart, required this.onStages});
  final MatchModel model;
  final RivalLedger rivals;
  final bool recordsAvailable;
  final VoidCallback onStart, onStages;

  @override
  Widget build(BuildContext context) {
    final stage = model.stage!;
    final guided = model.isGuidedFirstMatch;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (guided) ...[
        const Eyebrow('YOUR FIRST MATCH'),
        const SizedBox(height: 8),
      ],
      Text('STAGE ${model.level} · ${stage.name}', textAlign: TextAlign.center,
          style: StrikerText.caption.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      KeeperAvatar(kit: Color(stage.keeper.kitColor), size: 64),
      const SizedBox(height: 12),
      StageObjectiveView(model: model, intro: true),
      const SizedBox(height: 18),
      Text('VS ${stage.keeper.title} · ${stage.keeperSkill.title}',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(stage.keeper.kitColor), fontWeight: FontWeight.w700,
              fontFamily: StrikerFonts.display)),
      const SizedBox(height: 20),
      if (guided) ...[
        Text(FirstTouchLesson.aim.instruction, textAlign: TextAlign.center, style: StrikerText.body),
        const SizedBox(height: 14),
      ],
      PrimaryButton(onPressed: onStart, label: 'START STAGE  →'),
      const SizedBox(height: 12),
      Material(type: MaterialType.transparency, child: ExpansionTile(
        title: const Text('Match tips', style: TextStyle(fontSize: 13)),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12), children: [
          Text(recordsAvailable ? '${stage.keeper.title} · ${rivals.against(stage.keeper).scoreline}'
              : 'Rival record unavailable', textAlign: TextAlign.center,
              style: StrikerText.caption),
          const SizedBox(height: 10),
          Text(stage.tip, textAlign: TextAlign.center, style: StrikerText.caption),
          const SizedBox(height: 10),
          Text(stage.fireRule, textAlign: TextAlign.center,
              style: const TextStyle(color: StrikerColors.gold, fontSize: 12, height: 1.4,
                  fontFamily: StrikerFonts.body)),
          const SizedBox(height: 10),
          Text(stage.keeperSkill.hint, textAlign: TextAlign.center, style: StrikerText.caption),
          if (stage.showdown != null) ...[
            const SizedBox(height: 10),
            Text(stage.showdown!.rule, textAlign: TextAlign.center, style: StrikerText.caption),
          ],
          if (stage.timeLimit != null) ...[
            const SizedBox(height: 10),
            const Text('The clock runs while aiming and shooting. Release before zero.',
                textAlign: TextAlign.center, style: StrikerText.caption),
          ],
          const SizedBox(height: 10),
          const Text('Stars: 0 misses = 3 · 1 miss = 2 · 2 misses = 1',
              textAlign: TextAlign.center, style: StrikerText.caption),
        ],
      )),
      TextButton(onPressed: onStages, child: const Text('STAGE SELECT')),
    ]);
  }
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
          color: unlocked ? Color(stage.pitchColor).withValues(alpha: .55) : StrikerColors.surface.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: unlocked ? onTap : null,
            borderRadius: BorderRadius.circular(14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: unlocked ? Color(stage.accent).withValues(alpha: .45) : StrikerColors.outline),
              ),
              child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: unlocked ? Color(stage.accent) : StrikerColors.outline,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: unlocked
                    ? Text('$number', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                        fontFamily: StrikerFonts.display, color: StrikerColors.onGold))
                    : const Icon(Icons.lock_outline, size: 18, color: StrikerColors.faint),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(stage.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                      fontFamily: StrikerFonts.display,
                      color: unlocked ? StrikerColors.text : StrikerColors.muted)),
                  if (stage.showdown != null)
                    Text('${trophyWon ? 'TROPHY WON' : 'SHOWDOWN'} · ${stage.showdown!.title}',
                        style: const TextStyle(fontSize: 10, color: StrikerColors.gold,
                            fontFamily: StrikerFonts.display, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text('${stage.objectiveLabel}${stage.timeLimit == null ? '' : ' · ${stage.timeLimit}s'}',
                      style: StrikerText.caption),
                  if (stage.extraObjectiveLabel != null)
                    Text(stage.extraObjectiveLabel!,
                        style: const TextStyle(fontSize: 11, color: StrikerColors.gold,
                            fontFamily: StrikerFonts.body)),
                  const SizedBox(height: 3),
                  Text('vs ${stage.keeper.title} · ${stage.keeperSkill.title}',
                      style: TextStyle(fontSize: 11, fontFamily: StrikerFonts.body,
                          color: unlocked ? Color(stage.keeper.kitColor) : StrikerColors.faint)),
                  if (unlocked) ...[
                    const SizedBox(height: 3),
                    Text(record, style: StrikerText.caption.copyWith(fontSize: 10)),
                  ],
                  const SizedBox(height: 6),
                  StageStars(stars, size: 17),
                ])),
                if (unlocked) const Icon(Icons.chevron_right, color: StrikerColors.muted),
              ]),
            ),
          ),
        ),
      ),
    );
}
