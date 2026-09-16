import 'package:flutter/material.dart';
import '../game/star_rewards.dart';
import 'theme.dart';
import 'widgets.dart';

class NextRewardCard extends StatelessWidget {
  const NextRewardCard({super.key, required this.stars, required this.onOpen});
  final int stars;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final next = nextStarReward(stars);
    return Material(
      color: StrikerColors.raised,
      borderRadius: BorderRadius.circular(StrikerSpace.radius),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(StrikerSpace.radius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(StrikerSpace.radius),
            border: Border.all(color: StrikerColors.goldLine),
          ),
          child: ListTile(
            leading: const Icon(Icons.card_giftcard, color: StrikerColors.gold),
            title: Text(next == null ? 'Collection complete!' : 'Next: ${next.title}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                    fontFamily: StrikerFonts.body, color: StrikerColors.text)),
            subtitle: Text(next == null ? 'All five star rewards unlocked.'
                : '${next.stars - stars} more ${next.stars - stars == 1 ? 'star' : 'stars'} to unlock',
                style: StrikerText.caption),
            trailing: const Icon(Icons.chevron_right, color: StrikerColors.muted),
          ),
        ),
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
      const Eyebrow('COLLECTION'),
      const SizedBox(height: 8),
      const Text('STAR REWARDS', textAlign: TextAlign.center, style: StrikerText.headline),
      const SizedBox(height: 12),
      Text('$stars stars earned', textAlign: TextAlign.center,
          style: StrikerText.eyebrow.copyWith(fontSize: 13)),
      const SizedBox(height: 8),
      const Text('Earn stars to unlock new looks. Stars are never spent.\nEquip one look per category; every ball plays the same.',
          textAlign: TextAlign.center, style: StrikerText.caption),
      const SizedBox(height: 18),
      for (final slot in RewardSlot.values) ...[
        Padding(padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(slot.name.toUpperCase(),
                style: StrikerText.eyebrow.copyWith(color: StrikerColors.muted))),
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
    final kind = switch (reward.slot) {
      RewardSlot.ball => RewardSwatchKind.ball,
      RewardSlot.net => RewardSwatchKind.net,
      RewardSlot.pitch => RewardSwatchKind.pitch,
    };
    return Panel(
      padding: const EdgeInsets.all(12),
      borderColor: equipped ? StrikerColors.gold : StrikerColors.outline,
      child: Row(children: [
        RewardSwatch(kind: kind, primary: Color(reward.primary), secondary: Color(reward.secondary)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(reward.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13,
              fontFamily: StrikerFonts.body, color: StrikerColors.text)),
          const SizedBox(height: 4),
          Text(reward.stars == 0 ? 'Available from the start'
              : unlocked ? 'Unlocked at ${reward.stars} stars'
                  : '${reward.stars - stars} more stars needed',
              style: StrikerText.caption),
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
