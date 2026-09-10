/// OAuth client IDs. Pass at build time:
///
/// ```
/// flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=....apps.googleusercontent.com \
///   --dart-define=GOOGLE_IOS_CLIENT_ID=....apps.googleusercontent.com
/// ```
///
/// Android needs the *web* client ID as [googleServerClientId].
/// iOS also needs the iOS client ID in Info.plist (see AuthSecrets.xcconfig).
class AuthConfig {
  const AuthConfig({
    this.googleServerClientId = '',
    this.googleIosClientId = '',
  });

  final String googleServerClientId;
  final String googleIosClientId;

  factory AuthConfig.fromEnvironment() => const AuthConfig(
        googleServerClientId:
            String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
        googleIosClientId: String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
      );

  bool get googleReady =>
      googleServerClientId.isNotEmpty || googleIosClientId.isNotEmpty;
}
