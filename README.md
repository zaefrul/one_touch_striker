# One-Touch Striker — Flutter prototype

A portrait arcade football game: follow the sweeping arrow, tap the pitch, and beat the keeper. All artwork is rendered in code; no external image assets or backend are needed.

## Status

The first version was successfully built and tested in an iPhone simulator by the project owner on 6 September 2026. Basic gameplay worked with no major errors; a brief stutter was reported. Physical-device performance and Android installation still need verification.

The rendering updates cache field and player drawing commands, text layouts, dynamic paints and paths. Movement now maintains continuous phases as Classic difficulty increases; cinematic slow motion eases in and out and trails sample consistently across refresh rates. Results include accuracy, longest streak and a Classic personal-best celebration. Performance gains have not yet been measured. See [performance notes](PERFORMANCE_NOTES.md) for source findings and opt-in local profiling markers.

Challenge mode now has **12 stages and 36 stars**, with six harder Champion stages extending the original six on `feat/stage-challenges`. They add tougher corner targets, timed scoring rounds and a third defender with a repeating wave formation. Existing six-stage saves retain their medals and unlock stage seven after stage six. Select **PLAY CHALLENGES** from the home screen. Classic remains available under **LET'S PLAY**. This milestone is source-only: no analysis, tests, builds or game runs were executed for publication. The owner will validate it locally. See [challenge design and playtest notes](CHALLENGES.md).

**Beat the Keeper** adds earlier, single-use Fire Shots in challenges, three named keeper patterns, seven original sound effects, a saved sound toggle and direct retries. The opening stage can now deliver a Fire Shot after two consecutive goals; Corner Artist charges after one corner. See [rules and local handoff](BEAT_THE_KEEPER.md). These source changes have not been built, run or playtested here.

**Progressive keepers** now develop from Academy (stages 1–2), through Club
(3–4), Professional (5–6) and Elite (7–9), to World Class (10–12). They add
diving saves, signalled rushes/slides, marking of your previous shooting side
and save taunts. Articulated gloves, body and legs use the same geometry for
drawing and collision. See [keeper rules and playtest handoff](PRO_KEEPERS.md).
Difficulty and frame performance remain unmeasured for this source update.

**Rival Cup** adds showdowns at stages 3, 6, 9 and 12, four trophies, saved
win/loss records against each keeper and five cosmetic rewards at 3/9/18/27/36
stars. Existing stars unlock rewards automatically and are never spent. The
final now requires a Fire corner finish and allows 34 active seconds. See
[Rival Cup rules, save continuity and local checks](RIVAL_CUP.md). These changes
are source-reviewed only; no builds, tests or workflows were run.

## Run on your machine

Install stable Flutter and the platform toolchain, then clone this repository:

```bash
git clone git@github.com:zaefrul/one_touch_striker.git
cd one_touch_striker
git switch feat/stage-challenges
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run
```

Android, iOS, and web platform projects and the dependency lockfile are committed. Bootstrap is only needed to regenerate missing platform scaffolding. Use a Flutter version compatible with the committed lockfile; its current SDK constraints require Dart 3.12+ and Flutter 3.44+.

The audio milestone adds `audioplayers: ^6.8.1`. Its new dependency resolution is left to the owner: run `flutter pub get` after pulling and retain the updated `pubspec.lock`. The existing lockfile was not regenerated during source publication.

Android requires the Android SDK and an emulator or connected phone. Building for iOS requires macOS and Xcode, plus signing for a physical device.

For browser testing:

```bash
flutter run -d chrome
```

For an Android test APK:

```bash
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`. This is a debug build for testing.

## Optional manual checks and APK

The **Flutter checks and Android APK** workflow in this branch has only a `workflow_dispatch` trigger. Push and pull-request triggers have been removed so source publication does not automatically run checks or build an APK. No workflow was dispatched for this milestone. The version on `main` will remain unchanged until these changes are integrated.

If the owner later chooses to use it after integration, the manual workflow resolves committed dependencies, runs analysis and tests, then uploads **one-touch-striker-debug-apk**. Local validation is the current handoff; successful compilation alone would not establish physical-device performance.


## Classic rules

- Tap the pitch while aiming. The target locks at the instant of the tap.
- The ball travels on a straight path; the goalkeeper and defenders keep moving.
- Goal: 1 point. Either highlighted goal corner: 3 points.
- Five consecutive goals activate 2× scoring for subsequent shots. The fifth itself uses the previous multiplier.
- A miss, save, or block uses one chance and resets the streak.
- Three misses end the run. There is no time limit.
- First defender unlocks at 3 goals; second at 9. Movement and aiming speed increase with goals and are capped.
- Pause freezes the match. Backgrounding the app requires an explicit resume.
- Best score is saved locally after each new best. A failed storage operation displays a notice; gameplay remains available.

