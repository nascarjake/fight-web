class_name CombatInputRouter
extends RefCounted
## Local, remappable combat input for two players.
##
## The router owns semantic actions and delivers the current simulation-shaped
## input dictionary. It intentionally does not edit ProjectSettings/InputMap:
## both players can use independent keyboard layouts in the same local match.

const Profile = preload("res://scripts/input/control_profile.gd")
const CONFIG_VERSION := 1
const DEFAULT_CONFIG_PATH := "user://controls.cfg"
const ACTION_PRIORITY: PackedStringArray = ["super", "special_2", "special_1", "heavy", "low", "light", "dash"]

var config_path: String = DEFAULT_CONFIG_PATH
var profiles: Array[ControlProfile] = []
var _binding_state: Array[Dictionary] = [{}, {}]
var _held: Array[Dictionary] = [{}, {}]
var _edges: Array[Dictionary] = [{}, {}]


func _init(path: String = DEFAULT_CONFIG_PATH, load_saved: bool = true) -> void:
	config_path = path
	reset_to_defaults()
	if load_saved:
		load_from_disk()


func reset_to_defaults() -> void:
	profiles = [Profile.make_default(0), Profile.make_default(1)]
	_clear_runtime_state()


func reset_profile(player: int) -> bool:
	if not _valid_player(player):
		return false
	profiles[player] = Profile.make_default(player)
	_clear_runtime_state(player)
	return true


func profile(player: int) -> ControlProfile:
	if not _valid_player(player):
		return null
	return profiles[player]


func set_keyboard_enabled(player: int, enabled: bool) -> Dictionary:
	if not _valid_player(player):
		return _failure("invalid_player")
	var target := profiles[player]
	if enabled and not target.keyboard_enabled:
		# Enable it while validating: can_bind only treats enabled keyboards as a
		# shared source, and a failed check restores the previous safe state.
		target.keyboard_enabled = true
		for action in ControlProfile.ACTIONS:
			for binding: Dictionary in target.get_bindings(action):
				if ControlProfile.source_for_binding(binding) != ControlProfile.KEYBOARD_SOURCE:
					continue
				var status := can_bind(player, action, binding)
				if not bool(status["ok"]):
					target.keyboard_enabled = false
					return status
	target.keyboard_enabled = enabled
	_clear_runtime_state(player)
	return _success()


func assigned_device(player: int) -> int:
	var target := profile(player)
	return target.gamepad_device if target else -1


func player_for_device(device: int) -> int:
	for player in range(profiles.size()):
		if profiles[player].gamepad_device == device:
			return player
	return -1


func assign_device(player: int, device: int, takeover: bool = false) -> Dictionary:
	if not _valid_player(player) or device < 0:
		return _failure("invalid_device")
	var current_owner := player_for_device(device)
	if current_owner >= 0 and current_owner != player:
		if not takeover:
			return _failure("device_assigned", [{"player": current_owner, "device": device}])
		profiles[current_owner].gamepad_device = -1
		_clear_runtime_state(current_owner)
	profiles[player].gamepad_device = device
	_clear_runtime_state(player)
	return _success()


func unassign_device(player: int) -> bool:
	if not _valid_player(player):
		return false
	profiles[player].gamepad_device = -1
	_clear_runtime_state(player)
	return true


func assign_first_available_device(player: int) -> Dictionary:
	if not _valid_player(player):
		return _failure("invalid_player")
	for device: int in Input.get_connected_joypads():
		if player_for_device(device) < 0:
			return assign_device(player, device)
	return _failure("no_unassigned_device")


func connected_device_name(player: int) -> String:
	var device := assigned_device(player)
	if device < 0 or not Input.get_connected_joypads().has(device):
		return ""
	return Input.get_joy_name(device)


func can_bind(player: int, action: String, value: Dictionary) -> Dictionary:
	if not _valid_player(player):
		return _failure("invalid_player")
	if not ControlProfile.is_action(action):
		return _failure("invalid_action")
	var binding := ControlProfile.normalize_binding(value)
	if binding.is_empty():
		return _failure("invalid_binding")
	var conflicts := binding_conflicts(player, action, binding)
	if not conflicts.is_empty():
		return _failure("binding_conflict", conflicts)
	return _success()


