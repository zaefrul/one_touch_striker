import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

enum ShotSound {
  kick('kick.wav', 180, .65),
  net('net.wav', 600, .60),
  save('save.wav', 260, .55),
  post('post.wav', 550, .55),
  wide('wide.wav', 300, .40),
  charge('charge.wav', 700, .45),
  fireGoal('fire_goal.wav', 1100, .65);

  const ShotSound(this.file, this.milliseconds, this.volume);
  final String file;
  final int milliseconds;
  final double volume;
}

/// One preloaded voice per effect. Playback never waits in the tap or simulation
/// path, never queues old shots, and never allocates another native player.
class StrikerAudio {
  StrikerAudio() : _nativePlayback = true;
  StrikerAudio.silent() : _nativePlayback = false;

  final bool _nativePlayback;
  final Map<ShotSound, _SoundVoice> _voices = {};
  Future<void>? _loading;
  bool _enabled = true;
  bool _suspended = false;
  bool _disposed = false;

  set enabled(bool value) {
    _enabled = value;
    if (!value) stopAll();
  }

  set suspended(bool value) {
    _suspended = value;
    if (value) stopAll();
  }

  Future<void> preload() => _loading ??= _preload();

  Future<void> _preload() async {
    if (!_nativePlayback || _disposed) return;
    final context = AudioContextConfig(
      focus: AudioContextConfigFocus.mixWithOthers,
      respectSilence: true,
    ).build();
    try {
      await AudioPlayer.global.setAudioContext(context);
    } catch (_) {
      // Audio is optional; unsupported platforms can still play the game.
      return;
    }
    for (final sound in ShotSound.values) {
      if (_disposed) return;
      final voice = _SoundVoice(sound);
      _voices[sound] = voice;
      await voice.prepare(context);
    }
  }

  void play(ShotSound sound) {
    if (_disposed || !_enabled || _suspended) return;
    // Drop a cue if its asset is still loading; never replay it late.
    _voices[sound]?.play();
  }

  void stopAll() {
    for (final voice in _voices.values) {
      voice.stop();
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    stopAll();
    await _loading;
    await Future.wait(_voices.values.map((voice) => voice.dispose()));
    _voices.clear();
  }
}

class _SoundVoice {
  _SoundVoice(this.sound);
  final ShotSound sound;
  AudioPlayer? _player;
  Future<void> _commands = Future<void>.value();
  Timer? _stopTimer;
  int _generation = 0;
  bool _ready = false;
  bool _busy = false;
  bool _disposed = false;

  Future<void> prepare(AudioContext context) async {
    try {
      final player = _player = AudioPlayer();
      // Short effects need no platform position query on every display frame.
      player.positionUpdater = null;
      await player.setAudioContext(context);
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(sound.volume);
      await player.setSource(AssetSource('audio/${sound.file}'));
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  void play() {
    if (!_ready || _busy || _disposed) return;
    _busy = true;
    final generation = ++_generation;
    _enqueue(() async {
      if (_disposed || generation != _generation) return;
      await _player!.resume();
      if (_disposed || generation != _generation) return;
      // Android low-latency playback has no completion event. Return this voice
      // to its stopped, preloaded state after the known clip length.
      _stopTimer = Timer(Duration(milliseconds: sound.milliseconds + 60), stop);
    });
  }

  void stop() {
    _generation++;
    _busy = false;
    _stopTimer?.cancel();
    _stopTimer = null;
    if (_ready && !_disposed) {
      // This follows any in-flight resume, so pause/mute cannot leave it playing.
      _enqueue(() => _player!.stop());
    }
  }

  void _enqueue(Future<void> Function() command) {
    _commands = _commands.then((_) => command()).catchError((Object _) {
      _busy = false;
      _ready = false;
    });
  }

  Future<void> dispose() async {
    _disposed = true;
    _generation++;
    _stopTimer?.cancel();
    await _commands;
    try {
      await _player?.dispose();
    } catch (_) {
      // A failed platform player must not prevent other voices being released.
    }
  }
}
