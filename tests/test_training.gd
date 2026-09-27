extends SceneTree

var checks := 0
var failures := 0
var return_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _on_return() -> void:
	return_count += 1


func _run() -> void:
	var packed := load("res://scenes/training.tscn") as PackedScene
	_expect(packed != null, "Training scene loads")
	if packed == null:
		quit(1)
		return
	var training := packed.instantiate()
	root.add_child(training)
	await process_frame
	training.set_paused(true)
	_expect(training.simulation != null and training.actors.size() == 2, "Training owns a real simulation and two player-facing avatars")
	_expect(training.player_picker.item_count == 10 and training.opponent_picker.item_count == 10, "Training exposes the full fighter roster for player and dummy")
	_expect(training.dummy_picker.item_count == 6, "Training exposes original modes plus footsies and whiff practice")
	training.set_fighters("yuki", "rook")
	_expect(training.simulation.fighters[0]["fighter_id"] == "yuki" and training.simulation.fighters[1]["fighter_id"] == "rook", "Fighter pickers configure independent combat profiles")
	_expect(training.actors[0].fighter_id == "yuki" and training.actors[1].fighter_id == "rook", "Fighter pickers configure visible avatars")
	_expect(training.command_list.get_child_count() == 7, "Player-facing command list contains all seven current moves")
	training.set_meter(0.0)
	_expect(training.simulation.fighters[0]["energy"] == 0.0 and training.simulation.fighters[1]["energy"] == 0.0, "Meter reset control clears both meters")
	training.set_meter(100.0)
	_expect(training.simulation.fighters[0]["energy"] == 100.0 and training.simulation.fighters[1]["energy"] == 100.0, "Meter reset control fills both meters")
	training.simulation.fighters[0]["position"] = Vector2(-0.45, 0.0)
	training.simulation.fighters[1]["position"] = Vector2(0.45, 0.0)
	training.queue_action(0, "cross")
	for frame in range(48):
		training.step_once()
	_expect(training.input_history.size() > 0 and training.input_history[0].contains("HEAVY"), "Queued training action appears in input history")
	_expect(training.last_event.contains("HIT") or training.combo_damage > 0.0, "Training reports combat contact and combo damage")
	training.set_dummy_mode("block")
	training.reset_all()
	training.simulation.fighters[0]["position"] = Vector2(-0.45, 0.0)
	training.simulation.fighters[1]["position"] = Vector2(0.45, 0.0)
	training.queue_action(0, "jab")
	for frame in range(24):
		training.step_once()
	_expect(training.last_event.contains("BLOCK") or training.simulation.fighters[1]["guard"] < 100.0, "Block dummy creates guarded training feedback")
	training.toggle_hitboxes()
	_expect(training.debug_visible, "Hitbox toggle enables visual geometry")
	var before_side: float = training.simulation.fighters[0]["position"].x
	training.swap_sides()
	_expect(training.simulation.fighters[0]["position"].x != before_side, "Swap sides relocates the player fighter")
	training.set_fighters("kai", "neon")
	training.set_dummy_mode("footsies")
	for frame in range(90):
		training.step_once()
	_expect(training.opponent_intent_label.text.begins_with("CPU /") and training.footwork._history.size() > 0, "Training uses the real delayed match CPU and exposes its intention")
	_expect(training.range_label.text.contains("GAP") and training.range_label.text.contains("LIGHT"), "Training reports gap and normal reach")
	training.set_dummy_mode("whiff")
	training.reset_all()
	training.step_once()
	_expect(training.simulation.fighters[1]["move"] != null and training.simulation.fighters[1]["move"].id == "cross", "Whiff drill commits to a repeatable heavy")
	training.set_dummy_mode("stand")
	training.reset_all()
	# Route a real remapped input, not the queue_action helper.
	training.input_router.profile(0).set_bindings("light", [{"kind": "key", "physical_keycode": KEY_R}])
	var key := InputEventKey.new()
	key.physical_keycode = KEY_R
	key.pressed = true
	training._unhandled_input(key)
	training._simulation_tick()
	_expect(training.simulation.fighters[0]["move"] != null, "Remapped R attacks instead of triggering Training reset")
	_expect(training.input_history[0].contains("LIGHT"), "Real combat input appears in history")
	for frame in range(35):
		training.step_once()
	_expect(training.last_event.contains("WHIFF"), "Missed strike gives persistent whiff feedback")
	training.return_to_menu.connect(_on_return)
	training._request_return()
	_expect(return_count == 1, "Return button path emits a public menu signal")
	training.queue_free()
	await process_frame
	await process_frame
	print("Training integration checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures > 0 else 0)