## Challenge mode

| Stage | Objective | New challenge |
| --- | --- | --- |
| 1 · First Touch | Score 3 goals | The Sweeper; third consecutive goal can be a Fire goal |
| 2 · Moving Wall | Score 3 goals | The Sweeper and one defender |
| 3 · Corner Artist | Score once in each corner | Corner Duel showdown; one corner charges Fire |
| 4 · Beat the Clock | Score 4 goals in 25 active seconds | The Sentinel under time pressure |
| 5 · Double Trouble | Score 4 goals | The Gambler and two crossing defenders |
| 6 · Captain's Finish | Reach 8 points with a Fire goal finish in 30 active seconds | Fire Finish showdown; The Gambler and two defenders |
| 7 · Pressure Cooker | Score 5 goals in 26 active seconds | Faster Sweeper and two crossing defenders |
| 8 · Needle Threader | Score 3 corner goals | The Sentinel and two offset defenders; no timer |
| 9 · Triple Wall | Score 5 goals, including one past a rush | Rush Hour showdown; The Gambler and a three-defender wave; no timer |
| 10 · Sudden Rush | Score 12 points in 22 active seconds | Quick crossing defenders and Fire scoring under pressure |
| 11 · Corner Siege | Score 4 corner goals in 32 active seconds | The Sentinel and the triple wave under time pressure |
| 12 · Champion's Gate | Reach 18 points with a Fire corner finish in 34 active seconds | Champion Final showdown; fastest Gambler and three defenders |

Every attempt starts with three chances and its own score. Clearing a stage unlocks the next; replay any unlocked stage immediately. A clear with zero, one or two misses awards three, two or one stars respectively. Only the best stars per stage are saved, under `challenge_stars_v1`; Classic best scores use their existing key and are not changed by challenges. An unfinished attempt restarts from its briefing after relaunch.

Each showdown has a trophy and an additional win condition shown in the briefing
and HUD. Repeating the same corner does not fill both sides in Corner Duel;
numeric points alone do not complete a Fire finish. Completed challenge attempts
update the named keeper's local win/loss record once, including rematches and
forfeits. Leaving a briefing or closing an unfinished attempt adds no result.
STAR REWARDS equips unlocked ball, net and pitch looks; cosmetics have no effect
on scoring or physics. Rival records and equipment save separately from stars.

Retry from results goes directly into a fresh attempt; choosing a new stage opens its briefing. Two goals without a miss charge the next shot to 2× points. Corner objectives charge only from corner goals: one in Corner Artist, two in Needle Threader and Corner Siege. The boosted shot consumes charge; misses reset it. Fire Shots can still be saved, blocked or missed.

Timers run during aiming and ball flight, using active frame time before cinematic slow motion. Briefings, pause, result feedback and completion panels freeze the countdown. A shot released before zero still resolves, and a winning buzzer shot clears the stage. Defenders follow fixed stage patterns; keeper skill adds delayed reactions and, at Elite and World Class, memory of the last shot's side. Classic's goal-based unlocks do not add extra defenders during a challenge.

## Implemented

- Flutter menus, HUD, three-chance display, restart and pause overlay
- Flame update/render loop with a fitted 400 × 640 logical pitch
- Pure Dart match model with substep ball collision checks
- Moving keeper and defenders; deterministic shot direction
- Corner targets, points, streak multiplier and escalating difficulty
- Ball trail, net graphics, goal particles and result feedback
- Optional haptic feedback and local best score storage
- Continuous motion, eased highlight shots, cached player drawings and consistent trail sampling
- Accuracy, longest streak, shot totals and a Classic personal-best result badge
- Optional local DevTools phase markers via `--dart-define=STRIKER_TRACE=true`
- Twelve-stage challenge map, objective HUD, countdown, stage briefings and results
- Six Champion stages with tighter targets and a third defender in spaced lanes
- Stage-specific pitch palettes, defence patterns, unlocks, retries and saved stars
- Three named keepers with different movement, coloured kits and briefings
- Five challenge keeper tiers, articulated diving/sliding poses, marking and save taunts
- Early challenge Fire Shots, visible charge and direct rematches
- Four Rival Cup showdowns, permanent trophies and saved personal keeper records
- Five star cosmetics, next-reward targets and a saved equipment collection
- Preloaded sound effects, independent saved mute and lifecycle cleanup
- Touch semantics and tooltips (the visual timing mechanic is not fully screen-reader accessible)
- Existing simulation and widget regression cases, plus new challenge cases prepared for local execution

