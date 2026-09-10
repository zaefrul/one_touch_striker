# Challenge milestone

The playtest feedback was that the game becomes dull. This milestone gives each
short stage a specific skill to practise, a visible finish line, and a reward
that remains useful on replay. It does not claim that difficulty or engagement
has been validated: these are initial balance values for the owner's playtest.

## Player flow

Home → PLAY CHALLENGES → stage map → briefing → START STAGE → play → clear or retry.
Only cleared stages unlock the next one. All unlocked stages remain replayable.
Three misses end the current attempt; timed stages also end when the clock
expires. Retry now starts that stage immediately with three fresh chances, a full
timer, empty Fire charge and zero score. New stages still show a briefing.
Clearing stage twelve shows the campaign finish and returns
the player to the map to improve their stars.

| Stage | Skill | Target | Opposition | Time |
| --- | --- | --- | --- | --- |
| First Touch | Timing | 3 goals | The Sweeper | Unlimited |
| Moving Wall | Reading lanes | 3 goals | The Sweeper + 1 defender | Unlimited |
| Corner Artist | Precision | 2 corner goals | The Sentinel; only glowing corners advance progress | Unlimited |
| Beat the Clock | Quick decisions | 4 goals | The Sentinel | 25 active seconds |
| Double Trouble | Reading two lanes | 4 goals | The Gambler + 2 crossing defenders | Unlimited |
| Captain's Finish | Combining skills | 8 points | The Gambler + 2 offset defenders | 30 active seconds |
| Pressure Cooker | Fast decisions through traffic | 5 goals | The Sweeper + 2 crossing defenders | 26 active seconds |
| Needle Threader | Corners through traffic | 3 corner goals | The Sentinel + 2 offset defenders | Unlimited |
| Triple Wall | Reading three lanes | 5 goals | The Gambler + 3 defenders in a repeating wave | Unlimited |
| Sudden Rush | Converting Fire charge to points | 12 points | The Sweeper + 2 faster crossing defenders | 22 active seconds |
| Corner Siege | Precision under pressure | 4 corner goals | The Sentinel + 3 defenders in a repeating wave | 32 active seconds |
| Champion's Gate | Mastery | 18 points | The Gambler + 3 defenders with different speeds | 28 active seconds |

The deliberate reset to a keeper-only pitch in stage three makes corner timing
the new skill. Stage four adds urgency before stage five introduces the second
defender. Stage six combines those skills and rewards three-point corner shots.
Each stage has its own name and cached pitch palette.

## Champion stages (7–12)

This expansion continues the owner's preferred `feat/stage-challenges` version
from `d9073fef58b60cfe8a2afef3b0840ed3ace7cdc1`. The original six stage targets,
movement settings and save positions are retained. The map separates The Climb
from Champion Stages and now offers 36 stars.

Difficulty alternates between pace and precision. Stage eight removes the timer
while adding defended corners. Stage nine introduces the third defender without
a deadline, then stage eleven adds a clock to that formation. Stage ten has two
defenders but the shortest clock and a points target. The finale combines three
defenders with different speeds, the fastest keeper and the highest points target.
Three chances remain available in every stage.

| Stage | Aim speed | Keeper speed / range | Defender speed / pattern |
| --- | --- | --- | --- |
| 7 | 1.70 | 1.50 / 108 | 1.40 / crossing |
| 8 | 1.80 | 1.55 / 108 | 1.40 / offset sweeps |
| 9 | 1.85 | 1.60 / 108 | 1.40 / staggered wave |
| 10 | 1.95 | 1.65 / 110 | 1.60 / crossing |
| 11 | 2.00 | 1.75 / 110 | 1.50 / staggered wave |
| 12 | 2.10 | 1.85 / 110 | 1.65 / offset sweeps |

Speeds are phase radians per active simulation second; keeper range is in logical
pitch units. Offset sweeps add 0.25 speed per successive defender. The new wave
shares one speed with evenly spaced phases, so its openings repeat. Neither the
keeper nor defenders react to a hidden shot target. Three-defender rows sit at
Y = 250, 335 and 420; earlier two-defender rows remain at 278 and 386. The nearest
new row stays 128 units from the launch point instead of crowding the ball.
All three defender pictures and shirt labels are prepared in the existing cache.
The [progressive keeper update](PRO_KEEPERS.md) adds Academy-to-World-Class
skills, delayed dives, signalled slides, marking and save taunts to these stages.
Its new collision poses and learned coverage change the shooting difficulty;
the values above remain patrol settings rather than the whole keeper trajectory.

Five uninterrupted corner goals earn 3 + 3 + 6 + 3 + 3 = 18 points for the final
target. Fire doubles points, not goal/corner objective progress. This is scoring
arithmetic, not evidence that a physical shooting route or timer is balanced.
The new targets and speeds need the owner's device playtest.

