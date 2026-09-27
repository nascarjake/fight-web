class_name ControlSettings
extends Control
## Player-facing local controls screen.
##
## This intentionally talks only to CombatInputRouter. The owning game may inject
## its match router with set_router(), while a direct scene launch gets a durable
## user://controls.cfg router of its own.

signal back_requested
signal controls_changed

const Router = preload("res://scripts/input/combat_input_router.gd")
const Profile = preload("res://scripts/input/control_profile.gd")

const ACID := Color("d8ee58")
const CYAN := Color("77dcff")
const INK := Color("080d12")
const PANEL := Color("111923")
const MUTED := Color("82929d")
const ERROR := Color("ff7775")

var router: CombatInputRouter
var selected_player: int = 0
var selected_action: String = "light"
var capture_action: String = ""
var _owns_router := false
var _pending_takeover_device: int = -1

var _player_buttons: Array[Button] = []
var _action_buttons: Dictionary = {}
var _action_list: VBoxContainer
var _profile_title: Label
var _profile_note: Label
var _keyboard_toggle: CheckButton
var _device_picker: OptionButton
var _device_note: Label
var _selected_name: Label
var _selected_bindings: Label
var _capture_title: Label
var _capture_hint: Label
var _status: Label
var _remap_button: Button
var _takeover_button: Button
var _reset_action_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(960, 640)
	if router == null:
		router = Router.new()
		_owns_router = true
	_theme()
	_build_interface()
	_refresh_all()


## Inject the router that drives gameplay so changes take effect immediately.
func set_router(value: CombatInputRouter) -> void:
	if value == null:
		return
	router = value
	_owns_router = false
	if is_node_ready():
		_refresh_all()


func get_router() -> CombatInputRouter:
	return router


func open_controls(player: int = 0) -> void:
	selected_player = clampi(player, 0, 1)
	visible = true
	if is_node_ready():
		_refresh_all()
		call_deferred("_focus_selected_action")


func close_controls() -> void:
	capture_action = ""
	visible = false


