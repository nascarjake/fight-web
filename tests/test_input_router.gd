extends SceneTree
## Run with:
## Godot --headless --path desktop --script res://tests/test_input_router.gd

const Router = preload("res://scripts/input/combat_input_router.gd")
const Profile = preload("res://scripts/input/control_profile.gd")

## Keep test persistence outside user:// so headless CI does not touch a player's
## saved controls (or require access to the desktop application's support folder).
const TEST_PATH := "/private/tmp/fight-fight-test-input-router.cfg"

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.remove_absolute(TEST_PATH)
	var router = Router.new(TEST_PATH, false)
	_test_defaults(router)
	_test_keyboard_translation(router)
	_test_gamepad_translation(router)
	_test_conflict_safe_rebinding(router)
	_test_device_assignment(router)
	_test_persistence_and_display(router)
	DirAccess.remove_absolute(TEST_PATH)
	print("Input router checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _key(code: int, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	return event


func _button(device: int, button: int, pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = pressed
	return event


func _axis(device: int, axis: int, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	return event


func _has_source(profile: ControlProfile, action: String, source: String) -> bool:
	for binding: Dictionary in profile.get_bindings(action):
		if ControlProfile.source_for_binding(binding) == source:
			return true
	return false


func _has_binding(profile: ControlProfile, action: String, expected: Dictionary) -> bool:
	for binding: Dictionary in profile.get_bindings(action):
		if ControlProfile.bindings_equal(binding, expected):
			return true
	return false


func _test_defaults(router: CombatInputRouter) -> void:
	_expect(router.profile(0).gamepad_device == 0 and router.profile(1).gamepad_device == 1, "defaults reserve gamepad zero for P1 and one for P2")
	for player in range(2):
		for action in ControlProfile.ACTIONS:
			_expect(_has_source(router.profile(player), action, ControlProfile.KEYBOARD_SOURCE), "P%d has keyboard binding for %s" % [player + 1, action])
			_expect(_has_source(router.profile(player), action, ControlProfile.GAMEPAD_SOURCE), "P%d has gamepad binding for %s" % [player + 1, action])
	_expect(ControlProfile.move_id_for_action("light") == "jab" and ControlProfile.move_id_for_action("super") == "finisher", "semantic attack names retain the current simulation move IDs")


func _test_keyboard_translation(router: CombatInputRouter) -> void:
	router.handle_event(_key(KEY_A, true))
	router.handle_event(_key(KEY_I, true))
	router.handle_event(_key(KEY_J, true))
	var first: Dictionary = router.consume_simulation_input(0)
	_expect(first["axis"] == -1.0 and first["block"] and first["action"] == "jab", "P1 held movement/block and light edge become simulation input")
	_expect(router.consume_simulation_input(0)["action"].is_empty(), "attack edge is consumed exactly once")
	router.handle_event(_key(KEY_A, false))
	router.handle_event(_key(KEY_I, false))
	router.handle_event(_key(KEY_J, false))
	router.handle_event(_key(KEY_H, true))
	router.handle_event(_key(KEY_P, true))
	var super_input: Dictionary = router.consume_simulation_input(0)
	_expect(super_input["power"] and super_input["action"] == "finisher", "overdrive and super retain distinct simulation fields")
	router.handle_event(_key(KEY_H, false))
	router.handle_event(_key(KEY_P, false))
	router.handle_event(_key(KEY_1, true))
	var second: Dictionary = router.consume_simulation_input(1)
	_expect(second["action"] == "jab" and router.consume_simulation_input(0)["action"].is_empty(), "P2 keyboard is independent from P1")
	router.handle_event(_key(KEY_1, false))


func _test_gamepad_translation(router: CombatInputRouter) -> void:
	router.handle_event(_button(0, JOY_BUTTON_A, true))
	_expect(router.consume_simulation_input(0)["action"] == "jab", "P1 gamepad face button maps to light")
	router.handle_event(_button(0, JOY_BUTTON_A, false))
	router.handle_event(_axis(0, JOY_AXIS_LEFT_X, -0.9))
	_expect(router.consume_simulation_input(0)["axis"] == -1.0, "negative analog direction maps to left movement")
	router.handle_event(_axis(0, JOY_AXIS_LEFT_X, 0.0))
	_expect(router.consume_simulation_input(0)["axis"] == 0.0, "axis release clears held direction")
	router.handle_event(_axis(0, JOY_AXIS_TRIGGER_RIGHT, 0.8))
	_expect(router.consume_simulation_input(0)["action"] == "burst", "right trigger maps to Special II")
	router.handle_event(_axis(0, JOY_AXIS_TRIGGER_RIGHT, 0.0))


func _test_conflict_safe_rebinding(router: CombatInputRouter) -> void:
	var before: Array[Dictionary] = router.profile(0).get_bindings("heavy")
	var result: Dictionary = router.rebind(0, "heavy", Profile.key_binding(KEY_J))
	_expect(not result["ok"] and result["reason"] == "binding_conflict", "same-player keyboard conflict is rejected")
	_expect(router.profile(0).get_bindings("heavy") == before, "rejected rebind leaves existing binding untouched")
	result = router.rebind(1, "heavy", Profile.key_binding(KEY_J))
	_expect(not result["ok"] and result["conflicts"][0]["player"] == 0, "shared-keyboard conflict names the other player")
	result = router.rebind(0, "heavy", Profile.key_binding(KEY_F))
	_expect(result["ok"] and _has_binding(router.profile(0), "heavy", Profile.key_binding(KEY_F)), "non-conflicting rebind succeeds")
	_expect(_has_binding(router.profile(0), "heavy", Profile.button_binding(JOY_BUTTON_B)), "keyboard rebind preserves gamepad binding")
	_expect(router.set_keyboard_enabled(0, false)["ok"], "keyboard source can be disabled for a controller-only player")
	_expect(router.rebind(1, "heavy", Profile.key_binding(KEY_J))["ok"], "disabled keyboard no longer reserves its bindings")
	_expect(not router.set_keyboard_enabled(0, true)["ok"] and not router.profile(0).keyboard_enabled, "re-enabling a conflicting keyboard is safely rejected")
	router.reset_to_defaults()


func _test_device_assignment(router: CombatInputRouter) -> void:
	var result: Dictionary = router.assign_device(1, 0)
	_expect(not result["ok"] and result["reason"] == "device_assigned", "controller cannot silently drive two players")
	result = router.assign_device(1, 0, true)
	_expect(result["ok"] and router.assigned_device(0) == -1 and router.assigned_device(1) == 0, "explicit takeover moves controller ownership safely")
	router.reset_to_defaults()


func _test_persistence_and_display(router: CombatInputRouter) -> void:
	var rebound: Dictionary = router.rebind(0, "light", Profile.key_binding(KEY_R))
	_expect(rebound["ok"], "custom binding can be prepared for persistence")
	_expect(router.assign_device(0, 42)["ok"], "arbitrary future controller IDs may be assigned before connection")
	_expect(router.save_to_disk() == OK, "control profiles save to user storage")
	var restored = Router.new(TEST_PATH, true)
	_expect(_has_binding(restored.profile(0), "light", Profile.key_binding(KEY_R)), "saved keyboard rebind reloads")
	_expect(restored.assigned_device(0) == 42, "saved device assignment reloads")
	_expect(restored.bindings_label(0, "light").contains("R"), "move-list display reads the user's current keyboard binding")
	_expect(RestoredDisplay(restored) == "✕", "controller glyph API supports PlayStation-style UI")
	var captured := Router.binding_from_event(_key(KEY_G, true))
	_expect(Profile.bindings_equal(captured, Profile.key_binding(KEY_G)), "rebinding capture converts a physical key event")


func RestoredDisplay(router: CombatInputRouter) -> String:
	return Router.binding_glyph(Profile.button_binding(JOY_BUTTON_A), "playstation")
