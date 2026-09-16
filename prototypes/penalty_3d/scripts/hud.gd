class_name PenaltyHUD
extends Control

signal pause_requested
signal help_requested
signal resume_requested
signal next_requested
signal restart_requested
signal sound_changed(enabled: bool)
signal start_requested
signal rematch_requested
signal next_rival_requested
signal cup_requested
signal play_next_requested
signal equip_requested
signal rival_chosen(index: int)
signal reward_toggled

const Shot = preload("res://scripts/shot_math.gd")
const UI = preload("res://scripts/ui_theme.gd")
const Track = preload("res://scripts/shot_track.gd")
const Meter = preload("res://scripts/bend_meter.gd")
const Stars = preload("res://scripts/star_row.gd")
const ICON_PAUSE = preload("res://ui/icons/pause.svg")
const ICON_HELP = preload("res://ui/icons/help.svg")
const ICON_SOUND = preload("res://ui/icons/sound_on.svg")
const ICON_MUTED = preload("res://ui/icons/sound_off.svg")
const ICON_AIM = preload("res://ui/icons/aim.svg")
const ICON_CURVE = preload("res://ui/icons/curve.svg")
const ICON_KNUCKLE = preload("res://ui/icons/knuckle.svg")
const ICON_GOAL = preload("res://ui/icons/goal.svg")
const ICON_MISS = preload("res://ui/icons/miss.svg")
const ICON_TROPHY = preload("res://ui/icons/trophy.svg")
const RESULT_TITLES: Dictionary = {
	"GOAL": "Goal!",
	"SAVED": "Saved",
	"POST": "Off the post",
	"WIDE": "Wide",
	"OVER": "Over the bar",
}

var holding: bool = false
var curve_committed: bool = false
var ring_phase: float = 0.0
var ball_screen: Vector2 = Vector2.ZERO
var outcomes: Array[String] = []
var _safe_rect: Rect2
var _hud_margin: MarginContainer
var _hud_column: VBoxContainer
var _wordmark: Label
var _arena_title: Label
var _objective_card: PanelContainer
var _objective_eyebrow: Label
var _goal_count: Label
var _ball_count: Label
var _track: ArenaShotTrack
var _cue_panel: PanelContainer
var _cue_row: HBoxContainer
var _prompt: Label
var _hint: Label
var _meter: ArenaBendMeter
var _pause: Button
var _help: Button
var _sound: Button
var _shade: ColorRect
var _sheet_margin: MarginContainer
var _sheet_column: VBoxContainer
var _bottom_gap: Control
var _panel: PanelContainer
var _sheet_scroll: ScrollContainer
var _sheet_body: VBoxContainer
var _sheet_eyebrow: Label
var _sheet_title: Label
var _sheet_icon: TextureRect
var _sheet_detail: Label
var _sheet_note: Label
var _stars: ArenaStarRow
var _cup_block: VBoxContainer
var _rival_rows: Array[Dictionary] = []
var _reward_card: PanelContainer
var _reward_title: Label
var _reward_detail: Label
var _reward_lock: Label
var _help_rows: VBoxContainer
var _pause_tools: HBoxContainer
var _menu_sound: Button
var _footer: VBoxContainer
var _primary: Button
var _secondary: Button
var _quiet: Button
var _taunt: PanelContainer
var _taunt_label: Label
var _taunt_until: int = 0
var _sheet_mode: String = ""
var _primary_action: String = ""
var _fit_pending: bool = false
var _knuckle_hint: bool = false
var _resume_mode: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UI.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_margin = _full_margin(self)
	_hud_column = _centered_column(_hud_margin)
	_build_header()
	_build_objective()
	_spacer(_hud_column, false)
	_build_cue()
	_build_sheet()
	_build_taunt()
	resized.connect(_layout)
	_layout()
	set_score([])
	show_ready()

func _full_margin(parent: Control) -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return margin

func _centered_column(parent: Control) -> VBoxContainer:
	var row: HBoxContainer = _row(parent, 0)
	_spacer(row, true)
	var column: VBoxContainer = _column(row, UI.GAP)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_spacer(row, true)
	return column

func _column(parent: Node, gap: int = 12) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", gap)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(column)
	return column

func _row(parent: Node, gap: int = 12) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", gap)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	return row

func _spacer(parent: Node, horizontal: bool) -> Control:
	var spacer: Control = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if horizontal:
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)
	return spacer

