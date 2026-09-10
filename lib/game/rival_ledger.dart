import 'dart:convert';
import 'dart:math' as math;
import 'keeper_style.dart';
import 'match_model.dart';
import 'showdown.dart';

class RivalRecord {
  int wins = 0;
  int losses = 0;
  String get scoreline => 'You $wins · Keeper $losses';
}

/// Completed challenge attempts only. A model attempt ID is monotonic for the
/// lifetime of the screen, so HUD refreshes cannot count a result twice.
class RivalLedger {
  static const storageKey = 'rival_cup_records_v1';
  static const _maxCount = 999999;
  final Map<KeeperStyle, RivalRecord> _records = {
    for (final keeper in KeeperStyle.values) keeper: RivalRecord(),
  };
  final Set<Showdown> _trophies = {};
  int _lastRecordedAttempt = -1;

  RivalRecord against(KeeperStyle keeper) => _records[keeper]!;
  bool hasTrophy(Showdown showdown) => _trophies.contains(showdown);
  int get trophiesWon => _trophies.length;

  bool recordResult(MatchModel model) {
    if (!model.isChallenge || !model.stageStarted ||
        model.attemptId <= _lastRecordedAttempt ||
        (model.phase != MatchPhase.stageCleared && model.phase != MatchPhase.finished)) {
      return false;
    }
    final won = model.phase == MatchPhase.stageCleared;
    if (won && !model.objectiveMet) return false;
    _lastRecordedAttempt = model.attemptId;
    final record = against(model.keeperStyle);
    if (won) {
      record.wins = math.min(_maxCount, record.wins + 1);
      final showdown = model.stage!.showdown;
      if (showdown != null) _trophies.add(showdown);
    } else {
      record.losses = math.min(_maxCount, record.losses + 1);
    }
    return true;
  }

  String encode() => jsonEncode({
    'version': 1,
    'keepers': {
      for (final entry in _records.entries)
        entry.key.name: {'wins': entry.value.wins, 'losses': entry.value.losses},
    },
    'trophies': _trophies.map((trophy) => trophy.name).toList(),
  });

  /// Return false for unreadable/unknown versions so the caller can avoid
  /// overwriting existing history with an empty record after a load failure.
  bool restore(String? source) {
    if (source == null) return true;
    try {
      final data = jsonDecode(source);
      if (data is! Map || data['version'] != 1 || data['keepers'] is! Map) return false;
      final saved = data['keepers'] as Map;
      for (final keeper in KeeperStyle.values) {
        final values = saved[keeper.name];
        if (values is! Map) continue;
        against(keeper).wins = _count(values['wins']);
        against(keeper).losses = _count(values['losses']);
      }
      final trophies = data['trophies'];
      if (trophies is List) {
        for (final trophy in Showdown.values) {
          if (trophies.contains(trophy.name)) _trophies.add(trophy);
        }
      }
      return true;
    } on FormatException {
      return false;
    }
  }

  static int _count(Object? value) =>
      value is int && value >= 0 ? math.min(value, _maxCount) : 0;
}
