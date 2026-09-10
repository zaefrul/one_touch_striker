import 'package:flutter/material.dart';
import '../app_session.dart';
import '../home/play_flow.dart';
import 'campaign.dart';

const _lime = Color(0xffd9ff6a);
const _ink = Color(0xff062d29);

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, required this.session});

  final StrikerSession session;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int _openVenue = 0;

  StrikerSession get session => widget.session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const Expanded(
                        child: Text(
                          'PROGRESS',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.8,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        '${session.progress.totalStars} ★',
                        style: const TextStyle(
                          color: _lime,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: Campaign.venues,
                      itemBuilder: (context, venue) {
                        final stage = Campaign.venue(venue);
                        final open = session.progress.venueUnlocked(venue);
                        final expanded = open && _openVenue == venue;
                        var venueStars = 0;
                        for (var sub = 0;
                            sub < Campaign.substagesPerVenue;
                            sub++) {
                          venueStars += session.progress.stars(venue, sub);
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: Colors.white.withValues(alpha: .05),
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: open
                                  ? () => setState(() => _openVenue = venue)
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 14, 16, 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '${venue + 1}',
                                          style: TextStyle(
                                            color: open ? _lime : Colors.white24,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            stage.title,
                                            style: TextStyle(
                                              color: open
                                                  ? Colors.white
                                                  : Colors.white38,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: .4,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          open
                                              ? '$venueStars / 30'
                                              : 'LOCKED',
                                          style: TextStyle(
                                            color: open
                                                ? Colors.white54
                                                : Colors.white30,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (expanded) ...[
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          for (var sub = 0;
                                              sub < Campaign.substagesPerVenue;
                                              sub++)
                                            _SubTile(
                                              venue: venue,
                                              sub: sub,
                                              stars: session.progress
                                                  .stars(venue, sub),
                                              unlocked: session.progress
                                                  .unlocked(venue, sub),
                                              onPlay: () async {
                                                await playSubstage(
                                                  context: context,
                                                  session: session,
                                                  target:
                                                      SubstageRef(venue, sub),
                                                );
                                                if (mounted) {
                                                  setState(() {});
                                                }
                                              },
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
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

class _SubTile extends StatelessWidget {
  const _SubTile({
    required this.venue,
    required this.sub,
    required this.stars,
    required this.unlocked,
    required this.onPlay,
  });

  final int venue;
  final int sub;
  final int stars;
  final bool unlocked;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: unlocked ? _lime.withValues(alpha: .14) : Colors.white10,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: unlocked ? onPlay : null,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 68,
          height: 58,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${venue + 1}-${sub + 1}',
                style: TextStyle(
                  color: unlocked ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                unlocked ? '★' * stars + '☆' * (3 - stars) : '🔒',
                style: TextStyle(
                  color: unlocked ? _lime : Colors.white24,
                  fontSize: unlocked ? 11 : 12,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
