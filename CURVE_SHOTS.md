# Player-controlled curve shots

First control milestone on `feat/stage-challenges`, based on
`4930f9cab835a0ba031046af3259a7e12cea7702`. This source adds straight shots,
adjustable left/right curves and the stronger banana bend. The subsequent
[knuckle and practice milestone](KNUCKLE_PRACTICE.md) adds stationary release
timing. Chips, driven shots and variable shot power remain later milestones.

No analyzer, tests, builds, app runs or GitHub workflows were executed here.
The controls, rendering and cancellation paths were reviewed in source only.
Gesture feel, difficulty changes and frame performance need local playtesting.

## Controls

| Action | What happens |
| --- | --- |
| Touch inside the fitted pitch | Capture the arrow's initial direction immediately. The ball stays at the launch point. |
| Quick release with little or no movement | Shoot straight in the captured direction. |
| Hold still and release in the blue zone | Use the timed knuckle described in `KNUCKLE_PRACTICE.md`. |
| Drag left or right before releasing | Bend in that direction; farther movement adds more bend. |
| Drag back to the touch origin | Remove the bend and return to a straight shot. |
| Reach strong bend | The label changes from CURVE to BANANA. This is the same continuous control, not an automatic bonus. |
| Release | Lock the final spin and target, launch once, then play kick audio/haptics. |
| Move vertically | No height or power; deliberate movement opts the hold out of knuckle timing. |

The keeper, defenders and active stage clock continue while the player holds.
Holding longer does not charge power; a knuckle requires the specific release
window. A touch begun before
zero does not reserve a buzzer shot: the ball must be released before zero.
Once airborne, further touches cannot steer or launch another ball.

This changes physical input from shooting on finger-down to shooting on
finger-up. Waiting never launches automatically. A quick tap still shoots, with
direction taken at the start of that tap. Accessibility activation retains a
straight-shot action, though the visual timing game remains limited for players
who cannot use its visual cues.

## Preview and flight

While holding, the pitch shows a short curved arrow, the predicted goal-line
target, a left/right bend meter and one of five release labels. A red target
means the planned endpoint is outside the scoring opening. An outward marker
indicates endpoints beyond the visible pitch. The target does not predict a
save or guarantee a goal; opponents keep moving.

Preview and ball physics both call `ShotCurve.xAt`. With progress `p` from
launch to goal, the equivalent path is:

```text
x(p) = startX + (initialTargetX - startX) * p + 110 * spin * p²
finalTargetX = initialTargetX + 110 * spin
```

This is deterministic arcade sidespin, not a fluid simulation. The curve keeps
the starting direction and develops progressively. The final target is not
clamped into the goal. Too much bend can go wide or hit the post. Zero spin
follows the original straight trajectory. Existing forward speed, fixed
substeps and cinematic timing remain in place.

Defenders and keeper poses collide with the actual curved ball coordinates.
Goal, post and corner resolution use the curved endpoint. Professional keepers
continue to estimate from visible travel after their reaction delay and commit
once; they are not given the intended spin or final target. Curving around that
commitment may change difficulty and needs playtesting against each tier.

## Initial tuning values

These are starting values for local tuning, not measured usability results.
All distances are logical units on the 400-wide pitch. Input uses the same
fitted scale as rendering, including letterboxing.

| Parameter | Value |
| --- | --- |
| Sideways dead zone | 14 units from the touch origin |
| Full bend | 100 units of sideways drag |
| Spin range | -1 to +1; clamped after removing the dead zone |
| Maximum endpoint shift | 110 units left or right |
| BANANA label threshold | 75% bend; physics stay continuous across the threshold |

## Cancellation and existing progress

The first accepted pointer owns the shot. Other fingers cannot change it or
release it. A pointer cancellation, leaving the fitted pitch, layout resize,
pause, background pause, timeout or navigation discards the held preparation.
Resuming and lifting the old finger cannot fire it. Cancellation itself neither
launches a ball nor spends a chance; stage timing and forfeit rules still apply.

Classic scoring, challenge objectives, Fire charge, stars, trophies, rival
records and equipment keep their existing rules and storage keys. Curved goals
earn normal points; there is no extra curve bonus. The first-match guide and
Home copy explain the new release control for new and returning players.

The preview reuses its paint/path and five preloaded labels. Pointer movement
does not notify Flutter or add a ticker. Source structure alone does not prove
that the experience is smooth on a phone.

## Focused local handoff

Regression sources are in `test/curve_shot_test.dart` and
`test/curve_gesture_test.dart`; none were executed here. The existing Home
widget source also follows the new instructions and semantic label.

1. Quick tap: confirm immediate press feedback, release-to-shoot, and direction
   locked at press even after a brief hold. Compare responsiveness to the last build.
2. Hold and drag both ways: try a small curve, a banana bend, reversal, and
   returning to the centre. Check the target and actual flight agree.
3. Aim close to both posts and add excessive bend. Confirm honest wide/post
   results, including the off-pitch marker. Try bending around a defender.
4. Hold while the keeper moves, and against each keeper tier. Check visible
   contact matches saves/blocks and note any stage made trivial by curving.
5. Use a second finger, release outside the pitch, cancel through a system
   gesture, pause/background while holding, resume, and retry. No stale shot
   should fire; each released attempt should count once.
6. Release just before a timed stage expires, then repeat while still holding
   at zero. Only the released shot should finish its flight.
7. Check small phones, larger text and all equipment looks. Record stutter
   during first touch, continuous drag, release, result and retry using the
   existing opt-in local trace guidance in `PERFORMANCE_NOTES.md`.

For feedback, record device/build, whether bend direction matched intent,
whether the dead zone prevented accidental curves, and whether the player could
repeat approximately the same bend. Use those observations alongside the
knuckle drill handoff before changing gesture tuning or stage difficulty.
