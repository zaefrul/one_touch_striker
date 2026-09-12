import 'package:flutter/material.dart';
import '../game/challenge_stage.dart';
import 'star_rewards_panel.dart';

/// Put the next playable action before the collection and mode choices.
class HomePanel extends StatelessWidget {
  const HomePanel({super.key, required this.progress, required this.loaded,
      required this.onQuickPlay, required this.onStages, required this.onClassic,
      required this.onRewards});

  final ChallengeProgress progress;
  final bool loaded;
  final VoidCallback onQuickPlay;
  final VoidCallback onStages;
  final VoidCallback onClassic;
  final VoidCallback onRewards;

  @override
  Widget build(BuildContext context) {
    final firstMatch = progress.starsFor(0) == 0;
    final stage = challengeStages[progress.nextStageIndex];
    final action = !loaded ? 'LOADING PROGRESS…'
        : progress.completed ? 'CHOOSE A REMATCH  →'
            : firstMatch ? 'PLAY FIRST MATCH  →'
                : 'CONTINUE · STAGE ${progress.nextStageIndex + 1}  →';
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('YOUR NEXT GREAT GOAL',
          style: TextStyle(color: Color(0xffd9ff6a), fontSize: 10,
              letterSpacing: 2, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      const Text('ONE TAP.\nALL GLORY.', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900,
              height: 1.02, letterSpacing: -1.2)),
      const SizedBox(height: 12),
      Text(firstMatch
          ? 'Touch to aim. Drag to bend.\nRelease to beat the keeper.'
          : 'Touch to aim. Drag to bend. Release to shoot.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, height: 1.4, fontSize: 14)),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity,
          child: FilledButton(
            key: const ValueKey('quick_play'),
            onPressed: loaded ? onQuickPlay : null,
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(action, textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w900))),
          )),
      const SizedBox(height: 8),
      Text(!loaded ? 'Getting your saved progress'
          : progress.completed ? '${progress.totalStars}/${challengeStages.length * 3} stars · Keep the rivalry going'
              : firstMatch ? 'Guided Stage 1 · Score 3 goals · Three chances'
                  : '${stage.name} · ${stage.objectiveLabel}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60, fontSize: 12)),
      const SizedBox(height: 8),
      Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
        TextButton(onPressed: loaded ? onStages : null,
            child: const Text('PLAY CHALLENGES')),
        TextButton(onPressed: loaded ? onRewards : null,
            child: const Text('STAR REWARDS')),
      ]),
      NextRewardCard(stars: progress.totalStars, onOpen: onRewards),
      const SizedBox(height: 16),
      const Text('CLASSIC · CHASE YOUR BEST SCORE',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: Colors.white54, letterSpacing: 1)),
      const SizedBox(height: 8),
      SizedBox(width: double.infinity,
          child: OutlinedButton(onPressed: onClassic,
              child: const Padding(padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('LET’S PLAY  →',
                      style: TextStyle(fontWeight: FontWeight.w900))))),
      const SizedBox(height: 8),
      const Text('Goal +1 · Corner +3\nNo timer. Three misses end your Classic run.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.white54, height: 1.4)),
    ]);
  }
}
