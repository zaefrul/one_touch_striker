import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'auth_config.dart';
import 'auth_user.dart';

abstract class AuthBridge {
  Future<SocialProfile> signInWithGoogle();
  Future<SocialProfile> signInWithApple();
  Future<void> signOutGoogle();
  Future<bool> get appleAvailable;
}

class DefaultAuthBridge implements AuthBridge {
  DefaultAuthBridge({AuthConfig? config})
      : _config = config ?? AuthConfig.fromEnvironment();

  final AuthConfig _config;
  bool _googleReady = false;

  Future<void> _ensureGoogle() async {
    if (_googleReady) {
      return;
    }
    await GoogleSignIn.instance.initialize(
      clientId:
          _config.googleIosClientId.isEmpty ? null : _config.googleIosClientId,
      serverClientId: _config.googleServerClientId.isEmpty
          ? null
          : _config.googleServerClientId,
    );
    _googleReady = true;
  }

  @override
  Future<SocialProfile> signInWithGoogle() async {
    await _ensureGoogle();
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw const AuthFailure('Google Sign-In is not available on this device.');
    }
    try {
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile'],
      );
      return SocialProfile(
        id: account.id,
        name: account.displayName ?? '',
        email: account.email,
        provider: AuthProvider.google,
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthCanceled();
      }
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError) {
        throw const AuthFailure(
            'Google Sign-In is not configured. Add your OAuth client IDs.');
      }
      throw AuthFailure(error.description ?? 'Google Sign-In failed.');
    }
  }

  @override
  Future<SocialProfile> signInWithApple() async {
    if (!await appleAvailable) {
      throw const AuthFailure('Sign in with Apple is not available here.');
    }
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final given = credential.givenName ?? '';
      final family = credential.familyName ?? '';
      final name = '$given $family'.trim();
      return SocialProfile(
        id: credential.userIdentifier ?? '',
        name: name,
        email: credential.email,
        provider: AuthProvider.apple,
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const AuthCanceled();
      }
      throw AuthFailure(error.message);
    }
  }

  @override
  Future<void> signOutGoogle() async {
    if (!_googleReady) {
      return;
    }
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Local session is cleared either way.
    }
  }

  @override
  Future<bool> get appleAvailable async {
    if (kIsWeb) {
      return false;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return SignInWithApple.isAvailable();
      default:
        return false;
    }
  }
}