func _label(parent: Node, text_value: String, font_size: int, color: Color = UI.TEXT, wrap: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, text_value: String, variant: String = "ArenaQuiet") -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.theme_type_variation = variant
	button.custom_minimum_size = Vector2(UI.TOUCH, UI.TOUCH)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	parent.add_child(button)
	return button

func _icon_button(parent: Node, texture: Texture2D, description: String) -> Button:
	var button: Button = _button(parent, "")
	button.icon = texture
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.tooltip_text = description
	return button

func _icon(parent: Node, texture: Texture2D, color: Color = UI.GOLD) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate = color
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon

func _build_header() -> void:
	var header: HBoxContainer = _row(_hud_column)
	header.custom_minimum_size.y = UI.TOUCH
	var brand: VBoxContainer = _column(header, 2)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_wordmark = _label(brand, "ONE-TOUCH", 12, UI.GOLD)
	_wordmark.clip_text = true
	_arena_title = _label(brand, "Rival Cup", 20)
	_arena_title.clip_text = true
	_arena_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var toolbar: HBoxContainer = _row(header, 8)
	_pause = _icon_button(toolbar, ICON_PAUSE, "Pause")
	_pause.pressed.connect(func() -> void: pause_requested.emit())
	_help = _icon_button(toolbar, ICON_HELP, "How to play")
	_help.pressed.connect(func() -> void: help_requested.emit())
	_sound = _icon_button(toolbar, ICON_SOUND, "Mute sound")
	_sound.toggle_mode = true
	_sound.set_pressed_no_signal(true)
	_sound.toggled.connect(func(enabled: bool) -> void: sound_changed.emit(enabled))

func _build_objective() -> void:
	_objective_card = PanelContainer.new()
	_objective_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_column.add_child(_objective_card)
	var column: VBoxContainer = _column(_objective_card)
	_objective_eyebrow = _label(column, "THE SWEEPER", 12, UI.GOLD)
	var heading: HBoxContainer = _row(column)
	var objective: Label = _label(heading, "Score 3 goals", 22, UI.TEXT, true)
	objective.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objective.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_goal_count = _label(heading, "0 / 3", 24, UI.GOLD)
	var progress: HBoxContainer = _row(column)
	_track = Track.new()
	progress.add_child(_track)
	_ball_count = _label(progress, "5 BALLS", 12, UI.MUTED)
	_ball_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ball_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ball_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _build_cue() -> void:
	_cue_panel = PanelContainer.new()
	_cue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cue_panel.add_theme_stylebox_override("panel", UI.card(UI.SURFACE, 12))
	_cue_panel.custom_minimum_size.y = 72
	_hud_column.add_child(_cue_panel)
	var column: VBoxContainer = _column(_cue_panel, 4)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt = _label(column, "Touch to lock", 18)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cue_row = _row(column)
	_cue_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hint = _label(_cue_row, "Drag to bend", 12, UI.MUTED)
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_meter = Meter.new()
	_cue_row.add_child(_meter)
	_meter.hide()

func _build_sheet() -> void:
	_shade = ColorRect.new()
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shade)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sheet_margin = _full_margin(_shade)
	_sheet_column = _centered_column(_sheet_margin)
	_sheet_column.add_theme_constant_override("separation", 0)
	_spacer(_sheet_column, false)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UI.card(UI.SURFACE, 20))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet_column.add_child(_panel)
	_bottom_gap = _spacer(_sheet_column, false)
	var inner: VBoxContainer = _column(_panel, 16)
	_sheet_scroll = ScrollContainer.new()
	_sheet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sheet_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	inner.add_child(_sheet_scroll)
	_sheet_body = _column(_sheet_scroll, 16)
	_sheet_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var heading: VBoxContainer = _column(_sheet_body, 6)
	_sheet_eyebrow = _label(heading, "", 12, UI.MUTED)
	var title_row: HBoxContainer = _row(heading)
	_sheet_title = _label(title_row, "", 28, UI.TEXT, true)
	_sheet_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet_icon = _icon(title_row, ICON_GOAL)
	_sheet_detail = _label(heading, "", 14, UI.MUTED, true)
	_sheet_note = _label(_sheet_body, "", 14, UI.MUTED, true)
	_stars = Stars.new()
	_sheet_body.add_child(_stars)
	_build_cup_block()
	_build_help_rows()
	_pause_tools = _row(_sheet_body)
	var controls: Button = _button(_pause_tools, "Controls")
	controls.icon = ICON_HELP
	controls.clip_text = true
	controls.add_theme_constant_override("icon_max_width", 20)
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.pressed.connect(func() -> void: help_requested.emit())
	_menu_sound = _button(_pause_tools, "Sound on")
	_menu_sound.icon = ICON_SOUND
	_menu_sound.clip_text = true
	_menu_sound.add_theme_constant_override("icon_max_width", 20)
	_menu_sound.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_sound.toggle_mode = true
	_menu_sound.set_pressed_no_signal(true)
	_menu_sound.toggled.connect(func(enabled: bool) -> void: sound_changed.emit(enabled))
	_footer = _column(inner, 8)
	_primary = _button(_footer, "", "ArenaPrimary")
	_primary.custom_minimum_size.y = 52
	_primary.pressed.connect(_primary_pressed)
	_secondary = _button(_footer, "Restart set")
	_secondary.pressed.connect(_secondary_pressed)
	_quiet = _button(_footer, "Cup")
	_quiet.pressed.connect(func() -> void: cup_requested.emit())
	_sheet_body.resized.connect(_request_sheet_fit)
	_sheet_body.minimum_size_changed.connect(_request_sheet_fit)
	_shade.hide()

