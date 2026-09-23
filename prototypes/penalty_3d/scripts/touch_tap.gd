class_name ArenaTouchTap
extends RefCounted

## Raw touchscreen activation for menus; the pitch owns its touches separately.
## Project mouse emulation remains disabled, so there is no duplicate click.
static func bind(control: Control, action: Callable) -> void:
	var state: Dictionary = {"index": -1, "origin": Vector2.ZERO, "tint": Color.WHITE}
	var cancel: Callable = func() -> void:
		if int(state["index"]) != -1:
			control.self_modulate = state["tint"]
		state["index"] = -1
	# Let raw drags reach the enclosing ScrollContainer. Mouse/keyboard behaviour
	# remains native; panels and the toolbar's excluded pitch area contain input.
	control.mouse_filter = Control.MOUSE_FILTER_PASS
	control.visibility_changed.connect(cancel)
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.scroll_started.connect(cancel)
			break
		ancestor = ancestor.get_parent()
	control.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			if event.pressed and not event.canceled and int(state["index"]) == -1:
				if control is BaseButton and control.disabled:
					return
				state["index"] = event.index
				state["origin"] = event.position
				state["tint"] = control.self_modulate
				control.self_modulate = Color(1.15, 1.15, 1.15, 1.0)
			elif event.index == int(state["index"]) and (not event.pressed or event.canceled):
				cancel.call()
				if event.canceled or not control.is_visible_in_tree():
					return
				if control is BaseButton and control.disabled:
					return
				var origin: Vector2 = state["origin"]
				if origin.distance_to(event.position) <= 14.0 and Rect2(Vector2.ZERO, control.size).has_point(event.position):
					control.accept_event()
					action.call()
		elif event is InputEventScreenDrag and event.index == int(state["index"]):
			var origin: Vector2 = state["origin"]
			if origin.distance_to(event.position) > 14.0:
				cancel.call()
	)
