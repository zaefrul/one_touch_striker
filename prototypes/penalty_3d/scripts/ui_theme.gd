extends RefCounted

# Floodlit Night tokens, matching lib/ui/theme.dart.
const INK: Color = Color("#0a1226")
const SURFACE: Color = Color("#111d3a")
const RAISED: Color = Color("#182848")
const OUTLINE: Color = Color("#2a3d66")
const TEXT: Color = Color("#f4f1e8")
const MUTED: Color = Color("#a8b3cc")
const FAINT: Color = Color("#6b7898")
const GOLD: Color = Color("#ffb340")
const ON_GOLD: Color = Color("#1a1200")
const BLUE: Color = Color("#5fd4ff")
const CORAL: Color = Color("#ff6b6b")
const EDGE: int = 16
const GAP: int = 12
const TOUCH: int = 48
const MAX_WIDTH: float = 440.0

static func card(background: Color = SURFACE, padding: int = 16) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = OUTLINE
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

static func make_theme() -> Theme:
	var result: Theme = Theme.new()
	result.default_font_size = 14
	result.set_color("font_color", "Label", TEXT)
	result.set_constant("separation", "VBoxContainer", GAP)
	result.set_constant("separation", "HBoxContainer", GAP)
	result.set_stylebox("panel", "PanelContainer", card())
	result.set_font_size("font_size", "Button", 15)
	result.set_constant("h_separation", "Button", 8)
	result.set_constant("icon_max_width", "Button", 24)
	_button_colors(result, "Button", TEXT)
	result.set_color("font_disabled_color", "Button", MUTED)
	result.set_color("icon_disabled_color", "Button", MUTED)
	result.set_stylebox("normal", "Button", card(RAISED, 12))
	result.set_stylebox("hover", "Button", card(Color("#243860"), 12))
	result.set_stylebox("pressed", "Button", card(Color("#2d4570"), 12))
	result.set_stylebox("hover_pressed", "Button", card(Color("#35507c"), 12))
	result.set_stylebox("disabled", "Button", card(SURFACE, 12))
	var focus: StyleBoxFlat = card(Color.TRANSPARENT, 0)
	focus.border_color = BLUE
	focus.set_border_width_all(2)
	result.set_stylebox("focus", "Button", focus)

	result.set_type_variation("ArenaPrimary", "Button")
	_button_colors(result, "ArenaPrimary", ON_GOLD)
	result.set_font_size("font_size", "ArenaPrimary", 17)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var color: Color = GOLD
		if state == "hover":
			color = Color("#ffc45c")
		elif state == "pressed" or state == "hover_pressed":
			color = Color("#e69a26")
		var style: StyleBoxFlat = card(color, 14)
		style.border_color = color
		result.set_stylebox(state, "ArenaPrimary", style)

	result.set_type_variation("ArenaQuiet", "Button")
	result.set_stylebox("normal", "ArenaQuiet", card(SURFACE, 12))
	return result

static func _button_colors(result: Theme, type_name: String, color: Color) -> void:
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		result.set_color(state, type_name, color)
