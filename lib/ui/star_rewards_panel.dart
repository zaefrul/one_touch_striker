import 'package:flutter/material.dart';
import '../game/star_rewards.dart';

class NextRewardCard extends StatelessWidget {
  const NextRewardCard({super.key, required this.stars, required this.onOpen});
  final int stars;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final next = nextStarReward(stars);
    return Card(
      color: const Color(0xff173e35),
      child: ListTile(
        onTap: onOpen,
        leading: const Icon(Icons.card_giftcard, color: Color(0xffffc857)),
        title: Text(next == null ? 'Collection complete!' : 'Next: ${next.title}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        subtitle: Text(next == null ? 'All five star rewards unlocked.'
            : '${next.stars - stars} more ${next.stars - stars == 1 ? 'star' : 'stars'} to unlock',
            style: const TextStyle(fontSize: 12, color: Colors.white70)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class StarRewardsPanel extends StatelessWidget {
  const StarRewardsPanel({super.key, required this.stars, required this.selection,
      required this.onEquip, required this.onBack});
  final int stars;
  final CosmeticSelection selection;
  final ValueChanged<StarReward> onEquip;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('STAR REWARDS', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      Text('$stars stars earned', textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xffffc857), fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Earn stars to unlock new looks. Stars are never spent.\nEquip one look per category; every ball plays the same.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.5)),
      const SizedBox(height: 18),
      for (final slot in RewardSlot.values) ...[
        Padding(padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(slot.name.toUpperCase(),
                style: const TextStyle(fontSize: 11, letterSpacing: 2, color: Colors.white60))),
        for (final reward in StarReward.values.where((reward) => reward.slot == slot))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _RewardTile(reward: reward, stars: stars,
                equipped: selection.selected(slot) == reward, onEquip: () => onEquip(reward)),
          ),
      ],
      const SizedBox(height: 12),
      TextButton(onPressed: onBack, child: const Text('BACK')),
    ],
  );
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({required this.reward, required this.stars,
      required this.equipped, required this.onEquip});
  final StarReward reward;
  final int stars;
  final bool equipped;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    final unlocked = stars >= reward.stars;
    final icon = switch (reward.slot) {
      RewardSlot.ball => Icons.sports_soccer,
      RewardSlot.net => Icons.grid_on,
      RewardSlot.pitch => reward == StarReward.nightPitch ? Icons.nights_stay : Icons.wb_sunny,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: equipped ? const Color(0xffd9ff6a) : Colors.white12)),
      child: Row(children: [
        CircleAvatar(backgroundColor: Color(reward.primary),
            child: Icon(icon, color: Color(reward.secondary), size: 24)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(reward.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 4),
          Text(reward.stars == 0 ? 'Available from the start'
              : unlocked ? 'Unlocked at ${reward.stars} stars'
                  : '${reward.stars - stars} more stars needed',
              style: const TextStyle(fontSize: 11, color: Colors.white60)),
        ])),
        const SizedBox(width: 6),
        Tooltip(message: equipped ? '${reward.title} equipped' : 'Equip ${reward.title}',
          child: OutlinedButton(
            key: ValueKey('equip_${reward.name}'),
            onPressed: unlocked && !equipped ? onEquip : null,
            child: Text(equipped ? 'USING' : unlocked ? 'USE' : '${reward.stars} ★'),
          ),
        ),
      ]),
    );
  }
}
