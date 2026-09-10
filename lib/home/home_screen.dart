import 'package:flutter/material.dart';
import '../account/account_sheet.dart';
import '../app_session.dart';
import '../progress/campaign.dart';
import '../progress/progress_screen.dart';
import 'play_flow.dart';

const _lime = Color(0xffd9ff6a);
const _ink = Color(0xff062d29);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.session});

  final StrikerSession session;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StrikerSession get session => widget.session;

  @override
  Widget build(BuildContext context) {
    final next = session.progress.continueTarget;
    return Scaffold(
      backgroundColor: _ink,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 14, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.sports_soccer, color: _lime, size: 23),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: Text(
                          'ONE-TOUCH\nSTRIKER',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                            letterSpacing: 1.5,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Account',
                        onPressed: () async {
                          await showAccountSheet(
                            context: context,
                            auth: session.auth,
                          );
                          if (mounted) {
                            setState(() {});
                          }
                        },
                        icon: session.auth.signedIn
                            ? CircleAvatar(
                                radius: 11,
                                backgroundColor: _lime,
                                child: Text(
                                  session.auth.user!.initials,
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              )
                            : const Icon(Icons.person_outline,
                                size: 20, color: Colors.white60),
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
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    'CAMPAIGN',
                    style: TextStyle(
                      color: _lime,
                      fontSize: 11,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'ONE TAP.\nALL GLORY.',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      height: 1.02,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${session.progress.totalStars} / ${Campaign.maxStars} STARS',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    session.auth.signedIn
                        ? 'Signed in as ${session.auth.user!.name}.'
                        : 'Guest. Stars stay on this device.',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _lime,
                        foregroundColor: _ink,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        await playSubstage(
                          context: context,
                          session: session,
                          target: next,
                        );
                        if (mounted) {
                          setState(() {});
                        }
                      },
                      child: Text(
                        'CONTINUE  ·  ${next.code}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => ProgressScreen(session: session),
                          ),
                        );
                        if (mounted) {
                          setState(() {});
                        }
                      },
                      child: const Text(
                        'PROGRESS',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
