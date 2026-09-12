import 'package:flutter/material.dart';
import '../game/match_model.dart';
import '../game/practice_drill.dart';
import '../game/practice_progress.dart';

const _blue = Color(0xff7edfff);

class PracticeMenu extends StatelessWidget {
  const PracticeMenu({super.key, required this.progress, required this.recordsAvailable,
      required this.onSelect, required this.onBack});
  final PracticeProgress progress;
  final bool recordsAvailable;
  final ValueChanged<PracticeDrill> onSelect;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    const Text('PRACTICE ARENA', style: TextStyle(color: _blue,
        fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
    const SizedBox(height: 10),
    const Text('FIVE BALLS.\nFIND YOUR TOUCH.', textAlign: TextAlign.center,
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, height: 1.1)),
    const SizedBox(height: 12),
    const Text('Every released ball is one attempt.\nLearn a technique and beat your best out of five.',
        textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, height: 1.4)),
    for (final drill in PracticeDrill.values)
      Container(width: double.infinity, margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .05),
            borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(drill.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(drill.rule, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
          const SizedBox(height: 10),
          Text('${recordsAvailable ? 'Best' : 'Session best'} ${progress.bestFor(drill)}/${PracticeDrill.balls}',
              style: const TextStyle(color: _blue, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: () => onSelect(drill),
            child: Text('PLAY ${drill.title.toUpperCase()}  →', textAlign: TextAlign.center),
          )),
        ]),
      ),
    const SizedBox(height: 12),
    TextButton(onPressed: onBack, child: const Text('BACK HOME')),
  ]);
}

class PracticeResultPanel extends StatelessWidget {
  const PracticeResultPanel({super.key, required this.model, required this.best,
      required this.recordsAvailable, required this.newBest,
      required this.onRetry, required this.onDrills});
  final MatchModel model;
  final int best;
  final bool recordsAvailable, newBest;
  final VoidCallback onRetry, onDrills;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Text(model.practiceCompleted ? 'DRILL COMPLETE' : 'PRACTICE ENDED',
        style: const TextStyle(color: _blue, letterSpacing: 2, fontWeight: FontWeight.w800)),
    const SizedBox(height: 10),
    Text(model.practice!.title, textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
    const SizedBox(height: 12),
    Text('${model.practiceHits}/${PracticeDrill.balls}',
        style: const TextStyle(fontSize: 58, color: _blue, fontWeight: FontWeight.w900)),
    Text(model.practiceCompleted ? 'DRILL HITS' : '${model.resolvedShots}/5 balls completed',
        style: const TextStyle(color: Colors.white70)),
    if (newBest) ...[
      const SizedBox(height: 10),
      Text(recordsAvailable ? 'NEW PRACTICE BEST!' : 'NEW SESSION BEST!',
          style: const TextStyle(color: Color(0xffffc857), fontWeight: FontWeight.w800)),
    ],
    const SizedBox(height: 12),
    Text('${recordsAvailable ? 'Best' : 'Session best'} $best/5 · '
        '${best < 5 ? 'Next target: ${best + 1}/5' : 'Repeat a perfect 5/5'}',
        textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, height: 1.4)),
    if (!model.practiceCompleted) ...[
      const SizedBox(height: 8),
      const Text('Finish all five balls to record a best.',
          textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
    ],
    const SizedBox(height: 16),
    SizedBox(width: double.infinity, child: FilledButton(onPressed: onRetry,
        child: const Padding(padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('RETRY DRILL  ↻', style: TextStyle(fontWeight: FontWeight.w900))))),
    TextButton(onPressed: onDrills, child: const Text('CHOOSE A DRILL')),
    const SizedBox(height: 12),
    Text('${model.goals} goals · ${model.practiceCleanStrikes} clean knuckles',
        textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
    for (var i = 0; i < model.practiceShots.length; i++)
      Padding(padding: const EdgeInsets.only(top: 12), child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(model.practiceShots[i].hit ? Icons.check_circle : Icons.remove_circle_outline,
              color: model.practiceShots[i].hit ? _blue : Colors.white38, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${i + 1}. ${model.practiceShots[i].explanation}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            Text(model.practiceShots[i].note,
                style: const TextStyle(fontSize: 12, color: Colors.white54, height: 1.4)),
          ])),
        ],
      )),
  ]);
}

class PracticeFooter extends StatelessWidget {
  const PracticeFooter({super.key, required this.model, required this.savingAvailable});
  final MatchModel model;
  final bool savingAvailable;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        const Text('PRACTICE', style: TextStyle(color: _blue, fontSize: 10, letterSpacing: 1.2)),
        const Spacer(),
        Text('${model.resolvedShots}/${PracticeDrill.balls} BALLS COMPLETED',
            style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ]),
      const SizedBox(height: 8),
      LinearProgressIndicator(value: model.resolvedShots / PracticeDrill.balls,
          color: _blue, backgroundColor: Colors.white10, minHeight: 4,
          semanticsLabel: 'Practice balls completed',
          semanticsValue: '${model.resolvedShots} of ${PracticeDrill.balls}'),
      const SizedBox(height: 8),
      ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: Center(
        child: Text(model.phase == MatchPhase.result ? model.lastPracticeNote
            : model.phase == MatchPhase.aiming && model.lastTechniqueAdvice.isNotEmpty
                ? model.lastTechniqueAdvice : model.practice!.rule,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4)),
      )),
      if (!savingAvailable)
        const Text('PRACTICE BEST SAVING UNAVAILABLE',
            style: TextStyle(color: Colors.white54, fontSize: 10)),
    ]),
  );
}
