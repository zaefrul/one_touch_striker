# One-Touch Striker: 3D Rival Cup

A standalone Godot prototype for evaluating the same one-touch football loop in
3D. It is based on the Flutter game's Rival Cup keepers. The Godot project is
entirely inside this folder.

The owner reported passing headless checks for the earlier three-rival cup.
The new **Beat the Rush** update is source-reviewed only; its regression scripts
are prepared for local execution. Visual quality, audio mix and keeper difficulty
still need a phone playtest.
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

Headless checks (from the repository root):

```bash
godot --headless --path prototypes/penalty_3d --import
godot --headless --path prototypes/penalty_3d -s res://tests/cup_smoke.gd
godot --headless --path prototypes/penalty_3d -s res://tests/rush_smoke.gd
godot --headless --path prototypes/penalty_3d -s res://tests/champion_smoke.gd
```

`--quit-after N` counts iterations, not seconds, and booting into the cup map
does not exercise gameplay. Use the smoke scripts above. The manual aim and Champion update was source-reviewed only;
these commands are for the owner to run locally. No new APK was built for it.

## Play

The cup has **three five-ball rivals**. Score 3 goals to clear a keeper and
unlock the next. A set always uses all five balls so extra stars stay earnable.
Cleared rivals stay unlocked for rematch.

| Input | Action |
| --- | --- |
| Drag on the goal | Choose the target; releasing this drag never shoots |
| Touch/click below the goal | Prepare a shot toward your chosen target |
| A second finger on the goal while holding | Adjust aim without changing bend/lift or releasing |
| Release quickly | Straight shot |
| Hold and drag sideways | Choose left/right curve; more drag adds banana bend |
| Hold and drag up (after winning the cup) | Chip; upward distance controls lift |
| Drag back to the touch origin | Remove bend/lift; that hold cannot become a knuckle |
| Hold still and release in the blue timing sector | Knuckle shot |
| Keep holding through several revolutions | Ring keeps rotating; every revolution has a fresh timing window |
| Release early or late | Ordinary straight shot with timing feedback |
| Next ball | Start the next attempt immediately |
| Rematch / Next rival / Cup | Leave the current sheet; mid-set navigation records nothing |
| Pause icon / Escape | Pause or resume during a set |
| Help icon | Show controls |
| Speaker icon | Toggle sound; the choice is saved for this prototype |
| R during a set | Rematch the current rival (abandons an unfinished set) |
| Space on a result | Activate the primary action |
| Skip replay / Space / Escape during a highlight | Return to the scored result |

Stars: 3 goals → 1, 4 → 2, 5 → 3. The intro shows those thresholds under an
empty star row. The set result shows earned stars and the next target
("Score 3 to beat…", "Score 4 for two stars", "Score 5 for three stars",
or "Perfect. Next: …" / "Cup complete").

Win all three rivals to unlock the **Cup Ball**. The cup map previews it while
locked. The first cup win offers **Equip Cup Ball**; later the reward card
toggles Classic / Cup.

The timing ring is the knuckle technique clock inherited from the Flutter game.
Ordinary shots retain fixed speed; chips take longer as lift increases. The ring never fires or locks a shot by
itself. Small movements up to 14 logical pixels stay straight. Dragging beyond
that threshold commits the hold to its first clear axis: sideways for curve,
upward for chip once unlocked. An ambiguous diagonal waits for a clearer axis
and suppresses knuckle timing. Returning to the centre does not restore knuckle
eligibility during that hold.

Releasing over the toolbar/outside the pitch cancels a held shot. Pause,
backgrounding, a cancelled touch and window resize also cancel a hold. A shot
already in flight freezes during pause and resumes; cancellation consumes no ball.

## Beat the Rush

Win the original three-rival cup to unlock **Beat the Rush** and manual chips.
The first visit offers a free, animated chip lesson with **Skip lesson**.
The lesson starts with a central target that you can move. All modes now use
manual aiming; waiting never moves the target.
**Practice chip** remains available from the showdown intro and results.

The Gambler signals a rush with a forward stance and blue pitch chevrons on
balls 1, 3 and 5. He stays back on balls 2 and 4. Read the cue before releasing:
upward dragging makes a slower chip, while sideways dragging keeps the curve.
All five balls finish; 3/4/5 goals earn 1/2/3 best stars.

Win a completed showdown with at least one goal that physically passes above a
rushing keeper to earn **Sky Master**. The cosmetic badge appears beside the
shot markers and can be toggled on the map. A normal win still earns stars;
a chip around the keeper or a chip during the free lesson cannot earn the badge.

