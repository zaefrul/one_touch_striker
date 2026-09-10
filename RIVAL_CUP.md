# Rival Cup: showdowns, rewards and rematches

This source milestone extends the owner's preferred `feat/stage-challenges`
branch from `2d2a3d21e9733479c9c4c68dc297c9d65031e093`. The goal is to give each
short session a clear reason to continue: defeat a showdown, unlock a new look,
or improve a personal scoreline against a keeper. Engagement and difficulty
still need the owner's playtest; no retention or performance results are claimed.

## Four showdowns

The existing twelve stages keep their order, unlocks, three chances and best
stars. Every third stage adds a distinct win condition and a permanent trophy.
The objective box and pitch footer explain the extra condition throughout play.

| Stage | Showdown | To win |
| --- | --- | --- |
| 3 · Corner Artist | Corner Duel | Score once in each glowing corner. Repeat goals in one corner earn points and Fire charge but do not advance the second corner. No timer. |
| 6 · Captain's Finish | Fire Finish | Reach at least 8 points with a Fire goal as the finishing shot, within 30 active seconds. The finishing goal counts toward the total. |
| 9 · Triple Wall | Rush Hour | Score at least 5 goals, including one past a rushing keeper. Every third accepted shot is signalled `RUSH INCOMING`. No timer. |
| 12 · Champion's Gate | Champion Final | Reach at least 18 points with a Fire corner as the finishing shot, within 34 active seconds. |

For Fire Finish and Champion Final, an earlier Fire goal alone is insufficient
if the eventual points threshold is reached on a different kind of shot. The
stage remains open until the full condition is met or time/chances run out.
Rush Hour remembers a rush goal even if it occurs before goal five. The rush
schedule includes misses and blocks; waiting does not change which shot rushes.

The final's timer increases from 28 to 34 active seconds to allow another charge
cycle. Five consecutive corners score 3 + 3 + 6 + 3 + 3 = 18 but the fifth is
not a Fire shot. The sixth corner scores 6 more and clears. Another scoring
sequence is corner, centre, Fire corner, centre, centre, Fire corner:
3 + 1 + 6 + 1 + 1 + 6 = 18. These are arithmetic examples, not verified routes
through the moving defence or evidence that the timer is balanced.

A qualifying shot released before zero can still win. Pausing or ending during
the winning goal celebration preserves the clear. Retry resets both corner
flags, rush progress, shot count and Fire charge along with the existing state.
The other eight stages and Classic retain their prior win conditions.

## Star rewards

| Total best stars | Unlock | Appearance |
| --- | --- | --- |
| 3 | Neon Ball | Lime ball with a small halo |
| 9 | Retro Ball | Warm leather colours |
| 18 | Golden Net | Gold net and goal frame |
| 27 | Night Stadium | Dark blue pitch and decorative floodlights |
| 36 | Champion Ball | Gold ball with a star patch |

The next reward and remaining stars appear on Home and the stage map. A clear
that crosses a threshold shows the unlocked item with an equip action. STAR
REWARDS opens the collection from either screen. Players equip one ball, one
net and one pitch; the original looks remain available. Back returns to the
screen that opened the collection (a result-screen equip returns to the map).

Stars are never spent. Only improvements to a stage's best stars increase the
total, so repeating a three-star clear cannot farm currency. Looks apply to
Classic and challenges and change drawing only: ball radius, trajectory,
collisions, timing and keeper behaviour are unchanged. Night Stadium overrides
stage pitch colours while equipped; choosing Stage Colours restores them.

## Personal rival records

Each named keeper has a local `You X · Keeper Y` scoreline across all challenge
stages featuring that keeper. The map, briefing and results show it.

- A stage clear is a player win, including replays that earn no new stars.
- Running out of chances or time is a keeper win.
- END STAGE after starting is a forfeit and counts as a keeper win. The pause
  panel explains this. A winning goal already in feedback remains a player win.
