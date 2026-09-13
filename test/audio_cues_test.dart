import 'package:flutter_test/flutter_test.dart';
import 'package:one_touch_striker/game/audio_cues.dart';
import 'package:one_touch_striker/game/match_model.dart';
import 'package:one_touch_striker/game/practice_drill.dart';

// Source for the owner's local run. No tests were executed for publication.
void main() {
  test('identical display text still produces distinct contact sounds', () {
    final match = MatchModel()..start();
    final soundtrack = MatchSoundtrack()..update(match);
    match.finishShot(goal: false, keeperSave: true, text: 'MISS');
    expect(soundtrack.update(match).cues,
        [ShotSound.save, ShotSound.groan]);
    match.finishShot(goal: false, blocked: true, text: 'MISS');
    expect(soundtrack.update(match).cues,
        [ShotSound.blocked, ShotSound.groan]);
    match.finishShot(goal: false, post: true, text: 'MISS');
    expect(soundtrack.update(match).cues,
        [ShotSound.post, ShotSound.groan]);
    match.finishShot(goal: false, text: 'MISS');
    expect(soundtrack.update(match).cues,
        [ShotSound.wide, ShotSound.groan]);
  });

  test('a refresh cannot replay a start, goal, charge or result sting', () {
    final match = MatchModel()..prepareStage(0);
    final soundtrack = MatchSoundtrack();
    expect(soundtrack.update(match).cues, isEmpty);
    match.startStage();
    expect(soundtrack.update(match).cues, [ShotSound.whistle]);
    expect(soundtrack.update(match).cues, isEmpty);
    match.finishShot(goal: true, text: 'GOAL');
    expect(soundtrack.update(match).cues, [ShotSound.net, ShotSound.cheer]);
    match.finishShot(goal: true, text: 'GOAL');
    expect(soundtrack.update(match).cues,
        [ShotSound.net, ShotSound.cheer, ShotSound.charge]);
    expect(soundtrack.update(match).cues, isEmpty);
    match.finishShot(goal: true, text: 'GOAL');
    expect(soundtrack.update(match).cues, [ShotSound.fireGoal, ShotSound.cheer]);
    match.endRun();
    expect(soundtrack.update(match).cues, [ShotSound.victory]);
    expect(soundtrack.update(match).cues, isEmpty);
    match.retryStage();
    expect(soundtrack.update(match).cues, [ShotSound.whistle]);
    expect(soundtrack.update(match).cues, isEmpty);
  });

  test('suspense begins on the final chance and ends with the attempt', () {
    final match = MatchModel()..start();
    expect(MatchSoundtrack.sceneFor(match).suspense, 0);
    match.misses = 2;
    expect(MatchSoundtrack.sceneFor(match).suspense, greaterThan(0));
    match.misses = 3;
    expect(MatchSoundtrack.sceneFor(match).suspense, 0);
    match.endRun();
    final scene = MatchSoundtrack.sceneFor(match);
    expect(scene.menu, greaterThan(0));
    expect(scene.stadium, 0);
    expect(scene.suspense, 0);
  });

  test('clock pressure rises in the final seconds without alarming in briefings', () {
    final match = MatchModel()..prepareStage(3);
    match.secondsRemaining = 4;
    expect(MatchSoundtrack.sceneFor(match).suspense, 0);
    match.startStage();
    match.secondsRemaining = 9;
    expect(MatchSoundtrack.sceneFor(match).suspense, 0);
    match.secondsRemaining = 8;
    final warning = MatchSoundtrack.sceneFor(match).suspense;
    expect(warning, greaterThan(0));
    match.secondsRemaining = 4;
    expect(MatchSoundtrack.sceneFor(match).suspense, greaterThan(warning));
    // A legal last-second shot keeps its tension until its outcome is known.
    match.phase = MatchPhase.flying;
    match.secondsRemaining = 0;
    expect(MatchSoundtrack.sceneFor(match).suspense, greaterThan(0));
    match.goals = match.stage!.target;
    expect(MatchSoundtrack.sceneFor(match).suspense, 0);
  });

  test('stands grow with progression while drills keep a quieter mix', () {
    final match = MatchModel()..prepareStage(0)..startStage();
    final academy = MatchSoundtrack.sceneFor(match).stadium;
    match.prepareStage(11);
    match.startStage();
    expect(MatchSoundtrack.sceneFor(match).stadium, greaterThan(academy));
    match.startPractice(PracticeDrill.corners);
    final soundtrack = MatchSoundtrack()..update(match);
    match.shoot();
    match.finishShot(goal: false, text: 'MISS');
    final frame = soundtrack.update(match);
    expect(frame.scene.stadium, lessThan(academy));
    expect(frame.scene.suspense, 0);
    expect(frame.cues, [ShotSound.wide]);
  });
}
