import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game/challenge_stage.dart';
import 'game/match_model.dart';
import 'game/striker_audio.dart';
import 'game/striker_game.dart';
import 'ui/challenge_panel.dart';
import 'ui/run_summary.dart';

const lime = Color(0xffd9ff6a);
const ink = Color(0xff062d29);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: ink,
  ));
  runApp(const StrikerApp());
}

class StrikerApp extends StatelessWidget {
  const StrikerApp({super.key, this.audio});
  final StrikerAudio? audio;
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'One-Touch Striker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: ink,
          colorScheme: const ColorScheme.dark(primary: lime, surface: ink),
          fontFamily: 'sans-serif',
          useMaterial3: true,
        ),
        home: MatchScreen(audio: audio),
      );
}

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key, this.audio});
  final StrikerAudio? audio;
  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> with WidgetsBindingObserver {
  final model = MatchModel();
  final prefs = SharedPreferencesAsync();
  final progress = ChallengeProgress();
  late final StrikerGame game;
  late final StrikerAudio audio;
  late final Widget _pitch;
  int best = 0;
  bool haptics = true;
  bool sound = true;
  bool _soundChanged = false;
  bool _foreground = true;
  bool storageAvailable = true;
  bool _progressLoaded = false;
  bool _showStages = false;
  bool _bestLoaded = false;
  bool _classicRunActive = false;
  int _bestBeforeRun = 0;
  Future<void> _writes = Future<void>.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    game = StrikerGame(model, onChanged: _refresh, onShotResult: _result);
    audio = widget.audio ?? StrikerAudio();
    // Honour saved mute before allowing a cue; preload without delaying menus.
    audio.enabled = false;
    unawaited(audio.preload());
    // GameWidget already supplies a repaint boundary. Retain this widget too,
    // so HUD and result changes do not rebuild its subtree.
    _pitch = GameWidget(game: game);
    unawaited(_load());
  }

  Future<void> _load() async {
    game.trace.event('storage.load.begin');
    try {
      final saved = await prefs.getInt('best_score') ?? 0;
      if (!mounted) {
        return;
      }
      setState(() {
        if (saved > best) {
          best = saved;
        }
        if (_classicRunActive && saved > _bestBeforeRun) {
          _bestBeforeRun = saved;
        }
        _bestLoaded = true;
      });
      // Reconcile a new score earned while storage was loading.
      if (best > saved) {
        _saveInt('best_score', best);
      }
      final feedback = await prefs.getBool('haptics') ?? true;
      final savedSound = await prefs.getBool('sound') ?? true;
      final savedStars = await prefs.getStringList(ChallengeProgress.storageKey);
      if (mounted) {
        setState(() {
          haptics = feedback;
          if (!_soundChanged) sound = savedSound;
          progress.mergeSaved(savedStars);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => storageAvailable = false);
      }
    } finally {
      game.trace.event('storage.load.end');
      if (mounted) {
        audio.enabled = sound;
        setState(() => _progressLoaded = true);
      }
    }
  }

  void _saveInt(String key, int value) {
    _enqueueWrite(() async {
      game.trace.event('save.$key.begin');
      try {
        await prefs.setInt(key, value);
      } finally {
        game.trace.event('save.$key.end');
      }
    });
  }

  void _saveBool(String key, bool value) {
    _enqueueWrite(() => prefs.setBool(key, value));
  }

  void _enqueueWrite(Future<void> Function() write) {
    _writes = _writes.then((_) => write()).catchError((_) {
      if (mounted) {
        setState(() => storageAvailable = false);
      }
    });
  }

  void _refresh() {
    if (mounted) {
      audio.suspended = !_foreground || game.matchPaused;
      if (model.phase == MatchPhase.stageCleared &&
          progress.recordClear(model.stageIndex!, model.earnedStars)) {
        final savedStars = progress.encode();
        _enqueueWrite(() =>
            prefs.setStringList(ChallengeProgress.storageKey, savedStars));
      }
      setState(() {});
    }
  }

  void _result() {
    audio.play(model.lastWasGoal
        ? (model.lastWasFire ? ShotSound.fireGoal : ShotSound.net)
        : model.lastWasPost
            ? ShotSound.post
            : model.message == 'JUST WIDE!'
                ? ShotSound.wide
                : ShotSound.save);
    if (model.justChargedFire) audio.play(ShotSound.charge);
    // Stage attempts have their own rewards; keep the Classic record comparable.
    if (!model.isChallenge && model.score > best) {
      best = model.score;
      // Do not overwrite an existing record until its initial read completes.
      if (_bestLoaded) {
        _saveInt('best_score', best);
      }
    }
    if (haptics) {
      game.trace.event('haptic.result');
      unawaited(model.lastWasCorner || (model.lastWasFire && model.lastWasGoal)
          ? HapticFeedback.heavyImpact()
          : HapticFeedback.mediumImpact());
    }
    _refresh();
  }

  void _shoot() {
    // Lock the aim before issuing the platform haptic call.
    if (!game.shoot()) {
      return;
    }
    audio.play(ShotSound.kick);
    if (haptics) {
      game.trace.event('haptic.tap');
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  bool get _personalBest =>
      _classicRunActive && _bestLoaded &&
      model.score > _bestBeforeRun;

  void _startClassic() {
    audio.stopAll();
    _bestBeforeRun = best;
    _classicRunActive = true;
    game.startMatch();
  }

  void _pause() {
    if (!model.isPlaying) {
      return;
    }
    game.matchPaused = !game.matchPaused;
    _refresh();
  }

  void _selectStage(int index) {
    if (!_progressLoaded || !progress.isUnlocked(index)) {
      return;
    }
    _showStages = false;
    _classicRunActive = false;
    audio.stopAll();
    game.prepareStage(index);
  }

  void _retryStage() {
    audio.stopAll();
    game.retryStage();
  }

  void _endRun() {
    audio.stopAll();
    game.endRun();
  }

  void _stageMap() {
    audio.stopAll();
    _showStages = true;
    _classicRunActive = false;
    game.returnToMenu();
  }

  void _home() {
    audio.stopAll();
    _showStages = false;
    _classicRunActive = false;
    game.returnToMenu();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground && model.isPlaying) {
      game.matchPaused = true;
    }
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    game.pauseEngine();
    game.trace.dispose();
    unawaited(audio.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = model.phase == MatchPhase.ready;
    final finished = model.phase == MatchPhase.finished;
    final stageOverlay = model.phase == MatchPhase.stageIntro ||
        model.phase == MatchPhase.stageCleared;
    return PopScope(
      canPop: ready && !_showStages,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (model.isPlaying) {
            if (!game.matchPaused) {
              _pause();
            }
          } else if (model.isChallenge) {
            _stageMap();
          } else {
            _home();
          }
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 14, 8),
                  child: Row(children: [
                    const Icon(Icons.sports_soccer, color: lime, size: 23),
                    const SizedBox(width: 9),
                    const Expanded(
                        child: Text('ONE-TOUCH\nSTRIKER',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                                letterSpacing: 1.5,
                                fontSize: 16))),
                    IconButton(
                      tooltip: sound ? 'Turn sound off' : 'Turn sound on',
                      onPressed: () {
                        setState(() {
                          _soundChanged = true;
                          sound = !sound;
                          audio.enabled = sound;
                        });
                        _saveBool('sound', sound);
                      },
                      icon: Icon(sound ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                          size: 20, color: Colors.white60),
                    ),
                    IconButton(
                      tooltip:
                          haptics ? 'Turn vibration off' : 'Turn vibration on',
                      onPressed: () {
                        setState(() => haptics = !haptics);
                        _saveBool('haptics', haptics);
                      },
                      icon: Icon(
                          haptics ? Icons.vibration : Icons.phone_android,
                          size: 20,
                          color: Colors.white60),
                    ),
                    if (model.isPlaying)
                      IconButton(
                          tooltip: game.matchPaused ? 'Resume' : 'Pause',
                          onPressed: _pause,
                          icon: Icon(game.matchPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded)),
                    if (!model.isPlaying && (!ready || _showStages))
                      IconButton(
                          tooltip: model.isChallenge ? 'Stage select' : 'Home',
                          onPressed: model.isChallenge ? _stageMap : _home,
                          icon: const Icon(Icons.arrow_back_rounded)),
                  ]),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _stat(model.isChallenge ? 'STAGE SCORE' : 'SCORE',
                            model.score.toString().padLeft(2, '0'),
                            primary: true),
                        if (model.isChallenge)
                          _stat(model.isTimed ? 'TIME LEFT' : 'STARS',
                              model.isTimed ? '${model.timerSeconds}s' : '${progress.totalStars}/${challengeStages.length * 3}',
                              urgent: model.isTimed && model.timerSeconds <= 5)
                        else
                          _stat('BEST', '$best'),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('CHANCES',
                                  style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 1.8,
                                      color: Colors.white54)),
                              const SizedBox(height: 7),
                              Row(
                                  children: List.generate(
                                      3,
                                      (i) => Padding(
                                          padding:
                                              const EdgeInsets.only(left: 4),
                                          child: Icon(Icons.favorite_rounded,
                                              size: 19,
                                              color: i < model.lives
                                                  ? const Color(0xffff777a)
                                                  : Colors.white12)))),
                            ]),
                      ]),
                ),
                Expanded(
                  child: Stack(fit: StackFit.expand, children: [
                    ExcludeSemantics(
                      excluding: !model.isPlaying || game.matchPaused,
                      child: Semantics(
                        label: model.showTapCue
                            ? 'Aiming. Tap the pitch to lock the arrow. The ball shoots where the arrow points, not where you touch.'
                            : 'Football pitch. Tap to shoot in the arrow direction.',
                        button: true,
                        onTap: _shoot,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (_) => _shoot(),
                          child: _pitch,
                        ),
                      ),
                    ),
                    if (model.isPlaying &&
                        !game.matchPaused &&
                        (model.lastChance || model.onFire))
                      IgnorePointer(
                          child: ColoredBox(
                              color: model.lastChance
                                  ? const Color(0x18ff777a)
                                  : const Color(0x14d9ff6a))),
                    if (model.phase == MatchPhase.result && !game.matchPaused)
                      IgnorePointer(
                          child: Center(
                              child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 16),
                        decoration: BoxDecoration(
                            color: ink.withValues(alpha: .94),
                            borderRadius: BorderRadius.circular(20)),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(model.message,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: model.lastWasGoal
                                      ? lime
                                      : const Color(0xffff777a),
                                  fontSize: model.lastWasCorner ? 34 : 28,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text(model.resultSubtitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  letterSpacing: 1, fontSize: 11)),
                        ]),
                      ))),
                    if (ready || finished || stageOverlay || game.matchPaused)
                      ColoredBox(
                          color: ink.withValues(alpha: .80),
                          child: LayoutBuilder(
                              builder: (context, constraints) =>
                                  SingleChildScrollView(
                                    key: ValueKey((model.phase, model.stageIndex,
                                        _showStages, game.matchPaused)),
                                    child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                            minHeight: constraints.maxHeight),
                                        child: Center(
                                            child: Padding(
                                          padding: const EdgeInsets.all(26),
                                          child: _overlay(ready, finished),
                                        ))),
                                  ))),
                  ]),
                ),
                _footer(),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, {bool primary = false, bool urgent = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, letterSpacing: 1.8, color: Colors.white54)),
          Text(value,
              style: TextStyle(
                  fontSize: primary ? 36 : 28,
                  height: 1.15,
                  color: urgent ? const Color(0xffff777a) : primary ? lime : Colors.white,
                  fontWeight: FontWeight.w900)),
        ],
      );

  Widget _overlay(bool ready, bool finished) {
    if (ready && _showStages) {
      return ChallengeMap(progress: progress, onSelect: _selectStage, onBack: _home);
    }
    if (model.isChallenge && !game.matchPaused) {
      return StagePanel(
        model: model,
        progress: progress,
        onStart: game.startStage,
        onRetry: _retryStage,
        onNext: () => model.isFinalStage ? _stageMap() : _selectStage(model.stageIndex! + 1),
        onStages: _stageMap,
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
            ready
                ? 'YOUR NEXT GREAT GOAL'
                : finished
                    ? 'FULL TIME'
                    : 'TAKE A BREATHER',
            style: const TextStyle(
                color: lime,
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Text(
            ready
                ? 'ONE TAP.\nALL GLORY.'
                : finished
                    ? '${model.score}'
                    : 'PAUSED',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: finished ? 78 : 43,
                fontWeight: FontWeight.w900,
                height: 1.02,
                letterSpacing: -1.5)),
        const SizedBox(height: 16),
        Text(
            ready
                ? 'Follow the arrow. Pick your moment.\nBeat the keeper with a single tap.'
                : finished
                    ? 'Best $best · Aim for ${best + 1} points next.'
                    : model.isChallenge
                        ? '${model.stage!.name}\nYour objective and clock are paused.'
                        : 'Your match is waiting.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white70, height: 1.6, fontSize: 14)),
        const SizedBox(height: 22),
        if (finished) ...[
          RunSummary(model: model, personalBest: _personalBest,
              previousBest: _bestBeforeRun),
          const SizedBox(height: 22),
        ],
        if (ready) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _progressLoaded ? _stageMap : null,
              icon: const Icon(Icons.emoji_events_outlined),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(_progressLoaded ? 'PLAY CHALLENGES' : 'LOADING PROGRESS…',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('6 stages · ${progress.totalStars}/${challengeStages.length * 3} stars · New objectives',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.white60)),
          const SizedBox(height: 20),
          const Text('CLASSIC · CHASE YOUR BEST SCORE',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.white54, letterSpacing: 1)),
          const SizedBox(height: 8),
        ],
        SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: ready ? Colors.white10 : lime,
                  foregroundColor: ready ? Colors.white : ink,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16))),
              onPressed: () {
                if (game.matchPaused && !finished && !ready) {
                  _pause();
                } else {
                  _startClassic();
                }
              },
              child: Text(
                  ready
                      ? 'LET’S PLAY  →'
                      : finished
                          ? 'PLAY AGAIN  ↻'
                          : 'RESUME  →',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            )),
        if (!ready && !finished)
          Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextButton(
                onPressed: _endRun,
                child: Text(model.isChallenge ? 'END STAGE' : 'END RUN',
                    style: const TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6)),
              )),
        if (finished)
          TextButton(onPressed: _home, child: const Text('HOME & CHALLENGES')),
        if (ready)
          const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Text('No timer. Three misses end your run.',
                  style: TextStyle(fontSize: 11, color: Colors.white54))),
        if (ready) ...[
          const SizedBox(height: 20),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _Rule('GOAL', '+1'),
            SizedBox(width: 28),
            _Rule('CORNER', '+3'),
            SizedBox(width: 28),
            _Rule('MISSES', '3'),
          ]),
        ],
      ]);
  }

  Widget _footer() {
    final stage = model.stage;
    final fireLabel = stage == null
        ? ''
        : model.phase == MatchPhase.flying && model.shotIsFire
            ? 'FIRE SHOT · GOALS SCORE 2×'
            : model.objectiveMet
                ? 'STAGE COMPLETE'
                : model.timeExpired
                    ? 'TIME IS UP'
                    : model.phase == MatchPhase.finished
                        ? 'FRESH FIRE CHARGE ON RETRY'
                        : model.fireReady
                            ? 'FIRE SHOT READY · NEXT SHOT 2×'
                            : '${model.fireCharge}/${stage.fireChargeGoals} '
                              '${stage.fireChargeUnit.toUpperCase()}${stage.fireChargeGoals == 1 ? '' : 'S'} TO FIRE';
    final objective = stage == null
        ? (model.onFire ? 'ON FIRE · 2× POINTS' : '${model.streak}/5 STREAK TO 2×')
        : '${model.objectiveProgress}/${stage.target} ${stage.unit.toUpperCase()}';
    final hint = !storageAvailable
        ? 'PROGRESS SAVING UNAVAILABLE'
        : stage != null
            ? model.timeExpired && model.phase == MatchPhase.flying
                ? 'BUZZER SHOT — THIS ONE STILL COUNTS.'
                : stage.objective == StageObjective.corners
                    ? 'THE GLOWING CORNERS ADVANCE THIS STAGE.'
                    : model.onFire ? 'FIRE SHOT · GOALS SCORE 2×' : stage.skill
            : model.phase == MatchPhase.flying
                ? (model.lastChance ? 'LAST CHANCE…' : 'SHOT AWAY…')
                : model.showTapCue ? 'TAP THE GLOW. LOCK THE ARROW.'
                    : model.lastChance ? 'LAST CHANCE. MAKE IT COUNT.'
                        : model.onFire ? 'ON FIRE. GO FOR THE CORNER.'
                            : 'TIME THE ARROW. TAP THE PITCH.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
      child: Column(children: [
        Row(children: [
          Text(stage == null ? 'LEVEL ${model.level}' : 'STAGE ${model.level}/${challengeStages.length}',
              style: const TextStyle(fontSize: 10, letterSpacing: 1.4, color: Colors.white54)),
          const SizedBox(width: 12),
          Expanded(child: Text(objective,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 10, letterSpacing: 1,
                  color: stage != null || model.onFire ? lime : Colors.white54))),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: stage == null
                ? (model.streak / 5).clamp(0.0, 1.0)
                : (model.objectiveProgress / stage.target).clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: Colors.white10,
            color: lime,
            semanticsLabel: stage == null ? 'Streak progress' : stage.objectiveLabel,
            semanticsValue: objective,
          ),
        ),
        // Reserve this row throughout the stage so starting/ending an attempt
        // does not resize the pitch just to add or remove the charge meter.
        if (stage != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.local_fire_department_rounded,
                color: Color(0xffffc857), size: 18),
            const SizedBox(width: 6),
            Expanded(child: Text(fireLabel,
                style: const TextStyle(fontSize: 10, color: Color(0xffffc857)))),
            const SizedBox(width: 8),
            for (var i = 0; i < stage.fireChargeGoals; i++)
              Container(
                width: 18, height: 6,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  color: i < model.fireCharge
                      ? const Color(0xffffc857) : Colors.white12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ]),
        ],
        const SizedBox(height: 12),
        Text(hint, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, letterSpacing: 1.1, color: Colors.white60)),
      ]),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: const TextStyle(
                color: lime, fontSize: 25, fontWeight: FontWeight.w900)),
        Text(label,
            style: const TextStyle(
                color: Colors.white54, letterSpacing: 1.4, fontSize: 9)),
      ]);
}
