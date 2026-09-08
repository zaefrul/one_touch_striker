# Animation smoothness and local playtest

## Evidence and status

The owner's last report was a successful iPhone simulator build, no major errors,
and brief stutter. No device frame trace or before/after measurements have been
provided. These changes address source-level motion discontinuities and repeated
drawing work; they are not a measured claim that all stutter is gone.

This update builds on challenge commit
`d9d81b9c684df241b16ef10ad4da52106a325951`. That commit already aligned visible
player positions with collision anchors. Both updates are on
`feat/stage-challenges`; checking out the older `main` does not include them.

No analyzer, tests, builds or app runs were executed for this update. Added
regression cases are for the owner's local execution. The workflow remains
manual-only; no workflow is dispatched by this publication.

## What changed

| Source finding | Change | What to look for locally |
| --- | --- | --- |
| Classic used `sin(clock * currentSpeed)`, so a speed increase after a goal could instantly change position | Integrate keeper and aiming phases over time; use new speed only for future movement | No position jump at difficulty increases |
| Highlight shots switched from speed 1 to .38 in one frame | Ease the target near goal and recover gradually during feedback, at physics substeps | Continuous close-up and recovery |
| Ball rotation used `clock * spin`, with spin reset to zero after flight | Accumulate rotation during flight and retain its final angle in feedback | No rotation snap on impact |
| Kick squash began at maximum stretch | Use a sine-shaped pulse from normal size, through the squash, back to normal | A softer kick impulse |
| Trail sampling dropped each frame's leftover time and shifted a list | Preserve remainder, interpolate samples every 12 ms and use a fixed ring buffer | Consistent trail duration across refresh rates |
| Player artwork and several Paint/Path objects were recreated every render | Cache three player drawings; reuse paints, ball/arrow paths and confetti velocities | Less repeated Dart drawing work; inspect actual frame times |
| The app recreated GameWidget for HUD changes and sent overlapping notifications | Retain GameWidget and send one UI notification per event | Inspect first-shot and feedback spikes |
| Haptic dispatch preceded target locking | Lock the shot first, then issue haptics | Arrow timing matches the tap before platform feedback work |

Player pictures use the same anchors as the collision model. Collision boxes
remain the existing approximations. Cached vector commands still require
rasterization; caching does not guarantee a specific FPS.

Challenge clocks still count active time before cinematic scaling. Goal/miss
feedback keeps its original duration, and pausing/backgrounding freezes the
attempt. The existing 100 ms frame-gap cap remains; it is not an FPS guarantee.

## Results and records

- Classic and challenge results show accuracy, longest scoring streak, completed
  shots, goals, misses and corner goals.
- Accuracy counts resolved goals and misses. An abandoned in-flight shot is not
  added to the denominator. Longest streak survives misses and resets per attempt.
- Classic shows a one-time trophy badge when the score beats the record that
  existed before the run. Ties and lower scores do not celebrate.
- The badge respects the platform's reduced-animation preference.
- The saved best is read before a new best is written. A run that starts during
  that read reconciles its comparison against the saved record.
- Challenge medals remain separate from Classic's best score.

## Capture remaining stutter locally

Use a physical iPhone or Android phone in profile mode for performance conclusions.
Simulator/debug timing differs from deployed builds, as explained in
[Flutter's profiling guidance](https://docs.flutter.dev/perf/ui-performance).

Run this yourself after updating the branch:

```bash
flutter run --profile -d YOUR_PHYSICAL_DEVICE_ID --dart-define=STRIKER_TRACE=true
```

Open DevTools from the run output, go to Performance, and start recording before
pressing Play. The optional `Striker:` spans/markers identify:

| Marker | Meaning |
| --- | --- |
| `aiming.first` / `aiming.repeat` | Waiting for the tap |
| `tap.accepted` | The target has been locked |
| `shot.first` / `shot.repeat` | First versus subsequent flight |
| `feedback.goal` / `feedback.miss` | Goal, save, block or miss feedback |
| `classic.start-or-restart` | Starting/restarting Classic |
| `stage.prepare-or-retry` / `stage.start` | Stage changes and retries |
| `paused` / `results` / `stage.cleared` | Pause and end panels |
| `storage.load.*` / `save.best_score.*` | Loading and best-score write boundaries |
| `haptic.tap` / `haptic.result` | Platform haptic dispatch |

These use [Dart timeline tasks](https://api.dart.dev/dart-developer/TimelineTask-class.html)
and [instant events](https://api.dart.dev/dart-developer/Timeline/instantSync.html).
They are disabled by default and send no analytics. A marker identifies timing,
not causation. Inspect Flutter's UI and raster frame tracks to find the actual
spike. There is no per-frame logging or FPS counter substituted for measurement.

Record aiming, the first tap after launch, repeat shots, a goal, a miss,
pause/resume, restart and a stage change. For a haptic-associated spike, repeat
with vibration off using the existing toggle. Compare the prior commit and this
update on the same phone, refresh setting and build mode.

Fill these from observation; no values have been measured here:

| Phase | Visible stutter? | UI frame ms | Raster frame ms | Trace/recording time |
| --- | --- | --- | --- | --- |
| Steady aiming | — | — | — | — |
| First shot | — | — | — | — |
| Repeated shots | — | — | — | — |
| Goal/miss feedback | — | — | — | — |
| Restart or stage change | — | — | — | — |

Include phone model, OS, build mode, refresh setting, commit and vibration setting
when sharing the trace. Physical Android APK install/run remains unconfirmed from
the feedback received so far.

## Regression cases prepared for local execution

`test/motion_model_test.dart` covers motion continuity, easing, active timers,
rotation, streak statistics and trail sampling across refresh rates.
`test/results_widget_test.dart` covers a beaten record, tied replay, lower scores
and saved-record preservation. Existing Classic and challenge tests remain
available, including pause/retry and last-second shots.

Check result buttons on a small screen because the richer summary is scrollable.
Play complete attempts before judging the revised cinematic balance.
