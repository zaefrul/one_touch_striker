class_name ArenaStarRow
extends Control

const UI = preload("res://scripts/ui_theme.gd")

var stars: int = 0
var show_thresholds: bool = false

func _init() -> void:
	custom_minimum_size = Vector2(168, 36)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_stars(value: int, thresholds: bool = false) -> void:
	stars = clampi(value, 0, 3)
	show_thresholds = thresholds
	custom_minimum_size.y = 58 if thresholds else 36
	queue_redraw()

func _draw() -> void:
	var gap: float = 44.0
	var origin: float = size.x * 0.5 - gap
	var cy: float = 16.0 if show_thresholds else size.y * 0.5
	for i in range(3):
		var center: Vector2 = Vector2(origin + i * gap, cy)
		_star(center, 11.0, i < stars)
		if show_thresholds:
			var caption: String = ["3", "4", "5"][i]
			draw_string(
				ThemeDB.fallback_font,
				center + Vector2(-5, 26),
				caption,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				12,
				UI.MUTED if i >= stars else UI.GOLD
			)

func _star(center: Vector2, radius: float, filled: bool) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(10):
		var angle: float = -PI * 0.5 + float(i) * PI / 5.0
		var r: float = radius if i % 2 == 0 else radius * 0.42
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	if filled:
		draw_colored_polygon(points, UI.GOLD)
	else:
		points.append(points[0])
		draw_polyline(points, UI.FAINT, 1.6, true)
