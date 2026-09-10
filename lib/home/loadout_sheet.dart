import 'package:flutter/material.dart';
import '../game/bonus.dart';
import '../progress/campaign.dart';
import '../progress/progress_store.dart';

const _lime = Color(0xffd9ff6a);
const _ink = Color(0xff062d29);

Future<BallBonus?> showLoadoutSheet({
  required BuildContext context,
  required ProgressStore progress,
  required SubstageRef target,
}) {
  return showModalBottomSheet<BallBonus>(
    context: context,
    backgroundColor: _ink,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => LoadoutSheet(progress: progress, target: target),
  );
}

class LoadoutSheet extends StatefulWidget {
  const LoadoutSheet({
    super.key,
    required this.progress,
    required this.target,
  });

  final ProgressStore progress;
  final SubstageRef target;

  @override
  State<LoadoutSheet> createState() => _LoadoutSheetState();
}

class _LoadoutSheetState extends State<LoadoutSheet> {
  late BallBonus _picked;

  @override
  void initState() {
    super.initState();
    final stored = widget.progress.selectedBonus;
    _picked = widget.progress.bonusUnlocked(stored) ? stored : BallBonus.straight;
  }

  @override
  Widget build(BuildContext context) {
    final venue = Campaign.venue(widget.target.venue);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '${venue.title} · ${widget.target.sub + 1}/10',
                  style: const TextStyle(
                    color: _lime,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'PICK YOUR BALL',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '5 shots. Stars at ${widget.target.thresholds.join(' / ')}.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .62),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                for (final bonus in BallBonus.values) _tile(bonus),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    final picked = _picked;
                    widget.progress.selectBonus(picked);
                    Navigator.pop(context, picked);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _lime,
                    foregroundColor: _ink,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  child: const Text('KICK OFF'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(BallBonus bonus) {
    final unlocked = widget.progress.bonusUnlocked(bonus);
    final selected = _picked == bonus && unlocked;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? _lime : Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: unlocked ? () => setState(() => _picked = bonus) : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Icon(
                  unlocked ? Icons.sports_soccer : Icons.lock_rounded,
                  color: selected ? _ink : (unlocked ? _lime : Colors.white38),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bonus.label.toUpperCase(),
                        style: TextStyle(
                          color: selected ? _ink : Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        unlocked ? bonus.blurb : bonus.unlockHint,
                        style: TextStyle(
                          color: selected
                              ? _ink.withValues(alpha: .7)
                              : Colors.white54,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
