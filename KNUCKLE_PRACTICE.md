# Timed knuckles and Practice Arena

Source milestone on `feat/stage-challenges`, based on curve-shot commit
`41bc6e0ac59cd79ede99561ebd3ff21cba96cdd6`. No analyzer, tests, builds, app runs
or GitHub workflows were executed for publication. Gesture feel, difficulty and
frame performance still require local playtesting.

## Player controls

| Input | Result |
| --- | --- |
| Quick touch and release | Straight shot in the direction captured at touch-down |
| Hold still, release while the white marker is in the blue zone | Clean low-spin knuckle with a small late wobble |
| Release before or after the blue zone | Ordinary straight shot; feedback says Released early or Released late |
| Drag sideways, then release | Existing adjustable curve or stronger banana bend |
| Drag out of the centre and back | Removes sidespin, but cannot activate knuckle timing during that hold |
| Deliberate vertical movement | Opts out of knuckle timing; does not add height, power or a chip |

Each hold gets one timing window. Waiting longer never fires automatically,
loops the window or charges more power. Opponents and active stage clocks keep
moving. The marker stops at the end of the ring and the label says the shot is
late. Small finger jitter within the existing dead zone is allowed.

The first pointer owns the shot. Leaving the fitted pitch, cancellation,
resize, pause/background, timeout or navigation discards the preparation.
Lifting that old finger after resuming cannot shoot. Cancellation does not
spend a practice ball. Semantic activation retains the straight-shot action;
the blue timing mechanic itself still relies on visual cues.

## Five-ball drills

Select **PRACTICE ARENA** from Home. Every drill has five released balls, its
own best out of five, immediate retry and no countdown. Saves and misses use a
ball; three misses do not end practice early. Targets change only when the next
ball is ready, so the feedback shows the target the player actually attempted.

| Drill | Setup | What earns one hit |
| --- | --- | --- |
| Corner Practice | Alternating left/right marked corner; no keeper or defenders | A goal with its endpoint inside the marked target |
| Bend Around the Wall | Alternating corner target and one moving defender; no keeper | A curved goal inside the marked target |
| Knuckle Timing | A Club-level Sweeper with articulated saves; no defenders | A clean knuckle that also scores a goal |

A goal and a drill hit are different measures. A straight goal in Knuckle
Timing still appears as a goal, but earns no drill point. A clean knuckle save
counts toward clean execution, uses one ball and earns no point. Each result
separates technique from outcome, for example **Clean knuckle · Saved** or
**Released early · Goal**, with all five attempts listed on the result screen.
Early/late guidance remains visible during the next aim.

Completed attempts can improve the per-drill best. A tie does not celebrate a
new best. Results offer the next best-score target, or another perfect 5/5.
Ending a partial drill retains its notes for review but does not record a best;
an abandoned in-flight ball has no fabricated outcome. Retry starts a new five
balls and retains the previous best. Unfinished drills do not resume after
closing the app.

## Flight and fairness

Knuckle timing is available in Classic, all challenge stages and practice.
A clean release adds a bounded, deterministic sideways wobble late in flight
and reduces the ball's visual spin. The trajectory begins and ends on the
captured straight line. It does not steer an off-target shot back into goal.

The aim preview and actual ball use the same `KnuckleShot.offsetAt` calculation.
The preview shows the early portion of the path and its endpoint; it does not
predict a save. Defender boxes and articulated keeper poses test the actual
wobbling ball position. Keepers continue reacting to observed flight after
their existing delay; they do not receive the player's timing classification.
Clean execution can still result in a save, block, post or wide shot.

Fire remains the existing challenge scoring bonus and can apply to any shot
technique. It neither creates nor guarantees a knuckle. Practice has no Fire
charge, extra corner points, campaign unlocks or Classic streak multiplier.

## Initial tuning

These values are starting points for player feedback, not measured results.
Distances use the existing 400 × 640 logical pitch and fitted input scale.

| Parameter | Initial value |
| --- | --- |
| Quick tap | Less than 0.20 active seconds |
| Clean blue zone | 0.55–0.73 active seconds into a stationary hold |
| Timing ring | One second; stops at the end |
| Centre dead zone | Up to 14 logical units on each axis |
| Wobble begins | 45% of flight to the goal line |
| Maximum wobble bound | 14 logical units; actual peak is smaller |
| Knuckle visual rotation | 1.2 radians per simulation second |
| Practice target | Centre 91 or 309, half-width 18 |
| Practice aim / keeper patrol speed | 1.0 / 0.75 |

The timing meter uses simulation time before cinematic slow motion. The
existing 100 ms frame-gap cap still applies; long stalls do not advance it by
the full wall-clock gap. Use physical-device observations before changing the
blue window or claiming improved responsiveness.

## Save continuity and rendering

Best records use a separate versioned `practice_bests_v1` preference, with
stable drill IDs and validated values from 0 to 5. Writes use the existing
serialized queue when a completed attempt improves a best. Malformed or future
versions are left untouched; practice can keep session bests with a saving
notice. Classic scores, stars, trophies, rival records and equipment retain
their existing keys and rules.

The ring and target use reused paints and preloaded cue labels in the existing
Flame render loop. Practice mode is part of the field-cache key. No new ticker,
dependency, audio asset, per-frame Flutter notification or per-frame storage
write was added. These source choices are not performance measurements.

## Local handoff

Regression sources were prepared in `test/knuckle_shot_test.dart`,
`test/practice_drill_test.dart`, `test/practice_widget_test.dart` and the existing
pointer cases. None were executed. Injected scoring fixtures exercise rules
and persistence; separate shot cases exercise real trajectory/contact behavior.

1. Try a quick tap, a clean stationary hold, an early release and a late release.
   Confirm the ball launches only on release and the feedback matches intent.
2. Curve both ways, drag back to the centre and move vertically. Check that
   these do not unexpectedly turn into knuckles. Try small natural finger jitter.
3. Complete each drill with a mix of goals, saves and misses. Check the five-ball
   limit, alternating target, qualifying points, attempt notes and immediate retry.
4. Beat a drill best, tie it, end a partial attempt and reopen the app. Confirm
   bests persist and existing Classic scores, stars and equipment stay intact.
5. Pause/background while holding, resume and lift the old finger. Repeat just
   before a timed-stage expiry and with a second finger on the pitch.
6. Play knuckles against later keeper tiers. Record any visible contact that
   disagrees with a save/block, and whether the wobble offers a useful choice.
7. Check small-screen/large-text layout and capture first hold, blue-zone entry,
   release and retry with the opt-in markers in `PERFORMANCE_NOTES.md`.

Share device, OS/build mode, gesture intent, observed result and any stutter
phase. The next tuning decision should use that feedback: blue-window width,
wobble strength or drill target width. Chips, driven shots and variable power
remain later milestones.