Corner, near-post and Fire Shots have cinematic slow motion. Recorded replays are not included. There are no ads, purchases, accounts, multiplayer, analytics, or online services. Graphics, audio and stage balance need real-device playtesting before release.

## Project structure

| Path | Purpose |
| --- | --- |
| `lib/main.dart` | App shell, menu/HUD, lifecycle pause, storage and haptics |
| `lib/game/match_model.dart` | Simulation, scoring, difficulty and collisions |
| `lib/game/challenge_stage.dart` | Stage balance settings, objectives and persistent star progress |
| `lib/game/showdown.dart` | Four additional showdown rules and stable trophy IDs |
| `lib/game/rival_ledger.dart` | Single-count challenge results and persistent keeper records/trophies |
| `lib/game/star_rewards.dart` | Star thresholds, unlocks and persistent cosmetic selection |
| `lib/game/keeper_style.dart` | Named keeper profiles and continuous movement patterns |
| `lib/game/keeper_skill.dart` | Tier abilities, reaction delays, body travel and marking limits |
| `lib/game/keeper_controller.dart` | Delayed commitment, rush schedule, recovery and learned coverage |
| `lib/game/keeper_pose.dart` | Shared articulated body parts for drawing and collision |
| `lib/game/striker_audio.dart` | Preloaded effects, playback cleanup and mute control |
| `lib/game/striker_game.dart` | Flame adapter and procedural rendering |
| `lib/game/shot_trail.dart` | Fixed-interval trail sampling with reusable storage |
| `lib/game/playtest_trace.dart` | Opt-in local DevTools phase markers |
| `lib/ui/challenge_panel.dart` | Stage map, briefings, clear and retry panels |
| `lib/ui/star_rewards_panel.dart` | Next reward card and equipment collection |
| `lib/ui/run_summary.dart` | Shared result statistics and personal-best badge |
| `test/match_model_test.dart` | Shot lock, multiplier, misses, keeper, corners and frame gaps |
| `test/widget_test.dart` | Menu-to-game smoke check |
| `test/challenge_model_test.dart` | Objective, timer, buzzer-shot, retry and star-save regression cases |
| `test/challenge_widget_test.dart` | Challenge entry/retry, saved unlocks and pause/countdown cases |
| `test/motion_model_test.dart` | Movement continuity, easing, trail timing and statistics cases |
| `test/results_widget_test.dart` | Personal-best, tied-replay and record preservation cases |
| `test/keeper_challenge_test.dart` | Fire scoring, saves, buzzer shot, direct retry and keeper continuity |
| `test/pro_keeper_test.dart` | Delayed reactions, committed reach, slides, pose contact, taunts and resets |
| `test/rival_cup_test.dart` / `test/rival_cup_widget_test.dart` | Unexecuted showdown, record, legacy-save and equipment regression sources |
| `assets/audio/` / `tool/generate_audio.py` | Original WAV effects and their generator |
| `tool/bootstrap.sh` | Platform generation, dependency resolution and checks |

## First device checks

1. Confirm the menu and score panel fit a small Android screen and an iPhone with a safe-area inset.
2. Tap repeatedly during ball flight: exactly one shot should be resolved.
3. Check clear corner goals, keeper saves, and misses beyond both posts.
4. Reach five goals in a row; confirm the following shot receives double points.
5. Lose all chances, restart, and confirm score/chances reset while best remains.
6. Background during a shot; return and confirm explicit resume preserves that shot.
7. Close and reopen the app; confirm best score and vibration preference persist.
8. Play ten runs and tune aiming speed/keeper coverage based on actual misses and run lengths.

The fixed-step collision approximation uses small substeps (up to 1/240 second). Frames longer than 100 ms are bounded rather than fast-forwarded. These choices need performance evaluation on target phones.

## Reference documentation

- Flutter CLI: https://docs.flutter.dev/reference/flutter-cli
- Flutter installation: https://docs.flutter.dev/install
- FlameGame API: https://pub.dev/documentation/flame/latest/game/FlameGame-class.html
- SharedPreferencesAsync API: https://pub.dev/documentation/shared_preferences/latest/shared_preferences/SharedPreferencesAsync-class.html
