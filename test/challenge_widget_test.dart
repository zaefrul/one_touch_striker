import 'package:flutter_test/flutter_test.dart';
import 'package:one_touch_striker/game/challenge_stage.dart';
import 'package:one_touch_striker/main.dart';
import 'package:one_touch_striker/game/striker_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Future<void> tapVisible(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('stage briefing, end and retry stay in the same challenge', (tester) async {
    await tester.pumpWidget(StrikerApp(audio: StrikerAudio.silent()));
    await tester.pump(const Duration(milliseconds: 50));
    await tapVisible(tester, 'PLAY CHALLENGES');
    expect(find.text('12 stages.\nEarn your stars.'), findsOneWidget);
    await tapVisible(tester, 'PLAY STAGE 1  →');
    expect(find.text('Score 3 goals'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsNothing);
    await tapVisible(tester, 'START STAGE  →');
    expect(find.byTooltip('Pause'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    await tapVisible(tester, 'END STAGE');
    expect(find.text('RETRY STAGE  ↻'), findsOneWidget);
    expect(find.text('NEXT STAGE  →'), findsNothing);
    await tapVisible(tester, 'RETRY STAGE  ↻');
    expect(find.text('START STAGE  →'), findsNothing);
    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(find.text('0/3 GOALS'), findsOneWidget);
    expect(find.text('0/2 GOALS TO FIRE'), findsOneWidget);
  });

  testWidgets('saved stars unlock the timed stage and pause freezes its clock', (tester) async {
    await SharedPreferencesAsync().setStringList(
        ChallengeProgress.storageKey, ['3', '3', '3', '0', '0', '0']);
    await tester.pumpWidget(StrikerApp(audio: StrikerAudio.silent()));
    await tester.pump(const Duration(milliseconds: 50));
    await tapVisible(tester, 'PLAY CHALLENGES');
    expect(find.text('9/36 stars collected'), findsOneWidget);
    await tapVisible(tester, 'PLAY STAGE 4  →');
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('25s'), findsOneWidget);
    await tapVisible(tester, 'START STAGE  →');
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('25s'), findsOneWidget);
    await tester.tap(find.byTooltip('Resume'));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('25s'), findsNothing);
    expect(find.text('24s'), findsOneWidget);
  });

  testWidgets('a legacy campaign save opens stage seven from the map', (tester) async {
    await SharedPreferencesAsync().setStringList(
        ChallengeProgress.storageKey, ['3', '3', '3', '3', '3', '3']);
    await tester.pumpWidget(StrikerApp(audio: StrikerAudio.silent()));
    await tester.pump(const Duration(milliseconds: 50));
    await tapVisible(tester, 'PLAY CHALLENGES');
    expect(find.text('18/36 stars collected'), findsOneWidget);
    await tapVisible(tester, 'PLAY STAGE 7  →');
    expect(find.text('Pressure Cooker'), findsOneWidget);
    expect(find.text('Score 5 goals'), findsOneWidget);
    await tapVisible(tester, 'START STAGE  →');
    expect(find.text('0/5 GOALS'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsOneWidget);
  });

  testWidgets('the triple-wall stage renders its third defender on entry', (tester) async {
    await SharedPreferencesAsync().setStringList(
        ChallengeProgress.storageKey, List.filled(8, '3'));
    await tester.pumpWidget(StrikerApp(audio: StrikerAudio.silent()));
    await tester.pump(const Duration(milliseconds: 50));
    await tapVisible(tester, 'PLAY CHALLENGES');
    await tapVisible(tester, 'PLAY STAGE 9  →');
    await tapVisible(tester, 'START STAGE  →');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('0/5 GOALS'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsOneWidget);
  });

  testWidgets('saved sound preference loads and a toggle persists for relaunch', (tester) async {
    final prefs = SharedPreferencesAsync();
    await prefs.setBool('sound', false);
    await tester.pumpWidget(StrikerApp(audio: StrikerAudio.silent()));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byTooltip('Turn sound on'), findsOneWidget);
    await tester.tap(find.byTooltip('Turn sound on'));
    await tester.pump();
    expect(find.byTooltip('Turn sound off'), findsOneWidget);
    expect(await prefs.getBool('sound'), isTrue);
  });
}
