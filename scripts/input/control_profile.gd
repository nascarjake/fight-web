class_name ControlProfile
extends RefCounted
## Serializable controls for one local fighter.
##
## Bindings deliberately use plain dictionaries rather than InputEvent resources so
## they can live safely in a small ConfigFile and be shown in a move list without
## depending on project-wide InputMap state.

const ACTIONS: PackedStringArray = [
	"move_left", "move_right", "jump", "crouch", "block",
	"light", "heavy", "low", "special_1", "special_2", "dash",
	"overdrive", "super", "pause",
]
const MOVE_ACTIONS: PackedStringArray = ["light", "heavy", "low", "special_1", "special_2", "dash", "super"]
const KEYBOARD_SOURCE := "keyboard"
const GAMEPAD_SOURCE := "gamepad"

var player_index: int = 0
var keyboard_enabled: bool = true
## Godot joypad ID. -1 means that this player has no assigned controller.
var gamepad_device: int = -1
## Semantic action -> Array[Dictionary]. Dictionaries are normalized binding records.
var bindings: Dictionary = {}


func _init(player: int = 0) -> void:
	player_index = clampi(player, 0, 1)
	for action in ACTIONS:
		bindings[action] = []


static func make_default(player: int) -> ControlProfile:
	var profile := ControlProfile.new(player)
	profile.keyboard_enabled = true
	profile.gamepad_device = player
	var keyboard: Dictionary = _default_keyboard_bindings(player)
	for action in ACTIONS:
		for binding: Dictionary in keyboard.get(action, []):
			profile.add_binding(action, binding)
	for action in ACTIONS:
		for binding: Dictionary in _default_gamepad_bindings().get(action, []):
			profile.add_binding(action, binding)
	return profile


static func _default_keyboard_bindings(player: int) -> Dictionary:
	if player == 1:
		return {
			"move_left": [key_binding(KEY_LEFT)], "move_right": [key_binding(KEY_RIGHT)],
			"jump": [key_binding(KEY_UP)], "crouch": [key_binding(KEY_DOWN)],
			"block": [key_binding(KEY_0)], "light": [key_binding(KEY_1)],
			"heavy": [key_binding(KEY_2)], "low": [key_binding(KEY_3)],
			"dash": [key_binding(KEY_4)], "special_1": [key_binding(KEY_5)],
			"special_2": [key_binding(KEY_6)], "overdrive": [key_binding(KEY_7)],
			"super": [key_binding(KEY_8)], "pause": [key_binding(KEY_ENTER)],
		}
	return {
		"move_left": [key_binding(KEY_A)], "move_right": [key_binding(KEY_D)],
		"jump": [key_binding(KEY_W)], "crouch": [key_binding(KEY_S)],
		"block": [key_binding(KEY_I)], "light": [key_binding(KEY_J)],
		"heavy": [key_binding(KEY_K)], "low": [key_binding(KEY_L)],
		"special_1": [key_binding(KEY_U)], "special_2": [key_binding(KEY_O)],
		"dash": [key_binding(KEY_SHIFT)], "overdrive": [key_binding(KEY_H)],
		"super": [key_binding(KEY_P)], "pause": [key_binding(KEY_ESCAPE)],
	}


static func _default_gamepad_bindings() -> Dictionary:
	return {
		"move_left": [button_binding(JOY_BUTTON_DPAD_LEFT), axis_binding(JOY_AXIS_LEFT_X, -1)],
		"move_right": [button_binding(JOY_BUTTON_DPAD_RIGHT), axis_binding(JOY_AXIS_LEFT_X, 1)],
		"jump": [button_binding(JOY_BUTTON_DPAD_UP), axis_binding(JOY_AXIS_LEFT_Y, -1)],
		"crouch": [button_binding(JOY_BUTTON_DPAD_DOWN), axis_binding(JOY_AXIS_LEFT_Y, 1)],
		"block": [button_binding(JOY_BUTTON_LEFT_SHOULDER)],
		"light": [button_binding(JOY_BUTTON_A)], "heavy": [button_binding(JOY_BUTTON_B)],
		"low": [button_binding(JOY_BUTTON_X)], "special_1": [button_binding(JOY_BUTTON_Y)],
		"dash": [button_binding(JOY_BUTTON_RIGHT_SHOULDER)],
		"special_2": [axis_binding(JOY_AXIS_TRIGGER_RIGHT, 1)],
		"overdrive": [axis_binding(JOY_AXIS_TRIGGER_LEFT, 1)],
		"super": [button_binding(JOY_BUTTON_RIGHT_STICK)],
		"pause": [button_binding(JOY_BUTTON_START)],
	}


static func key_binding(physical_keycode: int) -> Dictionary:
	return {"kind": "key", "physical_keycode": physical_keycode}


static func button_binding(button: int) -> Dictionary:
	return {"kind": "joy_button", "button": button}


static func axis_binding(axis: int, direction: int, threshold: float = 0.55) -> Dictionary:
	return {"kind": "joy_axis", "axis": axis, "direction": -1 if direction < 0 else 1, "threshold": clampf(threshold, 0.1, 1.0)}


