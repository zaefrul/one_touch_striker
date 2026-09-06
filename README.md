# One-Touch Striker — Flutter prototype

A portrait arcade football game: follow the sweeping arrow, tap the pitch, and beat the keeper. All artwork is rendered in code; no external image assets or backend are needed.

## Status

Source implementation provided, **not yet compiled or device-tested**. Flutter and Dart were unavailable in the creation environment and the SDK download could not be reached. No APK, IPA, or verified runtime preview is included. The bootstrap shell script passed a shell syntax check; the archive passed integrity verification. The included Dart tests have not been run.

## Run on your machine

Install the current stable Flutter SDK and the platform toolchain, then extract this archive.

```bash
cd one_touch_striker
bash tool/bootstrap.sh
flutter devices
flutter run
```

The script generates Android, iOS, and web platform wrappers with `flutter create`, restores the supplied application source/tests/pubspec, resolves packages, formats Dart, runs analysis, and executes the tests. It stops on any failure. Commit the generated platform folders and `pubspec.lock` after successful setup for reproducible future builds. The archive intentionally contains source and bootstrap instructions rather than manually fabricated platform wrappers.

Flutter 3.27 / Dart 3.6 or newer is the declared baseline; dependency resolution on an older installation may require an SDK upgrade. Use stable Flutter for setup. Android needs the Android SDK and an emulator or USB-debugging-enabled phone. Building for iOS requires macOS, Xcode, and appropriate signing when using a physical device.

For browser testing after bootstrap:

```bash
flutter run -d chrome
```

For an Android debug APK after the checks pass:

```bash
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`. This is a debug build, not a signed store release.

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
- Seven simulation tests and one widget smoke test, pending execution

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