func _build_cup_block() -> void:
	_cup_block = _column(_sheet_body, 10)
	for i in range(3):
		var card: PanelContainer = PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.card(UI.RAISED, 12))
		_cup_block.add_child(card)
		var row: HBoxContainer = _row(card, 10)
		var swatch: ColorRect = ColorRect.new()
		swatch.custom_minimum_size = Vector2(28, 28)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		var words: VBoxContainer = _column(row, 2)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label: Label = _label(words, "", 17)
		var record: Label = _label(words, "", 12, UI.MUTED)
		var side: VBoxContainer = _column(row, 4)
		side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var star_row: ArenaStarRow = Stars.new()
		star_row.custom_minimum_size = Vector2(96, 28)
		side.add_child(star_row)
		var lock: Label = _label(side, "", 12, UI.MUTED)
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var index: int = i
		card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				rival_chosen.emit(index)
		)
		_rival_rows.append({
			"card": card,
			"swatch": swatch,
			"name": name_label,
			"record": record,
			"stars": star_row,
			"lock": lock,
		})
	_reward_card = PanelContainer.new()
	_reward_card.add_theme_stylebox_override("panel", UI.card(UI.RAISED, 12))
	_cup_block.add_child(_reward_card)
	var reward_row: HBoxContainer = _row(_reward_card, 10)
	var words: VBoxContainer = _column(reward_row, 2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reward_title = _label(words, "CUP BALL", 12, UI.GOLD)
	_reward_detail = _label(words, "Win all three rivals", 14, UI.MUTED, true)
	_reward_lock = _label(reward_row, "🔒", 22, UI.GOLD)
	_reward_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_reward_card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			reward_toggled.emit()
	)
	_cup_block.hide()

func _build_help_rows() -> void:
	_help_rows = _column(_sheet_body, 20)
	_help_row(ICON_AIM, "Aim & shoot", "Touch to lock. Release to shoot.")
	_help_row(ICON_CURVE, "Curve & banana", "Drag sideways. More drag, more bend.")
	_help_row(ICON_KNUCKLE, "Knuckle", "Hold still. Release in blue.")
	_label(_help_rows, "The ring keeps looping while you hold.", 12, UI.MUTED, true)

func _help_row(texture: Texture2D, heading: String, detail: String) -> void:
	var row: HBoxContainer = _row(_help_rows)
	_icon(row, texture)
	var words: VBoxContainer = _column(row, 4)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(words, heading, 17, UI.TEXT, true)
	_label(words, detail, 14, UI.MUTED, true)

func _build_taunt() -> void:
	_taunt = PanelContainer.new()
	_taunt.add_theme_stylebox_override("panel", UI.card(UI.RAISED, 8))
	_taunt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_taunt)
	_taunt_label = _label(_taunt, "", 13, UI.TEXT)
	_taunt.hide()