The [Beat the Keeper update](BEAT_THE_KEEPER.md) adds named profiles, a visible
Fire meter, sound and instant rematches. Two goals without a miss charge one Fire
Shot. Corner Artist requires one corner goal; Needle Threader and Corner Siege
require two corner goals without a miss. Centre goals do not add corner charge.
The charging goal pays normal
points. A Fire goal pays double (2 or 6), then charge resets. Any miss also resets
charge. Fire Shots use the same trajectory and collisions and can fail normally.

## Rewards and continuity

- Clear with 0 misses: 3 stars; 1 miss: 2 stars; 2 misses: 1 star.
- A replay can improve a medal but never lowers it. There are 36 stars to collect.
- Save the best medals in `SharedPreferencesAsync` as a string list under
  `challenge_stars_v1`. Derive unlocks from consecutive cleared stages.
- Append the six new stages without changing that key or reordering the original
  six. An old completed six-entry save retains its stars, unlocks stage seven
  and leaves stages eight onward locked. Partially completed saves resume at
  their previous stage. Additional star slots start at zero and save normally.
- Retain the existing `best_score` and `haptics` keys. Stage points never update
  the Classic record. Invalid star entries cannot skip stage locks.
- Progress loading completes before the challenge map can be opened. On a
  storage failure, gameplay stays available with a saving-unavailable notice.
- In-progress shots, attempts and timers are not saved across a process restart.
  Players reopen at the menu with completed stages and best medals restored.

## Timing and fairness

- The countdown advances only during aiming or flight. Pause, background pause,
  briefings, goal/miss feedback and clear screens do not consume time.
- Cinematic slow motion affects the simulation, not the countdown. The existing
  100 ms frame-gap cap still applies; this is an active-play timer, not a wall-clock deadline.
- A shot tapped before zero is allowed to resolve. If it meets the target, the
  stage clears. Otherwise the result is shown before the timeout panel. A new
  shot cannot start at zero.
- Ending the stage during its winning goal celebration preserves the clear.
- Rendering uses model positions. Challenge keeper dives now rotate and move
  the same articulated capsules used for ball contact, including the gloves and
  legs. The prior stationary keeper box is used only in Classic; defenders
  retain their original boxes. No dive translation exists only in the renderer.
- HUD timer refreshes happen on whole-second changes; objective updates happen
  on shot results. Static pitch drawing is re-recorded only when the stage changes.

## Owner's local validation

No Flutter analysis, tests, builds or app runs were performed for this milestone.
Regression cases have been added for the owner to run. GitHub publication uses
a source branch; its workflow is manual-only and was not dispatched.

The expansion cases cover upgrading a six-entry save, sequential unlocks through
stage twelve, interception by the third defender, the final buzzer shot and
retry, stage-seven menu entry and rendering the new defender. They are prepared
source cases, not executed results.

1. Open the stage map on a fresh install: only stage one should be playable.
   Confirm the menu, briefing, retry and next-stage buttons remain reachable on
   a small screen, including when scrolling and using larger text.
2. Clear stage one with zero misses, then replay with a miss. Confirm stage two
   stays unlocked and the three-star record is retained after closing/reopening.
3. In Corner Artist, score a centre goal, then two corner goals. Only the two
   corners should fill the objective; centre goals must not cost a chance.
4. In a timed stage, pause and background the app during aiming and flight.
   Resume should preserve the attempt and clock. Goal-feedback holds must not
   count down. Observe the last five seconds and a shot released just before zero.
5. Let time expire without shooting, then retry. Separately lose three chances,
   then retry. Check that stage identity, full timer, three chances and zero
   objective progress reset together.
6. Play stages with defenders. Look for visible collisions, readable openings
   and stutter, especially on the first shot and when switching pitch palettes.
7. Complete the finale, return to the map, and replay earlier stages for stars.
   Return to Classic: its best score and original goal-based progression should
   still work independently.
8. Upgrade with an existing six-stage save. Check that its medals survive and
   the map offers PLAY STAGE 7 with the correct total out of 36. Completing
   stage six should lead into Pressure Cooker, not show campaign completion.
9. Play Triple Wall and Corner Siege. Check the nearest defender's visible
   blocks, the third shirt drawing and whether the repeating wave leaves
   readable openings. Compare first-entry stutter with the two-defender stages.
10. In Champion's Gate, check a last-second Fire corner, immediate retry and
    the twelve-stage completion message. Note whether difficulty comes from
    timing decisions or excessive waiting for a lane.

For each stage, note attempts to clear, misses/saves/blocks, whether you knew what
to do, how often you had to wait, and whether you wanted another attempt. Record
the device and whether it was a simulator, plus any Android APK build/run result.

Tune `challengeStages` in `lib/game/challenge_stage.dart`: targets, aim speed,
keeper style/range/speed, Fire charge, defender speed/pattern and time limits are centralized.
Prioritize unreadable failures first, excessive waiting second, and stage target
or timer adjustments third, based on the actual notes.
