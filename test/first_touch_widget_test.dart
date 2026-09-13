import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_touch_striker/game/challenge_stage.dart';
import 'package:one_touch_striker/game/first_touch_guide.dart';
import 'package:one_touch_striker/game/match_model.dart';
import 'package:one_touch_striker/game/rival_ledger.dart';
import 'package:one_touch_striker/game/striker_audio.dart';
import 'package:one_touch_striker/game/striker_game.dart';
import 'package:one_touch_striker/game/tutorial_progress.dart';
import 'package:one_touch_striker/main.dart';
import 'package:one_touch_striker/ui/shot_gesture_surface.dart';
import 'package:one_touch_striker/ui/first_touch_coach.dart';
import 'package:one_touch_striker/ui/tutorial_screen.dart';
import 'package:one_touch_striker/ui/welcome_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// Prepared for the owner's local validation; not executed for publication.
Future<void> frames(WidgetTester tester, [int count = 35]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> tapText(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await frames(tester);
}

Future<void> launch(WidgetTester tester) async {
  await tester.pumpWidget(StrikerApp(audio: StrikerAudio.silent()));
  await frames(tester);
}

StrikerGame mainGame(WidgetTester tester) => tester
    .widgetList<GameWidget<StrikerGame>>(find.byType(GameWidget<StrikerGame>, skipOffstage: false))
    .map((widget) => widget.game!).firstWhere((game) => game.model is! TutorialMatchModel);

StrikerGame lessonGame(WidgetTester tester) => tester.widget<GameWidget<StrikerGame>>(
    find.descendant(of: find.byType(TutorialScreen), matching: find.byType(GameWidget<StrikerGame>))).game!;

void resolveGoal(StrikerGame game) {
  expect(game.shoot(), isTrue);
  game.model.finishShot(goal: true, text: 'GOAL');
  game.update(0);
  for (var frame = 0; frame < 180 && game.model.phase == MatchPhase.result; frame++) {
    game.update(1 / 60);
  }
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('fresh launch opens the welcome page; skip intro persists without earning stars', (tester) async {
    await launch(tester);
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(find.byType(TutorialScreen), findsNothing);
    expect(find.text('WELCOME'), findsOneWidget);
    expect(find.text('ONE TAP.\nALL GLORY.'), findsOneWidget);
    expect(mainGame(tester).model.phase, MatchPhase.ready);
    await tapText(tester, 'Skip intro');
    expect(find.byType(WelcomePage), findsNothing);
    expect(find.byType(TutorialScreen), findsNothing);
    expect(find.text('Score 3 goals'), findsOneWidget);
    expect(find.text('YOUR FIRST MATCH'), findsOneWidget);
    expect(mainGame(tester).model.phase, MatchPhase.stageIntro);
    expect(mainGame(tester).model.isGuidedFirstMatch, isTrue);
    final prefs = SharedPreferencesAsync();
    expect(await prefs.getStringList(ChallengeProgress.storageKey), isNull);
    expect(await prefs.getString(RivalLedger.storageKey), isNull);
    final saved = TutorialProgress()..restore(await prefs.getString(TutorialProgress.storageKey));
    expect(saved.needs(TutorialLesson.aim), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await launch(tester);
    expect(find.byType(WelcomePage), findsNothing);
    expect(find.byType(TutorialScreen), findsNothing);
  });

  testWidgets('welcome pages lead into the aim lesson, then the first match', (tester) async {
    await launch(tester);
    expect(find.text('WELCOME · 1/2'), findsOneWidget);
    await tapText(tester, 'NEXT  →');
    expect(find.text('WELCOME · 2/2'), findsOneWidget);
    expect(find.text('HOW TO SHOOT'), findsOneWidget);
    await tapText(tester, 'LET’S PLAY  →');
    await frames(tester);
    expect(find.byType(WelcomePage), findsNothing);
    expect(find.byType(TutorialScreen), findsOneWidget);
    expect(find.text('Aim & release'), findsOneWidget);
    expect(mainGame(tester).model.phase, MatchPhase.ready);
    await tapText(tester, 'Skip tutorials');
    expect(mainGame(tester).model.phase, MatchPhase.stageIntro);
    expect(mainGame(tester).model.stageIndex, 0);
  });

  testWidgets('the guided first match shows the live coach and no Fire modal', (tester) async {
    await launch(tester);
    await tapText(tester, 'NEXT  →');
    await tapText(tester, 'LET’S PLAY  →');
    await frames(tester);
    // Pass only the aim lesson, so the Fire lesson is still outstanding.
    final lesson = lessonGame(tester);
    final lessonSurface = find.descendant(of: find.byType(TutorialScreen),
        matching: find.byType(ShotGestureSurface));
    final lessonPointer = await tester.startGesture(tester.getCenter(lessonSurface));
    await tester.pump(const Duration(milliseconds: 50));
    await lessonPointer.up();
    lesson.model.finishShot(goal: false, text: 'WIDE');
    lesson.update(0);
    await tester.pump();
    expect(find.text('Gesture learned!'), findsOneWidget);
    await tapText(tester, 'LET’S PLAY');
    final match = mainGame(tester);
    expect(match.model.phase, MatchPhase.stageIntro);
    expect(match.model.isGuidedFirstMatch, isTrue);
    expect(find.text('YOUR FIRST MATCH'), findsOneWidget);
    expect(find.text(FirstTouchLesson.aim.instruction), findsOneWidget);
    await tapText(tester, 'START STAGE  →');
    expect(match.model.phase, MatchPhase.aiming);
    expect(find.byType(FirstTouchCoach), findsOneWidget);
    expect(find.text('FOLLOW THE ARROW'), findsOneWidget);
    resolveGoal(match);
    resolveGoal(match);
    await frames(tester);
    expect(match.model.fireReady, isTrue);
    expect(find.byType(TutorialScreen), findsNothing);
    expect(find.text('YOUR FIRE SHOT IS READY'), findsOneWidget);
    // Holding a shot hides the coach so the release label stays readable.
    final pointer = await tester.startGesture(tester.getCenter(find.byType(ShotGestureSurface)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(FirstTouchCoach), findsNothing);
    await pointer.up();
    await frames(tester);
    // The held release was a real shot; only its outcome, never a lesson, counts.
    expect(match.model.resolvedShots + (match.model.phase == MatchPhase.flying ? 1 : 0), 3);
    expect(await SharedPreferencesAsync().getStringList(ChallengeProgress.storageKey), isNull);
  });

  testWidgets('a first clear shows what comes next, then retires the coach', (tester) async {
    await launch(tester);
    await tapText(tester, 'Skip intro');
    await tapText(tester, 'START STAGE  →');
    final match = mainGame(tester);
    for (var i = 0; i < 3; i++) {
      resolveGoal(match);
    }
    await frames(tester);
    expect(match.model.phase, MatchPhase.stageCleared);
    expect(match.model.isGuidedFirstMatch, isTrue);
    expect(find.textContaining('First match cleared!'), findsOneWidget);
    expect(find.byType(FirstTouchCoach), findsNothing);
    final savedStars = await SharedPreferencesAsync().getStringList(ChallengeProgress.storageKey);
    expect(savedStars?.first, '3');
    await tapText(tester, 'PLAY THIS STAGE AGAIN');
    expect(match.model.phase, MatchPhase.aiming);
    expect(match.model.isGuidedFirstMatch, isFalse);
    expect(find.byType(FirstTouchCoach), findsNothing);
  });

  testWidgets('an actual released gesture is learned even when its shot misses', (tester) async {
    await launch(tester);
    await tapText(tester, 'NEXT  →');
    await tapText(tester, 'LET’S PLAY  →');
    await frames(tester);
    final game = lessonGame(tester);
    final surface = find.descendant(of: find.byType(TutorialScreen),
        matching: find.byType(ShotGestureSurface));
    final pointer = await tester.startGesture(tester.getCenter(surface));
    await tester.pump(const Duration(milliseconds: 50));
    await pointer.up();
    game.model.finishShot(goal: false, text: 'WIDE');
    game.update(0);
    await tester.pump();
    expect(find.text('Gesture learned!'), findsOneWidget);
    expect(mainGame(tester).model.misses, 0);
    await tapText(tester, 'LET’S PLAY');
    expect(mainGame(tester).model.phase, MatchPhase.stageIntro);
    final saved = TutorialProgress()..restore(
        await SharedPreferencesAsync().getString(TutorialProgress.storageKey));
    expect(saved.needs(TutorialLesson.aim), isFalse);
    expect(saved.needs(TutorialLesson.curveLeft), isTrue);
  });

  testWidgets('contextual Fire lesson freezes a timed match and leaves charge intact', (tester) async {
    final prefs = SharedPreferencesAsync();
    final learned = TutorialProgress();
    for (final lesson in TutorialLesson.values.where((lesson) => lesson != TutorialLesson.fire)) {
      learned.complete(lesson);
    }
    await prefs.setString(TutorialProgress.storageKey, learned.encode());
    await prefs.setStringList(ChallengeProgress.storageKey, ['3', '3', '3']);
    await launch(tester);
    await tapText(tester, 'CONTINUE · STAGE 4  →');
    await tapText(tester, 'START STAGE  →');
    final match = mainGame(tester);
    resolveGoal(match);
    resolveGoal(match);
    await frames(tester);
    expect(find.byType(TutorialScreen), findsOneWidget);
    final seconds = match.model.secondsRemaining;
    final charge = match.model.fireCharge;
    await frames(tester, 80);
    expect(match.model.secondsRemaining, seconds);
    expect(match.model.goals, 2);
    await tapText(tester, 'Skip tutorials');
    expect(match.model.fireCharge, charge);
    expect(match.model.fireReady, isTrue);
    expect(match.model.misses, 0);
    expect(await prefs.getStringList(ChallengeProgress.storageKey), ['3', '3', '3']);
    expect(await prefs.getString(RivalLedger.storageKey), isNull);
  });

  testWidgets('existing stars bypass first-launch tutorial and replay remains available', (tester) async {
    await SharedPreferencesAsync().setStringList(ChallengeProgress.storageKey, ['3']);
    await launch(tester);
    expect(find.byType(WelcomePage), findsNothing);
    expect(find.byType(TutorialScreen), findsNothing);
    expect(find.text('CONTINUE · STAGE 2  →'), findsOneWidget);
    await tapText(tester, 'PRACTICE ARENA');
    await tapText(tester, 'Replay tutorials');
    await tapText(tester, 'Aim & release');
    expect(find.byType(TutorialScreen), findsOneWidget);
  });
}