func _layout() -> void:
	if _sheet_column == null:
		return
	_safe_rect = Rect2(Vector2.ZERO, size)
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		var display_safe: Rect2i = DisplayServer.get_display_safe_area()
		if display_safe.has_area():
			var from_screen: Transform2D = get_viewport().get_screen_transform().affine_inverse()
			var top_left: Vector2 = from_screen * Vector2(display_safe.position)
			var bottom_right: Vector2 = from_screen * Vector2(display_safe.end)
			var clipped: Rect2 = _safe_rect.intersection(Rect2(top_left, bottom_right - top_left))
			if clipped.has_area():
				_safe_rect = clipped
	for margin in [_hud_margin, _sheet_margin]:
		margin.add_theme_constant_override("margin_left", int(ceil(_safe_rect.position.x)) + UI.EDGE)
		margin.add_theme_constant_override("margin_top", int(ceil(_safe_rect.position.y)) + UI.EDGE)
		margin.add_theme_constant_override("margin_right", int(ceil(size.x - _safe_rect.end.x)) + UI.EDGE)
		margin.add_theme_constant_override("margin_bottom", int(ceil(size.y - _safe_rect.end.y)) + UI.EDGE)
	var width: float = minf(UI.MAX_WIDTH, maxf(0.0, _safe_rect.size.x - UI.EDGE * 2))
	_hud_column.custom_minimum_size.x = width
	_sheet_column.custom_minimum_size.x = width
	_request_sheet_fit()
	queue_redraw()

func _request_sheet_fit() -> void:
	if not _fit_pending:
		_fit_pending = true
		_fit_sheet.call_deferred()

func _fit_sheet() -> void:
	_fit_pending = false
	if not _shade.visible:
		return
	var available: float = _safe_rect.size.y - UI.EDGE * 2 - 40.0 - 16.0
	available -= _footer.get_combined_minimum_size().y
	var content_height: float = _sheet_body.get_combined_minimum_size().y
	_sheet_scroll.custom_minimum_size.y = minf(content_height, maxf(0.0, available))

func in_play_area(point: Vector2) -> bool:
	if _shade.visible or not _safe_rect.grow(-8.0).has_point(point):
		return false
	return point.y >= _objective_card.get_global_rect().end.y + UI.GAP

func set_score(results: Array[String]) -> void:
	outcomes = results.duplicate()
	_goal_count.text = "%d / 3" % outcomes.count("GOAL")
	var left: int = maxi(0, 5 - outcomes.size())
	_ball_count.text = "SET COMPLETE" if left == 0 else "%d %s" % [left, "BALL LEFT" if left == 1 else "BALLS LEFT"]
	_track.set_outcomes(outcomes)
	if _cue_panel.visible and not holding:
		_cue_row.visible = outcomes.is_empty()

func set_rival(title: String) -> void:
	_arena_title.text = title
	_objective_eyebrow.text = title.to_upper()

func set_play_hud(visible_play: bool) -> void:
	_objective_card.visible = visible_play
	_cue_panel.visible = visible_play
	_pause.visible = visible_play

func set_tension(level: int) -> void:
	_track.set_pulse(0.0 if level <= 0 else (1.2 if level == 1 else 2.8))
	_goal_count.modulate = Color(1.15, 1.08, 0.9) if level >= 1 else Color.WHITE

func set_sound(enabled: bool) -> void:
	_sound.set_pressed_no_signal(enabled)
	_sound.icon = ICON_SOUND if enabled else ICON_MUTED
	_sound.tooltip_text = "Mute sound" if enabled else "Enable sound"
	_menu_sound.set_pressed_no_signal(enabled)
	_menu_sound.icon = _sound.icon
	_menu_sound.text = "Sound on" if enabled else "Sound off"

func show_ready() -> void:
	holding = false
	_close_sheet()
	_cue_panel.show()
	_prompt.text = "Touch to lock"
	_hint.text = "Drag to bend"
	_hint.add_theme_color_override("font_color", UI.MUTED)
	_knuckle_hint = false
	_cue_row.visible = outcomes.is_empty()
	_meter.hide()
	queue_redraw()

func show_hold(phase: float, amount: float, committed: bool, clean: bool, at: Vector2) -> void:
	if not holding:
		_cue_panel.show()
		_cue_row.show()
		_meter.show()
		_prompt.text = "Release to shoot"
	holding = true
	ring_phase = phase
	curve_committed = committed
	ball_screen = at
	_hint.text = "Knuckle ready" if clean else Shot.label_for(amount, false).capitalize()
	if clean != _knuckle_hint:
		_knuckle_hint = clean
		_hint.add_theme_color_override("font_color", UI.BLUE if clean else UI.MUTED)
	_meter.set_bend(amount, clean)
	queue_redraw()

func show_flight() -> void:
	holding = false
	_close_sheet()
	_cue_panel.hide()
	queue_redraw()

