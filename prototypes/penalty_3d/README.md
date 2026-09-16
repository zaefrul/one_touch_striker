# One-Touch Striker: 3D Penalty Arena

A standalone Godot prototype for evaluating the same one-touch football loop in
3D. It is based on the Flutter game's `feat/stage-challenges` branch. The Godot
project is entirely inside this folder.

**Status: source reviewed only. No editor import, parser/analyzer, game run,
automated test, export/build or GitHub workflow was executed for this prototype.**
60 FPS is a playtest target, not a measured result.

## Open it locally

1. Fetch the prototype branch:
   ```bash
   git fetch origin
   git switch --track origin/prototype/penalty-3d
   ```
   If you already have that local branch, switch to it and use
   `git pull --ff-only origin prototype/penalty-3d`.
2. Install the **Godot 4 Standard editor** (GDScript edition).
   The source targets Godot **4.4 or later**. Start with a current stable release:
   [official downloads](https://godotengine.org/download/).
3. In Godot's Project Manager, choose **Import** and select
   `prototypes/penalty_3d/project.godot`.
4. Let the editor import the included resources, then press **F5 / Run Project**.

This is a separate Godot application. `flutter run` continues to open the existing
Flutter game. To return to the campaign branch, use
`git switch feat/stage-challenges`.

## Play

The objective is **score 3 goals in 5 balls**. All five released shots count.
The moving ring on the goal shows the initial direction and target height.

| Input | Action |
| --- | --- |
| Touch/click the pitch | Lock the currently visible aim |
| Release quickly | Straight shot |
| Hold and drag sideways | Choose left/right curve; more drag adds banana bend |
| Drag back to the touch origin | Return to a straight shot; that hold remains in curve mode |
| Hold still and release in the blue timing sector | Knuckle shot |
| Keep holding through several revolutions | Ring keeps rotating; every revolution has a fresh timing window |
| Release early or late | Ordinary straight shot with timing feedback |
| Next Ball / Play Again | Start immediately |
| Pause icon / Escape | Pause or resume |
| Help icon | Show controls |
| Speaker icon | Toggle sound; the choice is saved for this prototype |
| R | Restart all five balls |
| Space on a result | Next ball / new set |

The timing ring is the knuckle technique clock inherited from the Flutter game.
Shot speed is fixed in this prototype. The ring never fires or locks a shot by
itself. Small movements up to 14 logical pixels stay straight. Dragging beyond
that threshold commits the hold to curve controls, preventing accidental
knuckles after dragging back to the centre.

Releasing over the toolbar/outside the pitch cancels a held shot. Pause,
backgrounding, a cancelled touch and window resize also cancel a hold. A shot
already in flight freezes during pause and resumes; cancellation consumes no ball.

## Implemented scope

- Genuine perspective 3D scene, fixed camera, pitch, goal frame and net.
- Procedural keeper with footwork, delayed committed dive, recovery and a brief
  save gesture. Geometry is an original stylised blockout for the prototype.
- Straight, adjustable curve/banana and deterministic knuckle paths.
- A shared path function for trajectory preview and ball flight.
- 3D swept ball contact against the posts and the keeper's visible body shapes.
- Whole-ball goal-line crossing and separate goal, save, post, wide and over results.
- Five-ball objective, session goal count and immediate retry.
- Existing project kick/net/save/post/wide/cheer audio and quiet crowd ambience.
- Saved sound preference in Godot's separate `user://arena_settings.cfg`.
- Reused meshes/materials, an instanced crowd and physics interpolation.
- A shared UI theme, matching vector icons, responsive cards and safe-area margins.

The twelve-stage campaign, stars, rivals, purchases and Flutter save data are
outside this prototype. It has no backend, telemetry, advertising or purchases.

## UI layout

The arena uses one compact objective card, five shot markers and a short bottom
prompt. Check marks and crosses distinguish attempts without relying on colour.
The cue disappears during ball flight. Per-shot results have one **Next ball**
action; the final result has **Play again**. **Restart set** is in Pause.

All screens share 48-unit touch targets, 52-unit primary actions, 16-unit card
corners and a centred column capped at 440 logical units. Godot containers own
the spacing. On Android/iOS, display safe areas are converted into viewport
coordinates before margins are applied. Help and pause content can scroll while
the action buttons stay outside the scroll area.

The toolbar and objective are excluded from shot input. Modal menus block pitch
input and disable the toolbar's keyboard focus. Resuming a shot in flight also
dismisses the pause overlay. The rotating technique ring is still drawn around
the projected ball; the UI update does not change its timing or the shot rules.

See [the UI layout reference](docs/ui-layout.svg) and
[the layout notes](docs/UI_LAYOUT.md). The SVG is an authored static design
reference, **not a screenshot or evidence of an engine run**. Actual font metrics,
mobile insets and live scene clearance still need the local checks in PLAYTEST.

## Why this engine

Godot is being evaluated as the 3D implementation candidate. Its Compatibility
renderer supports core 3D on mobile, desktop and web, and is intended to cover a
wide range of hardware. This scene uses that renderer without advanced lighting
or third-party plugins.

Flame's current `flame_3d` package labels itself experimental and advises against
production use. This prototype avoids tying the existing Flutter campaign to
that experimental rendering API. A final engine/migration decision depends on
local import, device performance and playtest results.

Sources checked while preparing the prototype:

- [Godot renderer guidance](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)
- [Flame 3D package status](https://pub.dev/packages/flame_3d)
- [Godot physics interpolation](https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/physics_interpolation_introduction.html)
- [Godot 3D geometry helpers](https://docs.godotengine.org/en/stable/classes/class_geometry3d.html)

## Architecture and tuning

| File | Responsibility |
| --- | --- |
| `scripts/main.gd` | Shot lifecycle, input ownership, round state, pause, audio |
| `scripts/shot_math.gd` | Flight, curve/knuckle timing, swept capsule/frame contact |
| `scripts/keeper.gd` | Committed keeper response and matching visible/contact shapes |
| `scripts/arena_art.gd` | Arena meshes, camera, instanced crowd, preview geometry |
| `scripts/hud.gd` | Container layout, safe areas, timing ring, results and menus |
| `scripts/ui_theme.gd` | Shared palette, typography and button/panel styles |
| `scripts/shot_track.gd`, `scripts/bend_meter.gd` | Compact progress and bend cues |
| `ui/icons/` | Original matching SVG control and technique icons |
| `shaders/ball.gdshader` | Procedural ball markings |

Distances are world units interpreted as metres. Y is ball height; Z runs from
the penalty spot at 11 toward the goal at 0. The full ball must cross Z = 0
before a goal is awarded. Flight is an authored arcade trajectory, not a
simulation of aerodynamic forces.

The goal is 7.32 units wide and 2.44 high, with 0.06-radius frame members.
Ball radius is 0.14. Flight to the goal centre plane takes 0.70 seconds.
Maximum sidespin shifts the goal-line destination by 2.65 units; it is never
clamped into the goal. The knuckle sector is 0.55–0.73 seconds of every one-second
hold cycle, matching `lib/game/knuckle_shot.dart`.

Keeper reaction is 0.19 seconds, root travel is limited to 1.55 units from its
commit position, and the dive transition lasts 0.34 seconds. Prediction reads
observed ball position/velocity after release and does not read the player's
locked target or spin. These are initial tuning values, not proven balance.

The default physics tick is 60 Hz. Four collision substeps give 240 pose samples
per second; display transforms interpolate between physics ticks. Sweeps find
the earliest capsule entry along each ball segment. Moving-frame contact handles
translation; rotating limbs use their midpoint pose within each substep. That
rotational approximation needs close-contact device review. Mesh cylinders plus
spherical end caps use the same segment endpoints and radii as contact checks.

Result rebounds, the net pulse and crowd reactions are presentation after the
attempt has been scored. They cannot change the result.

## Device export

The first handoff is source for local editor play, not an APK or iOS build.

Use Godot's export templates matching your installed editor. Configure the
Android/iOS export preset locally, using a **separate prototype application ID**
such as `com.zaefrul.onetouchstriker.arena3d` so it can coexist with the Flutter
game. Do not commit signing credentials.

- [Android export setup](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)
- [iOS export setup](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)

The iOS export workflow requires macOS and Xcode. No export preset or signing
identity is assumed here. Review [PLAYTEST.md](PLAYTEST.md) before evaluating the
prototype on phones.

## Asset provenance

The scene, keeper geometry, UI and ball shader were authored for this prototype.
No external character models, textures or image-generation service were used.

The icon and seven WAV files are copies of existing repository blobs from
commit `3e60054eca2a5df22b273b73e8b8ea4d512a0269`:

- `icon.png`: existing iOS app icon.
- `audio/`: the existing kick, net, save, post, wide, cheer and stadium WAV files.
