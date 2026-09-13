import 'dart:convert';
import 'knuckle_shot.dart';
import 'match_model.dart';
import 'practice_drill.dart';

enum TutorialLesson {
  aim('aim_release', 'Aim & release', 'Touch to lock. Release to shoot.'),
  curveLeft('curve_left', 'Bend left', 'Hold, drag left, then release.'),
  curveRight('curve_right', 'Bend right', 'Hold, drag right, then release.'),
  banana('banana', 'Banana shot', 'Drag farther sideways, then release.'),
  knuckle('knuckle', 'Knuckle timing', 'Hold still. Release in the marked zone.'),
  fire('fire', 'Fire shot', 'Fire is ready. Release your shot.');

  const TutorialLesson(this.id, this.title, this.prompt);
  final String id, title, prompt;

  // Check the released gesture, never the goal/save outcome.
  bool accepts(MatchModel model) => switch (this) {
    aim => model.shotSpin == 0,
    curveLeft => model.shotSpin < -.08,
    curveRight => model.shotSpin > .08,
    banana => model.shotSpin.abs() >= .75,
    knuckle => model.shotTiming == StrikeTiming.clean,
    fire => model.shotIsFire,
  };

  PracticeDrill get drill => switch (this) {
    curveLeft || curveRight || banana => PracticeDrill.curveWall,
    knuckle => PracticeDrill.knuckle,
    _ => PracticeDrill.corners,
  };
}

/// Separate from stars: losing a match cannot reset completed lessons.
class TutorialProgress {
  static const storageKey = 'tutorial_lessons_v1';
  final Set<String> _completed = {};
  final Set<String> _skipped = {};

  bool needs(TutorialLesson lesson) =>
      !_completed.contains(lesson.id) && !_skipped.contains(lesson.id);

  void complete(TutorialLesson lesson) {
    _completed.add(lesson.id);
    _skipped.remove(lesson.id);
  }

  void skipAll() {
    _skipped.addAll(TutorialLesson.values
        .where((lesson) => !_completed.contains(lesson.id)).map((lesson) => lesson.id));
  }

  bool restore(String? saved) {
    if (saved == null) return true;
    try {
      final data = jsonDecode(saved);
      if (data is! Map<String, dynamic> || data['version'] != 1 ||
          data['completed'] is! List || data['skipped'] is! List) return false;
      final known = TutorialLesson.values.map((lesson) => lesson.id).toSet();
      _completed.addAll((data['completed'] as List).whereType<String>().where(known.contains));
      _skipped.addAll((data['skipped'] as List).whereType<String>().where(known.contains));
      _skipped.removeAll(_completed);
      return true;
    } catch (_) {
      return false;
    }
  }

  String encode() => jsonEncode({
    'version': 1,
    'completed': _completed.toList()..sort(),
    'skipped': _skipped.toList()..sort(),
  });
}

/// Only lesson screens use this model. Match rules, scoring and collision
/// paths are shared; keepers and deadlines are removed from the sandbox.
class TutorialMatchModel extends MatchModel {
  @override
  bool get hasKeeper => false;
  @override
  bool get usesProfessionalKeeper => false;
  @override
  bool get isTimed => false;
  @override
  int get defenderCount => isPractice ? super.defenderCount : 0;
}