- Opening or leaving a briefing, pausing, resuming, toggling settings and
  revisiting a result do not add a result. Classic does not affect this record.
- A completed attempt is counted once using an in-memory attempt ID. Restarting
  the screen creates a new ledger that restores totals and accepts new IDs.
- Closing the process mid-attempt abandons it without a result. In-progress
  attempts are not resumed or inferred after relaunch.

Each showdown can award one trophy; rematches still update the keeper scoreline.
Collecting all four shows RIVAL CUP WON. A previously completed campaign offers
the first missing showdown from the map, so old players have a new target.

## Save continuity

| Key | Contents | Upgrade behaviour |
| --- | --- | --- |
| `challenge_stars_v1` | Existing best-star list | Same key and stage positions. Six-entry and twelve-entry saves keep existing medals and unlocks. |
| `rival_cup_records_v1` | Versioned JSON with keeper wins/losses and showdown IDs | New records start at zero; old clears are not invented as wins or trophies. |
| `striker_cosmetics_v1` | Versioned JSON with equipped ball, net and pitch IDs | Original looks by default. Existing stars immediately qualify for rewards. |

New data uses stable enum names rather than display text or stage list indices.
Unknown trophies are ignored; invalid counters are sanitized. An unreadable or
unknown-version rival record displays as unavailable and is not overwritten
with zero history. Optional record/equipment read failures do not discard a
successfully loaded star list. Unknown, wrong-slot or locked equipment is ignored.
Writes use the existing serial queue and captured snapshots. A failed write
shows the existing saving-unavailable notice; persistence then cannot be promised.
Classic best score, sound and haptics keep their existing keys.

## Rendering and handoff

Cosmetics use code-drawn colours and reusable paths. Equipping a net or pitch
invalidates the cached field picture once, as does changing stages. Floodlights
are recorded into that picture. Ball colour changes reuse paints; the champion
patch is prepared once. No new dependency, audio asset, animation ticker or
per-frame storage write is introduced. These design choices do not establish
measured frame performance.

No analyzer, tests, builds, app runs or GitHub workflows were executed for this
publication. The branch workflow remains manual-only. Prepared regression
sources in `test/rival_cup_test.dart` and `test/rival_cup_widget_test.dart` cover
showdown edge cases, single-count results, forfeit/relaunch behaviour, old saves,
reward thresholds and equipment saving. Existing objective fixtures now account
for opposite corners and the final's Fire finish and 34-second reset.

For the owner's local checks:

1. Upgrade with old stars. Confirm unlocks survive, rival totals start at zero,
   earned cosmetics are available, and no old trophy is invented.
2. Score twice in the same corner in stage three, then switch. Check the hint,
   distinct-corner progress, Fire charge and trophy after the clear.
3. Reach stage six's points target on a normal goal. It should wait for the Fire
   finish. Check a winning buzzer shot and ending during its celebration.
4. In stage nine, check the warning before shots 3, 6 and 9. Score enough normal
   goals without a rush goal, then beat the rush to finish. Confirm retry resets it.
5. In stage twelve, compare the 34-second clock with actual time spent charging
   and waiting for lanes. A Fire centre goal must not complete the final.
6. Replay a three-star clear, forfeit a new attempt, pause, leave a briefing,
   then reopen the app. Check each completed win/loss counted exactly once.
7. Unlock and equip a ball, net and pitch. Reopen, switch back to defaults and
   play both modes. Check ball visibility, corners, saved looks and unchanged stars.
8. Check map/reward/briefing/results scrolling, Back navigation and larger text
   on a small phone. Capture any first-shot or stage-switch stutter using the
   existing opt-in local markers described in `PERFORMANCE_NOTES.md`.

Share the device and build/run outcome, attempts per showdown, unclear failures,
time spent waiting and whether the next reward or keeper rematch made you want
another attempt. Use those observations to choose the next balance changes.
