import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_touch_striker/game/striker_audio.dart';
import 'package:one_touch_striker/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// Silent injection checks app integration; native playback still needs a phone.
Future<void> tapText(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('saved master mute and each channel survive settings and relaunch', (tester) async {
    final prefs = SharedPreferencesAsync();
    await prefs.setBool('sound', false);
    await prefs.setBool('audio_music', false);
    var audio = StrikerAudio.silent();
    await tester.pumpWidget(StrikerApp(autoTutorials: false, audio: audio));
    await tester.pump(const Duration(milliseconds: 50));
    expect(audio.enabled, isFalse);
    expect(audio.mix.music, isFalse);
    expect(audio.mix.effects, isTrue);
    expect(audio.mix.crowd, isTrue);
    await tapText(tester, 'AUDIO MIX');
    await tester.tap(find.byKey(const ValueKey('audio_crowd')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('audio_effects')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('audio_master')));
    await tester.pump();
    expect(audio.enabled, isTrue);
    expect(audio.mix.music, isFalse);
    expect(audio.mix.effects, isFalse);
    expect(audio.mix.crowd, isFalse);
    expect(await prefs.getBool('sound'), isTrue);
    expect(await prefs.getBool('audio_crowd'), isFalse);
    expect(await prefs.getBool('audio_effects'), isFalse);
    await tapText(tester, 'DONE');
    await tester.pumpWidget(const SizedBox.shrink());
    audio = StrikerAudio.silent();
    await tester.pumpWidget(StrikerApp(autoTutorials: false, audio: audio));
    await tester.pump(const Duration(milliseconds: 50));
    expect(audio.enabled, isTrue);
    expect(audio.mix.music, isFalse);
    expect(audio.mix.effects, isFalse);
    expect(audio.mix.crowd, isFalse);
    await tester.tap(find.byTooltip('Turn sound off'));
    await tester.pump();
    expect(audio.enabled, isFalse);
  });

  testWidgets('menus return after backgrounding and matches stay paused until resume', (tester) async {
    final audio = StrikerAudio.silent();
    await tester.pumpWidget(StrikerApp(autoTutorials: false, audio: audio));
    await tester.pump(const Duration(milliseconds: 50));
    expect(audio.scene.menu, greaterThan(0));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(audio.suspended, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(audio.suspended, isFalse);
    await tapText(tester, 'LET’S PLAY  →');
    expect(audio.scene.menu, 0);
    expect(audio.scene.stadium, greaterThan(0));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(audio.suspended, isTrue);
    await tapText(tester, 'AUDIO MIX');
    await tapText(tester, 'DONE');
    expect(audio.suspended, isTrue);
    await tester.tap(find.byTooltip('Resume'));
    await tester.pump();
    expect(audio.suspended, isFalse);
    expect(audio.scene.menu, 0);
  });
}
