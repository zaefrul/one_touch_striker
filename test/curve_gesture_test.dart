import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_touch_striker/game/match_model.dart';
import 'package:one_touch_striker/game/striker_audio.dart';
import 'package:one_touch_striker/game/striker_game.dart';
import 'package:one_touch_striker/main.dart';
import 'package:one_touch_striker/ui/shot_gesture_surface.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// Pointer and app integration sources prepared for the owner's local testing.
// No widget tests or app runs were executed for publication.
Future<StrikerGame> launchMatch(WidgetTester tester) async {
  await tester.pumpWidget(StrikerApp(audio: StrikerAudio.silent()));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.ensureVisible(find.text('PLAY FIRST MATCH  →'));
  await tester.tap(find.text('PLAY FIRST MATCH  →'));
  await tester.pump(const Duration(milliseconds: 50));
  return tester.widget<GameWidget<StrikerGame>>(
      find.byType(GameWidget<StrikerGame>)).game!;
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('the first finger owns the preview and release launches exactly once', (tester) async {
    final game = await launchMatch(tester);
    final bounds = tester.getRect(find.byType(ShotGestureSurface));
    final scale = math.min(bounds.width / 400, bounds.height / 640);
    final first = await tester.startGesture(bounds.center, pointer: 1);
    final initial = game.model.previewTargetX;
    await tester.pump(const Duration(milliseconds: 50));
    expect(game.model.phase, MatchPhase.aiming);
    expect(game.model.previewTargetX, initial);
    expect(game.model.keeper.shots, 0);
    final second = await tester.startGesture(bounds.center, pointer: 2);
    await second.moveBy(Offset(100 * scale, 0));
    await second.up();
    expect(game.model.preparedSpin, 0);
    expect(game.model.isPreparingShot, isTrue);
    await first.moveBy(Offset(-100 * scale, 0));
    final target = game.model.previewTargetX;
    expect(game.model.preparedSpin, closeTo(-1, 1e-6));
    await first.up();
    await tester.pump();
    expect(game.model.phase, MatchPhase.flying);
    expect(game.model.shotTargetX, target);
    expect(game.model.keeper.shots, 1);
    final late = await tester.startGesture(bounds.center, pointer: 3);
    await late.moveBy(Offset(100 * scale, 0));
    await late.up();
    expect(game.model.shotTargetX, target);
    expect(game.model.keeper.shots, 1);
  });

  testWidgets('pause and resume discard a held pointer without firing', (tester) async {
    final game = await launchMatch(tester);
    final first = await tester.startGesture(
        tester.getCenter(find.byType(ShotGestureSurface)), pointer: 1);
    await tester.tap(find.byTooltip('Pause'), pointer: 2);
    await tester.pump();
    expect(game.model.isPreparingShot, isFalse);
    await tester.tap(find.byTooltip('Resume'), pointer: 2);
    await tester.pump();
    await first.up();
    expect(game.model.phase, MatchPhase.aiming);
    expect(game.model.keeper.shots, 0);
    expect(game.model.misses, 0);
  });

  testWidgets('platform cancellation and leaving the pitch discard the shot', (tester) async {
    final game = await launchMatch(tester);
    final center = tester.getCenter(find.byType(ShotGestureSurface));
    final cancelled = await tester.startGesture(center, pointer: 1);
    await cancelled.cancel();
    expect(game.model.isPreparingShot, isFalse);
    final outside = await tester.startGesture(center, pointer: 2);
    await outside.moveTo(const Offset(-10, -10));
    await outside.up();
    expect(game.model.isPreparingShot, isFalse);
    expect(game.model.phase, MatchPhase.aiming);
    expect(game.model.keeper.shots, 0);
    expect(game.model.misses, 0);
  });

  testWidgets('drag scale follows the fitted pitch and resize cancels ownership', (tester) async {
    final match = MatchModel()..start();
    Widget surface(double width, double height) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: SizedBox(width: width, height: height,
        child: ShotGestureSurface(enabled: true, onBegin: match.beginShot,
          onDrag: match.adjustCurve, onRelease: () { match.releaseShot(); },
          onCancel: match.cancelShot, onAccessibleShot: () { match.shoot(); },
          child: const ColoredBox(color: Colors.green)),
      )),
    );
    // A wide viewport with horizontal letterboxing: the pitch is only 200 wide.
    await tester.pumpWidget(surface(300, 320));
    var center = tester.getCenter(find.byType(ShotGestureSurface));
    final first = await tester.startGesture(center, pointer: 1);
    await first.moveBy(const Offset(50, 0));
    expect(match.preparedSpin, 1);
    await first.cancel();
    await tester.pumpWidget(surface(300, 480));
    center = tester.getCenter(find.byType(ShotGestureSurface));
    final second = await tester.startGesture(center, pointer: 2);
    await second.moveBy(const Offset(75, 0));
    expect(match.preparedSpin, 1);
    await tester.pumpWidget(surface(200, 320));
    expect(match.isPreparingShot, isFalse);
    await second.up();
    expect(match.phase, MatchPhase.aiming);
  });

  testWidgets('vertical movement stays straight and semantic activation still shoots', (tester) async {
    final game = await launchMatch(tester);
    final bounds = tester.getRect(find.byType(ShotGestureSurface));
    final gesture = await tester.startGesture(bounds.center, pointer: 1);
    await gesture.moveBy(Offset(0, bounds.height * .1));
    expect(game.model.preparedSpin, 0);
    await gesture.cancel();
    final semantics = tester.widget<Semantics>(find.byWidgetPredicate((widget) =>
        widget is Semantics &&
        (widget.properties.label ?? '').startsWith('Football pitch.')));
    expect(semantics.properties.onTap, isNotNull);
    semantics.properties.onTap!();
    expect(game.model.phase, MatchPhase.flying);
    expect(game.model.shotSpin, 0);
    expect(game.model.keeper.shots, 1);
    await tester.pump();
  });
}
