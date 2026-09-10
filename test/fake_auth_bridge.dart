import 'package:one_touch_striker/account/auth_bridge.dart';
import 'package:one_touch_striker/account/auth_user.dart';

class FakeAuthBridge implements AuthBridge {
  FakeAuthBridge({
    this.google,
    this.apple,
    this.appleSupported = false,
  });

  SocialProfile? google;
  SocialProfile? apple;
  bool appleSupported;
  bool googleSignedOut = false;

  @override
  Future<SocialProfile> signInWithGoogle() async {
    final profile = google;
    if (profile == null) {
      throw const AuthCanceled();
    }
    return profile;
  }

  @override
  Future<SocialProfile> signInWithApple() async {
    final profile = apple;
    if (profile == null) {
      throw const AuthCanceled();
    }
    return profile;
  }

  @override
  Future<void> signOutGoogle() async {
    googleSignedOut = true;
  }

  @override
  Future<bool> get appleAvailable async => appleSupported;
}
