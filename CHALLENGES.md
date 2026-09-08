# Challenge milestone

The playtest feedback was that the game becomes dull. This milestone gives each
short stage a specific skill to practise, a visible finish line, and a reward
that remains useful on replay. It does not claim that difficulty or engagement
has been validated: these are initial balance values for the owner's playtest.

## Player flow

Home → PLAY CHALLENGES → stage map → briefing → START STAGE → play → clear or retry.
Only cleared stages unlock the next one. All unlocked stages remain replayable.
Three misses end the current attempt; timed stages also end when the clock
expires. Retry returns to that stage's briefing with three fresh chances, a full
timer and zero score. Clearing stage six shows the campaign finish and returns
the player to the map to improve their stars.

| Stage | Skill | Target | Opposition | Time |
| --- | --- | --- | --- | --- |
| First Touch | Timing | 3 goals | Slower keeper | Unlimited |
| Moving Wall | Reading lanes | 3 goals | Keeper + 1 sweeping defender | Unlimited |
| Corner Artist | Precision | 2 corner goals | Keeper; only the glowing corners advance progress | Unlimited |
| Beat the Clock | Quick decisions | 4 goals | Faster keeper | 25 active seconds |
| Double Trouble | Reading two lanes | 4 goals | Keeper + 2 defenders moving in opposite directions | Unlimited |
| Captain's Finish | Combining skills | 8 points | Changing-pace keeper + 2 offset defenders | 30 active seconds |

The deliberate reset to a keeper-only pitch in stage three makes corner timing
the new skill. Stage four adds urgency before stage five introduces the second
defender. The finale combines those skills and rewards three-point corner shots.
Each stage has its own name and cached pitch palette.

## Rewards and continuity

- Clear with 0 misses: 3 stars; 1 miss: 2 stars; 2 misses: 1 star.
- A replay can improve a medal but never lowers it. There are 18 stars to collect.
- Save the best medals in `SharedPreferencesAsync` as a string list under
  `challenge_stars_v1`. Derive unlocks from consecutive cleared stages.
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
- Rendering uses the keeper and defender positions from the match model.
  Previous render-only lean/dive translations were removed because they could
  show an opponent away from the actual collision anchor. Collision boxes are
  still the existing simple approximations, not pixel-perfect sprite outlines.
- HUD timer refreshes happen on whole-second changes; objective updates happen
  on shot results. Static pitch drawing is re-recorded only when the stage changes.

## Owner's local validation

No Flutter analysis, tests, builds or app runs were performed for this milestone.
Regression cases have been added for the owner to run. GitHub publication uses
a source branch; its workflow is manual-only and was not dispatched.

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

For each stage, note attempts to clear, misses/saves/blocks, whether you knew what
to do, how often you had to wait, and whether you wanted another attempt. Record
the device and whether it was a simulator, plus any Android APK build/run result.

Tune `challengeStages` in `lib/game/challenge_stage.dart`: targets, aim speed,
keeper range/speed/tempo, defender speed/pattern and time limits are centralized.
Prioritize unreadable failures first, excessive waiting second, and stage target
or timer adjustments third, based on the actual notes.
