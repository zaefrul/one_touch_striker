import 'dart:developer' as developer;

/// Opt-in local DevTools markers, disabled in normal builds. These identify
/// gameplay phases on the Flutter frame timeline; they do not claim a phase
/// caused a slow frame. No analytics, network requests or per-frame logging.
class PlaytestTrace {
  static const enabled = bool.fromEnvironment('STRIKER_TRACE');
  developer.TimelineTask? _phase;
  String? _label;

  void phase(String label, Map<String, Object> details) {
    if (!enabled || label == _label) {
      return;
    }
    _phase?.finish();
    _label = label;
    _phase = developer.TimelineTask()
      ..start('Striker: $label', arguments: details);
  }

  void event(String label, [Map<String, Object>? details]) {
    if (enabled) {
      developer.Timeline.instantSync('Striker: $label', arguments: details);
    }
  }

  void dispose() {
    _phase?.finish();
    _phase = null;
    _label = null;
  }
}
