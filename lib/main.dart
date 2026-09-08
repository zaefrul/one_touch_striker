import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game/challenge_stage.dart';
import 'game/match_model.dart';
import 'game/striker_game.dart';
import 'ui/challenge_panel.dart';

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
  const StrikerApp({super.key});
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
        home: const MatchScreen(),
      );
}

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});
  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> with WidgetsBindingObserver {
  final model = MatchModel();
  final prefs = SharedPreferencesAsync();
  final progress = ChallengeProgress();
  late final StrikerGame game;
  int best = 0;
  bool haptics = true;
  bool storageAvailable = true;
  bool _progressLoaded = false;
  bool _showStages = false;
  Future<void> _writes = Future<void>.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    game = StrikerGame(model, onChanged: _refresh, onShotResult: _result);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final saved = await prefs.getInt('best_score') ?? 0;
      final feedback = await prefs.getBool('haptics') ?? true;
      final savedStars = await prefs.getStringList(ChallengeProgress.storageKey);
      if (!mounted) {
        return;
      }
      setState(() {
        if (saved > best) {
          best = saved;
        }
        haptics = feedback;
        progress.mergeSaved(savedStars);
      });
      // Reconcile a new score earned while storage was loading.
      if (best > saved) {
        _saveInt('best_score', best);
      }
    } catch (_) {
      if (mounted) {
        setState(() => storageAvailable = false);
      }
    } finally {
      if (mounted) {
        setState(() => _progressLoaded = true);
      }
    }
  }

  void _saveInt(String key, int value) {
    _enqueueWrite(() => prefs.setInt(key, value));
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
    // Stage attempts have their own rewards; keep the Classic record comparable.
    if (!model.isChallenge && model.score > best) {
      best = model.score;
      _saveInt('best_score', best);
    }
    if (haptics) {
      unawaited(model.lastWasCorner
          ? HapticFeedback.heavyImpact()
          : HapticFeedback.mediumImpact());
    }
    _refresh();
  }

  void _shoot() {
    if (game.matchPaused || model.phase != MatchPhase.aiming) {
      return;
    }
    if (haptics) {
      unawaited(HapticFeedback.mediumImpact());
    }
    game.shoot();
  }

  void _pause() {
    if (!model.isPlaying) {
      return;
    }
    setState(() => game.matchPaused = !game.matchPaused);
  }

  void _selectStage(int index) {
    if (!_progressLoaded || !progress.isUnlocked(index)) {
      return;
    }
    _showStages = false;
    game.prepareStage(index);
  }

  void _stageMap() {
    _showStages = true;
    game.returnToMenu();
  }

  void _home() {
    _showStages = false;
    game.returnToMenu();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        model.isPlaying) {
      game.matchPaused = true;
      _refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    game.pauseEngine();
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
                          child: GameWidget(game: game),
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
        onRetry: () => _selectStage(model.stageIndex!),
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
                    ? '${model.goals} goals  ·  Best $best\nCan you find the corner next time?'
                    : model.isChallenge
                        ? '${model.stage!.name}\nYour objective and clock are paused.'
                        : 'Your match is waiting.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white70, height: 1.6, fontSize: 14)),
        const SizedBox(height: 22),
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
                  game.startMatch();
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
                onPressed: game.endRun,
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
                    : model.onFire ? 'ON FIRE · 2× POINTS' : stage.skill
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
