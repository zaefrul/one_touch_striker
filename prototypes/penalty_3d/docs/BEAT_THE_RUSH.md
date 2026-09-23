# Beat the Rush — source handoff

The next hook is **“I saw him coming, and chipped him myself.”** This update adds
one showdown after the original three-rival cup. It is source-reviewed only:
no engine import, tests, app runs, exports or GitHub workflows were executed for
this handoff. Previous APKs and reported smoke results describe the earlier cup.

## Player flow

1. Win the existing Rival Cup. The cup map unlocks **Beat the Rush** and chip input.
2. First entry offers a playable chip lesson. A moving upward cue demonstrates
   the gesture; the lesson fixes a central aim and repeats without consuming
   cup balls or changing records. **Skip lesson** starts the showdown.
3. Play five balls against The Gambler. Blue ground arrows and a forward stance
   signal a rush on balls 1, 3 and 5. Balls 2 and 4 use his ordinary dive.
4. Score three to win. Complete all five for the usual 3/4/5-goal star thresholds.
5. Win with at least one scoring chip over the rushing keeper to earn and equip
   **Sky Master**. Rematch for more stars; use **Practice chip** to replay the lesson.

The badge is cosmetic. It appears beside the shot markers and can be equipped
or removed on the cup map. It changes no shot or keeper attributes.

## Controls and physical rules

| Input | Behaviour |
| --- | --- |
| Quick touch/release | Ordinary straight shot |
| Hold still | Ring keeps rotating; release in blue for knuckle |
| First clear sideways drag | Curve/banana, same bend range as before |
| First clear upward drag, after cup win | Chip; more distance adds lift and flight time |
| Return to the origin | Remove bend/lift; no knuckle during that same hold |
| Ambiguous diagonal | Wait for a clear axis; suppress knuckle |
| Pause, background, canceled touch or resize | Cancel the hold without consuming a ball |

Both axes use the same width-based logical scale. The first selected axis stays
selected until release or cancellation. Dragging down does not introduce a new
shot type in this slice.

Preview and flight call `Shot.position_at(..., loft)`. Loft changes the actual Y
coordinate and flight duration; it is not a visual offset or automatic success.
The endpoint at the goal centre plane remains the locked target. Whole-ball
crossing and the existing frame/contact tests still decide the result.

The rush starts after release and a reaction delay, using observed ball position
and velocity. It commits to a bounded intercept, never reads the hidden aim, and
does not retarget after committing. Meshes and contacts use the same posed
capsule endpoints. Capsule radii and `contact_fraction()` remain unchanged.

A mastery chip requires all of the following in the same shot:

- Upward input with at least the configured mastery lift.
- A committed rushing keeper.
- Passage above the highest visible capsule, within the keeper's horizontal span.
- A subsequent confirmed goal, without a save or frame contact.

Shooting around him, clearing him then missing, scoring with another technique,
or succeeding in the free lesson cannot award the badge. An ordinary showdown
win still earns its stars and win record.

## Initial tuning — needs device playtesting

| Parameter | Value | Location |
| --- | --- | --- |
| Gesture dead zone | 14 logical units | `shot_gesture.gd` |
| Axis preference | 1.25× the other axis | `shot_gesture.gd` |
| Full lift travel beyond dead zone | 86 logical units | `shot_gesture.gd` |
| Ordinary / maximum chip flight | 0.70 / 1.20 seconds to centre plane | `shot_math.gd` |
| Extra chip arc coefficient | 8.0; adds 2.0 units at mid-flight at full lift | `shot_math.gd` |
| Minimum mastery lift | 0.20 | `shot_math.gd` |
| Rush reaction / travel time | 0.22 / 0.44 seconds | `rival.gd` |
| Forward travel / lateral reach | 3.0 / 1.55 units | `rival.gd` |
| Rush schedule | Balls 1, 3, 5 | `rival.gd` |

These are design values, not measured balance. In the phone playtest, check that
the rush is readable, partial lift is useful, the chip arc stays visible and a
keeper staying back presents a different decision. The cue must remain visible
through a long hold, and he must never rush before release.

## Progress and lifecycle

The original `rival_cup.cfg` format and three-profile roster are retained.
`rush_showdown.cfg` has its own version, lesson flag, best goals/chips, wins,
losses and badge state. The showdown uses a separate Gambler profile.

Only five valid outcomes reach `RushProgress.record_set()`. Main owns a
per-attempt recording guard; returning from Pause/Help only redraws the final
result. Rematching or leaving an incomplete set does not count as a defeat.
The lesson only records that it has been completed or skipped.

Rush saves write a temporary file before replacing the known version. Unknown
versions and malformed files remain intact, with an error available in
`last_save_error`; that session remains playable but cannot persist rush changes
until the file is reviewed. The original cup file is never used as a fallback.

The raw-touch helper activates menus on release, rejects canceled touches and
movement beyond its tap threshold, and lets drags reach menu scrolling. Mouse
emulation remains disabled. Mouse and keyboard activation stay native.

## Local verification

From the repository root, run locally:

```bash
godot --headless --path prototypes/penalty_3d --import
godot --headless --path prototypes/penalty_3d -s res://tests/cup_smoke.gd
godot --headless --path prototypes/penalty_3d -s res://tests/rush_smoke.gd
```

The new script uses isolated `rush_smoke_*.cfg` files and removes them after the
run. It exercises the production flight/collision path, gesture selection,
progress round-trips, incomplete attempts, result re-entry, hold cancellation
and raw touch activation. Invalid-save fixtures intentionally produce warnings.
It is prepared, **not executed**. Use [PLAYTEST.md](../PLAYTEST.md) for the phone
checks, including scrolling, second-finger pause, camera resets and audio balance.

Success for this slice means players can name the rush cue, deliberately chip
over it, choose another shot when the keeper stays back, and voluntarily rematch
for mastery or more stars. No claim about retention or revenue is made here.
