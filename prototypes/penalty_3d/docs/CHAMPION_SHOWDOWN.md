# Manual aim and Champion Showdown — source handoff

Hook: **“He expected that corner. I made him guess.”**

This implements manual target control and the five requested upgrades. Source
review only: no Godot import, tests, analyzer, app run, build, export or GitHub
workflow was executed for this handoff. Earlier APKs contain earlier source.

## Controls

Drag on the goal to set the white target; release that drag without shooting.
Hold below the goal, drag sideways for curve or upward for an unlocked chip,
and release to shoot. Holding still retains the looping knuckle timing ring.
With touch, a second finger can adjust the target while the shot finger holds.

Input ownership is fixed at touch-down. Moving a shot finger across the goal
does not change its role. Aim release cannot launch the ball, an unrelated
second shot finger cannot take over, and released shots cannot be redirected.
Pause/background/cancellation/resize clears both owners. New balls retain the
chosen target; the chip lesson starts centrally and allows adjustment.

## The Captain

Unlocked by the original Cup win. A completed five-ball set needs **4 goals**;
five is a perfect showdown. The original Cup and Rush still use their previous
three-goal clears and 3/4/5-goal star thresholds.

| Upgrade | Behaviour |
| --- | --- |
| Learned coverage | Last five observed resolved ball X positions, weighted toward recent shots, move the idle guard by at most 1.25 units. Includes observed saves/misses; never reads hidden aim. |
| Mixed defence | Exactly two nonconsecutive rushes among five balls; a rematch selects a different complete order. Forward stance and blue arrows reveal each rush before release. |
| Master preview | Four early samples, ending around 27% of flight; selected aim stays visible, bend-adjusted endpoint stays hidden. |
| Character | Navy/gold Captain with hair, face, number, crest, glove/boot details, planted idle steps, anticipation, rush strides, extending dive and landing/recovery. |
| Recorded highlights | Skippable two-second goal-side view of recorded ball position/rotation, keeper endpoints/pose and net motion. |

Captain prediction uses observed position, velocity and acceleration after the
reaction delay. It partially extrapolates lateral acceleration (55%) and commits
once to a limited destination. It never reads the chosen aim, spin or loft.
Changing a target while holding does not immediately move his learned guard.
Changing sides and late bend remain ways to beat him.

| Initial tuning | Value |
| --- | --- |
| Reaction delay | 0.18 seconds |
| Lateral reach from commitment | 1.90 units |
| Dive travel | 0.30 seconds |
| Maximum dive lean / lift | 1.18 radians / 0.88 units |
| Rush forward travel / time | 3.20 units / 0.40 seconds |
| Idle step travel time | 0.20 seconds |
| Recorded frames | At most 128 per shot |
| Playback duration | 2.0 seconds |

The glove/body cores and contact shapes use the same capsule endpoints. Radii
and swept contact math are unchanged. Decorative trim has no extra contact
shapes. The character is authored procedural geometry, not an imported player
model or a licensed footballer. Phone appearance and balance remain unverified.

## Practice and persistence

**Practice · Full preview** uses five balls against the same Captain with full
trajectory and endpoint. It has a separate temporary learning history. Practice
does not write Cup, Rush or Champion records or modify saved Champion memory.

`user://champion_showdown.cfg` stores version 1, best goals, wins, losses and
recent observed lanes. `main.gd` records one result only after all five balls.
Reopening a result, pausing, replaying, or skipping a replay cannot count again.
Abandonment writes no result; observed shots still inform the current session.
Only a completed set persists the current memory. Unknown or malformed saves
are preserved, with that session's changes kept in memory and a warning/error.

Cup/Rush configuration files, stars, equipment and badges keep their formats.
No migration of Flutter saves or changes to paid/cosmetic rewards are included.

## Highlight lifecycle

Top-corner, banana, clean knuckle and over-rush chip goals qualify as exceptional.
A goal meeting the mode's win threshold qualifies as the clincher. Playback is
limited to two per set: at most one exceptional goal plus the clincher. If one
goal is both, it uses a single replay. The free chip lesson skips highlights.

The recorder starts at release, samples live poses during flight, captures the
resolution point, then records roughly 0.26 seconds of actual result motion.
Scoring and any completed-set save happen before playback starts. The replay
uses display-rate interpolation of the recording; it runs no flight simulation,
keeper AI, collision checks, goal logic or progress writes.

Skip, natural completion, rematch and Cup restore the original camera transform,
FOV and live result pose. Pause/background freezes playback. Next ball clears
the old recording and resets camera/ball/keeper interpolation. The crowd replay
stinger is presentation only. No video capture, sharing or replay disk file is
created by this slice.

## Owner-run verification

```bash
godot --headless --path prototypes/penalty_3d --import
godot --headless --path prototypes/penalty_3d -s res://tests/cup_smoke.gd
godot --headless --path prototypes/penalty_3d -s res://tests/rush_smoke.gd
godot --headless --path prototypes/penalty_3d -s res://tests/champion_smoke.gd
```

The new script prepares cases for manual projection/input ownership, memory,
four-goal results, full-versus-short preview, practice/save isolation, corrupted
saves and once-only replay completion. It uses isolated `champion_smoke_*.cfg`
files and removes them. Existing smoke scenes now also isolate the Champion
progress path. None of these commands was run for this source handoff.

Use [PLAYTEST](../PLAYTEST.md) for device checks. Especially inspect the target's
touch region, animation weight/contact alignment, goal-side camera framing,
first-replay frame times and whether a player voluntarily rematches. Tuning is
a hypothesis until these observations are collected.
