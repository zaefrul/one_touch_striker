# Local prototype playtest

No checks below have been run by Codex. Complete them locally before deciding
whether to expand this prototype or migrate the Flutter campaign.

## First local pass

1. Import `project.godot` in the Godot 4 Standard editor. Record the editor
   version, renderer and any parser/import errors.
2. Run the main scene. Confirm the complete goal, ball and lower prompt fit the
   portrait window, and the goal remains visible above the result card.
3. Play all five balls with mouse input. Confirm the objective says 3 goals,
   the round uses five balls, and one click starts the next attempt.
4. Repeat on physical Android and iPhone hardware. Record model, OS version,
   export type and display refresh rate. Check notches and system gesture areas.

## Input and timing

| Action | Expected observation |
| --- | --- |
| Quick press/release | One straight shot; no shot at touch-down |
| Hold for at least ten seconds | Spinner completes ten revolutions and keeps moving |
| Release in blue on revolution 1, 3 and 8 | Clean knuckle each time while holding still |
| Release outside blue | Straight shot; feedback says early/late |
| Drag left/right by a small amount | Small predictable bend to that side |
| Drag farther sideways | Strong banana bend, potentially wide |
| Drag back to centre after committing curve | Straight shot; never accidental knuckle |
| Add another finger during a hold | It cannot take over or launch the held ball |
| Pause with another finger, then release the first | Hold cancels and consumes no ball |
| Background the app while holding | Returns paused; stale release cannot shoot |
| Pause while ball is flying | Ball and keeper freeze and continue on resume |
| Resize/rotate during a hold | Hold cancels; a new touch starts with a fresh origin |
| Release outside the play area | Cancels instead of firing |
| Press Next repeatedly | One new ready ball; no duplicate goal/attempt |

## UI layout pass

The source and static SVG were reviewed; the following runtime checks are still
pending. Compare the UI at 320 x 640, 400 x 800, a tall phone aspect ratio and a
tablet-sized viewport. Also try a short desktop window to exercise menu scrolling.

- Header icons share a baseline and have at least 48 logical units of touch area.
- The objective and goal count fit their card. Five markers remain on one row;
  scored shots show checks, missed shots show crosses, and the next ball has an
  outline. The caption counts down to **Set complete** after the fifth ball.
- The objective, ball, timing ring and bottom cue do not overlap. Hold through
  several revolutions; watch the blue zone and check the bend meter at both ends.
- The first ball says **Drag to bend**; later ready balls use only **Touch to lock**.
  Restart brings the first-ball cue back. Holding shows **Release to shoot**.
- Each result shows one clear outcome, one technique line and **Next ball**.
  The fifth result shows the final goal total and **Play again**, with appropriate
  wording for zero goals, one goal, a win and a perfect five.
  Pause, Help and Sound remain reachable from results; returning from Pause/Help
  restores the same result without consuming a ball.
- Pause has **Resume**, **Restart set**, **Controls** and the current sound setting.
  Help has three compact technique rows. Text wraps inside the card, and content
  scrolls when necessary without moving the action buttons off-screen.
- On phones with notches or gesture bars, check top/bottom safe margins in both
  orientations. On tablets, cards stay centred rather than spanning the pitch.
- Clicking any toolbar button cannot launch a shot. A release over the header
  cancels a held shot; menu touches cannot reach the pitch underneath.
- Pause while the ball is flying, then resume. Both the card and shade disappear
  immediately, the flight continues, and the usual result appears once.
- Resume from ready, a held shot and a result. Resize/background while paused.
  There must be no stale menu, double result or shot caused by releasing a button.
- Use Tab/Enter/Space with a keyboard. Focus should be visible; an open Pause/Help
  modal must not focus toolbar controls underneath. Check Escape and R still work.
- Mute from Pause and from the toolbar. Both speaker icons and the **Sound on/off**
  caption agree, and the choice survives restarting the prototype.

## Fairness and feel

- Watch the glove, head, torso and legs at contact, especially full-stretch saves.
- Shoot just inside and just outside each post. Check the ball's visible radius
  and the post radius agree with the result.
- Check high shots against the crossbar and corners.
- Confirm a goal is awarded only after the full ball passes behind the line.
- Repeat similar knuckle releases: the wobble should be bounded and repeatable.
- Try a late curve away from the committed dive. The keeper must not redirect
  to the final target after committing.
- The keeper uses capsule geometry and substep sampling. Record close-contact
  disagreements with video; do not infer fairness from source review alone.

## Sound and lifecycle

- Check kick, net, save, post and wide effects, crowd cheer and ambience.
- Toggle the speaker off, restart the app, and confirm it stays muted.
- Pause/background during audio and confirm it pauses without overlapping loops.
- Restart during feedback and confirm old effects stop and the new set is ready.

## Performance observations

Target steady 60 FPS on the chosen test phones. This target is unmeasured.

Use Godot's local profiler/monitors to capture idle aiming, a ten-second hold,
the first shot, consecutive goals, a full-stretch save and repeated retries.
Record frame-time spikes and memory growth after twenty sets. A 60 Hz frame
budget is approximately 16.7 ms; editor/debug results should be separated from
release-export measurements.

| Device / OS | Editor / export | Renderer | Refresh rate | Typical FPS | Worst observed frame | Scenario / notes |
| --- | --- | --- | --- | --- | --- | --- |
| Pending | | Compatibility | | Unmeasured | Unmeasured | |

## Replay comparison

Ask a few first-time players to try the 2D game and this prototype, alternating
which one they play first. Observe without coaching:

- Can they intentionally choose straight, curve and knuckle?
- Can they explain a save or miss?
- Do they voluntarily choose another set?
- Which presentation makes the shot easier to read and more satisfying?

Record player comments and voluntary retries; do not treat a handful of sessions
as proven retention or revenue. Expand beyond one arena only after the controls,
visible contacts and performance are satisfactory on the chosen devices.