func _theme() -> void:
	var palette := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue", "Arial"])
	palette.default_font = font
	palette.default_font_size = 15
	palette.set_color("font_color", "Label", Color("eef2ed"))
	palette.set_color("font_color", "Button", Color("edf3ed"))
	palette.set_color("font_color", "CheckButton", Color("edf3ed"))
	palette.set_color("font_hover_color", "Button", CYAN)
	palette.set_color("font_focus_color", "Button", ACID)
	palette.set_color("font_placeholder_color", "LineEdit", MUTED)
	palette.set_stylebox("normal", "Button", _box(Color("19232c"), Color("34424e"), 1, 7, 9))
	palette.set_stylebox("hover", "Button", _box(Color("26343e"), CYAN, 1, 7, 9))
	palette.set_stylebox("pressed", "Button", _box(Color("344754"), ACID, 2, 7, 9))
	palette.set_stylebox("focus", "Button", _box(Color("22313b"), ACID, 2, 7, 9))
	palette.set_stylebox("disabled", "Button", _box(Color("111820"), Color("27323a"), 1, 7, 9))
	palette.set_stylebox("normal", "OptionButton", _box(Color("18222a"), Color("3a4b57"), 1, 7, 9))
	palette.set_stylebox("hover", "OptionButton", _box(Color("25333d"), CYAN, 1, 7, 9))
	palette.set_stylebox("focus", "OptionButton", _box(Color("25333d"), ACID, 2, 7, 9))
	palette.set_stylebox("panel", "PanelContainer", _box(PANEL, Color("2c3c47"), 1, 8, 12))
	palette.set_constant("separation", "VBoxContainer", 9)
	palette.set_constant("separation", "HBoxContainer", 10)
	theme = palette


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var edge := ColorRect.new()
	edge.color = ACID
	edge.set_anchors_preset(Control.PRESET_TOP_WIDE)
	edge.offset_bottom = 4
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(edge)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24 if side != "top" else 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	root.add_child(_build_header())
	root.add_child(HSeparator.new())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)
	_build_profile_column(body)
	_build_actions_column(body)
	_build_rebind_column(body)
	root.add_child(_build_footer())


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 58
	header.add_theme_constant_override("separation", 12)
	var brand := _label("RIFT//RIOT", 23, ACID)
	brand.custom_minimum_size.x = 148
	header.add_child(brand)
	var title := _label("CONTROL DECK", 13, Color("b8c7ce"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	for player: int in range(2):
		var button := Button.new()
		button.text = "P%d" % (player + 1)
		button.custom_minimum_size = Vector2(64, 39)
		button.tooltip_text = "Edit Player %d's local profile" % (player + 1)
		button.pressed.connect(_select_player.bind(player))
		header.add_child(button)
		_player_buttons.append(button)
	var back := Button.new()
	back.text = "BACK  ESC"
	back.custom_minimum_size = Vector2(108, 39)
	back.pressed.connect(_request_return)
	header.add_child(back)
	return header


func _build_profile_column(parent: HBoxContainer) -> void:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(276, 0)
	column.add_theme_constant_override("separation", 10)
	parent.add_child(column)

	var card := PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 11)
	card.add_child(content)
	_profile_title = _label("PLAYER 1 PROFILE", 20, ACID)
	content.add_child(_profile_title)
	_profile_note = _label("A LOCAL KEYBOARD + CONTROLLER PROFILE", 11, MUTED)
	_profile_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_profile_note)
	content.add_child(HSeparator.new())

	content.add_child(_label("KEYBOARD", 11, CYAN))
	_keyboard_toggle = CheckButton.new()
	_keyboard_toggle.text = "KEYBOARD ENABLED"
	_keyboard_toggle.toggled.connect(_toggle_keyboard)
	content.add_child(_keyboard_toggle)
	var keyboard_note := _label("Keyboard bindings are shared only while both player profiles have keyboard input enabled.", 11, MUTED)
	keyboard_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(keyboard_note)

	content.add_child(HSeparator.new())
	content.add_child(_label("CONTROLLER", 11, CYAN))
	_device_picker = OptionButton.new()
	_device_picker.custom_minimum_size.y = 38
	content.add_child(_device_picker)
	var device_actions := HBoxContainer.new()
	content.add_child(device_actions)
	var assign := Button.new()
	assign.text = "ASSIGN"
	assign.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	assign.pressed.connect(_assign_selected_device)
	device_actions.add_child(assign)
	var unassign := Button.new()
	unassign.text = "UNASSIGN"
	unassign.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unassign.pressed.connect(_unassign_device)
	device_actions.add_child(unassign)
	_takeover_button = Button.new()
	_takeover_button.text = "TAKE OVER"
	_takeover_button.tooltip_text = "Explicitly move the selected controller from the other player"
	_takeover_button.visible = false
	_takeover_button.pressed.connect(_take_over_device)
	content.add_child(_takeover_button)
	_device_note = _label("No controller assigned. Keyboard is ready.", 11, MUTED)
	_device_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_device_note)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(spacer)
	var reset_profile := Button.new()
	reset_profile.text = "RESET P%d PROFILE" % (selected_player + 1)
	reset_profile.tooltip_text = "Restore this player's default keyboard and controller bindings"
	reset_profile.pressed.connect(_reset_profile)
	content.add_child(reset_profile)


func _build_actions_column(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	var heading := HBoxContainer.new()
	content.add_child(heading)
	var name := _label("ACTIONS", 18, Color("f2f6f0"))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(name)
	heading.add_child(_label("KEYBOARD / PAD", 10, MUTED))
	var guidance := _label("Select an action to inspect it, then remap the next key, controller button, or stick direction.", 11, MUTED)
	guidance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(guidance)
	content.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_action_list = VBoxContainer.new()
	_action_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_action_list)


