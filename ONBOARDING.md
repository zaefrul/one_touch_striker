# Animated onboarding, clear objectives and repeating timing

Source update on `feat/stage-challenges`, based on audio commit
`8edbbc80a414450370a62124fe840f88b64ed538`. Reviewed as source only. No analyzer,
tests, builds, dependency resolution, game runs or GitHub workflows were executed.

## Player experience

| Moment | Lesson or behaviour |
| --- | --- |
| Fresh launch | Animated aim/release demo followed by a real player gesture |
| Stage 2, or first curve practice | Bend left, bend right, then stronger banana bend |
| Stage 3, or first knuckle practice | Hold still and release in the marked timing zone |
| First ready Fire bonus | A free example of the charged shot, with the current stage's charge requirement |
| Existing later-stage save | Basic aim is considered learned; missing advanced lessons can be skipped |
| Practice Arena → Replay tutorials | Play any lesson again, or the full sequence |

Every lesson checks the released gesture. A save, block or wide shot does not
invalidate a correctly performed technique. Failed gestures get another free
attempt. The player advances using Next/Let's Play after a successful gesture.
Animations stop during actual input and pause. Reduced-motion settings show a
static demonstration. The knuckle demo illustrates the same repeating zone.

The lesson arena has its own model and game instance. It uses the same input,
curve, knuckle, trajectory and scoring code, with keepers and deadlines removed.
Curve lessons retain a wall. Fire lessons start with a demonstration charge;
that charge never transfers to a campaign attempt. Lesson outcomes do not enter
the campaign, Classic best, practice best or rival record save paths.

The original match is frozen, and held input cancelled, while a lesson route is
open and during its exit transition. Skipping a lesson resumes the intended
stage or practice action. Skip tutorials marks outstanding automatic lessons as
skipped. Skipping a manually replayed lesson only exits that replay.

## Timing contract

- The hold duration continues increasing until release or cancellation.
- The visible marker and knuckle timing both use duration modulo one revolution.
- One revolution remains 1 second; its successful window remains 0.55–0.73s.
- Quick-tap classification applies only to the first 0.20s of the whole hold.
- Holding still can produce a knuckle on any revolution. A deliberate drag opts
  the entire hold out, including after returning to the original touch position.
- The marker continues rotating for curve input, with the knuckle zone hidden.
- Release launches once. Holding never fires, locks a maximum or increases power.
- Pause, background, resize, leaving the pitch, cancellation and expiry continue
  to discard the draft. Normal opponents and the stage clock move while holding.

This is a timing spinner. Ball speed is unchanged. Variable shot power, chip
height and driven shots are outside this update.

## Objectives and screen text

Every stage begins with a short objective, chances and any deadline. Keeper name
and tier are secondary. Detailed advice, Fire rules and star requirements are
available under Match tips. Retry still starts the same stage directly.

The HUD uses the same objective component as the briefing. Corner Duel has
separate left/right completion indicators. Fire finishes keep the required final
shot visible alongside the points target. Rush Hour retains its separate rush
condition even before the goal target is reached. Existing completion rules and
stars have not changed.

Repeated control instructions and the decorative pitch caption are removed.
Preparation uses a short shot cue, the actual trajectory preview and timing ring.
The next aim shows one short correction, cleared when a new hold begins. The
feedback popup keeps the result, earned points and special technique; full
practice explanations stay in the attempt history.

## Saved state

`tutorial_lessons_v1` stores version 1 with completed and skipped stable lesson
IDs. This is independent of stage stars. Completing a replay removes that lesson
from the skipped set. Unknown save versions or unreadable values are preserved;
lessons remain usable for the session and the existing save-unavailable state
is set. No existing stars, rewards, rival records or audio settings are reset.

## Local validation handoff

Regression sources were updated for the new screens and control behaviour, and
new cases cover lesson persistence, independent gesture success, repeated timing
windows, first launch, replay and the frozen timed match. These cases are unrun.
`autoTutorials: false` is a test injection for existing mode-specific widget
fixtures; the shipped app enables automatic tutorials by default.

1. Fresh data: confirm the aim lesson appears automatically, gestures are real,
   and Skip returns to the Stage 1 objective. Relaunch: skipped/completed lessons
   should stay dismissed without requiring a stage win.
2. Complete aim with a wide shot; the lesson should still pass. Play curve,
   banana and knuckle lessons, including repeated failed gestures. Confirm the
   correct technique is required and Retry does not cost campaign chances.
3. Hold for 6+ revolutions. Release inside/outside the zone on different passes.
   Repeat with a sideways drag and a return to centre. No automatic shot, stale
   timing result, accidental knuckle or double release should occur.
4. Pause/background during a held tutorial shot, resume and lift the old finger.
   No shot should fire. Repeat during normal gameplay and while leaving a lesson.
5. On a timed stage, earn Fire and open its lesson. Wait, complete or skip it.
   The real attempt's clock, goals, charge, chances and records must be intact
   until the lesson transition finishes. The next real shot can still use Fire.
6. Verify both corners, each Fire finish, and the rush condition before and
   during play. Reaching only the numeric target must not falsely show a clear.
7. Try small phones, large text, reduced motion, mute and resumed audio. Check
   that controls stay reachable and instruction changes do not cancel a hold by
   resizing the pitch.
8. Observe first-time players: can they name the objective, choose a technique,
   and decide to retry without coaching? Retention and balance improvements are
   hypotheses until those playtests are complete.
