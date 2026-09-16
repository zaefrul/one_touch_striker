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
timing ring follows the ball's projected position.

## Screen hierarchy

- **Cup map:** three rival cards (kit, stars, You W · Keeper L, lock) plus the
  Cup Ball reward card and one primary **Play next rival**.
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
- **Help:** a centred sheet with three illustrated technique rows and Back to play.

Pause/help shades block pitch interaction and disable the underlying toolbar.
Results keep Pause, Help and Sound reachable, while shot input stays blocked by
the result state and HUD input guard. Both ready and in-flight resume paths close
the sheet. Button focus styles support keyboard review without stealing shots
from touch.

## Review status

Source review and visual inspection of the static SVG only. No Godot import,
parser, analyzer, test, app run, build/export or workflow was performed. The SVG
uses approximate text metrics and must not be used to claim actual device fit.
Use [PLAYTEST.md](../PLAYTEST.md) for safe areas, wrapping, scrolling, keyboard
focus, touch cancellation and pause/resume checks on real devices.

Godot references used for this implementation:

- [Container layout](https://docs.godotengine.org/en/4.4/tutorials/ui/gui_containers.html)
- [Theme resources](https://docs.godotengine.org/en/4.4/classes/class_theme.html)
- [Display safe area](https://docs.godotengine.org/en/4.4/classes/class_displayserver.html#class-displayserver-method-get-display-safe-area)
- [Viewport screen transform](https://docs.godotengine.org/en/4.4/classes/class_viewport.html#class-viewport-method-get-screen-transform)
