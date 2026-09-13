import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game/challenge_stage.dart';
import 'game/match_model.dart';
import 'game/striker_audio.dart';
import 'game/striker_game.dart';
import 'game/rival_ledger.dart';
import 'game/star_rewards.dart';
import 'game/practice_drill.dart';
import 'game/practice_progress.dart';
import 'game/tutorial_progress.dart';
import 'ui/challenge_panel.dart';
import 'ui/first_touch_coach.dart';
import 'ui/run_summary.dart';
import 'ui/star_rewards_panel.dart';
import 'ui/home_panel.dart';
import 'ui/shot_gesture_surface.dart';
import 'ui/practice_panel.dart';
import 'ui/audio_settings_sheet.dart';
import 'ui/stage_objective.dart';
import 'ui/tutorial_screen.dart';
import 'ui/welcome_page.dart';

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
  const StrikerApp({super.key, this.audio, this.autoTutorials = true});
  final StrikerAudio? audio;
  final bool autoTutorials;
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
        home: MatchScreen(audio: audio, autoTutorials: autoTutorials),
      );
}

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key, this.audio, this.autoTutorials = true});
  final StrikerAudio? audio;
  final bool autoTutorials;
  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> with WidgetsBindingObserver {
  final model = MatchModel();
  final prefs = SharedPreferencesAsync();
  final progress = ChallengeProgress();
  final rivals = RivalLedger();
  final cosmetics = CosmeticSelection();
  final practiceProgress = PracticeProgress();
  final tutorials = TutorialProgress();
  bool _tutorialOpen = false, _tutorialScheduled = false;
  bool _tutorialSavingAvailable = true, _hasExistingSave = false;
  bool _welcomePending = false;
  final soundtrack = MatchSoundtrack();
  late final StrikerGame game;
  late final StrikerAudio audio;
  late final Widget _pitch;
  int best = 0;
  bool haptics = true;
  bool sound = true;
  bool _soundChanged = false;
  AudioMix _audioMix = const AudioMix();
  bool _foreground = true;
  bool storageAvailable = true;
  bool _progressLoaded = false;
  bool _showStages = false;
  bool _showRewards = false;
  bool _showPractice = false;
  bool _practiceHistoryAvailable = false;
  int _practiceBestBefore = 0;
  bool _rivalHistoryAvailable = false;
  List<StarReward> _newRewards = const [];
  bool _bestLoaded = false;
  bool _classicRunActive = false;
  int _bestBeforeRun = 0;
  Future<void> _writes = Future<void>.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
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
      // Keep the existing star save independent of optional new record keys.
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
        _hasExistingSave = savedStars != null || saved > 0;
        if (mounted) {
          setState(() {
            haptics = feedback;
            if (!_soundChanged) sound = savedSound;
            progress.mergeSaved(savedStars);
          });
        }
      } catch (_) {
        if (mounted) setState(() => storageAvailable = false);
      }
      // Optional mix keys cannot prevent stars, records or the old mute key
      // from loading. Settings open only after this initial read completes.
      try {
        final music = await prefs.getBool(AudioMix.storageKey(AudioBus.music)) ?? true;
        final effects = await prefs.getBool(AudioMix.storageKey(AudioBus.effects)) ?? true;
        final crowd = await prefs.getBool(AudioMix.storageKey(AudioBus.crowd)) ?? true;
        if (mounted) _audioMix = AudioMix(music: music, effects: effects, crowd: crowd);
      } catch (_) {
        if (mounted) storageAvailable = false;
      }
      try {
        final savedRivals = await prefs.getString(RivalLedger.storageKey);
        if (mounted) {
          _rivalHistoryAvailable = rivals.restore(savedRivals);
          if (!_rivalHistoryAvailable) storageAvailable = false;
        }
      } catch (_) {
        if (mounted) storageAvailable = false;
      }
      try {
        final savedLooks = await prefs.getString(CosmeticSelection.storageKey);
        if (mounted) {
          if (!cosmetics.restore(savedLooks, progress.totalStars)) storageAvailable = false;
          game.applyCosmetics(cosmetics);
        }
      } catch (_) {
        if (mounted) storageAvailable = false;
      }
      try {
        final savedPractice = await prefs.getString(PracticeProgress.storageKey);
        _hasExistingSave = _hasExistingSave || savedPractice != null;
        if (mounted) {
          _practiceHistoryAvailable = practiceProgress.restore(savedPractice);
          if (!_practiceHistoryAvailable) storageAvailable = false;
        }
      } catch (_) {
        if (mounted) storageAvailable = false;
      }
      try {
        final savedTutorials = await prefs.getString(TutorialProgress.storageKey);
        if (mounted) {
          _tutorialSavingAvailable = tutorials.restore(savedTutorials);
          if (!_tutorialSavingAvailable) storageAvailable = false;
          // Existing play progress demonstrates basic shot control.
          if (savedTutorials == null && _hasExistingSave) {
            tutorials.complete(TutorialLesson.aim);
            _saveTutorials();
          }
          _welcomePending = widget.autoTutorials && _tutorialSavingAvailable &&
              !_hasExistingSave && tutorials.needs(TutorialLesson.aim);
        }
      } catch (_) {
        _tutorialSavingAvailable = false;
        if (mounted) storageAvailable = false;
      }
    } finally {
      game.trace.event('storage.load.end');
      if (mounted) {
        audio.mix = _audioMix;
        setState(() => _progressLoaded = true);
        _syncAudio();
        _maybeTeach();
      }
    }
  }

  void _saveTutorials() {
    if (!_tutorialSavingAvailable) return;
    final saved = tutorials.encode();
    _enqueueWrite(() => prefs.setString(TutorialProgress.storageKey, saved));
  }

  List<TutorialLesson> _needed(Iterable<TutorialLesson> lessons) => widget.autoTutorials
      ? lessons.where(tutorials.needs).toList() : const [];

  Future<void> _teach(List<TutorialLesson> lessons,
      {VoidCallback? after, bool replay = false}) async {
    if (!mounted || _tutorialOpen || !_foreground || lessons.isEmpty) return;
    _tutorialOpen = true;
    if (lessons.contains(TutorialLesson.aim)) _welcomePending = false;
    final wasPaused = game.matchPaused;
    game.matchPaused = true;
    game.pauseEngine();
    _syncAudio();
    try {
      final route = MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (lessonContext) => TutorialScreen(
          lessons: lessons,
          fireStageIndex: model.stageIndex ?? 0,
          onKick: _kickFeedback,
          onComplete: (lesson) {
            tutorials.complete(lesson);
            _saveTutorials();
          },
          onSkip: () {
            if (!replay) {
              tutorials.skipAll();
              _saveTutorials();
            }
            Navigator.of(lessonContext).pop();
          },
          onDone: () => Navigator.of(lessonContext).pop(),
        ),
      );
      await Navigator.of(context).push<void>(route);
      // Keep the match frozen until the lesson's exit transition is removed.
      await route.completed;
    } finally {
      _tutorialOpen = false;
      if (mounted) {
        game.matchPaused = wasPaused || (!_foreground && model.isPlaying);
        if (_foreground) game.resumeEngine();
        _refresh();
        after?.call();
        if (!_foreground && model.isPlaying) game.matchPaused = true;
      }
    }
  }

  /// First-launch introduction. Play continues into the aim lesson and the
  /// first match; Skip dismisses every automatic lesson and opens Stage 1.
  Future<void> _welcome() async {
    if (!mounted || _tutorialOpen || !_foreground) return;
    _tutorialOpen = true;
    _welcomePending = false;
    var play = false;
    final wasPaused = game.matchPaused;
    game.matchPaused = true;
    game.pauseEngine();
    _syncAudio();
    try {
      final route = MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (welcomeContext) => WelcomePage(
          onPlay: () {
            play = true;
            Navigator.of(welcomeContext).pop();
          },
          onSkip: () {
            tutorials.skipAll();
            _saveTutorials();
            Navigator.of(welcomeContext).pop();
          },
        ),
      );
      await Navigator.of(context).push<void>(route);
      await route.completed;
    } finally {
      _tutorialOpen = false;
      if (mounted) {
        game.matchPaused = wasPaused || (!_foreground && model.isPlaying);
        if (_foreground) game.resumeEngine();
        _refresh();
        if (play) {
          unawaited(_teach([TutorialLesson.aim], after: _quickPlay));
        } else {
          _quickPlay();
        }
      }
    }
  }

  void _maybeTeach() {
    if (!widget.autoTutorials || !_progressLoaded || !_foreground ||
        _tutorialOpen || _tutorialScheduled) return;
    final welcome = _welcomePending && tutorials.needs(TutorialLesson.aim) && model.phase == MatchPhase.ready;
    // The guided first match coaches Fire on the pitch instead of a modal.
    final fire = model.phase == MatchPhase.aiming && !game.matchPaused &&
        !model.isPreparingShot && model.fireReady && !model.isGuidedFirstMatch &&
        tutorials.needs(TutorialLesson.fire);
    if (!welcome && !fire) return;
    _tutorialScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tutorialScheduled = false;
      if (!mounted || !_foreground || _tutorialOpen) return;
      if (_welcomePending && tutorials.needs(TutorialLesson.aim) && model.phase == MatchPhase.ready) {
        unawaited(_welcome());
      } else if (model.phase == MatchPhase.aiming && !game.matchPaused &&
          !model.isPreparingShot && model.fireReady && !model.isGuidedFirstMatch &&
          tutorials.needs(TutorialLesson.fire)) {
        unawaited(_teach([TutorialLesson.fire]));
      }
    });
  }

  void _startStage() {
    final index = model.stageIndex;
    if (index == null || model.phase != MatchPhase.stageIntro) return;
    final lessons = _needed([
      TutorialLesson.aim,
      if (index >= 1) ...[
        TutorialLesson.curveLeft, TutorialLesson.curveRight, TutorialLesson.banana,
      ],
      if (index >= 2) TutorialLesson.knuckle,
    ]);
    if (lessons.isNotEmpty) {
      unawaited(_teach(lessons, after: game.startStage));
    } else {
      game.startStage();
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
      _syncAudio();
      final starsBefore = progress.totalStars;
      if (model.isChallenge && model.phase == MatchPhase.stageCleared &&
          progress.recordClear(model.stageIndex!, model.earnedStars)) {
        _newRewards = rewardsEarnedBetween(starsBefore, progress.totalStars);
        final savedStars = progress.encode();
        _enqueueWrite(() =>
            prefs.setStringList(ChallengeProgress.storageKey, savedStars));
      }
      if (_rivalHistoryAvailable && rivals.recordResult(model)) {
        final savedRivals = rivals.encode();
        _enqueueWrite(() => prefs.setString(RivalLedger.storageKey, savedRivals));
      }
      if (model.practiceCompleted && practiceProgress.record(model.practice!, model.practiceHits) &&
          _practiceHistoryAvailable) {
        final savedPractice = practiceProgress.encode();
        _enqueueWrite(() async {
          try {
            await prefs.setString(PracticeProgress.storageKey, savedPractice);
          } catch (_) {
            if (mounted) _practiceHistoryAvailable = false;
            rethrow; // The shared queue displays the storage failure notice.
          }
        });
      }
      setState(() {});
      _maybeTeach();
    }
  }

  void _syncAudio() {
    final frame = soundtrack.update(model);
    // Set current intent while still muted/suspended, then allow playback.
    audio.setScene(frame.scene);
    audio.suspended = !_foreground || (game.matchPaused && !_tutorialOpen);
    audio.enabled = _progressLoaded && sound;
    for (final cue in frame.cues) {
      audio.play(cue);
    }
  }

  void _setSound(bool value) {
    setState(() {
      _soundChanged = true;
      sound = value;
    });
    _syncAudio();
    _saveBool('sound', sound);
  }

  void _setAudioBus(AudioBus bus, bool enabled) {
    setState(() => _audioMix = _audioMix.withBus(bus, enabled));
    audio.mix = _audioMix;
    _saveBool(AudioMix.storageKey(bus), enabled);
  }

  void _openAudioSettings() {
    if (!_progressLoaded) return;
    unawaited(showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
      builder: (_) => AudioSettingsSheet(enabled: sound, mix: _audioMix,
          paused: game.matchPaused, onEnabled: _setSound, onBus: _setAudioBus),
    ));
  }

  void _result() {
    // A Fire shot released with the live coach counts as the Fire lesson.
    if (model.isGuidedFirstMatch && model.shotIsFire && tutorials.needs(TutorialLesson.fire)) {
      tutorials.complete(TutorialLesson.fire);
      _saveTutorials();
    }
    // Stage attempts have their own rewards; keep the Classic record comparable.
    if (model.isClassic && model.score > best) {
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
    if (game.shoot()) _kickFeedback();
  }

  void _releaseShot() {
    if (game.releaseShot()) _kickFeedback();
  }

  void _kickFeedback() {
    // The simulation launches before any audio or platform haptic work.
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
    if (!_progressLoaded) return;
    final lessons = _needed([TutorialLesson.aim]);
    if (lessons.isNotEmpty) {
      unawaited(_teach(lessons, after: _startClassic));
      return;
    }
    audio.stopEffects();
    _showStages = _showRewards = _showPractice = false;
    _newRewards = const [];
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
    _showRewards = false;
    _showPractice = false;
    _newRewards = const [];
    _classicRunActive = false;
    audio.stopEffects();
    // The live coach runs only until Stage 1 has been cleared once.
    game.prepareStage(index, guided: index == 0 && progress.starsFor(0) == 0);
  }

  void _quickPlay() {
    if (!_progressLoaded || model.isPlaying) return;
    if (progress.completed) {
      _stageMap();
      return;
    }
    final index = progress.nextStageIndex;
    _selectStage(index);
    // Every stage shows its short objective before the clock starts.
  }

  void _retryStage() {
    audio.stopEffects();
    _newRewards = const [];
    game.retryStage();
  }

  void _endRun() {
    audio.stopEffects();
    game.endRun();
  }

  void _stageMap() {
    audio.stopEffects();
    _showStages = true;
    _showRewards = false;
    _showPractice = false;
    _newRewards = const [];
    _classicRunActive = false;
    game.returnToMenu();
  }

  void _home() {
    audio.stopEffects();
    _showStages = false;
    _showRewards = false;
    _showPractice = false;
    _newRewards = const [];
    _classicRunActive = false;
    game.returnToMenu();
  }

  void _openRewards() {
    if (!_progressLoaded || model.isPlaying) return;
    audio.stopEffects();
    _showStages = _showStages || model.isChallenge;
    _showRewards = true;
    _showPractice = false;
    _classicRunActive = false;
    game.returnToMenu();
  }

  void _closeRewards() => setState(() => _showRewards = false);

  void _practiceMenu() {
    if (!_progressLoaded) return;
    audio.stopEffects();
    _showStages = _showRewards = false;
    _showPractice = true;
    _classicRunActive = false;
    _newRewards = const [];
    game.returnToMenu();
  }

  void _startPractice(PracticeDrill drill) {
    if (!_progressLoaded) return;
    final lessons = _needed([
      TutorialLesson.aim,
      if (drill == PracticeDrill.curveWall) ...[
        TutorialLesson.curveLeft, TutorialLesson.curveRight, TutorialLesson.banana,
      ],
      if (drill == PracticeDrill.knuckle) TutorialLesson.knuckle,
    ]);
    if (lessons.isNotEmpty) {
      unawaited(_teach(lessons, after: () => _startPractice(drill)));
      return;
    }
    audio.stopEffects();
    _showStages = _showRewards = _showPractice = false;
    _classicRunActive = false;
    _newRewards = const [];
    _practiceBestBefore = practiceProgress.bestFor(drill);
    game.startPractice(drill);
  }

  void _equipReward(StarReward reward) {
    if (!_progressLoaded || !cosmetics.equip(reward, progress.totalStars)) return;
    game.applyCosmetics(cosmetics);
    final savedLooks = cosmetics.encode();
    _enqueueWrite(() => prefs.setString(CosmeticSelection.storageKey, savedLooks));
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground && model.isPlaying) {
      game.matchPaused = true;
    }
    if (_foreground && !_tutorialOpen) game.resumeEngine();
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
      canPop: ready && !_showStages && !_showRewards && !_showPractice,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_showRewards) {
            _closeRewards();
          } else if (model.isPlaying) {
            if (!game.matchPaused) {
              _pause();
            }
          } else if (model.isPractice) {
            _practiceMenu();
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
                      onPressed: () => _setSound(!sound),
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
                    if (!model.isPlaying && (!ready || _showStages || _showRewards || _showPractice))
                      IconButton(
                          tooltip: _showRewards ? 'Back' : model.isPractice ? 'Practice arena'
                              : model.isChallenge ? 'Stage select' : 'Home',
                          onPressed: _showRewards ? _closeRewards : model.isPractice ? _practiceMenu
                              : model.isChallenge ? _stageMap : _home,
                          icon: const Icon(Icons.arrow_back_rounded)),
                  ]),
                ),
                if (!ready && model.phase != MatchPhase.stageIntro) Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (model.isPractice) ...[
                          _stat('HITS', '${model.practiceHits}/5', primary: true),
                          _stat(_practiceHistoryAvailable ? 'BEST' : 'SESSION BEST',
                              '${practiceProgress.bestFor(model.practice!)}/5'),
                          _stat('BALLS LEFT', '${model.practiceBallsLeft}'),
                        ] else ...[
                          _stat(model.isChallenge ? 'STAGE SCORE' : 'SCORE',
                              model.score.toString().padLeft(2, '0'),
                              primary: true),
                          if (model.isChallenge)
                            _stat(model.isTimed ? 'TIME LEFT' : 'STAGE',
                                model.isTimed ? '${model.timerSeconds}s' : '${model.level}/${challengeStages.length}',
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
                        ],
                      ]),
                ),
                Expanded(
                  child: Stack(fit: StackFit.expand, children: [
                    ShotGestureSurface(
                      enabled: model.phase == MatchPhase.aiming && !game.matchPaused,
                      onBegin: () {
                        final accepted = game.beginShot();
                        if (accepted) setState(() {}); // Hide the previous correction once.
                        return accepted;
                      },
                      onDrag: (dx, dy) => game.adjustCurve(dx, dragY: dy),
                      onRelease: _releaseShot,
                      onCancel: game.cancelShot,
                      onAccessibleShot: _shoot,
                      child: _pitch,
                    ),
                    // Live first-match coach reads the model; it never takes input.
                    if (FirstTouchCoach.shouldShow(model, paused: game.matchPaused))
                      IgnorePointer(child: FirstTouchCoach(model: model)),
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
                          const SizedBox(height: 6),
                          if (model.lastWasGoal)
                            Text('+${model.lastPoints}', style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19)),
                          if (model.shotIsKnuckle || model.shotSpin != 0)
                            Text(model.lastTechnique, textAlign: TextAlign.center,
                                style: const TextStyle(color: Color(0xff7edfff), fontSize: 12)),
                          if (model.isPractice)
                            Text(model.lastPracticeNote, textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ]),
                      ))),
                    if (ready || finished || stageOverlay || game.matchPaused)
                      ColoredBox(
                          color: ink.withValues(alpha: .80),
                          child: LayoutBuilder(
                              builder: (context, constraints) =>
                                  SingleChildScrollView(
                                    key: ValueKey((model.phase, model.stageIndex,
                                        model.practice, _showStages, _showRewards, _showPractice, game.matchPaused)),
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
    if (ready && _showPractice) {
      return PracticeMenu(progress: practiceProgress, recordsAvailable: _practiceHistoryAvailable,
          onSelect: _startPractice, onBack: _home,
          onTutorial: (lesson) => unawaited(_teach([lesson], replay: true)),
          onReplayTutorial: () => unawaited(_teach(TutorialLesson.values, replay: true)));
    }
    if (ready && _showRewards) {
      return StarRewardsPanel(stars: progress.totalStars, selection: cosmetics,
          onEquip: _equipReward, onBack: _closeRewards);
    }
    if (ready && _showStages) {
      return ChallengeMap(progress: progress, rivals: rivals,
          recordsAvailable: _rivalHistoryAvailable,
          onSelect: _selectStage, onBack: _home, onRewards: _openRewards);
    }
    if (ready) {
      return HomePanel(progress: progress, loaded: _progressLoaded,
          onQuickPlay: _quickPlay, onStages: _stageMap,
          onClassic: _startClassic, onRewards: _openRewards, onPractice: _practiceMenu,
          onAudio: _progressLoaded ? _openAudioSettings : null);
    }
    if (model.isPractice && finished && !game.matchPaused) {
      return PracticeResultPanel(model: model, best: practiceProgress.bestFor(model.practice!),
          recordsAvailable: _practiceHistoryAvailable,
          newBest: model.practiceCompleted && model.practiceHits > _practiceBestBefore,
          onRetry: () => _startPractice(model.practice!), onDrills: _practiceMenu);
    }
    if (model.isChallenge && !game.matchPaused) {
      return StagePanel(
        model: model,
        progress: progress,
        rivals: rivals,
        recordsAvailable: _rivalHistoryAvailable,
        newRewards: _newRewards,
        onRewards: _openRewards,
        onStart: _startStage,
        onRetry: _retryStage,
        onNext: () => model.isFinalStage ? _stageMap() : _selectStage(model.stageIndex! + 1),
        onStages: _stageMap,
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(finished ? 'FULL TIME' : 'TAKE A BREATHER',
          style: const TextStyle(color: lime, fontSize: 10, letterSpacing: 2,
              fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      Text(finished ? '${model.score}' : 'PAUSED', textAlign: TextAlign.center,
          style: TextStyle(fontSize: finished ? 78 : 43,
              fontWeight: FontWeight.w900, height: 1.02, letterSpacing: -1.5)),
      const SizedBox(height: 16),
      Text(finished ? 'Best $best · Aim for ${best + 1} points next.'
          : model.isPractice ? '${model.practice!.title}\nYour drill is paused.' : model.isChallenge
              ? '${model.stage!.name}\nYour objective and clock are paused.'
              : 'Your match is waiting.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, height: 1.6, fontSize: 14)),
      if (finished && model.lastFailure != null) ...[
        const SizedBox(height: 12),
        Text(model.retryAdvice, textAlign: TextAlign.center,
            style: const TextStyle(color: lime, height: 1.4, fontSize: 13)),
      ],
      const SizedBox(height: 18),
      SizedBox(width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: lime, foregroundColor: ink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: finished ? _startClassic : _pause,
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(finished ? 'PLAY AGAIN  ↻' : 'RESUME  →',
                    style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5))),
          )),
      if (finished) ...[
        const SizedBox(height: 22),
        RunSummary(model: model, personalBest: _personalBest, previousBest: _bestBeforeRun),
        TextButton(onPressed: _home, child: const Text('HOME & CHALLENGES')),
      ] else ...[
        TextButton.icon(onPressed: _progressLoaded ? _openAudioSettings : null,
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('AUDIO MIX')),
        Padding(padding: const EdgeInsets.only(top: 10),
            child: TextButton(onPressed: _endRun,
                child: Text(model.isPractice ? 'END DRILL' : model.isChallenge ? 'END STAGE' : 'END RUN',
                    style: const TextStyle(color: Colors.white54,
                        fontWeight: FontWeight.w800, letterSpacing: 1.6)))),
        if (model.isChallenge && !model.objectiveMet)
          const Text('Ending this attempt gives the keeper a win.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.white54)),
      ],
    ]);
  }

  String _playHint() {
    if (!storageAvailable) return 'Progress saving unavailable';
    if (model.phase != MatchPhase.aiming || model.isPreparingShot) return '';
    return model.lastFailure?.shortAdvice ?? '';
  }

  Widget _footer() {
    if (model.isPractice) {
      return PracticeFooter(model: model,
          savingAvailable: _practiceHistoryAvailable && storageAvailable);
    }
    if (_showPractice) {
      return const Padding(padding: EdgeInsets.all(18),
          child: Text('FIVE BALLS · INSTANT RETRY',
              style: TextStyle(fontSize: 10, color: Colors.white60, letterSpacing: 1)));
    }
    final stage = model.stage;
    if (!model.isPlaying || game.matchPaused) {
      return storageAvailable ? const SizedBox(height: 8)
          : const Padding(padding: EdgeInsets.all(8),
              child: Text('Progress saving unavailable',
                  style: TextStyle(color: Colors.white60, fontSize: 11)));
    }
    final hint = _playHint();
    return Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (stage != null) StageObjectiveView(model: model),
        const SizedBox(height: 8),
        Semantics(label: stage == null
            ? '${model.streak} consecutive goals'
            : model.fireReady ? 'Fire shot ready. Next goal scores double.'
                : '${model.fireCharge} of ${stage.fireChargeGoals} to Fire',
          child: ExcludeSemantics(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.local_fire_department_rounded, color: Color(0xffffc857), size: 19),
            const SizedBox(width: 6),
            Text(model.onFire ? 'FIRE · ×2' : stage == null ? '${model.streak}/5' : 'FIRE',
                style: const TextStyle(color: Color(0xffffc857), fontSize: 11)),
            if (stage != null) ...[
              const SizedBox(width: 8),
              for (var i = 0; i < stage.fireChargeGoals; i++)
                Container(width: 16, height: 6, margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(3),
                        color: i < model.fireCharge ? const Color(0xffffc857) : Colors.white12)),
            ],
          ])),
        ),
        // Reserve one short correction line so taking a shot cannot resize the pitch.
        SizedBox(height: MediaQuery.textScalerOf(context).scale(28),
            child: Center(child: Text(hint, maxLines: 2, overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.white70)))),
      ]),
    );
  }
}
