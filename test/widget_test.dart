import 'package:flutter_test/flutter_test.dart';
import 'package:one_touch_striker/main.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('home screen presents the play action', (tester) async {
    await tester.pumpWidget(const StrikerApp());
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('ONE TAP.\nALL GLORY.'), findsOneWidget);
    expect(find.text('LET’S PLAY  →'), findsOneWidget);
    await tester.ensureVisible(find.text('LET’S PLAY  →'));
    await tester.tap(find.text('LET’S PLAY  →'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('ONE TAP.\nALL GLORY.'), findsNothing);
    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(find.text('TAP THE GLOW. LOCK THE ARROW.'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('Aiming')));
    await tester.pump();
    expect(find.text('TAP THE GLOW. LOCK THE ARROW.'), findsNothing);
    expect(find.text('SHOT AWAY…'), findsOneWidget);
  });

  testWidgets('pause overlay can end the run', (tester) async {
    await tester.pumpWidget(const StrikerApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.ensureVisible(find.text('LET’S PLAY  →'));
    await tester.tap(find.text('LET’S PLAY  →'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(find.text('END RUN'), findsOneWidget);
    await tester.tap(find.text('END RUN'));
    await tester.pump();
    expect(find.text('FULL TIME'), findsOneWidget);
    expect(find.text('PLAY AGAIN  ↻'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsNothing);
  });
}
