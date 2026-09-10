# Progressive keeper skills

This source update extends `feat/stage-challenges` from
`c84327eae2dc17d552e9eb6a5405959d45bacfee`. The Sweeper, Sentinel and Gambler
retain their names, kits and patrol preferences, with progressively more
advanced football actions across the twelve challenges.

## Progression

| Stages | Tier | New behaviour | Reaction delay | Maximum sideways body travel |
| --- | --- | --- | --- | --- |
| 1–2 | Academy | Animated footwork and ready stance | No reactive dive | Patrol only |
| 3–4 | Club | Set feet, push off, extend both gloves, land and recover | 280 ms | 28 units |
| 5–6 | Professional | Every third shot: rush and slide; taunt after a keeper save | 240 ms | 36 units |
| 7–9 | Elite | Shade the side used on the previous shot; stronger dives and rushes | 200 ms | 44 units |
| 10–12 | World Class | Earlier commitment, greater travel and stronger marking | 170 ms | 52 units |

These are game balance settings, not measured professional reaction times.
The listed travel is the body anchor's maximum sideways displacement; the drawn
arms and gloves add physical reach. All tiers use a 280 ms eased commitment.
Distances use the existing 400 × 640 logical pitch. Delay, dive and ball flight
share the cinematic simulation clock, while challenge timers retain active time.

The map shows each keeper's tier. Briefings describe the new move and how to
respond. A cue in the centre of the net leaves both corner targets visible.

## Moves and openings

- **Dive:** once the reaction delay has passed, project the already visible
  straight ball flight onto the keeper's interception line. Choose one bounded
  destination and stick to it. There is no mid-flight retargeting or guaranteed
  save. A shot beyond his physical reach can pass him.
- **Rush and slide:** from Professional onward, every third accepted shot in
  the attempt is a rush. Before it, show `RUSH INCOMING`, crouch and step eight
  units forward. After the delay, advance to Y = 150, 158 or 166 by tier and
  use a low, spread-leg block. Sideways body travel is 60% of dive travel, so
  the rush trades lateral coverage for an earlier interception. The counter
  includes goals and misses and restarts on a retry.
- **Mark:** Elite and World Class remember the previous resolved shot's side,
  gradually biasing their patrol by up to 16 or 24 units. `COVERING LEFT/RIGHT`
  exposes that tendency. They do not follow the aiming arrow or change their
  committed destination to chase a new target.
- **Taunt:** after an actual keeper save, get up, raise/wave the gloves and
  show `TRY AGAIN!`, `NOT THIS TIME!` or `MY BOX!` by keeper personality. A post,
  wide shot or defender block does not earn a keeper taunt. The gesture occupies
  the existing one-second miss feedback and does not add a delay of its own.
- **Save feedback:** report `DIVING SAVE!` or `SLIDING SAVE!` for those moves,
  reuse the preloaded glove sound, and roll the parried ball away during feedback.
  One resolved save consumes one chance, including a saved Fire Shot.

## Motion and collision

`KeeperController` owns the keeper's actual X/Y position, rotation and action.
`KeeperPose` reuses fourteen capsules for the torso, head, articulated arms,
gloves, legs and boots. A capsule is a line with rounded ends; circles have
coincident endpoints. The renderer draws these same endpoints and radii under
the pose's translation and rotation. Ball contact inverse-transforms the ball
and checks distance to these capsules. Shadows, hair and the shirt number are
decorative; there is no separate stationary box behind the diving keeper.

Reaction updates run with the existing physics substeps. Footwork brakes
gradually during the set instead of stopping instantly at the tap. Recovery eases the
rotation and limbs back to the ready pose; foot placement is smoothed. Joint
objects and paints are reused, and the finite cue labels are prepared before
play. This adds articulated drawing and collision work, so frame cost still
needs device profiling. It is a 2D arcade pose, not motion-captured animation.

Classic retains its prior keeper path, artwork and collision box. Challenge
targets, timers, Fire scoring, twelve stage positions and stored stars retain
their existing rules. New skills change shot difficulty and need retuning from
real playtest feedback. Pause/background pause freezes the controller through
the existing game update gate. Retry resets the keeper's action, pose, reaction,
shot counter, marking memory and parry state with the attempt.

## Local handoff

No Dart/Flutter analyzer, tests, builds, app runs or workflows were executed.
The branch workflow remains manual-only. Prepared cases in
`test/pro_keeper_test.dart` cover delayed observation, bounded commitment,
the third-shot rush, rotated glove collision, save-only taunts, reset of learned
marking and consistency across 60/120 Hz frame partitions. The existing widget
case for stage nine now also checks the Elite briefing. These are unexecuted
regression sources, not validation results.

For the owner's local playtest:

1. Stage three: try both a close shot and the far open corner. Check whether
   you can see the set, dive and actual glove/body contact before judging saves.
2. Stage five: play through three accepted shots. Confirm the rush warning and
   forward step are visible, then compare centre and corner attempts.
3. Stage seven: shoot repeatedly to one side, then switch. Check the covering
   cue and whether the opposite opening feels useful.
4. Watch a genuine keeper save, a defender block and a post hit. Only the keeper
   save should trigger the glove taunt. Retry immediately after failure.
5. Pause/background during a dive or slide and during save feedback. Resume
   should continue the same pose and shot; the stage clock should stay frozen
   through pause and result feedback.
6. Compare stage ten/twelve with the prior commit on the same phone, especially
   the first dive, glove contact, getting up and the third defender. Capture a
   trace with the existing optional markers if animation stutters.

Record attempts to clear, unclear saves, time spent waiting, and whether each
new move suggests a useful response. Include the device and Android APK
build/install/run outcome. Tune `KeeperSkill` values before making the timers
stricter if the combined challenge becomes frustrating.