func binding_conflicts(player: int, action: String, value: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _valid_player(player) or not ControlProfile.is_action(action):
		return result
	var binding := ControlProfile.normalize_binding(value)
	if binding.is_empty():
		return result
	var target := profiles[player]
	var source := ControlProfile.source_for_binding(binding)
	for other_player in range(profiles.size()):
		var other := profiles[other_player]
		if source == ControlProfile.KEYBOARD_SOURCE:
			if other_player != player and (not target.keyboard_enabled or not other.keyboard_enabled):
				continue
		elif other_player != player and (target.gamepad_device < 0 or target.gamepad_device != other.gamepad_device):
			continue
		for other_action in ControlProfile.ACTIONS:
			if other_player == player and other_action == action:
				continue
			for existing: Dictionary in other.get_bindings(other_action):
				if ControlProfile.bindings_equal(existing, binding):
					result.append({"player": other_player, "action": other_action, "binding": existing.duplicate()})
	return result


## Replaces bindings of the same exact kind (key, button, or axis) while preserving
## the other source. Rebinding Light from J to F, for example, keeps its gamepad A.
func rebind(player: int, action: String, value: Dictionary, replace_same_kind: bool = true) -> Dictionary:
	var status := can_bind(player, action, value)
	if not bool(status["ok"]):
		return status
	var binding := ControlProfile.normalize_binding(value)
	var target := profiles[player]
	if replace_same_kind:
		var kept: Array[Dictionary] = []
		var kind := str(binding["kind"])
		for existing: Dictionary in target.get_bindings(action):
			if str(existing.get("kind", "")) != kind:
				kept.append(existing)
		target.set_bindings(action, kept)
	target.add_binding(action, binding)
	_clear_runtime_state(player)
	return _success()


func add_binding(player: int, action: String, value: Dictionary) -> Dictionary:
	var status := can_bind(player, action, value)
	if not bool(status["ok"]):
		return status
	profiles[player].add_binding(action, value)
	_clear_runtime_state(player)
	return _success()


func remove_binding(player: int, action: String, value: Dictionary) -> bool:
	var target := profile(player)
	if target == null:
		return false
	var removed := target.remove_binding(action, value)
	if removed:
		_clear_runtime_state(player)
	return removed


func reset_action(player: int, action: String) -> Dictionary:
	var target := profile(player)
	if target == null or not ControlProfile.is_action(action):
		return _failure("invalid_action")
	var defaults := Profile.make_default(player)
	for binding: Dictionary in defaults.get_bindings(action):
		var status := can_bind(player, action, binding)
		if not bool(status["ok"]):
			return status
	target.reset_action(action)
	_clear_runtime_state(player)
	return _success()


func save_to_disk() -> Error:
	var config := ConfigFile.new()
	config.set_value("meta", "version", CONFIG_VERSION)
	for player in range(profiles.size()):
		config.set_value("player_%d" % player, "profile", JSON.stringify(profiles[player].to_dict()))
	return config.save(config_path)


func load_from_disk() -> bool:
	var config := ConfigFile.new()
	if config.load(config_path) != OK:
		return false
	if int(config.get_value("meta", "version", 0)) != CONFIG_VERSION:
		return false
	var loaded: Array[ControlProfile] = []
	for player in range(2):
		var payload := str(config.get_value("player_%d" % player, "profile", ""))
		var parsed = JSON.parse_string(payload)
		if not parsed is Dictionary:
			return false
		var candidate := Profile.from_dict(parsed, player)
		candidate.player_index = player
		loaded.append(candidate)
	profiles = loaded
	_repair_device_assignments()
	_clear_runtime_state()
	return true


func handle_event(event: InputEvent) -> bool:
	var handled := false
	for player in range(profiles.size()):
		if _handle_event_for_player(player, event):
			handled = true
	return handled


func is_pressed(player: int, action: String) -> bool:
	return _valid_player(player) and bool(_held[player].get(action, false))


func is_just_pressed(player: int, action: String) -> bool:
	return _valid_player(player) and bool(_edges[player].get(action, false))


func consume_pressed(player: int, action: String) -> bool:
	if not is_just_pressed(player, action):
		return false
	_edges[player].erase(action)
	return true


func clear_edges(player: int = -1) -> void:
	if player < 0:
		for index in range(profiles.size()):
			_edges[index].clear()
		return
	if _valid_player(player):
		_edges[player].clear()


## Use this when a modal, scene transition, or pause screen takes focus. It
## prevents a key released while the UI owns input from becoming a stuck walk,
## guard, or attack when combat resumes.
func clear_input_state(player: int = -1) -> void:
	_clear_runtime_state(player)


## Converts semantic state to the dictionary consumed by FightSimulation.step().
## Pause stays queued for menu code; it is not accidentally discarded by combat.
func consume_simulation_input(player: int) -> Dictionary:
	if not _valid_player(player):
		return {}
	var axis := 0.0
	if is_pressed(player, "move_left") != is_pressed(player, "move_right"):
		axis = -1.0 if is_pressed(player, "move_left") else 1.0
	var action := ""
	for semantic in ACTION_PRIORITY:
		if consume_pressed(player, semantic):
			var move_id := ControlProfile.move_id_for_action(semantic)
			if action.is_empty() and not move_id.is_empty():
				action = move_id
	var jump := consume_pressed(player, "jump")
	var overdrive := consume_pressed(player, "overdrive")
	return {
		"axis": axis,
		"jump": jump,
		"crouch": is_pressed(player, "crouch"),
		"block": is_pressed(player, "block"),
		"action": action,
		"power": overdrive,
	}


func bindings_label(player: int, action: String, prefer_gamepad: bool = false) -> String:
	var target := profile(player)
	if target == null:
		return ""
	var listed: Array[String] = []
	for binding: Dictionary in _ordered_bindings(target, action, prefer_gamepad):
		listed.append(binding_label(binding, glyph_style_for_player(player)))
	return " / ".join(listed)


func display_for_action(player: int, action: String, prefer_gamepad: bool = false) -> Dictionary:
	var target := profile(player)
	if target == null:
		return {}
	var ordered := _ordered_bindings(target, action, prefer_gamepad)
	if ordered.is_empty():
		return {"action": action, "label": "UNBOUND", "glyph": "", "binding": {}}
	var binding: Dictionary = ordered[0]
	var style := glyph_style_for_player(player)
	return {"action": action, "label": binding_label(binding, style), "glyph": binding_glyph(binding, style), "binding": binding.duplicate()}


func glyph_style_for_player(player: int) -> String:
	var name := connected_device_name(player).to_lower()
	if name.contains("dualshock") or name.contains("dualsense") or name.contains("playstation"):
		return "playstation"
	if name.contains("switch") or name.contains("joy-con"):
		return "switch"
	return "xbox"


static func binding_from_event(event: InputEvent, threshold: float = 0.55) -> Dictionary:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			return ControlProfile.key_binding(code)
	elif event is InputEventJoypadButton:
		if event.pressed:
			return ControlProfile.button_binding(event.button_index)
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) >= threshold:
			return ControlProfile.axis_binding(event.axis, -1 if event.axis_value < 0.0 else 1, threshold)
	return {}


