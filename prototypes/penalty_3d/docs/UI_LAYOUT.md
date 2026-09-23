# Arena UI layout

This pass applies to the standalone Godot 3D prototype on `prototype/penalty-3d`.
The authored [layout reference](ui-layout.svg) shows the intended hierarchy and
spacing. It is not a running-game capture. The arena behind the UI is schematic;
the existing 3D scene and camera are retained.

## Layout rules

| Element | Rule |
| --- | --- |
| Outer margin | 16 logical units inside the device safe area |
| Content width | Centred; at most 440 logical units |
| Spacing | 4 for closely related text; 8 for action stacks; 12 between groups; 16 inside cards; 20 inside sheets |
| Corners | 16 on all cards and buttons |
| Typography | 12 captions; 14 body; 18 cue; 20 arena title; 22 objective; 24 goal count; 28 sheet title |
| Touch areas | At least 48 x 48; primary actions at least 52 high |
| Colour | Floodlit Night: navy surfaces, warm text, gold actions, cyan timing, coral misses |
| Shot history | Five circles; check/cross shapes supplement colour |
| Small windows | Sheet content scrolls; primary and secondary actions stay visible |

`ui_theme.gd` owns shared styling. The HUD uses MarginContainer, HBoxContainer,
VBoxContainer and PanelContainer nodes instead of individual fixed coordinates.
The shot track and bend meter draw within their own control bounds. Only the
timing ring and the chip lesson cue follow the ball's projected position.

## Screen hierarchy

- **Cup map:** three rival cards (kit, stars, You W · Keeper L, lock) plus the
  Cup Ball reward card, the locked/unlocked Rush Showdown card and one primary
  **Play next rival** (changes to **Beat the Rush** after cup completion).
- **Rival intro:** name, Score 3 goals, one weakness line, a three-star row
  labelled 3 · 4 · 5, **Start**, and a quiet Cup link.
- **Ready:** rival name and toolbar; objective and remaining balls; open pitch;
  one bottom cue. Extra drag guidance appears on the first ball only.
- **Holding:** replace the ready cue with a release prompt and technique/meter.
  The ring continues rotating for the entire hold.
- **In flight:** remove the bottom cue. The objective stays in place.
- **Shot result:** a bottom sheet with outcome, technique and Next ball. Restart
  is available from Pause rather than competing with Next ball after every shot.
- **Set result:** stars, the next target line, and one primary action (Rematch,
  Next rival, or Equip Cup Ball). Rematch is a quiet link after a clear. Cup is
  always a quiet link.
- **Pause:** a centred sheet with round status, controls/audio, Resume and Restart.
- **Help:** three illustrated technique rows; a fourth chip row appears after
  cup completion. **Back to play** stays outside the scroll area.
- **Chip lesson:** an editable central starting aim, an animated upward drag cue and **Chip the rush**.
  The result offers Try again or Start showdown; Skip lesson is available.
- **Rush result:** earned stars, rush-chip count and the next mastery/star target;
  Rematch, Practice chip and Cup. The new badge has its own equip toggle on the map.

Pause/help shades block pitch interaction and disable the underlying toolbar.
Results keep Pause, Help and Sound reachable, while shot input stays blocked by
the result state and HUD input guard. Both ready and in-flight resume paths close
the sheet. Button focus styles support keyboard review without stealing shots
from touch. Raw phone touches activate on release through `touch_tap.gd`;
canceled touches, scrolling and large drags cannot activate a button. Mouse
emulation stays disabled. Small star rows scale spacing to their available width.

## Review status

The original static SVG predates the Rush Showdown card and lesson. This update
was source-reviewed only; its live layout still needs a phone check. No Godot import,
parser, analyzer, test, app run, build/export or workflow was performed. The SVG
uses approximate text metrics and must not be used to claim actual device fit.
Use [PLAYTEST.md](../PLAYTEST.md) for safe areas, wrapping, scrolling, keyboard
focus, touch cancellation and pause/resume checks on real devices.

Godot references used for this implementation:

- [Container layout](https://docs.godotengine.org/en/4.4/tutorials/ui/gui_containers.html)
- [Theme resources](https://docs.godotengine.org/en/4.4/classes/class_theme.html)
- [Display safe area](https://docs.godotengine.org/en/4.4/classes/class_displayserver.html#class-displayserver-method-get-display-safe-area)
- [Viewport screen transform](https://docs.godotengine.org/en/4.4/classes/class_viewport.html#class-viewport-method-get-screen-transform)


## Champion extension

The cup sheet adds a Captain card with best/record and **Practice · Full preview**.
After Cup completion, **Challenge The Captain** becomes the primary action;
Beat the Rush remains available in its own card. Both cards scroll with the map.
Champion gameplay retains the same objective layout, now with a four-goal target.
The brief intro explains memory, blue rush arrows and the shortened trajectory.

Aim uses a draggable white goal reticle; the lower pitch owns shot preparation.
Champion hides the bend-adjusted endpoint. Practice and existing modes retain it.
The help sheet explains the two regions and optional second-finger adjustment.

During a highlight, objective/cue cards disappear and a small **HIGHLIGHT / Skip
replay** bar sits inside the usual safe margins. Pause and sound stay accessible.
Leaving playback restores the home camera and the already-scored result sheet.
These layout changes require the runtime checks in PLAYTEST; no new screenshot
or visual-validation claim accompanies this source handoff.
