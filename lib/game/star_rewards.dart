import 'dart:convert';

enum RewardSlot { ball, net, pitch }

/// These choices change drawing only. Stars unlock them permanently and are
/// never spent; the match model has no dependency on cosmetic selections.
enum StarReward {
  classicBall('Classic Ball', RewardSlot.ball, 0, 0xfff8faed, 0xff233e37),
  neonBall('Neon Ball', RewardSlot.ball, 3, 0xffd9ff6a, 0xff164d50),
  retroBall('Retro Ball', RewardSlot.ball, 9, 0xffffd7a0, 0xff794c2c),
  championBall('Champion Ball', RewardSlot.ball, 36, 0xffffc857, 0xff533c75),
  standardNet('Classic Net', RewardSlot.net, 0, 0xff32635a, 0xffeef8df),
  goldNet('Golden Net', RewardSlot.net, 18, 0xffb78b42, 0xffffd777),
  dayPitch('Stage Colours', RewardSlot.pitch, 0, 0xff126a50, 0xff167456),
  nightPitch('Night Stadium', RewardSlot.pitch, 27, 0xff0a2338, 0xff103047);

  const StarReward(this.title, this.slot, this.stars, this.primary, this.secondary);
  final String title;
  final RewardSlot slot;
  final int stars;
  final int primary;
  final int secondary;
}

const milestoneRewards = [
  StarReward.neonBall, StarReward.retroBall, StarReward.goldNet,
  StarReward.nightPitch, StarReward.championBall,
];

StarReward? nextStarReward(int stars) {
  for (final reward in milestoneRewards) {
    if (stars < reward.stars) return reward;
  }
  return null;
}

List<StarReward> rewardsEarnedBetween(int before, int after) =>
    milestoneRewards.where((reward) => before < reward.stars && after >= reward.stars).toList();

class CosmeticSelection {
  static const storageKey = 'striker_cosmetics_v1';
  StarReward ball = StarReward.classicBall;
  StarReward net = StarReward.standardNet;
  StarReward pitch = StarReward.dayPitch;

  StarReward selected(RewardSlot slot) => switch (slot) {
    RewardSlot.ball => ball, RewardSlot.net => net, RewardSlot.pitch => pitch,
  };

  bool equip(StarReward reward, int totalStars) {
    if (totalStars < reward.stars || selected(reward.slot) == reward) return false;
    switch (reward.slot) {
      case RewardSlot.ball:
        ball = reward;
        break;
      case RewardSlot.net:
        net = reward;
        break;
      case RewardSlot.pitch:
        pitch = reward;
        break;
    }
    return true;
  }

  String encode() => jsonEncode({
    'version': 1, 'ball': ball.name, 'net': net.name, 'pitch': pitch.name,
  });

  bool restore(String? source, int totalStars) {
    if (source == null) return true;
    try {
      final data = jsonDecode(source);
      if (data is! Map || data['version'] != 1) return false;
      for (final reward in StarReward.values) {
        if (data[reward.slot.name] == reward.name && totalStars >= reward.stars) {
          equip(reward, totalStars);
        }
      }
      return true;
    } on FormatException {
      return false;
    }
  }
}
