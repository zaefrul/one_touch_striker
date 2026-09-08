import 'package:flutter/material.dart';
import '../game/match_model.dart';

class RunSummary extends StatelessWidget {
  const RunSummary({
    super.key,
    required this.model,
    this.personalBest = false,
    this.previousBest = 0,
  });

  final MatchModel model;
  final bool personalBest;
  final int previousBest;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (personalBest) ...[
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: .90, end: 1.0),
              duration: MediaQuery.of(context).disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              // Keep the contents stable; only the badge transform animates.
              child: Semantics(
                liveRegion: true,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0x22ffc857),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x88ffc857)),
                  ),
                  child: Column(children: [
                    const Icon(Icons.emoji_events_rounded,
                        size: 36, color: Color(0xffffc857)),
                    const SizedBox(height: 6),
                    const Text('NEW PERSONAL BEST!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xffffc857),
                            fontWeight: FontWeight.w900, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(previousBest == 0
                        ? 'Your first record. Make the next one count.'
                        : '$previousBest → ${model.score} points',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 14,
            children: [
              _Metric('ACCURACY', '${model.accuracy}%'),
              _Metric('LONGEST STREAK', '${model.longestStreak}'),
              _Metric('SHOTS', '${model.resolvedShots}'),
            ],
          ),
          const SizedBox(height: 12),
          Text('${model.goals} goals · ${model.misses} misses · ${model.cornerGoals} corners',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 94,
        child: Column(children: [
          Text(value,
              style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900,
                  color: Color(0xffd9ff6a))),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9, color: Colors.white60,
                  letterSpacing: .5)),
        ]),
      );
}