static func binding_label(binding: Dictionary, style: String = "xbox") -> String:
	var normalized := ControlProfile.normalize_binding(binding)
	match str(normalized.get("kind", "")):
		"key":
			var code := int(normalized["physical_keycode"])
			var label := OS.get_keycode_string(code)
			return label if not label.is_empty() else "KEY %d" % code
		"joy_button":
			return binding_glyph(normalized, style)
		"joy_axis":
			return binding_glyph(normalized, style)
	return "UNBOUND"


static func binding_glyph(binding: Dictionary, style: String = "xbox") -> String:
	var normalized := ControlProfile.normalize_binding(binding)
	var kind := str(normalized.get("kind", ""))
	if kind == "key":
		return binding_label(normalized, style)
	if kind == "joy_axis":
		var axis := int(normalized["axis"])
		var direction := int(normalized["direction"])
		if axis == JOY_AXIS_TRIGGER_LEFT:
			return "L2" if style == "playstation" else "ZL" if style == "switch" else "LT"
		if axis == JOY_AXIS_TRIGGER_RIGHT:
			return "R2" if style == "playstation" else "ZR" if style == "switch" else "RT"
		var stick := "LS"
		var arrow := "←" if direction < 0 else "→"
		if axis == JOY_AXIS_LEFT_Y:
			arrow = "↑" if direction < 0 else "↓"
		elif axis == JOY_AXIS_RIGHT_X:
			stick = "RS"
		elif axis == JOY_AXIS_RIGHT_Y:
			stick = "RS"
			arrow = "↑" if direction < 0 else "↓"
		return stick + " " + arrow
	if kind != "joy_button":
		return ""
	var button := int(normalized["button"])
	if style == "playstation":
		var playstation := {JOY_BUTTON_A: "✕", JOY_BUTTON_B: "○", JOY_BUTTON_X: "□", JOY_BUTTON_Y: "△", JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_BACK: "CREATE", JOY_BUTTON_START: "OPTIONS", JOY_BUTTON_DPAD_UP: "D-PAD ↑", JOY_BUTTON_DPAD_DOWN: "D-PAD ↓", JOY_BUTTON_DPAD_LEFT: "D-PAD ←", JOY_BUTTON_DPAD_RIGHT: "D-PAD →"}
		return str(playstation.get(button, "BUTTON %d" % button))
	if style == "switch":
		var switch_labels := {JOY_BUTTON_A: "B", JOY_BUTTON_B: "A", JOY_BUTTON_X: "Y", JOY_BUTTON_Y: "X", JOY_BUTTON_LEFT_SHOULDER: "L", JOY_BUTTON_RIGHT_SHOULDER: "R", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_BACK: "−", JOY_BUTTON_START: "+", JOY_BUTTON_DPAD_UP: "D-PAD ↑", JOY_BUTTON_DPAD_DOWN: "D-PAD ↓", JOY_BUTTON_DPAD_LEFT: "D-PAD ←", JOY_BUTTON_DPAD_RIGHT: "D-PAD →"}
		return str(switch_labels.get(button, "BUTTON %d" % button))
	var xbox := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS", JOY_BUTTON_BACK: "VIEW", JOY_BUTTON_START: "MENU", JOY_BUTTON_DPAD_UP: "D-PAD ↑", JOY_BUTTON_DPAD_DOWN: "D-PAD ↓", JOY_BUTTON_DPAD_LEFT: "D-PAD ←", JOY_BUTTON_DPAD_RIGHT: "D-PAD →"}
	return str(xbox.get(button, "BUTTON %d" % button))


