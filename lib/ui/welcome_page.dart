import 'package:flutter/material.dart';
import 'theme.dart';
import 'widgets.dart';

/// First-launch introduction. Two short screens: what the game is, then how a
/// shot works. It never touches the match, stars or save queues; the caller
/// decides what happens after Play or Skip.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key, required this.onPlay, required this.onSkip});
  final VoidCallback onPlay, onSkip;

  static const pageCount = 2;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final _controller = PageController();
  int _page = 0;
  bool _leaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_leaving) return;
    if (MediaQuery.of(context).disableAnimations) {
      _controller.jumpToPage(_page + 1);
    } else {
      _controller.nextPage(
          duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
    }
  }

  void _leave({required bool play}) {
    if (_leaving) return;
    _leaving = true;
    if (play) { widget.onPlay(); } else { widget.onSkip(); }
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == WelcomePage.pageCount - 1;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave(play: false);
      },
      child: Scaffold(backgroundColor: StrikerColors.ink, body: SafeArea(
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480),
          child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 8, 8, 0), child: Row(children: [
              const BallGlyph(size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('WELCOME · ${_page + 1}/${WelcomePage.pageCount}',
                  style: StrikerText.statLabel)),
              TextButton(onPressed: () => _leave(play: false), child: const Text('Skip intro')),
            ])),
            Expanded(child: PageView(
              controller: _controller,
              onPageChanged: (page) => setState(() => _page = page),
              children: const [_IntroCard(), _ShotCard()],
            )),
            Semantics(label: 'Page ${_page + 1} of ${WelcomePage.pageCount}',
              child: ExcludeSemantics(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < WelcomePage.pageCount; i++)
                  Container(width: i == _page ? 22 : 8, height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(4),
                          color: i == _page ? StrikerColors.gold : StrikerColors.outline)),
              ]))),
            Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 16), child: PrimaryButton(
              buttonKey: const ValueKey('welcome_primary'),
              onPressed: last ? () => _leave(play: true) : _next,
              label: last ? 'LET’S PLAY  →' : 'NEXT  →',
            )),
          ]),
        )),
      )),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) => _Card(children: [
    const BallGlyph(size: 64),
    const SizedBox(height: 22),
    const Eyebrow('WELCOME'),
    const SizedBox(height: 10),
    const Text('ONE TAP.\nALL GLORY.', textAlign: TextAlign.center, style: StrikerText.headline),
    const SizedBox(height: 16),
    const Text('You are the striker. Beat the keeper.',
        textAlign: TextAlign.center, style: StrikerText.body),
    const SizedBox(height: 14),
    Panel(
      color: StrikerColors.surface,
      borderColor: StrikerColors.gold.withValues(alpha: .3),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: const Column(mainAxisSize: MainAxisSize.min, children: [
        Eyebrow('YOUR FIRST MATCH'),
        SizedBox(height: 6),
        Text('Score 3 goals · 3 chances', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
            fontFamily: StrikerFonts.display, color: StrikerColors.text)),
      ]),
    ),
  ]);
}

class _ShotCard extends StatelessWidget {
  const _ShotCard();

  @override
  Widget build(BuildContext context) => const _Card(children: [
    Eyebrow('HOW TO SHOOT'),
    SizedBox(height: 10),
    Text('LOCK.\nBEND.\nRELEASE.', textAlign: TextAlign.center,
        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, height: 1.05, letterSpacing: -1,
            fontFamily: StrikerFonts.display, color: StrikerColors.text)),
    SizedBox(height: 20),
    _Step(icon: Icons.touch_app_rounded, title: 'LOCK',
        body: 'Touch the pitch to lock the sweeping arrow.'),
    SizedBox(height: 12),
    _Step(icon: Icons.swap_horiz_rounded, title: 'BEND',
        body: 'Keep holding and drag sideways to curve the ball.'),
    SizedBox(height: 12),
    _Step(icon: Icons.sports_soccer, title: 'RELEASE',
        body: 'Lift your finger to shoot.'),
    SizedBox(height: 18),
    Text('Where you touch does not steer the ball. The arrow does.',
        textAlign: TextAlign.center, style: StrikerText.caption),
  ]);
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, constraints) =>
    SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: children),
      ),
    ));
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title, body;

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 44, height: 44,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: StrikerColors.goldSoft,
            border: Border.all(color: StrikerColors.gold.withValues(alpha: .4))),
        child: Icon(icon, color: StrikerColors.gold, size: 22)),
    const SizedBox(width: 14),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: StrikerText.statLabel.copyWith(color: StrikerColors.text)),
      const SizedBox(height: 2),
      Text(body, style: StrikerText.body.copyWith(fontSize: 13)),
    ])),
  ]);
}