static func is_action(action: String) -> bool:
	return ACTIONS.has(action)


static func action_label(action: String) -> String:
	var labels := {
		"move_left": "Move Left", "move_right": "Move Right", "jump": "Jump", "crouch": "Crouch", "block": "Block",
		"light": "Light Attack", "heavy": "Heavy Attack", "low": "Low Attack",
		"special_1": "Special I", "special_2": "Special II", "dash": "Dash / Dodge",
		"overdrive": "Overdrive", "super": "Super", "pause": "Pause",
	}
	return str(labels.get(action, action.replace("_", " ").capitalize()))


static func move_id_for_action(action: String) -> String:
	var move_ids := {
		"light": "jab", "heavy": "cross", "low": "low_kick", "special_1": "launcher",
		"special_2": "burst", "dash": "dodge", "super": "finisher",
	}
	return str(move_ids.get(action, ""))


static func source_for_binding(binding: Dictionary) -> String:
	return KEYBOARD_SOURCE if str(binding.get("kind", "")) == "key" else GAMEPAD_SOURCE


static func normalize_binding(raw: Dictionary) -> Dictionary:
	var kind := str(raw.get("kind", ""))
	match kind:
		"key":
			var code: int = int(raw.get("physical_keycode", 0))
			return key_binding(code) if code > 0 else {}
		"joy_button":
			var button: int = int(raw.get("button", -1))
			return button_binding(button) if button >= 0 else {}
		"joy_axis":
			var axis: int = int(raw.get("axis", -1))
			var direction: int = int(raw.get("direction", 1))
			if axis < 0:
				return {}
			return axis_binding(axis, direction, float(raw.get("threshold", 0.55)))
	return {}


static func binding_id(binding: Dictionary) -> String:
	var normalized := normalize_binding(binding)
	match str(normalized.get("kind", "")):
		"key":
			return "key:%d" % int(normalized["physical_keycode"])
		"joy_button":
			return "joy_button:%d" % int(normalized["button"])
		"joy_axis":
			return "joy_axis:%d:%d" % [int(normalized["axis"]), int(normalized["direction"])]
	return ""


static func bindings_equal(first: Dictionary, second: Dictionary) -> bool:
	var a := normalize_binding(first)
	var b := normalize_binding(second)
	if a.is_empty() or b.is_empty() or a.get("kind") != b.get("kind"):
		return false
	return binding_id(a) == binding_id(b)


func get_bindings(action: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for binding: Dictionary in bindings.get(action, []):
		result.append(binding.duplicate())
	return result


func set_bindings(action: String, values: Array) -> bool:
	if not is_action(action):
		return false
	var clean: Array[Dictionary] = []
	for value in values:
		if not value is Dictionary:
			continue
		var binding := normalize_binding(value)
		if binding.is_empty():
			continue
		var duplicate := false
		for existing: Dictionary in clean:
			if bindings_equal(existing, binding):
				duplicate = true
				break
		if not duplicate:
			clean.append(binding)
	bindings[action] = clean
	return true


func add_binding(action: String, value: Dictionary) -> bool:
	if not is_action(action):
		return false
	var binding := normalize_binding(value)
	if binding.is_empty():
		return false
	var current: Array = bindings.get(action, [])
	for existing: Dictionary in current:
		if bindings_equal(existing, binding):
			return true
	current.append(binding)
	bindings[action] = current
	return true


func remove_bindings_from_source(action: String, source: String) -> void:
	if not is_action(action):
		return
	var kept: Array[Dictionary] = []
	for binding: Dictionary in bindings.get(action, []):
		if source_for_binding(binding) != source:
			kept.append(binding)
	bindings[action] = kept


func remove_binding(action: String, value: Dictionary) -> bool:
	if not is_action(action):
		return false
	var binding := normalize_binding(value)
	if binding.is_empty():
		return false
	var kept: Array[Dictionary] = []
	var removed := false
	for existing: Dictionary in bindings.get(action, []):
		if not removed and bindings_equal(existing, binding):
			removed = true
			continue
		kept.append(existing)
	bindings[action] = kept
	return removed


func reset_action(action: String) -> bool:
	if not is_action(action):
		return false
	var defaults := make_default(player_index)
	bindings[action] = defaults.get_bindings(action)
	return true


func to_dict() -> Dictionary:
	var copied: Dictionary = {}
	for action in ACTIONS:
		copied[action] = get_bindings(action)
	return {
		"player_index": player_index,
		"keyboard_enabled": keyboard_enabled,
		"gamepad_device": gamepad_device,
		"bindings": copied,
	}


static func from_dict(data: Dictionary, fallback_player: int = 0) -> ControlProfile:
	var profile := ControlProfile.new(int(data.get("player_index", fallback_player)))
	profile.keyboard_enabled = bool(data.get("keyboard_enabled", true))
	profile.gamepad_device = int(data.get("gamepad_device", -1))
	var raw_bindings = data.get("bindings", {})
	if not raw_bindings is Dictionary:
		return profile
	for action in ACTIONS:
		var values = raw_bindings.get(action, [])
		if values is Array:
			profile.set_bindings(action, values)
	return profile
