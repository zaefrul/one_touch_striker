import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_touch_striker/game/challenge_stage.dart';
import 'package:one_touch_striker/game/keeper_style.dart';
import 'package:one_touch_striker/game/rival_ledger.dart';
import 'package:one_touch_striker/game/star_rewards.dart';
import 'package:one_touch_striker/game/striker_audio.dart';
import 'package:one_touch_striker/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// Prepared sources only. These widget cases were not executed for publication.
Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> launch(WidgetTester tester) async {
  await tester.pumpWidget(StrikerApp(audio: StrikerAudio.silent()));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('saved stars unlock equipment and equipped ball survives relaunch', (tester) async {
    final prefs = SharedPreferencesAsync();
    await prefs.setStringList(ChallengeProgress.storageKey, ['3']);
    await launch(tester);
    await tapText(tester, 'STAR REWARDS');
    final neon = find.byKey(const ValueKey('equip_neonBall'));
    final retro = find.byKey(const ValueKey('equip_retroBall'));
    expect(tester.widget<OutlinedButton>(neon).onPressed, isNotNull);
    expect(tester.widget<OutlinedButton>(retro).onPressed, isNull);
    await tester.ensureVisible(neon);
    await tester.tap(neon);
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.widget<OutlinedButton>(neon).onPressed, isNull);
    final saved = CosmeticSelection();
    expect(saved.restore(await prefs.getString(CosmeticSelection.storageKey), 3), isTrue);
    expect(saved.ball, StarReward.neonBall);
    expect(await prefs.getStringList(ChallengeProgress.storageKey), ['3']);

    await tester.pumpWidget(const SizedBox.shrink());
    await launch(tester);
    await tapText(tester, 'STAR REWARDS');
    expect(find.byTooltip('Neon Ball equipped'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    expect(find.text('ONE TAP.\nALL GLORY.'), findsOneWidget);
  });

  testWidgets('completed legacy campaign offers missing showdowns without invented trophies', (tester) async {
    await SharedPreferencesAsync().setStringList(
        ChallengeProgress.storageKey, List.filled(12, '3'));
    await launch(tester);
    await tapText(tester, 'PLAY CHALLENGES');
    expect(find.text('36/36 stars collected'), findsOneWidget);
    expect(find.text('0/4 showdown trophies'), findsOneWidget);
    await tapText(tester, 'STAR REWARDS');
    expect(find.byKey(const ValueKey('equip_championBall')), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    expect(find.text('12 stages.\nEarn your stars.'), findsOneWidget);
    await tapText(tester, 'WIN CORNER DUEL  →');
    expect(find.text('Corner Artist'), findsOneWidget);
    expect(find.text('The Sentinel · You 0 · Keeper 0'), findsOneWidget);
  });

  testWidgets('ending a started challenge persists one rival loss across refreshes', (tester) async {
    final prefs = SharedPreferencesAsync();
    await launch(tester);
    await tapText(tester, 'PLAY CHALLENGES');
    await tapText(tester, 'PLAY STAGE 1  →');
    await tapText(tester, 'START STAGE  →');
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(find.text('Ending this attempt gives the keeper a win.'), findsOneWidget);
    await tapText(tester, 'END STAGE');
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('The Sweeper · You 0 · Keeper 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Turn sound off'));
    await tester.pump(const Duration(milliseconds: 50));
    final saved = RivalLedger();
    expect(saved.restore(await prefs.getString(RivalLedger.storageKey)), isTrue);
    expect(saved.against(KeeperStyle.sweeper).losses, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await launch(tester);
    await tapText(tester, 'PLAY CHALLENGES');
    await tapText(tester, 'PLAY STAGE 1  →');
    expect(find.text('The Sweeper · You 0 · Keeper 1'), findsOneWidget);
    // Leaving a briefing has never started an attempt and must add no loss.
    await tapText(tester, 'STAGE SELECT');
    await tester.pump(const Duration(milliseconds: 50));
    final afterBriefing = RivalLedger()
      ..restore(await prefs.getString(RivalLedger.storageKey));
    expect(afterBriefing.against(KeeperStyle.sweeper).losses, 1);
  });
}
