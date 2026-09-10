import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_bridge.dart';
import 'auth_user.dart';

class AuthService {
  AuthService({AuthBridge? bridge, SharedPreferencesAsync? prefs})
      : _bridge = bridge ?? DefaultAuthBridge(),
        _prefs = prefs ?? SharedPreferencesAsync();

  static const sessionKey = 'auth_user';

  final AuthBridge _bridge;
  final SharedPreferencesAsync _prefs;
  AuthUser? user;

  bool get signedIn => user != null;

  Future<void> restore() async {
    try {
      final raw = await _prefs.getString(sessionKey);
      if (raw == null || raw.isEmpty) {
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final saved =
            AuthUser.fromJson(Map<String, Object?>.from(decoded));
        if (saved.id.isNotEmpty) {
          user = saved;
        }
      }
    } catch (_) {
      user = null;
    }
  }

  Future<AuthUser> signInWithGoogle() => _signIn(_bridge.signInWithGoogle);

  Future<AuthUser> signInWithApple() => _signIn(_bridge.signInWithApple);

  Future<AuthUser> _signIn(Future<SocialProfile> Function() signIn) async {
    final profile = await signIn();
    if (profile.id.isEmpty) {
      throw const AuthFailure('Sign-in did not return an account.');
    }
    final next = AuthUser(
      id: profile.id,
      name: _displayName(profile),
      email: profile.email ??
          (user?.id == profile.id ? user?.email : null),
      provider: profile.provider,
    );
    user = next;
    await _persist();
    return next;
  }

  String _displayName(SocialProfile profile) {
    if (profile.name.trim().isNotEmpty) {
      return profile.name.trim();
    }
    if (user?.id == profile.id && (user?.name.isNotEmpty ?? false)) {
      return user!.name;
    }
    final email = profile.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'Player';
  }

  Future<void> signOut() async {
    await _bridge.signOutGoogle();
    user = null;
    try {
      await _prefs.remove(sessionKey);
    } catch (_) {
      // Still signed out in memory.
    }
  }

  Future<bool> get appleAvailable => _bridge.appleAvailable;

  Future<void> _persist() async {
    final current = user;
    if (current == null) {
      return;
    }
    await _prefs.setString(sessionKey, jsonEncode(current.toJson()));
  }
}
