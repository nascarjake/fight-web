extends SceneTree
## Run with:
## Godot --headless --path desktop --script res://tests/test_control_settings.gd

const Screen = preload("res://scripts/control_settings.gd")
const Router = preload("res://scripts/input/combat_input_router.gd")
const Profile = preload("res://scripts/input/control_profile.gd")
const TEST_PATH := "/private/tmp/rift_riot_test_control_settings.cfg"

var checks := 0
var failures := 0
var return_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.remove_absolute(TEST_PATH)
	var router = Router.new(TEST_PATH, false)
	var screen = Screen.new()
	screen.set_router(router)
	root.add_child(screen)
	await process_frame
	await process_frame
	_expect(screen._action_buttons.size() == Profile.ACTIONS.size(), "all semantic actions are represented in the player-facing list")
	_expect(screen.selected_player == 0 and screen.selected_action == "light", "screen defaults to P1 light attack")
	_expect(screen._selected_bindings.text.contains("KEYBOARD") and screen._selected_bindings.text.contains("CONTROLLER"), "selected action shows keyboard and controller labels")

	screen._select_player(1)
	_expect(screen.selected_player == 1 and screen._profile_title.text.contains("PLAYER 2"), "profile selector switches the edited player")
	screen._select_action("heavy")
	screen._begin_capture()
	_expect(screen.capture_action == "heavy", "remap button begins physical input capture")
	screen._unhandled_input(_key(KEY_F))
	_expect(screen.capture_action.is_empty() and _has_binding(router.profile(1), "heavy", Profile.key_binding(KEY_F)), "captured keyboard key rebinds the selected player action")
	_expect(FileAccess.file_exists(TEST_PATH), "successful binding capture persists controls")

	screen._select_player(0)
	screen._select_action("heavy")
	var before: Array[Dictionary] = router.profile(0).get_bindings("heavy")
	screen._begin_capture()
	screen._unhandled_input(_key(KEY_J))
	_expect(router.profile(0).get_bindings("heavy") == before, "conflicting capture leaves existing action binding untouched")
	_expect(screen._status.text.contains("ALREADY"), "conflicting capture names a surfaced error")

	screen._keyboard_toggle.button_pressed = false
	await process_frame
	_expect(not router.profile(0).keyboard_enabled, "keyboard enable toggle changes the selected profile")
	screen._reset_profile()
	_expect(router.profile(0).keyboard_enabled and _has_binding(router.profile(0), "light", Profile.key_binding(KEY_J)), "reset profile restores defaults")

	router.assign_device(0, 77)
	screen._refresh_all()
	_expect(screen._device_note.text.contains("reserved"), "assigned offline controller is clearly represented in profile status")
	screen._unassign_device()
	_expect(router.assigned_device(0) == -1, "unassign control path clears controller ownership")

	screen.back_requested.connect(_returned)
	screen._request_return()
	_expect(return_count == 1, "back path exposes a public return signal")
	screen.queue_free()
	await process_frame
	DirAccess.remove_absolute(TEST_PATH)
	print("Control settings checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures > 0 else 0)


func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	return event


func _has_binding(profile: ControlProfile, action: String, expected: Dictionary) -> bool:
	for binding: Dictionary in profile.get_bindings(action):
		if ControlProfile.bindings_equal(binding, expected):
			return true
	return false


func _returned() -> void:
	return_count += 1


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
