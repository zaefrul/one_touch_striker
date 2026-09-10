import 'package:flutter/material.dart';
import '../app_session.dart';
import '../match/match_screen.dart';
import '../progress/campaign.dart';
import 'loadout_sheet.dart';

Future<void> playSubstage({
  required BuildContext context,
  required StrikerSession session,
  required SubstageRef target,
}) async {
  final bonus = await showLoadoutSheet(
    context: context,
    progress: session.progress,
    target: target,
  );
  if (bonus == null || !context.mounted) {
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => MatchScreen(
        session: session,
        target: target,
        bonus: bonus,
      ),
    ),
  );
}
