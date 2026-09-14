class_name PenaltyHUD
extends Control

signal pause_requested
signal help_requested
signal resume_requested
signal next_requested
signal restart_requested
signal sound_changed(enabled: bool)

const Shot = preload("res://scripts/shot_math.gd")
const LIME: Color = Color("#d9ff6a")
const BLUE: Color = Color("#7edfff")
const WHITE: Color = Color("#efffe2")
const RED: Color = Color("#ff8581")

var holding: bool = false
var curve_committed: bool = false
var ring_phase: float = 0.0
var spin: float = 0.0
var ball_screen: Vector2 = Vector2.ZERO
var outcomes: Array[String] = []
var _title: Label
var _objective: Label
var _progress: Label
var _prompt: Label
var _hint: Label
var _pause: Button
var _help: Button
var _sound: Button
var _shade: ColorRect
var _panel: PanelContainer
var _sheet_title: Label
var _sheet_detail: Label
var _primary: Button
var _secondary: Button
var _sheet_mode: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title = _label("3D ARENA", 15)
	_title.modulate = LIME
	_objective = _label("SCORE 3 GOALS", 25)
	_progress = _label("5 BALLS", 14)
	_prompt = _label("TOUCH TO LOCK", 19)
	_hint = _label("Drag to bend", 13)
	_pause = _button("II")
	_pause.tooltip_text = "Pause"
	_pause.pressed.connect(func() -> void: pause_requested.emit())
	_help = _button("?")
	_help.tooltip_text = "Controls"
	_help.pressed.connect(func() -> void: help_requested.emit())
	_sound = _button("SFX")
	_sound.tooltip_text = "Sound"
	_sound.toggle_mode = true
	_sound.button_pressed = true
	_sound.toggled.connect(func(enabled: bool) -> void: sound_changed.emit(enabled))
	_build_sheet()
	resized.connect(_layout)
	_layout()

func _label(text_value: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _button(text_value: String) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(44, 44)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_stylebox_override("normal", _style(Color("#143b3b")))
	button.add_theme_stylebox_override("hover", _style(Color("#245453")))
	button.add_theme_stylebox_override("pressed", _style(Color("#436c49")))
	add_child(button)
	return button

func _build_sheet() -> void:
	_shade = ColorRect.new()
	_shade.color = Color(0.015, 0.05, 0.07, 0.86)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _style(Color("#0b302f")))
	_shade.add_child(_panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	_panel.add_child(column)
	_sheet_title = Label.new()
	_sheet_title.add_theme_font_size_override("font_size", 27)
	_sheet_title.add_theme_color_override("font_color", LIME)
	_sheet_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_sheet_title)
	_sheet_detail = Label.new()
	_sheet_detail.add_theme_font_size_override("font_size", 16)
	_sheet_detail.add_theme_color_override("font_color", WHITE)
	_sheet_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sheet_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sheet_detail.custom_minimum_size = Vector2(260, 56)
	column.add_child(_sheet_detail)
	_primary = Button.new()
	_primary.custom_minimum_size.y = 54
	_primary.add_theme_font_size_override("font_size", 17)
	_primary.add_theme_color_override("font_color", Color("#102d27"))
	_primary.add_theme_color_override("font_hover_color", Color("#102d27"))
	_primary.add_theme_color_override("font_pressed_color", Color("#102d27"))
	_primary.add_theme_stylebox_override("normal", _style(LIME))
	_primary.add_theme_stylebox_override("hover", _style(Color("#ecffb2")))
	_primary.add_theme_stylebox_override("pressed", _style(Color("#accb57")))
	_primary.focus_mode = Control.FOCUS_NONE
	_primary.pressed.connect(_primary_pressed)
	column.add_child(_primary)
	_secondary = Button.new()
	_secondary.text = "RESTART SET"
	_secondary.custom_minimum_size.y = 44
	_secondary.add_theme_font_size_override("font_size", 14)
	_secondary.add_theme_color_override("font_color", WHITE)
	_secondary.add_theme_stylebox_override("normal", _style(Color("#194441")))
	_secondary.focus_mode = Control.FOCUS_NONE
	_secondary.pressed.connect(func() -> void: restart_requested.emit())
	column.add_child(_secondary)
	_shade.hide()

func _layout() -> void:
	if _title == null:
		return
	var width: float = size.x
	_title.position = Vector2(24, 38)
	_pause.position = Vector2(width - 168, 28)
	_help.position = Vector2(width - 118, 28)
	_sound.position = Vector2(width - 68, 28)
	_objective.position = Vector2(24, 90)
	_objective.size = Vector2(width - 48, 38)
	_progress.position = Vector2(24, 130)
	_progress.size = Vector2(width - 48, 28)
	_prompt.position = Vector2(20, size.y - 122)
	_prompt.size = Vector2(width - 40, 34)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(20, size.y - 66)
	_hint.size = Vector2(width - 40, 28)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.position = Vector2(24, maxf(185.0, size.y - 338.0) if _sheet_mode == "result" else maxf(185.0, size.y * 0.32))
	_panel.size = Vector2(width - 48, 0)
	queue_redraw()

