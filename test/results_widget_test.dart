import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_touch_striker/game/striker_game.dart';
import 'package:one_touch_striker/main.dart';
import 'package:one_touch_striker/ui/run_summary.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Future<void> tapAction(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pump(const Duration(milliseconds: 50));
}

StrikerGame currentGame(WidgetTester tester) =>
    tester.widget<GameWidget<StrikerGame>>(
        find.byType(GameWidget<StrikerGame>)).game!;

void cornerGoal(StrikerGame game) {
  game.model.finishShot(goal: true, corner: true, text: 'CORNER');
  game.update(0); // Deliver the normal result callback to the app shell.
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('results celebrate a beaten record but not a tied replay', (tester) async {
    final prefs = SharedPreferencesAsync();
    await prefs.setInt('best_score', 2);
    await tester.pumpWidget(const StrikerApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tapAction(tester, 'LET’S PLAY  →');
    final game = currentGame(tester);
    cornerGoal(game);
    game.endRun();
    await tester.pump();
    expect(find.text('NEW PERSONAL BEST!'), findsOneWidget);
    expect(find.text('ACCURACY'), findsOneWidget);
    expect(find.text('LONGEST STREAK'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(await prefs.getInt('best_score'), 3);

    await tapAction(tester, 'PLAY AGAIN  ↻');
    cornerGoal(game);
    game.endRun();
    await tester.pump();
    expect(find.text('NEW PERSONAL BEST!'), findsNothing);
    expect(tester.widget<RunSummary>(find.byType(RunSummary)).personalBest, isFalse);
    expect(await prefs.getInt('best_score'), 3);
  });

  testWidgets('a lower-scoring result keeps the saved record and shows its stats', (tester) async {
    final prefs = SharedPreferencesAsync();
    await prefs.setInt('best_score', 20);
    await tester.pumpWidget(const StrikerApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tapAction(tester, 'LET’S PLAY  →');
    final game = currentGame(tester);
    cornerGoal(game);
    game.model.finishShot(goal: false, text: 'MISS');
    game.update(0);
    game.endRun();
    await tester.pump();
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('NEW PERSONAL BEST!'), findsNothing);
    expect(await prefs.getInt('best_score'), 20);
  });
}
