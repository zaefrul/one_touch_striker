import 'package:flutter/material.dart';
import '../game/challenge_stage.dart';
import 'star_rewards_panel.dart';
import 'theme.dart';
import 'widgets.dart';

/// Put the next playable action before the collection and mode choices.
class HomePanel extends StatelessWidget {
  const HomePanel({super.key, required this.progress, required this.loaded,
      required this.onQuickPlay, required this.onStages, required this.onClassic,
      required this.onRewards, required this.onPractice, this.onAudio, this.best = 0});

  final ChallengeProgress progress;
  final bool loaded;
  final VoidCallback onQuickPlay;
  final VoidCallback onStages;
  final VoidCallback onClassic;
  final VoidCallback onRewards;
  final VoidCallback onPractice;
  final VoidCallback? onAudio;
  final int best;

  @override
  Widget build(BuildContext context) {
    final firstMatch = progress.starsFor(0) == 0;
    final stage = challengeStages[progress.nextStageIndex];
    final action = !loaded ? 'LOADING PROGRESS…'
        : progress.completed ? 'CHOOSE A REMATCH  →'
            : firstMatch ? 'PLAY FIRST MATCH  →'
                : 'CONTINUE · STAGE ${progress.nextStageIndex + 1}  →';
    final objective = !loaded ? 'Getting your saved progress'
        : progress.completed ? '${progress.totalStars}/${challengeStages.length * 3} stars · Keep the rivalry going'
            : firstMatch ? 'Stage 1 · Score 3 goals'
                : '${stage.name} · ${stage.objectiveLabel}';
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Panel(child: Column(children: [
        const Eyebrow('YOUR NEXT GREAT GOAL'),
        const SizedBox(height: 10),
        const Text('ONE TAP.\nALL GLORY.', textAlign: TextAlign.center,
            style: StrikerText.headline),
        const SizedBox(height: 12),
        Text(objective, textAlign: TextAlign.center, style: StrikerText.caption),
        const SizedBox(height: 16),
        PrimaryButton(
          buttonKey: const ValueKey('quick_play'),
          onPressed: loaded ? onQuickPlay : null,
          label: action,
        ),
      ])),
      const SizedBox(height: 12),
      ModeTile(
        title: 'PLAY CHALLENGES',
        subtitle: '${progress.totalStars}/${challengeStages.length * 3} stars · Rival Cup',
        progress: progress.totalStars / (challengeStages.length * 3),
        onTap: loaded ? onStages : null,
        glyph: const Icon(Icons.emoji_events_rounded, color: StrikerColors.gold),
      ),
      const SizedBox(height: 8),
      ModeTile(
        title: 'PRACTICE ARENA',
        subtitle: 'Five-ball drills · Timed knuckle shot',
        onTap: loaded ? onPractice : null,
        glyph: const BallGlyph(size: 26),
      ),
      const SizedBox(height: 8),
      ModeTile(
        title: 'LET’S PLAY  →',
        subtitle: best > 0 ? 'Classic · Best $best' : 'Classic · Chase your best score',
        onTap: loaded ? onClassic : null,
        glyph: const Icon(Icons.bolt_rounded, color: StrikerColors.gold),
      ),
      const SizedBox(height: 8),
      NextRewardCard(stars: progress.totalStars, onOpen: onRewards),
      TextButton(onPressed: loaded ? onRewards : null, child: const Text('STAR REWARDS')),
      if (onAudio != null) QuietButton(
        label: 'AUDIO MIX',
        icon: Icons.tune_rounded,
        onPressed: onAudio,
      ),
    ]);
  }
}