func _handle_event_for_player(player: int, event: InputEvent) -> bool:
	var target := profiles[player]
	var handled := false
	for action in ControlProfile.ACTIONS:
		for binding: Dictionary in target.get_bindings(action):
			var source := ControlProfile.source_for_binding(binding)
			if source == ControlProfile.KEYBOARD_SOURCE:
				if not target.keyboard_enabled:
					continue
			elif target.gamepad_device < 0 or event.device != target.gamepad_device:
				continue
			var state := _event_binding_state(event, binding)
			if not bool(state.get("matched", false)):
				continue
			handled = true
			_set_binding_state(player, action, binding, bool(state.get("pressed", false)))
	return handled


func _event_binding_state(event: InputEvent, binding: Dictionary) -> Dictionary:
	var kind := str(binding.get("kind", ""))
	if kind == "key" and event is InputEventKey:
		var code: int = int(binding["physical_keycode"])
		var actual: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if actual == code:
			return {"matched": true, "pressed": event.pressed}
	elif kind == "joy_button" and event is InputEventJoypadButton:
		if event.button_index == int(binding["button"]):
			return {"matched": true, "pressed": event.pressed}
	elif kind == "joy_axis" and event is InputEventJoypadMotion:
		if event.axis == int(binding["axis"]):
			var value: float = event.axis_value * float(binding["direction"])
			return {"matched": true, "pressed": value >= float(binding["threshold"])}
	return {}


func _set_binding_state(player: int, action: String, binding: Dictionary, pressed: bool) -> void:
	var state_id := action + "|" + ControlProfile.binding_id(binding)
	if bool(_binding_state[player].get(state_id, false)) == pressed:
		return
	var previously_held := is_pressed(player, action)
	_binding_state[player][state_id] = pressed
	var held := false
	for candidate: Dictionary in profiles[player].get_bindings(action):
		if bool(_binding_state[player].get(action + "|" + ControlProfile.binding_id(candidate), false)):
			held = true
			break
	_held[player][action] = held
	if held and not previously_held:
		_edges[player][action] = true


func _ordered_bindings(target: ControlProfile, action: String, prefer_gamepad: bool) -> Array[Dictionary]:
	var preferred_source := ControlProfile.GAMEPAD_SOURCE if prefer_gamepad else ControlProfile.KEYBOARD_SOURCE
	var result: Array[Dictionary] = []
	for binding: Dictionary in target.get_bindings(action):
		if ControlProfile.source_for_binding(binding) == preferred_source:
			result.append(binding)
	for binding: Dictionary in target.get_bindings(action):
		if ControlProfile.source_for_binding(binding) != preferred_source:
			result.append(binding)
	return result


func _repair_device_assignments() -> void:
	var claimed: Dictionary = {}
	for target: ControlProfile in profiles:
		if target.gamepad_device < 0:
			continue
		if claimed.has(target.gamepad_device):
			target.gamepad_device = -1
		else:
			claimed[target.gamepad_device] = true


func _clear_runtime_state(player: int = -1) -> void:
	if player < 0:
		_binding_state = [{}, {}]
		_held = [{}, {}]
		_edges = [{}, {}]
		return
	if _valid_player(player):
		_binding_state[player].clear()
		_held[player].clear()
		_edges[player].clear()


func _valid_player(player: int) -> bool:
	return player >= 0 and player < profiles.size()


func _success() -> Dictionary:
	return {"ok": true, "reason": "", "conflicts": []}


func _failure(reason: String, conflicts: Array = []) -> Dictionary:
	return {"ok": false, "reason": reason, "conflicts": conflicts}
