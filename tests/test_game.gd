extends SceneTree
## Integration smoke test using the real native scene, rig, UI, and match wrapper.
## Run after import: Godot --headless --audio-driver Dummy --path desktop
##   --script res://tests/test_game.gd
## No settings signals or persistence APIs are invoked.

var checks: int = 0
var failures: int = 0
var game = null
var completed: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/game.tscn") as PackedScene
	if packed == null:
		_expect(false, "native game scene loads")
		quit(1)
		return
	game = packed.instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	if game.ui == null or game.stage == null or game.actors.size() != 2:
		_expect(false, "native scene initializes UI, stage, and both avatars")
		game.queue_free()
		quit(1)
		return
	game.stage.set_process(false)
	game.difficulty = 1
	_test_main_and_roster()
	_test_local_input_and_pause()
	_test_round_result_rematch()
	_test_arcade_result_action()
	_test_cinematic_integration()
	_test_lethal_cinematic_result()
	_test_result_effect_cleanup()
	_expect(completed.size() == 7, "all integration scenarios reached completion")
	# Manual simulation can enqueue many sound cues in a single engine frame.
	# Stop the sources and let the Dummy driver's audio thread drain those playbacks
	# before freeing the scene; process-frame waits alone do not advance that thread.
	game.sound.music.stop()
	for voice: AudioStreamPlayer in game.sound.voices:
		voice.stop()
	await create_timer(0.5).timeout
	game.queue_free()
	await process_frame
	await process_frame
	print("Game integration checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _ticks(frames: int) -> void:
	for frame: int in range(frames):
		game._physics_process(1.0 / 60.0)


func _key(code: Key, pressed: bool = true) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	game._input(event)


func _held_key(code: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _press_named(parent: Node, title: String) -> bool:
	for child: Node in parent.get_children():
		if child is Button and child.text == title and not child.disabled:
			child.pressed.emit()
			return true
		if _press_named(child, title):
			return true
	return false


func _test_main_and_roster() -> void:
	_expect(game.screen == "main" and game.ui._main.visible, "startup shows main menu")
	_expect(game.actors[0].visible and not game.actors[1].visible, "menu showcases one available avatar")
	_expect(_press_named(game.ui._main_content, "LOCAL VERSUS"), "local-versus menu action exists")
	_expect(game.screen == "select" and game.chosen_mode == "local" and game.ui._fighter_select.visible, "mode action opens fighter selection")
	var roster: GridContainer = game.ui._roster
	_expect(roster.get_child_count() == 12, "roster exposes twelve slots")
	for index: int in range(12):
		var tile: Button = roster.get_child(index) as Button
		_expect(tile.disabled == (index >= 10), "ten actual VRoid roster slots are enabled")
		if index >= 10:
			_expect(tile.focus_mode == Control.FOCUS_NONE and tile.get_signal_connection_list("pressed").is_empty(), "locked slots have no selection action or focus")
			tile.pressed.emit()
	_expect(game.screen == "select" and game.ui._fighter_select.visible and not game.ui._stage_select.visible, "locked roster events cannot advance selection")
	(roster.get_child(0) as Button).pressed.emit()
	_expect(game.ui._selection_slot == 1 and game.ui._fighter_select.visible, "P1 confirmation opens independent P2 choice")
	(roster.get_child(2) as Button).pressed.emit()
	_expect(game.ui._stage_select.visible and not game.ui._fighter_select.visible, "available fighter confirms into stage selection")
	_expect(game.ui._stage_buttons.size() >= 1, "stage selection offers real arenas")
	var selected_stage: int = game.ui._stage_buttons.size() - 1
	game.ui._stage_buttons[selected_stage].pressed.emit()
	_expect(game.chosen_stage == selected_stage, "stage button updates game selection")
	_expect(_press_named(game.ui._stage_footer, "LET'S FIGHT"), "stage selection exposes fight action")
	# Fix the test fixture in memory; user-saved lab overrides remain untouched.
	_use_catalog_moves()
	_expect(game.screen == "fight" and game.session.mode == "local" and game.ui._hud.visible, "selection enters real local match")
	_expect(game.session.phase == "intro" and game.ui._p2_identity.text == "P2", "local intro has second-player HUD identity")
	_expect(game.actors[0].visible and game.actors[1].visible, "both selected fighters appear in match")
	_expect(game.ui._energy[0].value == 0.0 and game.ui._energy[1].value == 0.0, "native HUD displays match starting meter")
	_expect(game.session.fighter_ids == ["kai", "yuki"] and game.actors[0].fighter_id == "kai" and game.actors[1].fighter_id == "yuki", "independent fighter choices reach actual models and simulation")
	_expect(game.ui._player_names[1].text == "YUKI", "HUD names the chosen opponent")
	completed.append("selection")


func _test_local_input_and_pause() -> void:
	_ticks(MatchSession.INTRO_FRAMES)
	_expect(game.session.phase == "fight", "root physics drives intro into live combat")
	_held_key(KEY_D, true)
	_held_key(KEY_LEFT, true)
	var first_position: Vector2 = game.session.simulation.fighters[0]["position"]
	var second_position: Vector2 = game.session.simulation.fighters[1]["position"]
	_ticks(1)
	_held_key(KEY_D, false)
	_held_key(KEY_LEFT, false)
	_expect(game.session.simulation.fighters[0]["position"].x > first_position.x and game.session.simulation.fighters[1]["position"].x < second_position.x, "physical keys independently move both local players")
	_key(KEY_J)
	_key(KEY_1)
	_ticks(1)
	_expect(game.session.simulation.fighters[0]["move"] != null and game.session.simulation.fighters[0]["move"].id == "jab", "P1 keyboard action reaches simulation")
	_expect(game.session.simulation.fighters[1]["move"] != null and game.session.simulation.fighters[1]["move"].id == "jab", "P2 keyboard action reaches simulation")
	_expect(game.queued[0].is_empty() and game.queued[1].is_empty(), "one-shot input queue clears after tick")
	_ticks(40)
	game.sound._last_swing = -1000
	_key(KEY_SHIFT)
	_ticks(1)
	_expect(game.session.simulation.fighters[0]["move"] != null and game.session.simulation.fighters[0]["move"].id == "dodge" and game.sound._last_swing > -1000, "mobility move routes through the live authored sound path")
	_key(KEY_ESCAPE)
	var tick: int = game.session.simulation.tick
	_ticks(5)
	_expect(game.paused and game.ui._pause.visible and game.session.simulation.tick == tick, "pause freezes simulation and opens pause menu")
	_key(KEY_K)
	_expect(game.queued[0].is_empty(), "paused attack cannot leak into input queue")
	game.joy_triggers = {"0:4": true}
	var start: InputEventJoypadButton = InputEventJoypadButton.new()
	start.button_index = JOY_BUTTON_START
	start.pressed = true
	game._input(start)
	_expect(not game.paused and not game.ui._pause.visible, "controller Start resumes pause")
	_expect(game.joy_triggers.is_empty(), "resume clears stale controller trigger edges")
	if game.paused:
		game._resume()
	_ticks(1)
	_expect(game.session.simulation.tick == tick + 1, "resumed match advances exactly one tick")
	completed.append("input")


func _test_round_result_rematch() -> void:
	game.session.simulation.fighters[1]["hp"] = 0.0
	_ticks(1)
	_expect(game.session.phase == "round_end" and game.session.wins == [1, 0], "native loop resolves knockout into round result")
	_expect(game.ui._health[1].value == 0.0 and game.ui._win_markers[0].text.contains("◆"), "HUD reflects knockout and awarded round")
	_ticks(MatchSession.ROUND_END_FRAMES)
	_expect(game.session.phase == "intro" and game.session.round_number == 2 and game.ui._health[1].value == 100.0, "next-round presentation restores HUD and fighter state")
	_ticks(MatchSession.INTRO_FRAMES)
	game.debug_visible = true
	game.session.simulation.fighters[1]["hp"] = 0.0
	_ticks(1)
	_ticks(MatchSession.ROUND_END_FRAMES)
	_expect(game.screen == "result" and game.session.phase == "match_end" and game.ui._result.visible, "second knockout enters native result screen")
	_expect(game.ui._result_title.text == "P1 WINS", "local result identifies winning player")
	_expect(game.actors[0].visible and not game.actors[1].visible and game.actors[0].position == Vector3.ZERO, "result stages only the winner")
	_expect(not game.debug_mesh.visible and not game.debug_label.visible, "collision debug stays hidden in result presentation")
	_expect(_press_named(game.ui._result_actions, "REMATCH"), "result rematch action exists")
	_use_catalog_moves()
	_expect(game.screen == "fight" and game.session.phase == "intro" and game.session.wins == [0, 0], "result rematch creates a clean new match")
	_expect(game.actors[1].visible and not game.ui._result.visible, "rematch restores opponent and dismisses result")
	game.ui.menu_requested.emit()
	_expect(game.screen == "main" and game.ui._main.visible and not game.ui._hud.visible, "menu action returns from match to main menu")
	_expect(game.actors[0].visible and not game.actors[1].visible and not game.paused, "main menu restores single-avatar presentation")
	completed.append("results")


func _test_arcade_result_action() -> void:
	game.ui.mode_selected.emit("arcade")
	game.ui._confirm_fighter()
	game.ui.fight_requested.emit()
	_use_catalog_moves()
	# MatchSession separately tests every round and rival. Here verify event wiring,
	# the native result button, and the next-rival transition using a terminal fixture.
	game.session.phase = "round_end"
	game.session.phase_frames = 1
	var arcade_wins: Array[int] = [2, 0]
	game.session.wins = arcade_wins
	game.session.winner = 0
	_ticks(1)
	_expect(game.screen == "result" and game.ui._result.visible, "arcade match event enters result UI")
	_expect(_press_named(game.ui._result_actions, "NEXT FIGHT"), "arcade win exposes next-fight action")
	_expect(game.screen == "fight" and game.session.arcade_index == 1 and game.session.phase == "intro", "next-fight button advances arcade session")
	var stage_after_arcade: int = game.chosen_stage
	game.ui.menu_requested.emit()
	game.ui.mode_selected.emit("cpu")
	game.ui._confirm_fighter()
	_expect(game.chosen_stage == stage_after_arcade and game.ui._stage_index == stage_after_arcade, "selection keeps stage synchronized after arcade progression")
	game.ui.menu_requested.emit()
	completed.append("arcade")


func _use_catalog_moves() -> void:
	for side in range(2):
		game.session.simulation.set_fighter_moves(side, FighterCatalog.moves(game.session.fighter_ids[side]))


func _test_cinematic_integration() -> void:
	for profile: Dictionary in FighterCatalog.all():
		var id: String = profile.id
		game.chosen_mode = "local"
		# Alternate attacker sides: camera/facing must also work for Player 2.
		var side: int = 1 if id in ["neon", "rook", "vex", "raijin"] else 0
		var ids: Array[String] = []
		ids.assign([id, "kai" if id != "kai" else "neon"] if side == 0 else ["kai", id])
		game.ui.set_fighters(ids)
		game._begin_match()
		_use_catalog_moves()
		game.session.phase = "fight"
		var sim: FightSimulation = game.session.simulation
		sim.fighters[0].position = Vector2(-.5, 0)
		sim.fighters[1].position = Vector2(.5, 0)
		sim.fighters[side].energy = 100.0
		game.queued[side] = {"action": "finisher"}
		for frame in range(90):
			_ticks(1)
			if game.session.phase == "cinematic": break
		_expect(game.session.phase == "cinematic" and game.director.active, id + " confirmed super starts native camera director")
		if game.session.phase != "cinematic": continue
		var clock: int = game.session.remaining_frames
		var tick: int = sim.tick
		var original_positions: Array[Vector2] = [sim.fighters[0].position, sim.fighters[1].position]
		var restore_camera: Transform3D = game.stage.camera.global_transform
		var damage: float = sim.pending_cinematic.damage
		_expect(root.get_camera_3d() == game.director.camera and game.ui._cinematic.visible and not game.ui._hud.visible, id + " cinematic takes camera and HUD ownership")
		_key(KEY_J)
		_key(KEY_8)
		_expect(game.queued[0].is_empty() and game.queued[1].is_empty(), id + " cinematic discards gameplay buttons")
		_ticks(30)
		_expect(sim.fighters[1 - side].hp == 100.0 and sim.tick == tick and game.session.remaining_frames == clock, id + " opening shot freezes combat and clock before damage")
		_key(KEY_ESCAPE)
		var camera_frame: int = game.director.frame
		_ticks(3)
		_expect(game.paused and game.director.frame == camera_frame, id + " pause also freezes cinematic clock")
		_key(KEY_ESCAPE)
		var first_camera: Vector3 = game.director.camera.global_position
		_ticks(61)
		_expect(game.director.camera.global_position.distance_to(first_camera) > .5 and game.director.camera.global_transform.is_finite(), id + " close-up transitions to moving combo camera")
		_expect(sim.fighters[0].position == original_positions[0] and sim.fighters[1].position == original_positions[1], id + " choreography never moves simulation collision bodies")
		_ticks(119)
		_expect(game.session.phase == "fight" and not game.director.active and sim.pending_cinematic.is_empty(), id + " cinematic resolves and returns to live fight")
		_expect(is_equal_approx(sim.fighters[1 - side].hp, 100.0 - damage), id + " damage commits once after automatic choreography")
		_expect(root.get_camera_3d() == game.stage.camera and game.stage.camera.global_transform.is_equal_approx(restore_camera), id + " fight camera restores exactly")
		_expect(game.ui._hud.visible and not game.ui._cinematic.visible and game.markers[0].visible and game.markers[1].visible, id + " HUD and player indicators restore")
		_expect(sim.tick == tick and game.session.remaining_frames == clock, id + " all210 cinematic frames leave fight clock intact")
		game.session.simulation.freeze_frames = 0
		_ticks(1)
		_expect(sim.tick == tick + 1 and game.session.remaining_frames == clock - 1, id + " combat resumes on the next tick")
	game._main_menu()
	_expect(root.get_camera_3d() == game.stage.camera and not game.director.active and game.ui._main.visible, "menu has no leftover cinematic ownership")
	completed.append("cinematics")


func _test_lethal_cinematic_result() -> void:
	game.chosen_mode = "local"
	var ids: Array[String] = ["kai", "neon"]
	game.ui.set_fighters(ids)
	game._begin_match()
	_use_catalog_moves()
	game.session.phase = "fight"
	var prior_wins: Array[int] = [1, 0]
	game.session.wins = prior_wins
	var sim: FightSimulation = game.session.simulation
	sim.fighters[0].position = Vector2(-.5, 0)
	sim.fighters[1].position = Vector2(.5, 0)
	sim.fighters[0].energy = 100.0
	sim.fighters[1].hp = 10.0
	_key(KEY_P)
	for frame in range(90):
		_ticks(1)
		if game.session.phase == "cinematic": break
	_expect(game.session.phase == "cinematic" and game.director.active, "lethal super confirms through native keyboard and director")
	if game.session.phase != "cinematic": return
	var tick: int = sim.tick
	var clock: int = game.session.remaining_frames
	var duration: int = game.director.duration
	_ticks(duration - 1)
	_expect(sim.fighters[1].hp == 10.0 and game.session.wins == [1, 0] and game.session.phase == "cinematic", "lethal cinematic cannot damage or award match before its last frame")
	_expect(game.screen == "fight" and not game.ui._result.visible, "potential cinematic knockout keeps result UI closed")
	_ticks(1)
	_expect(sim.fighters[1].hp == 0.0 and sim.fighters[1].state == "down", "last cinematic frame commits lethal damage and knockdown")
	_expect(game.session.phase == "round_end" and game.session.wins == [2, 0] and game.session.winner == 0, "lethal cinematic awards precisely the deciding round")
	_expect(sim.tick == tick and game.session.remaining_frames == clock, "lethal resolution preserves frozen simulation tick and round clock")
	_expect(not game.director.active and sim.pending_cinematic.is_empty() and root.get_camera_3d() == game.stage.camera, "lethal resolution releases director and restores fight camera")
	_expect(game.ui._hud.visible and not game.ui._cinematic.visible and game.ui._health[1].value == 0.0, "knockout returns cinematic UI to the updated round HUD")
	var hit_count: int = 0
	var round_count: int = 0
	for event: Dictionary in game.session.events:
		if event.get("type") == "hit" and event.get("cinematic", false): hit_count += 1
		if event.get("type") == "round_over": round_count += 1
	_expect(hit_count == 1 and round_count == 1, "native lethal resolution exposes one cinematic hit and one round-over event")
	_expect(not game.session.resolve_cinematic() and game.session.wins == [2, 0], "repeated cinematic resolution cannot award another win")
	_ticks(MatchSession.ROUND_END_FRAMES - 1)
	_expect(game.screen == "fight" and game.session.phase == "round_end", "deciding cinematic knockout keeps the full round-end presentation")
	_ticks(1)
	_expect(game.screen == "result" and game.session.phase == "match_end" and game.ui._result.visible and game.ui._result_title.text == "P1 WINS", "lethal super flows automatically from round-end to match result")
	_expect(game.actors[0].visible and not game.actors[1].visible and not game.markers[0].visible and not game.markers[1].visible, "cinematic match win stages only its victor without fight indicators")
	_ticks(30)
	_expect(game.session.wins == [2, 0] and sim.fighters[1].hp == 0.0 and sim.tick == tick, "result presentation cannot repeat cinematic damage or wins")
	_expect(_press_named(game.ui._result_actions, "REMATCH"), "cinematic match result offers a working rematch action")
	_expect(game.session.phase == "intro" and game.session.wins == [0, 0] and sim.pending_cinematic.is_empty() and sim.fighters[0].energy == 0.0 and sim.fighters[1].hp == 100.0, "rematch after a lethal super clears its pending damage, score, and meter")
	game.ui.menu_requested.emit()
	_expect(game.screen == "main" and game.ui._main.visible and root.get_camera_3d() == game.stage.camera, "lethal-super rematch can return cleanly to menu")
	completed.append("lethal_cinematic")


func _test_result_effect_cleanup() -> void:
	game.chosen_mode = "local"
	var ids: Array[String] = ["neon", "kai"]
	game.ui.set_fighters(ids)
	game._begin_match()
	_use_catalog_moves()
	game.session.phase = "fight"
	var prior_wins: Array[int] = [1, 0]
	game.session.wins = prior_wins
	var sim: FightSimulation = game.session.simulation
	sim.fighters[0].position = Vector2(-3.0, 0)
	sim.fighters[1].position = Vector2(3.0, 0)
	sim.fighters[0].energy = 100.0
	_key(KEY_H)
	_key(KEY_O)
	for frame in range(60):
		_ticks(1)
		if not sim.projectiles.is_empty(): break
	_expect(not sim.projectiles.is_empty() and not game.stage._projectile_nodes.is_empty(), "live special creates a real simulation projectile and its stage visual")
	_expect(sim.fighters[0].power_frames > 0 and game.stage._charge_nodes.has(0), "native overdrive input creates an active power aura before result cleanup")
	# End a deciding round while the projectile is still safely out of contact range.
	# The frozen terminal simulation retains both effects, so cleanup must belong to UI flow.
	sim.fighters[1].hp = 0.0
	_ticks(1)
	_expect(game.session.phase == "round_end" and not sim.projectiles.is_empty() and sim.fighters[0].power_frames > 0, "round-end fixture preserves live projectile and power state")
	_ticks(MatchSession.ROUND_END_FRAMES)
	_expect(game.screen == "result" and game.ui._result.visible, "effect cleanup fixture reaches result through actual match-over event")
	_expect(not sim.projectiles.is_empty() and sim.fighters[0].power_frames > 0, "result cleanup assertion has surviving simulation effects to reject")
	_expect(game.stage._projectile_nodes.is_empty() and game.stage._charge_nodes.is_empty() and game.stage._effects.is_empty(), "match-over clears projectile, power, and impact visuals without recreating them in the same tick")
	_ticks(30)
	_expect(game.stage._projectile_nodes.is_empty() and game.stage._charge_nodes.is_empty(), "victory presentation cannot resurrect frozen fight effects")
	game.ui.menu_requested.emit()
	_expect(game.screen == "main" and game.stage._projectile_nodes.is_empty() and game.stage._charge_nodes.is_empty(), "returning from result to menu keeps combat effects cleared")
	completed.append("effect_cleanup")