func in_play_area(point: Vector2) -> bool:
	return not _shade.visible and point.x >= 12 and point.x <= size.x - 12 \
		and point.y >= 185 and point.y <= size.y - 38

func set_score(results: Array[String]) -> void:
	outcomes = results.duplicate()
	var goals: int = outcomes.count("GOAL")
	_progress.text = "%d / 3 GOALS  ·  %d / 5 BALLS" % [goals, outcomes.size()]
	queue_redraw()

func set_sound(enabled: bool) -> void:
	_sound.set_pressed_no_signal(enabled)
	_sound.text = "SFX" if enabled else "OFF"

func show_ready() -> void:
	holding = false
	_shade.hide()
	_prompt.show()
	_hint.show()
	_prompt.text = "TOUCH TO LOCK"
	_hint.text = "Drag to bend" if outcomes.is_empty() else ""
	queue_redraw()

func show_hold(phase: float, amount: float, committed: bool, clean: bool, at: Vector2) -> void:
	holding = true
	ring_phase = phase
	spin = amount
	curve_committed = committed
	ball_screen = at
	_prompt.text = "KNUCKLE · RELEASE" if clean else Shot.label_for(spin, false)
	_hint.text = "RELEASE TO SHOOT"
	queue_redraw()

func show_flight() -> void:
	holding = false
	_prompt.hide()
	_hint.hide()
	queue_redraw()

func show_result(outcome: String, technique: String, final_ball: bool) -> void:
	holding = false
	_prompt.hide()
	_hint.hide()
	_sheet_mode = "result"
	_shade.color = Color(0.015, 0.05, 0.07, 0.12)
	_sheet_title.text = outcome + "!"
	var goals: int = outcomes.count("GOAL")
	_sheet_detail.text = technique + " · " + outcome.capitalize()
	_primary.text = "NEXT BALL"
	_secondary.show()
	if final_ball:
		_sheet_title.text = "KEEPER BEATEN" if goals >= 3 else "REMATCH?"
		_sheet_detail.text += "\n%d / 5 GOALS" % goals
		if goals < 3:
			var missing: int = 3 - goals
			_sheet_detail.text += "\n%d more %s to win" % [missing, "goal" if missing == 1 else "goals"]
		_primary.text = "PLAY AGAIN"
		_secondary.hide()
	_shade.show()
	_layout()
	queue_redraw()

func show_menu(help_page: bool) -> void:
	holding = false
	_sheet_mode = "menu"
	_shade.color = Color(0.015, 0.05, 0.07, 0.86)
	_sheet_title.text = "MAKE YOUR SHOT" if help_page else "PAUSED"
	_sheet_detail.text = "Touch → lock aim\nDrag sideways → curve\nHold still + blue zone → knuckle" if help_page else "Ready when you are."
	_primary.text = "BACK TO PLAY" if help_page else "RESUME"
	_secondary.show()
	_shade.show()
	_layout()
	queue_redraw()

func _primary_pressed() -> void:
	if _sheet_mode == "result":
		next_requested.emit()
	else:
		resume_requested.emit()

func _draw() -> void:
	for i in range(5):
		var color: Color = Color("#44665b")
		if i < outcomes.size():
			color = LIME if outcomes[i] == "GOAL" else RED
		draw_circle(Vector2(30 + i * 22, 170), 6.0, color)
	if not holding:
		return
	var radius: float = 31.0
	draw_arc(ball_screen, radius, -PI * 0.5, PI * 1.5, 64, Color("#345d60"), 4.0, true)
	if not curve_committed:
		draw_arc(ball_screen, radius, -PI * 0.5 + TAU * Shot.SWEET_START, -PI * 0.5 + TAU * Shot.SWEET_END, 24, BLUE, 6.0, true)
	var marker: Vector2 = ball_screen + Vector2.UP.rotated(TAU * ring_phase) * radius
	draw_circle(marker, 5.0, WHITE)
	var meter: Vector2 = Vector2(size.x * 0.5, size.y - 82)
	draw_line(meter - Vector2(66, 0), meter + Vector2(66, 0), Color("#54766c"), 3.0, true)
	draw_line(meter, meter + Vector2(spin * 66.0, 0), LIME, 5.0, true)
	draw_circle(meter + Vector2(spin * 66.0, 0), 4.0, WHITE)
