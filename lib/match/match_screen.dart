import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_session.dart';
import '../game/bonus.dart';
import '../game/match_model.dart';
import '../game/striker_game.dart';
import '../progress/campaign.dart';

const lime = Color(0xffd9ff6a);
const ink = Color(0xff062d29);

class MatchScreen extends StatefulWidget {
  const MatchScreen({
    super.key,
    required this.session,
    required this.target,
    required this.bonus,
  });

  final StrikerSession session;
  final SubstageRef target;
  final BallBonus bonus;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> with WidgetsBindingObserver {
  late final MatchModel model;
  late final StrikerGame game;
  bool _recorded = false;

  StrikerSession get session => widget.session;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    model = MatchModel(
      stage: widget.target.stage,
      intensity: widget.target.intensity,
      bonus: widget.bonus,
      shotsMax: Campaign.shotsMax,
    );
    game = StrikerGame(model, onChanged: _refresh, onShotResult: _result);
    model.start();
  }

  void _refresh() {
    if (model.phase == MatchPhase.finished) {
      unawaited(_recordStars());
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _recordStars() async {
    if (_recorded) {
      return;
    }
    _recorded = true;
    final earned = starsFor(model.score, widget.target.thresholds);
    await session.progress
        .recordStars(widget.target.venue, widget.target.sub, earned);
    if (mounted) {
      setState(() {});
    }
  }

  void _result() {
    if (session.haptics) {
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
    if (session.haptics) {
      unawaited(HapticFeedback.mediumImpact());
    }
    game.shoot();
  }

  void _pause() {
    setState(() => game.matchPaused = !game.matchPaused);
  }

  void _replay() {
    _recorded = false;
    game.startMatch();
  }

  Future<void> _next() async {
    final next = widget.target.next;
    if (next == null || !session.progress.unlocked(next.venue, next.sub)) {
      return;
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MatchScreen(
          session: session,
          target: next,
          bonus: session.progress.bonusUnlocked(widget.bonus)
              ? widget.bonus
              : BallBonus.straight,
        ),
      ),
    );
  }

  int get _hudShot {
    if (model.phase == MatchPhase.result ||
        model.phase == MatchPhase.finished) {
      return model.shotsTaken.clamp(1, model.shotsMax);
    }
    return (model.shotsTaken + 1).clamp(1, model.shotsMax);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        model.phase != MatchPhase.ready &&
        model.phase != MatchPhase.finished) {
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
    final finished = model.phase == MatchPhase.finished;
    final earned = starsFor(model.score, widget.target.thresholds);
    final next = widget.target.next;
    final nextOpen =
        next != null && session.progress.unlocked(next.venue, next.sub);
    return PopScope(
      canPop: finished,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !game.matchPaused) {
          _pause();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 14, 8),
                  child: Row(children: [
                    const Icon(Icons.sports_soccer, color: lime, size: 23),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        '${widget.target.stage.title}\n${widget.target.code}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          letterSpacing: 1.2,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: session.haptics
                          ? 'Turn vibration off'
                          : 'Turn vibration on',
                      onPressed: () async {
                        await session.setHaptics(!session.haptics);
                        if (mounted) {
                          setState(() {});
                        }
                      },
                      icon: Icon(
                        session.haptics
                            ? Icons.vibration
                            : Icons.phone_android,
                        size: 20,
                        color: Colors.white60,
                      ),
                    ),
                    if (!finished)
                      IconButton(
                        tooltip: game.matchPaused ? 'Resume' : 'Pause',
                        onPressed: _pause,
                        icon: Icon(game.matchPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded),
                      ),
                  ]),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _stat('SCORE', model.score.toString().padLeft(2, '0'),
                          primary: true),
                      _stat('BONUS', widget.bonus.title),
                      _stat('SHOT', '$_hudShot/${model.shotsMax}'),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(fit: StackFit.expand, children: [
                    Semantics(
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
                    if (!finished &&
                        !game.matchPaused &&
                        (model.lastChance || model.onFire))
                      IgnorePointer(
                        child: ColoredBox(
                          color: model.lastChance
                              ? const Color(0x18ff777a)
                              : const Color(0x14d9ff6a),
                        ),
                      ),
                    if (model.phase == MatchPhase.result && !game.matchPaused)
                      IgnorePointer(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 16),
                            decoration: BoxDecoration(
                              color: ink.withValues(alpha: .94),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  model.message,
                                  style: TextStyle(
                                    color: model.lastWasGoal
                                        ? lime
                                        : const Color(0xffff777a),
                                    fontSize: model.lastWasCorner ? 34 : 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  model.resultSubtitle,
                                  style: const TextStyle(
                                    letterSpacing: 2,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (finished || game.matchPaused)
                      ColoredBox(
                        color: ink.withValues(alpha: .80),
                        child: LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(26),
                                  child: finished
                                      ? _results(earned, nextOpen)
                                      : _paused(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
                  child: Column(children: [
                    Row(children: [
                      Text(
                        widget.bonus.title,
                        style: const TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.4,
                          color: Colors.white54,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        model.multiplier == 2
                            ? 'ON FIRE · 2× POINTS'
                            : '${model.streak}/3 STREAK TO 2×',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1,
                          color:
                              model.multiplier == 2 ? lime : Colors.white54,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (model.streak / 3).clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: Colors.white10,
                        color: lime,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      session.storageAvailable
                          ? (model.phase == MatchPhase.flying
                              ? (model.lastChance
                                  ? 'LAST CHANCE…'
                                  : 'SHOT AWAY…')
                              : model.showTapCue
                                  ? 'TAP THE GLOW. LOCK THE ARROW.'
                                  : model.lastChance
                                      ? 'LAST CHANCE. MAKE IT COUNT.'
                                      : model.onFire
                                          ? 'ON FIRE. GO FOR THE CORNER.'
                                          : 'TIME THE ARROW. TAP THE PITCH.')
                          : 'PROGRESS SAVING UNAVAILABLE',
                      style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.3,
                        color: Colors.white60,
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, {bool primary = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 1.8,
              color: Colors.white54,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: primary ? 36 : 22,
              height: 1.15,
              color: primary ? lime : Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );

  Widget _paused() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'TAKE A BREATHER',
            style: TextStyle(
              color: lime,
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'PAUSED',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 43,
              fontWeight: FontWeight.w900,
              height: 1.02,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your match is waiting.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, height: 1.6, fontSize: 14),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: lime,
                foregroundColor: ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _pause,
              child: const Text(
                'RESUME  →',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: TextButton(
              onPressed: game.endRun,
              child: const Text(
                'END SUBSTAGE',
                style: TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ),
        ],
      );

  Widget _results(int earned, bool nextOpen) {
    final bars = widget.target.thresholds;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'FULL TIME',
          style: TextStyle(
            color: lime,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${model.score}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 78,
            fontWeight: FontWeight.w900,
            height: 1.02,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '★' * earned + '☆' * (3 - earned),
          style: const TextStyle(
            color: lime,
            fontSize: 28,
            letterSpacing: 4,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Stars at ${bars.join(' / ')}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            height: 1.6,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: lime,
              foregroundColor: ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _replay,
            child: const Text(
              'REPLAY  ↻',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (nextOpen)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _next,
              child: Text(
                'NEXT  ·  ${widget.target.next!.code}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'MAP',
            style: TextStyle(
              color: Colors.white54,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}
