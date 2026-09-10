# Beat the Keeper milestone

This is the next source update on `feat/stage-challenges`, based on smoothness
commit `38164fb164e572e20d65c130eaefe01892c52e84`. The design goal is a satisfying
early finish, opponents whose openings can be learned, and an immediate rematch.
Enjoyment, retention, audio latency and frame performance have not been measured.

## Fire Shots in challenges

| Stages | Charge requirement | Earliest boosted shot |
| --- | --- | --- |
| 1, 2, 4–7, 9–10, 12 | Two consecutive goals | Third shot |
| 3: Corner Artist | One corner goal; centre goals do not charge | Second shot |
| 8: Needle Threader; 11: Corner Siege | Two corner goals without a miss; centre goals do not charge | Third shot |

- The charging goal earns its normal points. Charge is visible below the pitch.
- The next shot is a Fire Shot: a goal earns 2 points, a corner earns 6.
- It uses the same locked trajectory, opponent positions and collision rules.
  It can be saved, blocked, hit the post or go wide.
- Resolving that shot consumes the charge. A Fire goal does not also charge the
  next Fire Shot. Any miss resets charge and the scoring streak.
- Fire Shots use the existing eased cinematic approach. A Fire goal gets the
  stronger 1.25-second celebration, ball glow, particles, sound and haptic.
- Charge-ready sound plays only when another shot can follow; it does not play
  for a winning goal or after the active timer has expired.
- Classic retains five consecutive goals to activate ongoing 2× scoring. Its
  best-score record and goal-based defender progression remain comparable.

For example, three ordinary goals in First Touch score **1 + 1 + 2 = 4** and
clear the stage. One goal in each corner in Corner Artist scores **3 + 6 = 9**.
Two ordinary goals followed by a Fire corner can meet Captain's Finish's
eight-point objective and Fire finish. With the subsequent
[Rival Cup rules](RIVAL_CUP.md), five consecutive corners reach 18 points in
Champion's Gate but the required Fire corner finish occurs on the sixth,
bringing the total to **24**. The final now allows 34 active seconds.
These are scoring rules, not playtest results.

## Three opponents

| Keeper | Stages | Readable behaviour |
| --- | --- | --- |
| The Sweeper, gold kit | 1–2, 7, 10 | Smooth side-to-side sweep |
| The Sentinel, blue kit | 3–4, 8, 11 | Holds at each side, eases across, then holds again |
| The Gambler, pink kit | 5–6, 9, 12 | Spends longer on the right, with a shorter left-side visit |

Each has a name and tip in the briefing, a label on the map/pitch, and a distinct
kit. `keeper_style.dart` defines deterministic offsets with continuous position
and velocity at cycle/hold boundaries. Both drawing and collisions read the same
model coordinate. The subsequent [progressive keeper update](PRO_KEEPERS.md)
adds delayed dives, slides and learned coverage on top of those patrol styles,
with shared articulated collision geometry. Classic and defender boxes retain
their original approximations. Defenders, goals and timers stay configured per stage.

## Rematch and continuity

Retry after failure or a clear starts that stage immediately. A new stage still
opens its briefing. Retry resets score, chances, clock, streak, ball, charge,
trail and feedback together. The result panel gives a specific three-star target,
or another perfect clear if three stars were already earned. Previous stars and
unlocks are preserved. The later [Rival Cup update](RIVAL_CUP.md) adds cosmetic
unlocks from existing stars and personal keeper win/loss records on rematches.

## Sound and local setup

Seven original synthetic WAV effects cover kick, net/cheer, glove save/block,
post, wide shot, charge swell and Fire goal. See `assets/AUDIO.md` for provenance
and `tool/generate_audio.py` for their reproducible source.

`StrikerAudio` preloads one player per effect, disables position polling and uses
low-latency playback. There is no asset decoding or new player creation in the
shot callback. Cues arriving before their preload completes are dropped. Mute,
pause, backgrounding, changing mode and retries stop active effects; queued
playback is invalidated. A saved `sound` preference is independent of haptics.
The audio context requests mixing with other apps and respects iOS silent mode.
Unsupported/failed audio leaves gameplay available.

This adds `audioplayers: ^6.8.1`. Dependency resolution was not run here, so the
previous `pubspec.lock` is retained and needs updating on the owner's machine:

```bash
git fetch origin
git switch feat/stage-challenges
git pull --ff-only origin feat/stage-challenges
flutter pub get
```

Keep the resulting `pubspec.lock` in your local change set. The manual workflow
now uses ordinary `flutter pub get` so it can resolve the new dependency if you
later explicitly dispatch it. It still has only `workflow_dispatch`; publishing
this source does not start builds or tests. No workflow was dispatched here.

## Owner's playtest

No Dart/Flutter analyzer, tests, builds or app runs were executed here. Regression
cases are prepared for the new scoring, keeper continuity, saved mute and direct
retry; widget cases use silent audio so they do not depend on a native player.

On your phone, check the first charge/Fire goal, a saved Fire Shot, the two-corner
stage and the finale's last-second shot. Pause or mute during a sound, retry
immediately, then background/reopen and check that no stale sound plays. Confirm
saved stars, Classic best and the mute preference survive relaunch. Check the
briefing/results on a small screen and the first audio event with sound on/off.

For engagement, observe whether players voluntarily retry and can explain what
they will do differently. Record attempts, waiting time and unclear saves before
tuning speed, holds or thresholds. Use `PERFORMANCE_NOTES.md` for frame profiling.

Audio API references: [audioplayers package](https://pub.dev/packages/audioplayers),
[resource retention](https://pub.dev/documentation/audioplayers/latest/audioplayers/ReleaseMode.html),
[position updater](https://pub.dev/documentation/audioplayers/latest/audioplayers/AudioPlayer/positionUpdater.html),
[audio context](https://pub.dev/documentation/audioplayers/latest/audioplayers/AudioContextConfig-class.html).
