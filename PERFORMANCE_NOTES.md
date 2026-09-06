# Rendering update

The first version builds and runs in the iPhone simulator according to the project owner's test. A brief stutter was reported; there is no frame-time trace yet.

## Changes

- Record the pitch, goal, net, corner targets and static labels once as a vector `Picture`, then replay the commands each frame.
- Reuse the finite set of text layouts, with player labels prepared before gameplay.
- Reuse the trail and confetti Paint objects.
- Dispose Picture and TextPainter resources when the game is removed; recreate them lazily if needed on a later mount.

The old renderer creates and lays out 5–7 TextPainter objects per frame depending on defender count. The update removes that repeated layout work. This is a code observation, not proof of the stutter's cause. Picture caching removes repeated Dart recording work; the commands still need rasterization.

The match simulation, score rules, aiming, difficulty, app lifecycle handling, dependencies and existing tests are retained from the repository baseline.

## Verify

After switching to the update branch:

```bash
flutter pub get
flutter analyze
flutter test
```

Restart the app completely so the new loading path runs. Check the pitch/net/labels, goals, misses, defender unlocks, pause/resume and restart. Both portrait screen sizes should fit as before.

For meaningful performance measurements, use a physical phone in profile mode. Simulator and debug performance differ from release behavior; if a physical phone is unavailable, continue functional testing without drawing a performance conclusion.

```bash
flutter devices
flutter run --profile -d YOUR_PHYSICAL_DEVICE_ID
```

Replace the device identifier, then open Flutter DevTools from the link in the run output. In Performance, record the first shot, repeated shots, a goal, a miss, defender unlocks and restart. Compare the old and new versions using the same phone and build mode. Look at UI and raster frame times; the frame interval is about 16.7 ms at 60 Hz or 8.3 ms at 120 Hz.

Record when stutter occurs: first shot only, every tap, collision/goal feedback, steady aiming, or restart. A trace of any remaining spike should guide the next fix.

Local Flutter execution was unavailable when this change was prepared. The repository workflow is the source for build/test status. No before/after device timings have been recorded yet.

## References

- [Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance)
- [TextPainter API](https://api.flutter.dev/flutter/painting/TextPainter-class.html)
- [Picture disposal](https://api.flutter.dev/flutter/dart-ui/Picture/dispose.html)