func _build_rebind_column(parent: HBoxContainer) -> void:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(306, 0)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	parent.add_child(column)
	var card := PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 11)
	card.add_child(content)
	content.add_child(_label("REMAP", 12, CYAN))
	_selected_name = _label("LIGHT ATTACK", 25, ACID)
	_selected_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_selected_name)
	_selected_bindings = _label("", 12, Color("d4e0e4"))
	_selected_bindings.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_selected_bindings)
	content.add_child(HSeparator.new())
	_capture_title = _label("READY", 12, ACID)
	content.add_child(_capture_title)
	_capture_hint = _label("Select REMAP ACTION, then press the next key, face button, trigger, or stick direction.", 12, MUTED)
	_capture_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_capture_hint)
	_remap_button = Button.new()
	_remap_button.text = "REMAP ACTION"
	_remap_button.custom_minimum_size.y = 46
	_remap_button.pressed.connect(_begin_capture)
	content.add_child(_remap_button)
	_reset_action_button = Button.new()
	_reset_action_button.text = "RESET ACTION"
	_reset_action_button.pressed.connect(_reset_action)
	content.add_child(_reset_action_button)
	var rule := _label("Each active player profile keeps unique inputs. If an input is already in use, RIFT//RIOT leaves both bindings untouched and tells you where it is assigned.", 11, MUTED)
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(rule)
	var stretch := Control.new()
	stretch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stretch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(stretch)
	_status = _label("READY TO TUNE YOUR FIGHTER.", 11, Color("a5b5bd"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status)


func _build_footer() -> Control:
	var footer := HBoxContainer.new()
	footer.custom_minimum_size.y = 34
	var note := _label("CHANGES SAVE AUTOMATICALLY  •  ESC CANCELS A CAPTURE OR RETURNS TO THE LAST SCREEN", 11, MUTED)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(note)
	var save := Button.new()
	save.text = "SAVE NOW"
	save.custom_minimum_size = Vector2(110, 32)
	save.pressed.connect(_save)
	footer.add_child(save)
	return footer


func _select_player(player: int) -> void:
	selected_player = clampi(player, 0, 1)
	capture_action = ""
	_pending_takeover_device = -1
	_set_status("EDITING PLAYER %d." % (selected_player + 1), MUTED)
	_refresh_all()


func _select_action(action: String) -> void:
	if not Profile.is_action(action):
		return
	selected_action = action
	capture_action = ""
	_set_status("SELECTED %s." % Profile.action_label(action).to_upper(), MUTED)
	_refresh_actions()
	_refresh_selected_action()
	_focus_selected_action()


func _focus_selected_action() -> void:
	var button: Button = _action_buttons.get(selected_action, null)
	if is_instance_valid(button):
		button.grab_focus()


func _refresh_all() -> void:
	if router == null or not is_node_ready():
		return
	var profile := router.profile(selected_player)
	if profile == null:
		return
	for index: int in range(_player_buttons.size()):
		var player_button := _player_buttons[index]
		var selected := index == selected_player
		player_button.text = "P%d  EDITING" % (index + 1) if selected else "P%d" % (index + 1)
		player_button.add_theme_stylebox_override("normal", _box(Color("33452a") if selected else Color("19232c"), ACID if selected else Color("34424e"), 2 if selected else 1, 7, 9))
	_profile_title.text = "PLAYER %d PROFILE" % (selected_player + 1)
	_profile_title.add_theme_color_override("font_color", ACID if selected_player == 0 else CYAN)
	_profile_note.text = "P%d can use keyboard%s." % [selected_player + 1, " and its assigned controller" if profile.gamepad_device >= 0 else " only"]
	_keyboard_toggle.set_pressed_no_signal(profile.keyboard_enabled)
	_keyboard_toggle.text = "KEYBOARD ENABLED" if profile.keyboard_enabled else "KEYBOARD DISABLED"
	_refresh_devices()
	_refresh_actions()
	_refresh_selected_action()


func _refresh_devices() -> void:
	_device_picker.clear()
	var assigned := router.assigned_device(selected_player)
	_device_picker.add_item("NO CONTROLLER")
	_device_picker.set_item_metadata(0, -1)
	var selected_index := 0
	var devices: PackedInt32Array = Input.get_connected_joypads()
	for device: int in devices:
		var name := Input.get_joy_name(device).strip_edges()
		if name.is_empty():
			name = "CONTROLLER %d" % device
		_device_picker.add_item("%d  %s" % [device + 1, name])
		var index := _device_picker.item_count - 1
		_device_picker.set_item_metadata(index, device)
		if device == assigned:
			selected_index = index
	if assigned >= 0 and not devices.has(assigned):
		_device_picker.add_item("%d  ASSIGNED (OFFLINE)" % (assigned + 1))
		selected_index = _device_picker.item_count - 1
		_device_picker.set_item_metadata(selected_index, assigned)
	_device_picker.select(selected_index)
	var device_name := router.connected_device_name(selected_player)
	if assigned < 0:
		_device_note.text = "No controller assigned. You can still play on keyboard."
	elif device_name.is_empty():
		_device_note.text = "Controller %d stays reserved for P%d and will reconnect automatically." % [assigned + 1, selected_player + 1]
	else:
		_device_note.text = "%s is assigned to P%d." % [device_name, selected_player + 1]
	_takeover_button.visible = _pending_takeover_device >= 0


func _refresh_actions() -> void:
	if _action_list == null:
		return
	for child: Node in _action_list.get_children():
		_action_list.remove_child(child)
		child.queue_free()
	_action_buttons.clear()
	for action: String in Profile.ACTIONS:
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 59
		button.tooltip_text = "Select %s to remap it" % Profile.action_label(action)
		var selected := action == selected_action
		button.add_theme_stylebox_override("normal", _box(Color("263741") if selected else Color("131e26"), ACID if selected else Color("30414c"), 2 if selected else 1, 6, 9))
		button.add_theme_stylebox_override("hover", _box(Color("2a3b46"), CYAN, 1, 6, 9))
		button.add_theme_stylebox_override("focus", _box(Color("2a3b46"), ACID, 2, 6, 9))
		var keyboard := _bindings_for_source(action, Profile.KEYBOARD_SOURCE)
		var gamepad := _bindings_for_source(action, Profile.GAMEPAD_SOURCE)
		button.text = "%s\n  KEY  %s     PAD  %s" % [Profile.action_label(action).to_upper(), keyboard, gamepad]
		button.pressed.connect(_select_action.bind(action))
		_action_list.add_child(button)
		_action_buttons[action] = button


func _refresh_selected_action() -> void:
	if _selected_name == null or router == null:
		return
	_selected_name.text = Profile.action_label(selected_action).to_upper()
	_selected_bindings.text = "KEYBOARD  %s\nCONTROLLER  %s" % [_bindings_for_source(selected_action, Profile.KEYBOARD_SOURCE), _bindings_for_source(selected_action, Profile.GAMEPAD_SOURCE)]
	if capture_action.is_empty():
		_capture_title.text = "READY"
		_capture_title.add_theme_color_override("font_color", ACID)
		_capture_hint.text = "Press REMAP ACTION to capture the next key, controller button, trigger, or stick direction. Existing conflicting inputs will be rejected safely."
		_remap_button.text = "REMAP ACTION"
		_reset_action_button.disabled = false
	else:
		_capture_title.text = "LISTENING FOR %s" % Profile.action_label(capture_action).to_upper()
		_capture_title.add_theme_color_override("font_color", CYAN)
		_capture_hint.text = "Press the desired physical input now. ESC cancels without changing your profile."
		_remap_button.text = "CANCEL CAPTURE"
		_reset_action_button.disabled = true


func _bindings_for_source(action: String, source: String) -> String:
	if router == null:
		return "—"
	var values: Array[String] = []
	for binding: Dictionary in router.profile(selected_player).get_bindings(action):
		if Profile.source_for_binding(binding) == source:
			values.append(Router.binding_label(binding, router.glyph_style_for_player(selected_player)))
	if values.is_empty():
		return "OFF" if source == Profile.KEYBOARD_SOURCE and not router.profile(selected_player).keyboard_enabled else "UNBOUND"
	return " / ".join(values)


func _begin_capture() -> void:
	if not capture_action.is_empty():
		capture_action = ""
		_set_status("CAPTURE CANCELLED. NO BINDINGS CHANGED.", MUTED)
		_refresh_selected_action()
		return
	capture_action = selected_action
	_pending_takeover_device = -1
	_set_status("WAITING FOR A PHYSICAL INPUT…", CYAN)
	_refresh_selected_action()


func _toggle_keyboard(enabled: bool) -> void:
	if router == null:
		return
	var result: Dictionary = router.set_keyboard_enabled(selected_player, enabled)
	if bool(result.get("ok", false)):
		_save("KEYBOARD %s FOR P%d." % ["ENABLED" if enabled else "DISABLED", selected_player + 1])
	else:
		_set_status(_status_for_failure(result), ERROR)
	_refresh_all()


func _assign_selected_device() -> void:
	if router == null:
		return
	var device := int(_device_picker.get_item_metadata(_device_picker.selected))
	if device < 0:
		_set_status("SELECT A CONNECTED CONTROLLER TO ASSIGN IT.", ERROR)
		return
	var result: Dictionary = router.assign_device(selected_player, device)
	if bool(result.get("ok", false)):
		_pending_takeover_device = -1
		_save("CONTROLLER %d ASSIGNED TO P%d." % [device + 1, selected_player + 1])
	else:
		if str(result.get("reason", "")) == "device_assigned":
			_pending_takeover_device = device
		_set_status(_status_for_failure(result), ERROR)
		_refresh_devices()


func _take_over_device() -> void:
	if router == null or _pending_takeover_device < 0:
		return
	var device := _pending_takeover_device
	var result: Dictionary = router.assign_device(selected_player, device, true)
	if bool(result.get("ok", false)):
		_pending_takeover_device = -1
		_save("CONTROLLER %d MOVED TO P%d." % [device + 1, selected_player + 1])
	else:
		_set_status(_status_for_failure(result), ERROR)
		_refresh_devices()


func _unassign_device() -> void:
	if router == null:
		return
	if router.assigned_device(selected_player) < 0:
		_set_status("P%d HAS NO CONTROLLER TO UNASSIGN." % (selected_player + 1), MUTED)
		return
	router.unassign_device(selected_player)
	_pending_takeover_device = -1
	_save("CONTROLLER UNASSIGNED FROM P%d." % (selected_player + 1))


func _reset_action() -> void:
	if router == null:
		return
	var result: Dictionary = router.reset_action(selected_player, selected_action)
	if bool(result.get("ok", false)):
		_save("%s RESET TO DEFAULTS." % Profile.action_label(selected_action).to_upper())
	else:
		_set_status(_status_for_failure(result), ERROR)
	_refresh_all()


func _reset_profile() -> void:
	if router == null:
		return
	# reset_profile() is intentionally a low-level router convenience.  The UI
	# makes its potentially shared keyboard/controller result explicit and rolls
	# it back if it would collide with the other active player.
	var before: Dictionary = router.profile(selected_player).to_dict()
	router.reset_profile(selected_player)
	var failed: Dictionary = {}
	for action: String in Profile.ACTIONS:
		for binding: Dictionary in router.profile(selected_player).get_bindings(action):
			var status: Dictionary = router.can_bind(selected_player, action, binding)
			if not bool(status.get("ok", false)):
				failed = status
				break
		if not failed.is_empty():
			break
	var assigned := router.assigned_device(selected_player)
	if failed.is_empty() and assigned >= 0:
		for other: int in range(2):
			if other != selected_player and router.assigned_device(other) == assigned:
				failed = {"ok": false, "reason": "device_assigned", "conflicts": [{"player": other, "device": assigned}]}
				break
	if not failed.is_empty():
		router.profiles[selected_player] = Profile.from_dict(before, selected_player)
		_set_status("PROFILE RESET BLOCKED: " + _status_for_failure(failed), ERROR)
		_refresh_all()
		return
	capture_action = ""
	_pending_takeover_device = -1
	_save("P%d PROFILE RESTORED TO DEFAULTS." % (selected_player + 1))


func _save(success_message: String = "CONTROLS SAVED.") -> void:
	if router == null:
		return
	var error := router.save_to_disk()
	if error == OK:
		_set_status(success_message, ACID)
		controls_changed.emit()
	else:
		_set_status("COULD NOT SAVE CONTROLS (ERROR %d)." % error, ERROR)
	_refresh_all()


func _status_for_failure(result: Dictionary) -> String:
	var reason := str(result.get("reason", ""))
	if reason == "binding_conflict":
		var conflicts: Array = result.get("conflicts", [])
		if not conflicts.is_empty() and conflicts[0] is Dictionary:
			var conflict: Dictionary = conflicts[0]
			return "INPUT ALREADY BELONGS TO P%d %s. NOTHING CHANGED." % [int(conflict.get("player", 0)) + 1, Profile.action_label(str(conflict.get("action", "action"))).to_upper()]
		return "INPUT IS ALREADY IN USE. NOTHING CHANGED."
	if reason == "device_assigned":
		var devices: Array = result.get("conflicts", [])
		if not devices.is_empty() and devices[0] is Dictionary:
			return "CONTROLLER IS ASSIGNED TO P%d. CHOOSE TAKE OVER TO MOVE IT." % (int(devices[0].get("player", 0)) + 1)
		return "CONTROLLER IS ALREADY ASSIGNED."
	if reason == "no_unassigned_device":
		return "NO UNASSIGNED CONTROLLER IS CONNECTED."
	return "CONTROL CHANGE REJECTED: %s." % reason.replace("_", " ").to_upper()


func _set_status(value: String, color: Color) -> void:
	if _status == null:
		return
	_status.text = value
	_status.add_theme_color_override("font_color", color)


func _request_return() -> void:
	if not capture_action.is_empty():
		capture_action = ""
		_set_status("CAPTURE CANCELLED. NO BINDINGS CHANGED.", MUTED)
		_refresh_selected_action()
		return
	back_requested.emit()
	if get_signal_connection_list("back_requested").is_empty() and get_tree() != null:
		get_tree().change_scene_to_file("res://scenes/game.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not capture_action.is_empty():
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_request_return()
			return
		var binding: Dictionary = Router.binding_from_event(event)
		if binding.is_empty():
			return
		get_viewport().set_input_as_handled()
		var target := capture_action
		capture_action = ""
		var result: Dictionary = router.rebind(selected_player, target, binding)
		if bool(result.get("ok", false)):
			_save("%s NOW USES %s." % [Profile.action_label(target).to_upper(), Router.binding_label(binding, router.glyph_style_for_player(selected_player)).to_upper()])
		else:
			_set_status(_status_for_failure(result), ERROR)
		_refresh_all()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_request_return()


func _label(value: String, size: int = 14, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _box(fill: Color, border: Color = Color.TRANSPARENT, width: int = 0, radius: int = 6, padding: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style