Showdown records and the lesson flag live in `user://rush_showdown.cfg`.
Cup stars, rivalry records and the Cup Ball stay in `user://rival_cup.cfg`.
See [the behaviour and tuning notes](docs/BEAT_THE_RUSH.md).

## Champion Showdown

After winning the Cup, challenge **The Captain**: **4 goals from 5**, with all
five balls played. A 5/5 win is a perfect showdown. He visibly guards your
recent favourite side, reading the last five observed shot positions with extra
weight on recent attempts. His two rushes are shuffled among five balls; the
complete order changes on rematch. Blue arrows and a forward stance identify a
rush before release. No arrows means he stays back.

Champion shows the selected aim and only the initial arc. **Practice · Full
preview** uses the same boss with a complete trajectory and endpoint marker.
Practice has its own temporary memory and writes no results. The original Cup
and Rush star thresholds stay at 3/4/5; Champion records are separate in
`user://champion_showdown.cfg` (best goals, wins/losses, observed lanes).

The Captain has a navy/gold kit, face, hair, number and crest, glove details,
planted idle footsteps, a crouched anticipation pose, running strides, extended
dives and a landing/recovery motion. The posed body/glove cores still drive
contact; cosmetic trim adds no contact shapes.

Exceptional or clinching goals can trigger a **skippable two-second goal-side
highlight**. Ball position/rotation, keeper limb endpoints and net motion are
recorded during the real shot. Playback samples that recording and does not run
flight, keeper decisions, collision or scoring again. At most two highlights
play per set (one exceptional goal plus the clincher). Practice also offers
highlights; the repeating chip lesson does not.

See [Champion behaviour and tuning](docs/CHAMPION_SHOWDOWN.md) and the owner-run
cases in `tests/champion_smoke.gd`. These are prepared source, not passing test
results. Camera framing, readable animation and difficulty need device review.

## Implemented scope

- Genuine perspective 3D scene, fixed aiming camera, pitch, goal frame and net.
- Three profile-driven keepers (Sweeper, Sentinel, Gambler) with readable patrols,
  kit colours, stance, delayed committed dive, recovery and a save taunt.
  Capsule radii and contact maths are unchanged; every visible capsule is still
  the contact capsule.
- Manual draggable target, with separate shot and aim touch ownership.
- Straight, adjustable curve/banana, deterministic knuckle and manual chip paths.
- A separate adaptive Captain showdown, full-preview practice and recorded highlights.
- An unlockable Rush Showdown, skippable chip lesson, saved mastery badge and
  delayed keeper rushes using the same visible/contact geometry.
- A shared path function for trajectory preview and ball flight.
- 3D swept ball contact against the posts and the keeper's visible body shapes.
- Whole-ball goal-line crossing and separate goal, save, post, wide and over results.
- Five-ball sets, saved stars / wins / losses in `user://rival_cup.cfg`, rematch
  of cleared rivals, and a derived cup win.
- Signature goal titles from the confirmed crossing position, crowd stingers,
  particles, a post-goal camera push and final-ball tension.
- Classic / Cup Ball materials, a locked cup-map preview and an equip toggle.
- Floodlit Night palette shared with the Flutter UI tokens.
- Existing project kick/net/save/post/wide audio, plus fire_goal, victory, groan
  and suspense; quiet crowd ambience.
- Saved sound preference in Godot's separate `user://arena_settings.cfg`.
- Reused meshes/materials, an instanced crowd and physics interpolation.
- A shared UI theme, matching vector icons, responsive cards and safe-area margins.

The Flutter twelve-stage map and Flutter save migration remain out of scope. The prototype has no backend,
telemetry, advertising or purchases.

## UI layout

The arena uses one compact objective card, five shot markers and a short bottom
prompt. Check marks and crosses distinguish attempts without relying on colour.
The cue disappears during ball flight. Per-shot results have one **Next ball**
action. Set results have one primary action. **Restart set** is in Pause.

All screens share 48-unit touch targets, 52-unit primary actions, 16-unit card
corners and a centred column capped at 440 logical units. Godot containers own
the spacing. On Android/iOS, display safe areas are converted into viewport
coordinates before margins are applied. Help and pause content can scroll while
the action buttons stay outside the scroll area.

