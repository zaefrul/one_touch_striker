import 'package:flutter/material.dart';
import '../game/match_model.dart';
import '../game/practice_drill.dart';
import '../game/practice_progress.dart';
import '../game/tutorial_progress.dart';
import 'theme.dart';
import 'widgets.dart';

class PracticeMenu extends StatelessWidget {
  const PracticeMenu({super.key, required this.progress, required this.recordsAvailable,
      required this.onSelect, required this.onBack, this.onTutorial, this.onReplayTutorial});
  final PracticeProgress progress;
  final bool recordsAvailable;
  final ValueChanged<PracticeDrill> onSelect;
  final VoidCallback onBack;
  final ValueChanged<TutorialLesson>? onTutorial;
  final VoidCallback? onReplayTutorial;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    const Eyebrow('TRAINING'),
    const SizedBox(height: 10),
    const Text('PRACTICE ARENA', style: StrikerText.eyebrow),
    const SizedBox(height: 10),
    const Text('FIVE BALLS.\nFIND YOUR TOUCH.', textAlign: TextAlign.center,
        style: StrikerText.headline),
    const SizedBox(height: 12),
    const Text('Every released ball is one attempt.\nLearn a technique and beat your best out of five.',
        textAlign: TextAlign.center, style: StrikerText.body),
    if (onTutorial != null)
      Material(type: MaterialType.transparency, child: ExpansionTile(
        title: const Text('Replay tutorials'),
        leading: const Icon(Icons.touch_app_outlined, color: StrikerColors.cyan),
        children: [
          if (onReplayTutorial != null)
            ListTile(title: const Text('Play all lessons'),
                trailing: const Icon(Icons.play_arrow_rounded), onTap: onReplayTutorial),
          for (final lesson in TutorialLesson.values)
            ListTile(title: Text(lesson.title), trailing: const Icon(Icons.play_arrow_rounded),
                onTap: () => onTutorial!(lesson)),
        ],
      )),
    for (final drill in PracticeDrill.values)
      Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.adjust, color: StrikerColors.cyan, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(drill.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                    fontFamily: StrikerFonts.display, color: StrikerColors.text))),
          ]),
          const SizedBox(height: 8),
          Text(drill.rule, style: StrikerText.body.copyWith(fontSize: 13)),
          const SizedBox(height: 10),
          Row(children: [
            for (var i = 0; i < PracticeDrill.balls; i++)
              Container(
                width: 10, height: 10,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < progress.bestFor(drill) ? StrikerColors.cyan : StrikerColors.outline,
                ),
              ),
            const Spacer(),
            Text('${recordsAvailable ? 'Best' : 'Session best'} ${progress.bestFor(drill)}/${PracticeDrill.balls}',
                style: const TextStyle(color: StrikerColors.cyan, fontWeight: FontWeight.w700,
                    fontFamily: StrikerFonts.body)),
          ]),
          const SizedBox(height: 8),
          PrimaryButton(onPressed: () => onSelect(drill),
              label: 'PLAY ${drill.title.toUpperCase()}  →'),
        ])),
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
        style: StrikerText.eyebrow.copyWith(color: StrikerColors.cyan)),
    const SizedBox(height: 10),
    Text(model.practice!.title, textAlign: TextAlign.center, style: StrikerText.title),
    const SizedBox(height: 12),
    Text('${model.practiceHits}/${PracticeDrill.balls}',
        style: StrikerText.score.copyWith(fontSize: 58, color: StrikerColors.cyan)),
    Text(model.practiceCompleted ? 'DRILL HITS' : '${model.resolvedShots}/5 balls completed',
        style: StrikerText.caption),
    if (newBest) ...[
      const SizedBox(height: 10),
      Text(recordsAvailable ? 'NEW PRACTICE BEST!' : 'NEW SESSION BEST!',
          style: const TextStyle(color: StrikerColors.gold, fontWeight: FontWeight.w800,
              fontFamily: StrikerFonts.display)),
    ],
    const SizedBox(height: 12),
    Text('${recordsAvailable ? 'Best' : 'Session best'} $best/5 · '
        '${best < 5 ? 'Next target: ${best + 1}/5' : 'Repeat a perfect 5/5'}',
        textAlign: TextAlign.center, style: StrikerText.body),
    if (!model.practiceCompleted) ...[
      const SizedBox(height: 8),
      const Text('Finish all five balls to record a best.',
          textAlign: TextAlign.center, style: StrikerText.caption),
    ],
    const SizedBox(height: 16),
    PrimaryButton(onPressed: onRetry, label: 'RETRY DRILL  ↻'),
    TextButton(onPressed: onDrills, child: const Text('CHOOSE A DRILL')),
    const SizedBox(height: 12),
    Text('${model.goals} goals · ${model.practiceCleanStrikes} clean knuckles',
        textAlign: TextAlign.center, style: StrikerText.caption),
    for (var i = 0; i < model.practiceShots.length; i++)
      Padding(padding: const EdgeInsets.only(top: 12), child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(model.practiceShots[i].hit ? Icons.check_circle : Icons.remove_circle_outline,
              color: model.practiceShots[i].hit ? StrikerColors.cyan : StrikerColors.faint, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${i + 1}. ${model.practiceShots[i].explanation}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    fontFamily: StrikerFonts.body, color: StrikerColors.text)),
            Text(model.practiceShots[i].note, style: StrikerText.caption),
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
        const Text('PRACTICE', style: TextStyle(color: StrikerColors.cyan, fontSize: 10,
            letterSpacing: 1.2, fontFamily: StrikerFonts.display, fontWeight: FontWeight.w700)),
        const Spacer(),
        Text('${model.resolvedShots}/${PracticeDrill.balls} BALLS COMPLETED',
            style: StrikerText.statLabel),
      ]),
      const SizedBox(height: 8),
      LinearProgressIndicator(value: model.resolvedShots / PracticeDrill.balls,
          color: StrikerColors.cyan, backgroundColor: StrikerColors.outline, minHeight: 4,
          semanticsLabel: 'Practice balls completed'),
      const SizedBox(height: 8),
      Text(model.practice!.shortRule, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: StrikerColors.cyan, fontWeight: FontWeight.w700,
              fontFamily: StrikerFonts.body)),
      SizedBox(height: MediaQuery.textScalerOf(context).scale(28), child: Center(child: Text(
          model.phase == MatchPhase.aiming && !model.isPreparingShot
              ? model.lastFailure?.shortAdvice ?? '' : '',
          maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
          style: StrikerText.caption))),
      if (!savingAvailable)
        const Text('PRACTICE BEST SAVING UNAVAILABLE',
            style: StrikerText.statLabel),
    ]),
  );
}