func show_result(outcome: String, technique: String, title_override: String = "") -> void:
	holding = false
	_cue_panel.hide()
	_sheet_eyebrow.text = "BALL %d OF 5" % outcomes.size()
	_sheet_title.text = title_override if title_override != "" else RESULT_TITLES.get(outcome, outcome.capitalize())
	_sheet_title.add_theme_color_override("font_color", UI.GOLD if outcome == "GOAL" else UI.CORAL)
	_sheet_icon.texture = ICON_GOAL if outcome == "GOAL" else ICON_MISS
	_sheet_icon.modulate = UI.GOLD if outcome == "GOAL" else UI.CORAL
	_sheet_detail.text = technique
	_sheet_detail.show()
	_sheet_note.hide()
	_stars.hide()
	_primary.text = "Next ball"
	_primary_action = "next"
	_open_sheet("result")
	queue_redraw()

func show_set_result(goals: int, stars: int, next_line: String, won: bool, first_cup_win: bool, has_next: bool) -> void:
	holding = false
	_cue_panel.hide()
	_sheet_eyebrow.text = "SET COMPLETE"
	_sheet_title.text = "Keeper beaten" if won else "One more try"
	_sheet_title.add_theme_color_override("font_color", UI.GOLD if won else UI.TEXT)
	_sheet_icon.texture = ICON_TROPHY if won else ICON_AIM
	_sheet_icon.modulate = UI.GOLD
	_sheet_detail.text = "%d goals from 5 balls" % goals if goals != 1 else "1 goal from 5 balls"
	_sheet_detail.show()
	_sheet_note.text = next_line
	_sheet_note.show()
	_stars.show()
	_stars.set_stars(stars, false)
	if first_cup_win:
		_primary.text = "Equip Cup Ball"
		_primary_action = "equip"
	elif won and has_next:
		_primary.text = "Next rival"
		_primary_action = "next_rival"
	elif won:
		_primary.text = "Cup"
		_primary_action = "cup"
	else:
		_primary.text = "Rematch"
		_primary_action = "rematch"
	_open_sheet("set_result")
	_secondary.visible = won
	_secondary.text = "Rematch"
	_quiet.visible = true
	_quiet.text = "Cup"
	queue_redraw()

func show_intro(profile: RivalProfile) -> void:
	holding = false
	_cue_panel.hide()
	set_play_hud(false)
	_arena_title.text = profile.title
	_sheet_eyebrow.text = profile.intro_cue
	_sheet_title.text = profile.title
	_sheet_title.add_theme_color_override("font_color", profile.kit)
	_sheet_icon.texture = ICON_AIM
	_sheet_icon.modulate = profile.kit
	_sheet_detail.text = "Score 3 goals"
	_sheet_detail.show()
	_sheet_note.text = profile.weakness
	_sheet_note.show()
	_stars.show()
	_stars.set_stars(0, true)
	_primary.text = "Start"
	_primary_action = "start"
	_open_sheet("intro")
	_quiet.visible = true
	_quiet.text = "Cup"
	queue_redraw()

func show_cup(progress: CupProgress) -> void:
	holding = false
	_cue_panel.hide()
	set_play_hud(false)
	_arena_title.text = "Rival Cup"
	_sheet_eyebrow.text = "RIVAL CUP"
	_sheet_title.text = "Pick your keeper"
	_sheet_title.add_theme_color_override("font_color", UI.TEXT)
	_sheet_icon.texture = ICON_TROPHY
	_sheet_icon.modulate = UI.GOLD
	_sheet_detail.text = "Score 3 goals. Stars stay. Rematch anyone you have cleared."
	_sheet_detail.show()
	_sheet_note.hide()
	_stars.hide()
	var roster: Array[RivalProfile] = RivalProfile.roster()
	for i in range(roster.size()):
		var profile: RivalProfile = roster[i]
		var row: Dictionary = _rival_rows[i]
		var unlocked: bool = progress.is_unlocked(i)
		row["swatch"].color = profile.kit if unlocked else UI.FAINT
		row["name"].text = profile.title
		row["record"].text = "You %d · Keeper %d" % [progress.wins_of(profile.id), progress.losses_of(profile.id)]
		row["stars"].set_stars(progress.stars_of(profile.id))
		row["lock"].text = "" if unlocked else "Locked"
		row["card"].modulate = Color.WHITE if unlocked else Color(1, 1, 1, 0.55)
	if progress.cup_won():
		_reward_detail.text = "Equipped" if progress.ball == "cup" else "Tap to equip"
		_reward_lock.text = "●" if progress.ball == "cup" else "○"
	else:
		_reward_detail.text = "Win all three rivals"
		_reward_lock.text = "🔒"
	_primary.text = "Play next rival"
	_primary_action = "play_next"
	_open_sheet("cup")
	queue_redraw()

