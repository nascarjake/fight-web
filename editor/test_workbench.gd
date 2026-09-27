extends SceneTree
## Headless UI and persistence smoke test. Uses a unique move ID and removes its save file.
## Run: godot --headless --path desktop --script res://editor/test_workbench.gd

var _failures: PackedStringArray = []
var _change_count: int = 0
var _scrubbed_frame: int = -1
var _selection_count: int = 0
var _mode_change_count: int = 0

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _run() -> void:
	var move := MoveData.new()
	move.id = "__workbench_smoke_%d" % OS.get_process_id()
	move.cancel_start = 10
	move.cancel_end = 15
	move.cancel_into = PackedStringArray(["jab"])
	var moves: Array[MoveData] = [move]
	var editor := MoveWorkbench.new()
	editor.setup(moves)
	editor.set_animation_names(PackedStringArray(["jab", "idle", "heavy"]))
	editor.move_changed.connect(func(_move: MoveData) -> void: _change_count += 1)
	editor.move_selected.connect(func(_move: MoveData) -> void: _selection_count += 1)
	editor.mode_changed.connect(func(_mode: String) -> void: _mode_change_count += 1)
	editor.scrubbed.connect(func(frame: int) -> void: _scrubbed_frame = frame)
	root.add_child(editor)
	editor.size = Vector2(384, 900)
	await process_frame
	_check(editor.selected_move() == move, "Workbench must retain the supplied MoveData reference.")
	_check(editor.get_combined_minimum_size().x <= 384, "Workbench must fit its intended desktop panel width.")
	_check(editor.get_combined_minimum_size().y <= 900, "Scrollable form must fit within the desktop viewport.")
	editor.set_mode("training")
	_check(editor._training_button.button_pressed and not editor._preview_button.button_pressed and _mode_change_count == 0, "External mode synchronization must not emit mode_changed.")
	var initial_selection_count: int = _selection_count
	_check(editor.select_move_id(move.id, false), "Move ID selection must find existing moves.")
	_check(_selection_count == initial_selection_count, "Silent move selection must not emit move_selected.")
	_check(not editor.select_move_id("missing_move", false), "Missing move selection must fail without changing the selected move.")
	editor._on_number_changed(9, &"startup", -1)
	editor._on_number_changed(1.35, &"hitbox_offset", 0)
	editor._on_text_changed("jab, heavy", &"cancel_into")
	_check(move.startup == 9, "Timing edit must reach the shared resource.")
	_check(is_equal_approx(move.hitbox_offset.x, 1.35), "Vector field edit must reach the shared resource.")
	_check(move.cancel_into == PackedStringArray(["jab", "heavy"]), "Cancel destinations must parse comma-separated IDs.")
	_check(_change_count == 3, "Every edit must emit move_changed.")
	(editor._fields[&"animated_hitbox"] as CheckButton).button_pressed = true
	editor._on_number_changed(-0.2, &"hitbox_entry_delta", 0)
	editor._on_number_changed(0.4, &"exposed_limb_size", 0)
	editor._on_number_changed(0.3, &"exposed_limb_size", 1)
	editor._on_number_changed(4, &"exposed_recovery_frames", -1)
	_check(move.animated_hitbox and move.exposed_recovery_frames == 4, "Collision animation and exposed-limb edits reach the resource.")
	editor._on_scrub(8)
	_check(_scrubbed_frame == 8 and not editor._playing, "Scrubbing must pause and emit the exact frame.")
	_check(editor._frame_label.text == "F 008", "Playhead must display a zero-based frame.")
	editor._save_move()
	var save_path: String = MoveWorkbench.SAVE_DIR.path_join(move.id + ".tres")
	_check(FileAccess.file_exists(save_path), "Save must create a .tres file: " + editor._status.text)
	if FileAccess.file_exists(save_path):
		var saved: MoveData = ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as MoveData
		_check(saved != null and saved.startup == 9, "Persisted move must load with the edited frame data.")
		_check(saved != null and saved.hitbox_offset == move.hitbox_offset and saved.cancel_into == move.cancel_into, "Vector and array fields must roundtrip.")
		_check(saved != null and saved.animated_hitbox and saved.hitbox_entry_delta == Vector2(-0.2, 0) and saved.exposed_limb_size == Vector2(0.4, 0.3) and saved.exposed_recovery_frames == 4, "Collision animation and limb exposure roundtrip with the move.")
		move.startup = 20
		editor._reload_saved()
		_check(move.startup == 9 and editor.selected_move() == move, "Reload must restore data in place.")
		move.invuln_start = 100
		move.invuln_end = 105
		editor._save_move()
		_check(editor._status.text.begins_with("Save blocked:"), "Invalid frame windows must block save with visible feedback.")
		editor._reload_saved()
		_check(move.invuln_start == -1 and move.invuln_end == -1, "An invalid edit must not overwrite the previous save.")
		var invalid := MoveData.new()
		invalid.id = move.id
		invalid.hitbox_size = Vector2.ZERO
		var invalid_save: Error = ResourceSaver.save(invalid, save_path)
		_check(invalid_save == OK, "Test fixture must save successfully.")
		move.startup = 11
		editor._reload_saved()
		_check(move.startup == 11 and editor._status.text.contains("Rejected:"), "Reload must reject invalid saved resources without altering live data.")
		var cleanup_error: Error = DirAccess.remove_absolute(save_path)
		_check(cleanup_error == OK, "Smoke test save must be cleaned up.")
	_check(not editor._safe_id("../escape") and editor._safe_id("heavy_02"), "Save IDs must prevent path traversal.")
	editor.queue_free()
	await process_frame
	if _failures.is_empty():
		print("WORKBENCH PASS: shared edits, vector/array fields, scrub, 384px layout, .tres roundtrip, validation, reload, safe IDs.")
		quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		quit(1)
