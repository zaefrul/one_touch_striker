import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'audio_cues.dart';

export 'audio_cues.dart';

/// Preloaded effects and three reusable loop players. No audio work runs in the
/// render loop or blocks a shot. Late effects are dropped; only the latest
/// desired soundtrack is applied when loading or a transition completes.
class StrikerAudio {
  StrikerAudio() : _nativePlayback = true;
  StrikerAudio.silent() : _nativePlayback = false;

  final bool _nativePlayback;
  final Map<ShotSound, _SoundVoice> _voices = {};
  final Map<AudioLoop, _LoopVoice> _loops = {};
  Future<void>? _loading;
  AudioMix _mix = const AudioMix();
  AudioScene _scene = const AudioScene();
  bool _enabled = true;
  bool _suspended = false;
  bool _disposed = false;

  bool get enabled => _enabled;
  bool get suspended => _suspended;
  AudioMix get mix => _mix;
  AudioScene get scene => _scene;

  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    if (!value) {
      stopAll();
    } else {
      _applyScene();
    }
  }

  set suspended(bool value) {
    if (_suspended == value) return;
    _suspended = value;
    if (value) {
      stopAll();
    } else {
      _applyScene();
    }
  }

  set mix(AudioMix value) {
    _mix = value;
    for (final entry in _voices.entries) {
      if (!value.allows(entry.key.bus)) entry.value.stop();
    }
    _applyScene();
  }

  void setScene(AudioScene value) {
    _scene = value;
    _applyScene();
  }

  void _applyScene() {
    if (_disposed) return;
    for (final entry in _loops.entries) {
      final audible = _enabled && !_suspended && _mix.allows(entry.key.bus);
      entry.value.setLevel(audible ? _scene.levelFor(entry.key) : 0,
          immediate: !audible);
    }
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
    // Each chain is sequential. Menu preparation need not wait for every SFX.
    await Future.wait([_preloadEffects(context), _preloadLoops(context)]);
  }

  Future<void> _preloadEffects(AudioContext context) async {
    for (final sound in ShotSound.values) {
      if (_disposed) return;
      final voice = _SoundVoice(sound);
      _voices[sound] = voice;
      await voice.prepare(context);
    }
  }

  Future<void> _preloadLoops(AudioContext context) async {
    for (final loop in AudioLoop.values) {
      if (_disposed) return;
      final voice = _LoopVoice(loop);
      _loops[loop] = voice;
      await voice.prepare(context);
      // Saved mute, app backgrounding and navigation may change during load.
      _applyScene();
    }
  }

  void play(ShotSound sound) {
    if (_disposed || !_enabled || _suspended || !_mix.allows(sound.bus)) return;
    // A new crowd reaction replaces the old one instead of piling up roars.
    if (sound.bus == AudioBus.crowd) {
      for (final entry in _voices.entries) {
        if (entry.key.bus == AudioBus.crowd) entry.value.stop();
      }
    }
    // Drop a cue if its asset is still loading; never replay it late.
    _voices[sound]?.play();
  }

  void stopEffects() {
    for (final voice in _voices.values) {
      voice.stop();
    }
  }

  void stopAll() {
    stopEffects();
    for (final voice in _loops.values) {
      voice.setLevel(0, immediate: true);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    stopAll();
    await _loading;
    await Future.wait([
      ..._voices.values.map((voice) => voice.dispose()),
      ..._loops.values.map((voice) => voice.dispose()),
    ]);
    _voices.clear();
    _loops.clear();
  }
}

/// Serialized, cancellable 180 ms fades. There is no timer or position polling
/// while a loop is steady, and stale fades cannot restart a muted scene.
class _LoopVoice {
  _LoopVoice(this.loop);
  final AudioLoop loop;
  AudioPlayer? _player;
  Future<void> _commands = Future<void>.value();
  bool _ready = false, _playing = false, _disposed = false;
  bool _hardStop = true;
  double _target = 0, _volume = 0;
  int _generation = 0;

  Future<void> prepare(AudioContext context) async {
    try {
      final player = _player = AudioPlayer();
      player.positionUpdater = null;
      await player.setAudioContext(context);
      await player.setPlayerMode(PlayerMode.mediaPlayer);
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(0);
      await player.setSource(AssetSource('audio/${loop.file}'));
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  void setLevel(double value, {bool immediate = false}) {
    if (!_ready || _disposed) return;
    final target = value.clamp(0.0, 1.0).toDouble();
    if (_target == target && (!immediate || _hardStop)) return;
    _target = target;
    _hardStop = immediate;
    final generation = ++_generation;
    _commands = _commands.then((_) async {
      if (_disposed || !_ready || generation != _generation) return;
      if (immediate && target == 0) {
        await _player!.stop();
        _playing = false;
        _volume = 0;
        return;
      }
      if (!_playing && target > 0) {
        await _player!.setVolume(0);
        _volume = 0;
        if (_disposed || generation != _generation) return;
        await _player!.resume();
        _playing = true;
      }
      final from = _volume;
      for (var step = 1; step <= 6; step++) {
        if (_disposed || generation != _generation) return;
        final fraction = step / 6;
        final eased = fraction * fraction * (3 - 2 * fraction);
        final volume = from + (target - from) * eased;
        await _player!.setVolume(volume);
        _volume = volume;
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      if (target == 0 && generation == _generation) {
        await _player!.stop();
        _playing = false;
        _volume = 0;
      }
    }).catchError((Object _) {
      _ready = false;
      // Best effort silence if a native fade command failed mid-transition.
      return _silenceAfterFailure();
    });
  }

  Future<void> _silenceAfterFailure() async {
    try {
      await _player?.stop();
    } catch (_) {
      // Audio remains optional on unsupported or interrupted platforms.
    }
    _playing = false;
    _volume = 0;
  }

  Future<void> dispose() async {
    _disposed = true;
    _generation++;
    await _commands;
    try {
      await _player?.dispose();
    } catch (_) {
      // Other voices still need to release their native resources.
    }
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