The toolbar and objective are excluded from shot input. Modal menus block pitch
input and disable the toolbar's keyboard focus. Resuming a shot in flight also
dismisses the pause overlay. The rotating technique ring is still drawn around
the projected ball.

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
- [Godot command-line](https://docs.godotengine.org/en/4.4/tutorials/editor/command_line_tutorial.html)

## Architecture and tuning

| File | Responsibility |
| --- | --- |
| `scripts/main.gd` | Cup, lesson, Rush/Champion/practice/replay flow; input and pause |
| `scripts/manual_aim.gd` | Goal-plane projection and target drag region |
| `scripts/champion_brain.gd` | Observed shot memory, bounded guarding bias, rush schedule |
| `scripts/champion_progress.gd` | Separate four-goal showdown records and saved lanes |
| `scripts/shot_replay.gd` | Bounded actual-shot recording and playback interpolation |
| `scripts/captain_art.gd` | Authored Captain character details tied to posed limbs |
| `scripts/rival.gd` | Cup trio, Rush Gambler and Captain profiles |
| `scripts/cup_progress.gd` | Original cup stars, unlocks, wins/losses, equipped ball |
| `scripts/rush_progress.gd` | Separate showdown records, lesson flag, mastery badge |
| `scripts/shot_gesture.gd` | Axis choice, drag distance, knuckle exclusion |
| `scripts/keeper.gd` | Profile-driven pose and matching visible/contact shapes |
| `scripts/goal_fx.gd` | Signature classification, crowd, particles, camera, tension |
| `scripts/shot_math.gd` | Shared flight/chip arc, timing, swept capsule/frame contact |
| `scripts/arena_art.gd` | Arena meshes, camera, crowd, ball materials, rival banner |
| `scripts/hud.gd` | Cup map, intro, results, safe areas, timing ring |
| `scripts/ui_theme.gd` | Floodlit Night palette and button/panel styles |
| `scripts/star_row.gd`, `scripts/shot_track.gd`, `scripts/bend_meter.gd` | Stars, progress, bend cues |
| `scripts/chip_guide.gd`, `scripts/touch_tap.gd` | Animated lesson cue and raw touch menu activation |
| `tests/cup_smoke.gd`, `tests/rush_smoke.gd`, `tests/champion_smoke.gd` | Owner-run progression, input, replay and lifecycle regression cases |
| `ui/icons/` | Original matching SVG control and technique icons |
| `shaders/ball.gdshader` | Classic / Cup Ball markings |

Distances are world units interpreted as metres. Y is ball height; Z runs from
the penalty spot at 11 toward the goal at 0. The full ball must cross Z = 0
before a goal is awarded. Flight is an authored arcade trajectory, not a
simulation of aerodynamic forces.

The goal is 7.32 units wide and 2.44 high, with 0.06-radius frame members.
Ball radius is 0.14. Ordinary flight to the goal centre plane takes 0.70 seconds;
maximum chip lift takes 1.20 seconds.
Maximum sidespin shifts the goal-line destination by 2.65 units; it is never
clamped into the goal. The knuckle sector is 0.55–0.73 seconds of every one-second
hold cycle, matching `lib/game/knuckle_shot.dart`.

Keeper reaction, reach, dive time and lift cap come from the rival profile.
Prediction reads observed ball position/velocity after release; the Captain also
estimates acceleration from successive observations. It never reads the player's
chosen aim, spin or loft and never retargets after committing. These are initial tuning values,
not proven balance. A reduced Sweeper lift does not by itself make high shots
safe: rotating the torso can still raise a glove into the path.

The default physics tick is 60 Hz. Four collision substeps give 240 pose samples
per second; display transforms interpolate between physics ticks. Sweeps find
the earliest capsule entry along each ball segment. Moving-frame contact handles
translation; rotating limbs use their midpoint pose within each substep. That
rotational approximation needs close-contact device review. Mesh cylinders plus
spherical end caps use the same segment endpoints and radii as contact checks.

Result rebounds, the net pulse and crowd reactions are presentation after the
attempt has been scored. They cannot change the result. Signature classification
uses the confirmed scoring position captured at the goal-line crossing.

## Device export

The owner has reported debug/release APKs from the earlier Rival Cup version.
This manual aim and Champion handoff updates source only; those existing APKs do not include
these changes. Import and export the updated project locally to try it on a phone.

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

The icon and WAV files are copies of existing repository blobs:

- `icon.png`: existing iOS app icon.
- `audio/`: kick, net, save, post, wide, cheer, stadium, fire_goal, victory,
  groan and suspense from `assets/audio/`.
