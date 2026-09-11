# First-minute hook milestone

Source update on `feat/stage-challenges`, based on
`a13e4c22e5ae8b8757cd53c6d290a677fd9b4185`. The goal is to make the first match
easier to enter and understand, and make each retry suggest a useful correction.
This is a design hypothesis. It has not been built, run or playtested here;
replay appeal and frame performance remain unmeasured.

## Enter through a real match

Home now puts the next challenge action first:

| Saved progress | Primary action | Result |
| --- | --- | --- |
| Still loading | LOADING PROGRESS | Challenge entry stays disabled until the reads finish. |
| Stage 1 has no stars | PLAY FIRST MATCH | Start guided Stage 1 directly, with three chances and the normal three-goal target. |
| Campaign partially cleared | CONTINUE · STAGE N | Open the briefing for the next uncleared stage. |
| All 12 stages cleared | CHOOSE A REMATCH | Open the map to improve stars or collect missing trophies. |

PLAY CHALLENGES still opens the complete stage map. STAR REWARDS and Classic
remain available. The home content is shorter and the primary action precedes
the collection and mode choices. Picking Stage 1 from the map still opens its
briefing; its guide is enabled if Stage 1 has never been cleared.

## Learn through live shots

The guide uses existing Stage 1 gameplay, with no separate practice score:

1. Before a first goal: explain that tapping anywhere locks the arrow and that
   the target dot shows the shot direction. Keep the TAP cue after unsuccessful
   first shots so one failed tap does not remove the teaching cue.
2. After a goal: ask the player to read the keeper and find open space. Explain
   that two goals without a miss charge a Fire Shot.
3. When Fire is actually ready: explain double points and choosing a clear lane.

The actual score and charge select the instructions. The guide neither aims
the shot nor changes keeper movement, contact geometry, Fire rules, time,
chances or outcomes. A player can miss or lose. Two consecutive goals naturally
produce the first Fire opportunity; a run with misses may clear without a Fire
goal. No scripted goal or artificial completion condition is added.

Clearing the stage awards normal stars and a win against the keeper, unlocks Stage 2, and
may unlock Neon Ball at three total stars. The existing saved Stage 1 stars
retire the guide on future visits. An immediate retry after a clear also retires
it; a failed attempt keeps the guide. Classic and later stages have no guide.
No new persistence key or save migration is needed. If loading stars fails, the
existing saving-unavailable notice remains visible.

## Understand the miss

`ShotFailure` is set by the simulation when the ball resolves at the goal line
or contacts an opponent. Display text is not used to distinguish causes.

| Cause | Suggested correction |
| --- | --- |
| Wide | Tap while the target dot is inside the goal. |
| Post | Leave a little space inside the post. |
| Keeper | Look for a lane away from his gloves. |
| Defender | Wait for an opening through the defence. |

The correction appears during feedback and remains in the footer while aiming
again, so it can be read after the brief animation. On a stage failure, the
result panel shows one correction near Retry, while the objective box and
missing-target explanation remain available below. A timeout without a last
miss offers a timing reminder. A goal clears stale miss advice; restarting also
clears it. A saved Fire Shot is still a keeper save and consumes one chance.

A thin neutral ring keeps the locked target visible during flight and result
feedback. It marks the accepted aim, including outside-post targets; it does not
predict a goal or claim the lane is safe. Ball contact and scoring are unchanged.

## Keep the next attempt close

Challenge Retry/Next now appears before the detailed objective/statistics section.
The star award and any newly unlocked cosmetic appear before the action, so the
reward can be noticed before advancing. Classic Play Again also precedes its
detailed statistics. New-stage briefings still explain rules before Start.

The guide has a minimum-height instruction area to reduce pitch resizing with
normal text, while allowing larger accessibility text to grow. Existing pause,
background pause, sound, haptics and input phase guards continue to apply. No new
animation ticker, asset, dependency or per-frame Flutter notification is added.
The target ring uses a reusable paint and the existing render loop.

## Source handoff

No analyzer, tests, builds, app runs or GitHub workflows were executed. The
workflow remains manual-only; local validation is the owner's responsibility
under the agreed workflow. New regression sources are prepared in
`test/first_touch_test.dart` and `test/first_touch_widget_test.dart` for local use.
They cover unchanged physical outcomes, target locking, guide progression,
retry/completion, physical miss classification, quick entry, pause, reward
persistence and returning-player navigation. They are not passing-test claims.

Use these focused local checks:

1. With no Stage 1 stars, tap PLAY FIRST MATCH. Check immediate live Stage 1,
   readable instructions, the target dot and the three-chance display.
2. Tap on different parts of the pitch while holding the same arrow timing.
   The accepted direction must come from the arrow, not the finger position.
   Extra taps during flight must not create another shot.
3. Miss first, then score two consecutive goals and release the boosted shot.
   Check the repeated TAP cue, correction, charge lesson and real outcome.
4. Produce a post, a wide shot, a keeper save and a defender block. Check that
   each correction matches what happened and is available during the next aim.
5. Pause/background during aiming and flight, resume, fail and retry. Confirm
   no extra attempt result or loss of progress and no stale correction on retry.
6. Clear Stage 1, check stars/reward/keeper record, close and reopen. Home should
   offer Stage 2; repeating Stage 1 should no longer show the guide. Repeat with
   an existing partially completed and fully completed save.
7. Check Home, results and the guide on a small phone and with larger text.
   Check the neutral target ring with all ball/net/pitch looks and at both posts.
8. Profile first-shot, goal/save feedback and retry on a physical phone using
   the existing local trace guidance in `PERFORMANCE_NOTES.md`.

For a small first-session pilot, record the device/build, whether players can
explain the control without coaching, time to first goal, unclear misses,
voluntary retries, and where they stop. These observations should guide the next
iteration; elapsed session time alone does not establish fun or retention.
