import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_touch_striker/account/account_sheet.dart';
import 'package:one_touch_striker/account/auth_service.dart';
import 'package:one_touch_striker/account/auth_user.dart';
import 'package:one_touch_striker/main.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'fake_auth_bridge.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<void> pumpPortrait(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('home screen shows Continue and Progress, then reaches the pitch',
      (tester) async {
    await pumpPortrait(tester, const StrikerApp());
    expect(find.text('ONE TAP.\nALL GLORY.'), findsOneWidget);
    expect(find.textContaining('CONTINUE'), findsOneWidget);
    expect(find.text('PROGRESS'), findsOneWidget);
    expect(find.byTooltip('Account'), findsOneWidget);
    await tester.tap(find.textContaining('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('PICK YOUR BALL'), findsOneWidget);
    expect(find.text('STRAIGHT'), findsWidgets);
    await tester.ensureVisible(find.text('KICK OFF'));
    await tester.tap(find.text('KICK OFF'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('PICK YOUR BALL'), findsNothing);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.text('TAP THE GLOW. LOCK THE ARROW.'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('Aiming')));
    await tester.pump();
    expect(find.text('TAP THE GLOW. LOCK THE ARROW.'), findsNothing);
    expect(find.text('SHOT AWAY…'), findsOneWidget);
  });

  testWidgets('pause overlay can end the substage', (tester) async {
    await pumpPortrait(tester, const StrikerApp());
    await tester.tap(find.textContaining('CONTINUE'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('KICK OFF'));
    await tester.tap(find.text('KICK OFF'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(find.text('END SUBSTAGE'), findsOneWidget);
    await tester.tap(find.text('END SUBSTAGE'));
    await tester.pump();
    expect(find.text('FULL TIME'), findsOneWidget);
    expect(find.text('REPLAY  ↻'), findsOneWidget);
    expect(find.text('MAP'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsNothing);
  });

  testWidgets('account sheet can sign in with google', (tester) async {
    final auth = AuthService(
      bridge: FakeAuthBridge(
        google: const SocialProfile(
          id: 'g-ui',
          name: 'Zae',
          email: 'zae@example.com',
          provider: AuthProvider.google,
        ),
      ),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AccountSheet(auth: auth)),
    ));
    await tester.pump();
    expect(find.text('CONTINUE WITH GOOGLE'), findsOneWidget);
    await tester.tap(find.text('CONTINUE WITH GOOGLE'));
    await tester.pump();
    expect(auth.signedIn, isTrue);
    expect(find.text('ZAE'), findsOneWidget);
  });
}
