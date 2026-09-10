import 'package:shared_preferences/shared_preferences.dart';
import 'account/auth_service.dart';
import 'progress/progress_store.dart';

class StrikerSession {
  StrikerSession({
    AuthService? auth,
    ProgressStore? progress,
    SharedPreferencesAsync? prefs,
  }) : this._withPrefs(prefs ?? SharedPreferencesAsync(), auth, progress);

  StrikerSession._withPrefs(
    this.prefs,
    AuthService? auth,
    ProgressStore? progress,
  )   : progress = progress ?? ProgressStore(prefs: prefs),
        auth = auth ?? AuthService(prefs: prefs);

  final SharedPreferencesAsync prefs;
  final ProgressStore progress;
  final AuthService auth;
  bool haptics = true;
  bool storageAvailable = true;

  Future<void> boot() async {
    try {
      await Future.wait<void>([
        progress.restore(),
        auth.restore(),
        _loadHaptics(),
      ]);
    } catch (_) {
      storageAvailable = false;
    }
  }

  Future<void> _loadHaptics() async {
    haptics = await prefs.getBool('haptics') ?? true;
  }

  Future<void> setHaptics(bool value) async {
    haptics = value;
    try {
      await prefs.setBool('haptics', value);
    } catch (_) {
      storageAvailable = false;
    }
  }
}
