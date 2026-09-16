class_name ArenaBendMeter
extends Control

const UI = preload("res://scripts/ui_theme.gd")
var amount: float = 0.0
var clean: bool = false

func _init() -> void:
	custom_minimum_size = Vector2(96, 18)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_bend(value: float, knuckle_ready: bool) -> void:
	var clamped: float = clampf(value, -1.0, 1.0)
	if is_equal_approx(amount, clamped) and clean == knuckle_ready:
		return
	amount = clamped
	clean = knuckle_ready
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var half_width: float = maxf(0.0, size.x * 0.5 - 4.0)
	var tip: Vector2 = center + Vector2(amount * half_width, 0)
	draw_line(center - Vector2(half_width, 0), center + Vector2(half_width, 0), UI.OUTLINE, 3.0, true)
	draw_line(center - Vector2(0, 4), center + Vector2(0, 4), UI.MUTED, 1.0, true)
	draw_line(center, tip, UI.BLUE if clean else UI.LIME, 4.0, true)
	draw_circle(tip, 3.5, UI.BLUE if clean else UI.TEXT)
