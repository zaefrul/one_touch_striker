# Floodlit Night design tokens

Menus, HUD and the Flame pitch all read from `lib/ui/theme.dart`.

## Palette

| Token | Hex | Use |
| --- | --- | --- |
| ink | `#0a1226` | App background, scrim, letterbox |
| surface | `#111d3a` | Sheets and recessed panels |
| raised | `#182848` | Cards, tiles, ad boards |
| outline | `#2a3d66` | Borders and empty meters |
| text | `#f4f1e8` | Primary copy |
| muted / faint | `#a8b3cc` / `#6b7898` | Secondary copy and disabled marks |
| gold | `#ffb340` | Primary actions, Fire, goals, stars |
| cyan | `#5fd4ff` | Timing ring, knuckle, practice |
| coral | `#ff6b6b` | Misses, last chance, urgent clock |
| grass / stripe | `#1f8a4c` / `#23985a` | Default pitch |

## Type

- Display: Barlow Condensed (600 / 700 / 900) for titles, scores, eyebrows and buttons
- Body: Barlow (400 / 500 / 600) for copy and captions
- Scale: eyebrow 11, caption 12, body 14, button 16, title 24, headline 34, score 64–80

Fonts are OFL-licensed files in `assets/fonts/`.

## Layout

16 logical units of edge inset, 12 between groups, 8 in action stacks. Cards 16 radius, buttons 14. Primary actions at least 56 high. Overlay scrims are a vertical ink gradient, not a backdrop filter.
