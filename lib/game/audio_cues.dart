import 'match_model.dart';
import 'shot_failure.dart';

enum AudioBus { music, effects, crowd }

/// Original bundled clips. Timings include the complete WAV tail so Android's
/// low-latency players can be stopped without relying on completion events.
enum ShotSound {
  kick('kick.wav', 180, .65),
  net('net.wav', 600, .60),
  save('save.wav', 260, .55),
  blocked('blocked.wav', 340, .60),
  post('post.wav', 550, .55),
  wide('wide.wav', 300, .40),
  charge('charge.wav', 700, .45),
  fireGoal('fire_goal.wav', 1100, .65),
  cheer('cheer.wav', 1400, .48, AudioBus.crowd),
  groan('groan.wav', 850, .40, AudioBus.crowd),
  whistle('whistle.wav', 420, .32),
  victory('victory.wav', 1700, .50),
  fullTime('full_time.wav', 950, .38);

  const ShotSound(this.file, this.milliseconds, this.volume,
      [this.bus = AudioBus.effects]);
  final String file;
  final int milliseconds;
  final double volume;
  final AudioBus bus;
}

enum AudioLoop {
  menu('menu-song.mp3', AudioBus.music),
  inGame('in-game-song.mp3', AudioBus.music),
  stadium('stadium.wav', AudioBus.crowd),
  suspense('suspense.wav', AudioBus.music);

  const AudioLoop(this.file, this.bus);
  final String file;
  final AudioBus bus;
}

class AudioMix {
  const AudioMix({this.music = true, this.effects = true, this.crowd = true});
  final bool music, effects, crowd;

  bool allows(AudioBus bus) => switch (bus) {
    AudioBus.music => music,
    AudioBus.effects => effects,
    AudioBus.crowd => crowd,
  };

  AudioMix withBus(AudioBus bus, bool enabled) => AudioMix(
      music: bus == AudioBus.music ? enabled : music,
      effects: bus == AudioBus.effects ? enabled : effects,
      crowd: bus == AudioBus.crowd ? enabled : crowd);

  static String storageKey(AudioBus bus) => 'audio_${bus.name}';
}

/// Desired loop levels, independent of mute, loading and app lifecycle.
class AudioScene {
  const AudioScene({
    this.menu = 0,
    this.inGame = 0,
    this.stadium = 0,
    this.suspense = 0,
  });
  final double menu, inGame, stadium, suspense;

  double levelFor(AudioLoop loop) => switch (loop) {
    AudioLoop.menu => menu,
    AudioLoop.inGame => inGame,
    AudioLoop.stadium => stadium,
    AudioLoop.suspense => suspense,
  };
}

class AudioFrame {
  const AudioFrame(this.scene, this.cues);
  final AudioScene scene;
  final List<ShotSound> cues;
}

/// Reads simulation events, never display strings. Repeated HUD refreshes and
/// pause/resume cannot replay a goal, start whistle or full-time sting.
class MatchSoundtrack {
  int? _attempt;
  int _resultSerial = 0;
  bool _started = false, _ended = false;

  AudioFrame update(MatchModel model) {
    if (_attempt != model.attemptId) {
      _attempt = model.attemptId;
      _resultSerial = model.resultSerial;
      _started = _ended = false;
    }
    final cues = <ShotSound>[];
    if (model.isPlaying && !_started) {
      _started = true;
      cues.add(ShotSound.whistle);
    }
    if (model.resultSerial != _resultSerial) {
      _resultSerial = model.resultSerial;
      cues.add(shotCue(model));
      if (!model.isPractice) {
        cues.add(model.lastWasGoal ? ShotSound.cheer : ShotSound.groan);
      }
      if (model.justChargedFire) cues.add(ShotSound.charge);
    }
    final ended = model.phase == MatchPhase.stageCleared ||
        model.phase == MatchPhase.finished;
    if (_started && ended && !_ended) {
      _ended = true;
      cues.add(model.phase == MatchPhase.stageCleared ||
              (model.practiceCompleted && model.practiceHits == 5)
          ? ShotSound.victory : ShotSound.fullTime);
    }
    return AudioFrame(sceneFor(model), cues);
  }

  static ShotSound shotCue(MatchModel model) {
    if (model.lastWasGoal) {
      return model.lastWasFire ? ShotSound.fireGoal : ShotSound.net;
    }
    return switch (model.lastFailure) {
      ShotFailure.keeper => ShotSound.save,
      ShotFailure.defender => ShotSound.blocked,
      ShotFailure.post => ShotSound.post,
      ShotFailure.wide => ShotSound.wide,
      null => ShotSound.wide,
    };
  }

  static AudioScene sceneFor(MatchModel model) {
    if (!model.isPlaying) {
      final results = model.phase == MatchPhase.stageCleared ||
          model.phase == MatchPhase.finished;
      return AudioScene(menu: results ? .20 : .38);
    }
    // Bring the stands up as opponents improve, with headroom for shot cues.
    final progression = (model.level - 1).clamp(0, 11) / 11;
    final stadium = model.isPractice ? .08
        : .18 + progression * .12 + model.streak.clamp(0, 5) * .012;
    final pressure = !model.isPractice && !model.objectiveMet && model.lives > 0 &&
        (model.lives == 1 || (model.isTimed && model.secondsRemaining <= 8));
    final suspense = !pressure ? 0.0
        : model.isTimed && model.secondsRemaining <= 4 ? .42 : .30;
    // Keep the bed quiet so kick, net and crowd cues stay readable.
    final feedback = model.phase == MatchPhase.result;
    final inGame = model.isPractice ? .14 : .20;
    return AudioScene(
      inGame: inGame * (feedback ? .40 : 1) * (suspense > 0 ? .55 : 1),
      stadium: stadium * (feedback ? .65 : 1),
      suspense: suspense * (feedback ? .45 : 1),
    );
  }
}