func show_menu(help_page: bool) -> void:
	holding = false
	_cue_panel.hide()
	if _sheet_mode != "help" and _sheet_mode != "pause":
		_resume_mode = _sheet_mode
	_sheet_eyebrow.text = "CONTROLS" if help_page else "RIVAL CUP"
	_sheet_title.text = "Make your shot" if help_page else "Paused"
	_sheet_title.add_theme_color_override("font_color", UI.TEXT)
	_sheet_icon.texture = ICON_HELP if help_page else ICON_PAUSE
	_sheet_icon.modulate = UI.GOLD
	var goals: int = outcomes.count("GOAL")
	var left: int = maxi(0, 5 - outcomes.size())
	_sheet_detail.text = "%d %s · %d %s left" % [goals, "goal" if goals == 1 else "goals", left, "ball" if left == 1 else "balls"]
	_sheet_detail.visible = not help_page
	_sheet_note.hide()
	_stars.hide()
	_primary.text = "Back to play" if help_page else "Resume"
	_primary_action = "resume"
	_open_sheet("help" if help_page else "pause")
	queue_redraw()

func show_taunt(line: String, at: Vector2) -> void:
	_taunt_label.text = line
	_taunt.show()
	var pos: Vector2 = at + Vector2(18, -40)
	pos.x = clampf(pos.x, _safe_rect.position.x + 8.0, _safe_rect.end.x - 140.0)
	pos.y = clampf(pos.y, _safe_rect.position.y + 8.0, _safe_rect.end.y - 48.0)
	_taunt.global_position = pos
	_taunt_until = Time.get_ticks_msec() + 1800

func hide_taunt() -> void:
	_taunt.hide()
	_taunt_until = 0

func _process(_delta: float) -> void:
	if _taunt_until > 0 and Time.get_ticks_msec() >= _taunt_until:
		hide_taunt()

func _open_sheet(mode: String) -> void:
	_sheet_mode = mode
	_help_rows.visible = mode == "help"
	_pause_tools.visible = mode == "pause"
	_cup_block.visible = mode == "cup"
	_stars.visible = mode == "intro" or mode == "set_result"
	_secondary.visible = mode == "pause"
	if mode == "pause":
		_secondary.text = "Restart set"
	_quiet.visible = mode == "intro" or mode == "set_result"
	_bottom_gap.visible = mode != "result" and mode != "set_result"
	var light: bool = mode == "result" or mode == "set_result"
	_shade.color = Color(0.04, 0.07, 0.15, 0.16 if light else 0.80)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE if light else Control.MOUSE_FILTER_STOP
	_shade.show()
	_sheet_scroll.scroll_vertical = 0
	_set_toolbar_enabled(light or mode == "cup" or mode == "intro")
	if mode == "cup" or mode == "intro":
		_pause.disabled = true
	_request_sheet_fit()
	_primary.grab_focus()

func _close_sheet() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null and _shade.is_ancestor_of(focused):
		focused.release_focus()
	_shade.hide()
	_sheet_mode = ""
	_set_toolbar_enabled(true)

func _set_toolbar_enabled(enabled: bool) -> void:
	_pause.disabled = not enabled
	_help.disabled = not enabled
	_sound.disabled = not enabled

func _primary_pressed() -> void:
	match _primary_action:
		"next":
			next_requested.emit()
		"start":
			start_requested.emit()
		"rematch":
			rematch_requested.emit()
		"next_rival":
			next_rival_requested.emit()
		"play_next":
			play_next_requested.emit()
		"equip":
			equip_requested.emit()
		"cup":
			cup_requested.emit()
		_:
			resume_requested.emit()

func _secondary_pressed() -> void:
	if _sheet_mode == "set_result":
		rematch_requested.emit()
	else:
		restart_requested.emit()

func _draw() -> void:
	if not holding:
		return
	var radius: float = 31.0
	draw_arc(ball_screen, radius, -PI * 0.5, PI * 1.5, 64, UI.OUTLINE, 4.0, true)
	if not curve_committed:
		draw_arc(ball_screen, radius, -PI * 0.5 + TAU * Shot.SWEET_START, -PI * 0.5 + TAU * Shot.SWEET_END, 24, UI.BLUE, 6.0, true)
	var marker: Vector2 = ball_screen + Vector2.UP.rotated(TAU * ring_phase) * radius
	draw_circle(marker, 5.0, UI.TEXT)
