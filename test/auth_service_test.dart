import 'package:flutter_test/flutter_test.dart';
import 'package:one_touch_striker/account/auth_service.dart';
import 'package:one_touch_striker/account/auth_user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'fake_auth_bridge.dart';

void main() {
  late SharedPreferencesAsync prefs;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = SharedPreferencesAsync();
  });

  test('google sign-in persists and restores the session', () async {
    final bridge = FakeAuthBridge(
      google: const SocialProfile(
        id: 'g-1',
        name: 'Zae Frul',
        email: 'zae@example.com',
        provider: AuthProvider.google,
      ),
    );
    final auth = AuthService(bridge: bridge, prefs: prefs);
    final user = await auth.signInWithGoogle();
    expect(user.name, 'Zae Frul');
    expect(user.initials, 'ZF');
    expect(auth.signedIn, isTrue);

    final again = AuthService(bridge: FakeAuthBridge(), prefs: prefs);
    await again.restore();
    expect(again.user?.id, 'g-1');
    expect(again.user?.provider, AuthProvider.google);
    expect(again.user?.email, 'zae@example.com');
  });

  test('apple sign-in keeps the first name when a later login is nameless',
      () async {
    final bridge = FakeAuthBridge(
      apple: const SocialProfile(
        id: 'a-1',
        name: 'Alex Keeper',
        email: 'alex@privaterelay.appleid.com',
        provider: AuthProvider.apple,
      ),
    );
    final auth = AuthService(bridge: bridge, prefs: prefs);
    await auth.signInWithApple();
    bridge.apple = const SocialProfile(
      id: 'a-1',
      name: '',
      provider: AuthProvider.apple,
    );
    final again = await auth.signInWithApple();
    expect(again.name, 'Alex Keeper');
  });

  test('canceled sign-in leaves the guest session in place', () async {
    final auth = AuthService(bridge: FakeAuthBridge(), prefs: prefs);
    await expectLater(auth.signInWithGoogle(), throwsA(isA<AuthCanceled>()));
    expect(auth.user, isNull);
  });

  test('sign out clears the saved session', () async {
    final bridge = FakeAuthBridge(
      google: const SocialProfile(
        id: 'g-2',
        name: 'Player',
        provider: AuthProvider.google,
      ),
    );
    final auth = AuthService(bridge: bridge, prefs: prefs);
    await auth.signInWithGoogle();
    await auth.signOut();
    expect(auth.user, isNull);
    expect(bridge.googleSignedOut, isTrue);

    final again = AuthService(bridge: FakeAuthBridge(), prefs: prefs);
    await again.restore();
    expect(again.user, isNull);
  });
}
