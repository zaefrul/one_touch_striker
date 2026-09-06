# One-Touch Striker — Flutter prototype

A portrait arcade football game: follow the sweeping arrow, tap the pitch, and beat the keeper. All artwork is rendered in code; no external image assets or backend are needed.

## Status

The first version was successfully built and tested in an iPhone simulator by the project owner on 6 September 2026. Basic gameplay worked with no major errors; a brief stutter was reported. Physical-device performance and Android installation still need verification.

The rendering update caches static field drawing commands and text layouts, and reuses trail/confetti paints. Performance gains have not yet been measured. See [performance notes](PERFORMANCE_NOTES.md) for the changes and a before/after profiling procedure.

## Run on your machine

Install stable Flutter and the platform toolchain, then clone this repository:

```bash
git clone git@github.com:zaefrul/one_touch_striker.git
cd one_touch_striker
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run
```

Android, iOS, and web platform projects and the dependency lockfile are committed. Bootstrap is only needed to regenerate missing platform scaffolding. Use a Flutter version compatible with the committed lockfile; its current SDK constraints require Dart 3.12+ and Flutter 3.44+.

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

## Automated checks and APK

The **Flutter checks and Android APK** workflow runs on pull requests and pushes to `main`, and can be started manually after it reaches `main`. It resolves the committed dependencies, runs analysis and tests, then builds and uploads a debug APK. Open the completed run under **Actions** and download **one-touch-striker-debug-apk** from Artifacts. Failed checks prevent APK generation.

Successful CI verifies the build and automated tests; it does not establish real-device performance.


## Rules

- Tap the pitch while aiming. The target locks at the instant of the tap.
- The ball travels on a straight path; the goalkeeper and defenders keep moving.
- Goal: 1 point. Either highlighted goal corner: 3 points.
- Five consecutive goals activate 2× scoring for subsequent shots. The fifth itself uses the previous multiplier.
- A miss, save, or block uses one chance and resets the streak.
- Three misses end the run. There is no time limit.
- First defender unlocks at 3 goals; second at 9. Movement and aiming speed increase with goals and are capped.
- Pause freezes the match. Backgrounding the app requires an explicit resume.
- Best score is saved locally after each new best. A failed storage operation displays a notice; gameplay remains available.

## Implemented

- Flutter menus, HUD, three-chance display, restart and pause overlay
- Flame update/render loop with a fitted 400 × 640 logical pitch
- Pure Dart match model with substep ball collision checks
- Moving keeper and defenders; deterministic shot direction
- Corner targets, points, streak multiplier and escalating difficulty
- Ball trail, net graphics, goal particles and result feedback
- Optional haptic feedback and local best score storage
- Touch semantics and tooltips (the visual timing mechanic is not fully screen-reader accessible)
- Seven simulation tests and one widget smoke test, run by CI

Sound effects and slow-motion replays are not included in this first prototype. There are no ads, purchases, accounts, multiplayer, analytics, or online services. Graphics and balance need real-device playtesting before release.

## Project structure

| Path | Purpose |
| --- | --- |
| `lib/main.dart` | App shell, menu/HUD, lifecycle pause, storage and haptics |
| `lib/game/match_model.dart` | Simulation, scoring, difficulty and collisions |
| `lib/game/striker_game.dart` | Flame adapter and procedural rendering |
| `test/match_model_test.dart` | Shot lock, multiplier, misses, keeper, corners and frame gaps |
| `test/widget_test.dart` | Menu-to-game smoke check |
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

