import 'dart:convert';
import 'dart:math' as math;
import 'practice_drill.dart';

/// Practice records use a separate, versioned key and never spend campaign stars.
class PracticeProgress {
  static const storageKey = 'practice_bests_v1';
  final Map<PracticeDrill, int> _best = {for (final drill in PracticeDrill.values) drill: 0};

  int bestFor(PracticeDrill drill) => _best[drill]!;

  bool record(PracticeDrill drill, int hits) {
    if (hits < 0 || hits > PracticeDrill.balls || hits <= bestFor(drill)) return false;
    _best[drill] = hits;
    return true;
  }

  String encode() => jsonEncode({'version': 1,
      'best': {for (final drill in PracticeDrill.values) drill.id: bestFor(drill)}});

  /// Validate before merging, keeping unreadable/future records untouched.
  bool restore(String? source) {
    if (source == null) return true;
    try {
      final data = jsonDecode(source);
      if (data is! Map || data['version'] != 1 || data['best'] is! Map) return false;
      final values = data['best'] as Map;
      final incoming = <PracticeDrill, int>{};
      for (final drill in PracticeDrill.values) {
        final count = values.containsKey(drill.id) ? values[drill.id] : 0;
        if (count is! int || count < 0 || count > PracticeDrill.balls) return false;
        incoming[drill] = count;
      }
      for (final entry in incoming.entries) {
        _best[entry.key] = math.max(bestFor(entry.key), entry.value);
      }
      return true;
    } on FormatException {
      return false;
    }
  }
}
