extends Node3D
## Native game flow. All combat advances through MatchSession at 60 Hz.

const Actor = preload("res://scripts/avatar_actor.gd")
const Stage = preload("res://scripts/game_stage.gd")
const Interface = preload("res://scripts/game_ui.gd")
const Audio = preload("res://scripts/game_audio.gd")
const Session = preload("res://combat/MatchSession.gd")
const Director = preload("res://scripts/super_director.gd")
const InputRouter = preload("res://scripts/input/combat_input_router.gd")
const CommandScene = preload("res://scenes/fighter_command.tscn")
const TrainingScene = preload("res://scenes/training.tscn")
const TrainingModeScript = preload("res://scripts/training_mode.gd")
const ControlSettingsScene = preload("res://scenes/control_settings.tscn")

var stage: GameStage
var ui: GameUI
var sound: GameAudio
var session: MatchSession
var actors: Array[AvatarActor] = []
var markers: Array[Label3D] = []
var auras: Array[MeshInstance3D] = []
var debug_mesh: MeshInstance3D
var debug_label: Label
var screen: String = "main"
var chosen_mode: String = "cpu"
var chosen_stage: int = 0
var difficulty: int = 1
var paused: bool = false
var debug_visible: bool = false
var presentation_time: float = 0.0
var result_time: float = 0.0
var result_shown: bool = false
var queued: Array[Dictionary] = [{}, {}]
var joy_triggers: Dictionary = {}
var settings := ConfigFile.new()
var flash: ColorRect
var flash_tween: Tween
var last_phase: String = ""
var chosen_fighters: Array[String] = ["kai", "neon"]
var director: SuperDirector
var input_router
var command
var preview_requested: String = "kai"
var preview_delay: float = 0.0
var active_effect_seen: Array[bool] = [false, false]
var prior_heights: Array[float] = [0.0, 0.0]


func _ready() -> void:
	DisplayServer.window_set_title("RIFT//RIOT")
	DisplayServer.window_set_min_size(Vector2i(1100, 720))
	settings.load("user://game_settings.cfg")
	difficulty = clampi(int(settings.get_value("game", "difficulty", 1)), 0, 3)
	stage = Stage.new()
	add_child(stage)
	stage.setup(0)
	for i in range(2):
		var actor := Actor.new()
		stage.add_child(actor)
		actor.setup(false, chosen_fighters[i])
		actors.append(actor)
		var marker := Label3D.new()
		marker.text = "P1" if i == 0 else "P2"
		marker.font_size = 34
		marker.pixel_size = .004
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.modulate = Color("e5f36b") if i == 0 else Color("83c5ff")
		marker.outline_size = 8
		stage.add_child(marker)
		markers.append(marker)
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = .42
		mesh.outer_radius = .44
		mesh.rings = 40
		mesh.ring_segments = 8
		ring.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color("cce839") if i == 0 else Color("489af4")
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 1.3
		ring.material_override = mat
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stage.add_child(ring)
		auras.append(ring)
	debug_mesh = MeshInstance3D.new()
	debug_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var debug_mat := StandardMaterial3D.new()
	debug_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_mat.vertex_color_use_as_albedo = true
	debug_mat.no_depth_test = true
	debug_mesh.material_override = debug_mat
	stage.add_child(debug_mesh)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui = Interface.new()
	canvas.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1, .92, .65, 0)
	canvas.add_child(flash)
	command = CommandScene.instantiate()
	canvas.add_child(command)
	command.close_command()
	debug_label = Label.new()
	debug_label.position = Vector2(24, 165)
	debug_label.add_theme_font_size_override("font_size", 14)
	debug_label.add_theme_color_override("font_color", Color("b5ecb9"))
	debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(debug_label)
	sound = Audio.new()
	add_child(sound)
	director = Director.new()
	add_child(director)
	input_router = InputRouter.new()
	sound.set_music(bool(settings.get_value("audio", "music", true)))
	ui.set_music(sound.enabled)
	ui.set_difficulty(difficulty)
	ui.mode_selected.connect(_select_mode)
	ui.fighter_confirmed.connect(func(): sound.play("menu_select"))
	ui.fighter_changed.connect(_preview_character)
	ui.stage_selected.connect(_select_stage)
	ui.fight_requested.connect(_begin_match)
	ui.menu_requested.connect(_main_menu)
	ui.rematch_requested.connect(_rematch)
	ui.next_requested.connect(_next_match)
	ui.pause_requested.connect(_pause)
	ui.resume_requested.connect(_resume)
	ui.lab_requested.connect(_open_lab)
	ui.training_requested.connect(_open_training)
	ui.command_requested.connect(_open_command)
	ui.control_settings_requested.connect(_open_control_settings)
	ui.quit_requested.connect(func(): get_tree().quit())
	ui.music_toggled.connect(_set_music)
	ui.difficulty_changed.connect(_set_difficulty)
	command.back_requested.connect(_close_command)
	command.training_requested.connect(_open_training_for_move)
	_main_menu()
	if "--capture-tour" in OS.get_cmdline_user_args():
		_capture_tour()
	elif "--capture-roster" in OS.get_cmdline_user_args():
		_capture_roster()
	elif "--capture" in OS.get_cmdline_user_args():
		_capture_later()


func _main_menu() -> void:
	if director: director.cancel()
	stage.clear_combat_effects()
	screen = "main"
	joy_triggers.clear()
	if input_router: input_router.clear_input_state()
	paused = false
	queued = [{}, {}]
	presentation_time = 0
	actors[0].visible = true
	actors[1].visible = false
	actors[0].position = Vector3.ZERO
	actors[0].setup(false, chosen_fighters[0])
	preview_requested = chosen_fighters[0]
	ui.set_fighters(chosen_fighters)
	stage.set_presentation("menu")
	ui.show_main()
	ui.set_music(sound.enabled)
	sound.set_battle(false)
	_hide_indicators()


func _select_mode(value: String) -> void:
	chosen_mode = value
	screen = "select"
	presentation_time = 0
	stage.set_presentation("select")
	ui.show_select(value, stage.stage_names())
	ui.set_stage(chosen_stage)
	sound.play("menu_select")


func _preview_character(id: String, slot: int) -> void:
	chosen_fighters[slot] = id
	preview_requested = id
	preview_delay = .12
	presentation_time = 0


func _select_stage(index: int) -> void:
	chosen_stage = index
	stage.set_stage(index)
	stage.set_presentation("select")
	sound.play("menu_select")


func _begin_match() -> void:
	chosen_fighters = ui.get_fighters()
	session = Session.new()
	session.configure(chosen_mode, difficulty, chosen_fighters[0], chosen_fighters[1])
	_enter_match()


func _load_moves() -> void:
	for side in range(2):
		var id: String = session.fighter_ids[side]
		var moves: Array[MoveData] = FighterCatalog.moves(id)
		for i in moves.size():
			var path := "user://moves/" + id + "/" + moves[i].id + ".tres"
			if ResourceLoader.exists(path):
				var saved := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MoveData
				if saved and saved.id == moves[i].id and saved.validation_errors().is_empty(): moves[i] = saved
		session.simulation.set_fighter_moves(side, moves)


func _enter_match() -> void:
	director.cancel()
	stage.clear_combat_effects()
	chosen_fighters = session.fighter_ids.duplicate()
	_load_moves()
	ui.set_fighters(chosen_fighters)
	screen = "fight"
	joy_triggers.clear()
	if input_router: input_router.clear_input_state()
	paused = false
	result_shown = false
	result_time = 0
	queued = [{}, {}]
	last_phase = ""
	active_effect_seen = [false, false]
	prior_heights = [0.0, 0.0]
	stage.set_presentation("fight")
	for i in range(2):
		actors[i].setup(i == 1 and chosen_fighters[0] == chosen_fighters[1], chosen_fighters[i])
		actors[i].visible = true
		actors[i].reset_pose()
		actors[i].apply_state(session.simulation.fighters[i])
		markers[i].position = actors[i].position + Vector3(0, 2.02, 0)
		auras[i].position = Vector3(actors[i].position.x, .018, 0)
		markers[i].visible = true
		auras[i].visible = true
	ui.show_hud(chosen_mode)
	sound.set_battle(true)
	_refresh_hud()
	_show_intro()
	get_viewport().gui_release_focus()


func _rematch() -> void:
	if session == null: return
	session.rematch()
	_enter_match()
	sound.play("menu_select")


func _next_match() -> void:
	if session == null: return
	session.next_arcade_match()
	chosen_stage = (chosen_stage + 1) % stage.stage_names().size()
	stage.set_stage(chosen_stage)
	_enter_match()
	sound.play("menu_select")


func _pause() -> void:
	if screen != "fight" or paused: return
	paused = true
	queued = [{}, {}]
	if input_router: input_router.clear_input_state()
	ui.show_pause()
	sound.set_battle(false)


func _resume() -> void:
	paused = false
	joy_triggers.clear()
	queued = [{}, {}]
	if input_router: input_router.clear_input_state()
	ui.hide_pause()
	get_viewport().gui_release_focus()
	sound.set_battle(session == null or session.phase != "cinematic")


func _open_lab() -> void:
	director.cancel()
	if input_router: input_router.clear_input_state()
	get_tree().change_scene_to_file("res://scenes/combat_lab.tscn")


func _open_training() -> void:
	director.cancel()
	if input_router: input_router.clear_input_state()
	get_tree().change_scene_to_packed(TrainingScene)


func _open_training_for_move(fighter_id: String, move_id: String) -> void:
	TrainingModeScript.configure_next(fighter_id, chosen_fighters[1], move_id)
	_open_training()


func _open_control_settings() -> void:
	director.cancel()
	if input_router: input_router.clear_input_state()
	get_tree().change_scene_to_packed(ControlSettingsScene)


func _open_command() -> void:
	if command == null:
		return
	var fighter_id := chosen_fighters[0]
	if screen == "fight" and session != null:
		fighter_id = session.fighter_ids[0]
	command.set_binding_labels(_command_binding_labels())
	command.open_command(fighter_id)


func _close_command() -> void:
	if command != null:
		command.close_command()
	if input_router:
		input_router.clear_input_state()


func _command_binding_labels() -> Dictionary:
	var labels := {}
	if input_router == null:
		return labels
	for action: String in ["light", "heavy", "low", "special_1", "dash", "special_2", "super"]:
		labels[action] = input_router.bindings_label(0, action)
	return labels


func _set_music(value: bool) -> void:
	sound.set_music(value)
	settings.set_value("audio", "music", value)
	settings.save("user://game_settings.cfg")


func _set_difficulty(value: int) -> void:
	difficulty = clampi(value, 0, 3)
	settings.set_value("game", "difficulty", difficulty)
	settings.save("user://game_settings.cfg")


func _physics_process(delta: float) -> void:
	if not is_instance_valid(ui): return
	if screen in ["main", "select"]:
		presentation_time += delta
		if actors[0].fighter_id != preview_requested:
			preview_delay -= delta
			if preview_delay <= 0: actors[0].setup(false, preview_requested)
		actors[0].present(&"showcase", presentation_time, .12)
		return
	if paused or session == null: return
	if screen == "result":
		result_time += delta
		var win := maxi(0, session.winner)
		actors[win].present(&"victory", result_time, -.15)
		return
	if session.phase == "cinematic":
		_cinematic_tick()
		return
	var frozen: bool = session.simulation.freeze_frames > 0
	var previous_phase := session.phase
	session.step([_player_input(0), _player_input(1)])
	queued = [{}, {}]
	if session.phase == "intro" and previous_phase != "intro": _load_moves()
	if session.phase == "intro" and previous_phase != "intro": stage.clear_combat_effects()
	for i in range(2):
		actors[i].apply_state(session.simulation.fighters[i], not frozen or previous_phase != "fight")
		markers[i].position = actors[i].position + Vector3(0, 2.02, 0)
		auras[i].position = Vector3(actors[i].position.x, .018, 0)
		var power: int = session.simulation.fighters[i].get("power_frames", 0)
		auras[i].scale = Vector3.ONE * (1.15 + .1 * sin(session.simulation.tick * .25) if power > 0 else 1.0)
	for event: Dictionary in session.events:
		_handle_event(event)
	if screen == "fight" and session.phase != "cinematic": _combat_visuals(not frozen)
	if session.phase == "intro" and previous_phase != "intro": _show_intro()
	_refresh_hud()
	_update_debug()


func _process(delta: float) -> void:
	if stage == null: return
	if screen == "fight" and session != null and session.phase != "cinematic":
		stage.frame_fighters(session.simulation.fighters, delta)


func _handle_event(event: Dictionary) -> void:
	var type := str(event.get("type", ""))
	if type == "round_started":
		ui.show_announcement("FIGHT", "MAKE IT COUNT")
		sound.play("round")
	elif type == "round_over":
		var title := "TIME UP" if event.get("reason") == "timeout" else "K.O."
		if event.get("tie", false): title = "DOUBLE DOWN"
		ui.show_announcement(title, "DRAW · ROUND REPLAY" if event.get("tie", false) else "PLAYER %d TAKES THE ROUND" % (int(event.winner) + 1))
		sound.play("burst", true)
		_flash(Color(1, .83, .35, .16))
	elif type == "match_over":
		_finish_match()
	elif type == "move_started":
		var side := int(event.get("fighter", 0))
		active_effect_seen[side] = false
		var move_id := str(event.get("move", ""))
		var started_move := event.get("move_data") as MoveData
		if move_id == "finisher":
			var profile: Dictionary = FighterCatalog.get_fighter(session.fighter_ids[side])
			ui.show_announcement(str(profile.super_name), "SUPER // LIMIT RELEASE")
			sound.play_super(0)
			var tint: Color = profile.color
			tint.a = .12
			_flash(tint)
		elif started_move != null:
			var profile: Dictionary = FighterCatalog.get_fighter(session.fighter_ids[side])
			sound.play_move(started_move, str(event.get("style", session.fighter_ids[side])), float(profile.voice_pitch))
		else:
			sound.play_swing("heavy" if move_id in ["cross", "low_kick"] else "special" if move_id in ["launcher", "burst"] else "light")
	elif type == "cinematic_requested":
		_begin_cinematic(event)
	elif type == "power_started":
		ui.show_announcement("OVERDRIVE", "P%d // DAMAGE +25%% · 6 SECONDS" % (int(event.fighter) + 1))
		sound.play("burst")
	elif type in ["hit", "blocked", "guard_break", "armored", "counter"]:
		var defender := int(event.get("defender", 1))
		var at: Vector2 = session.simulation.fighters[defender].position + Vector2(0, 1.2)
		var contact_move := event.get("move_data") as MoveData
		var strong := str(event.get("move", "")) in ["burst", "finisher"] or (contact_move != null and contact_move.category in ["Heavy", "Special I", "Special II", "Super"])
		var style: String = str(event.get("style", session.fighter_ids[1 - defender]))
		stage.impact(at, type in ["blocked", "counter"], strong, style, contact_move.camera_impulse if contact_move != null else 0.0)
		if type in ["blocked", "counter"]:
			sound.play("block")
		else:
			var pitch: float = float(FighterCatalog.get_fighter(session.fighter_ids[defender]).voice_pitch)
			sound.play_hit(style, strong or str(event.get("move", "")) in ["cross", "launcher"], pitch, contact_move.sfx_cue if contact_move != null else "")
		if strong:
			var flash: Color = contact_move.impact_flash if contact_move != null else Color(1, .86, .42, .12)
			_flash(flash)
		if type == "guard_break": ui.show_announcement("GUARD CRUSH", "DEFENSE BROKEN")


func _begin_cinematic(payload: Dictionary) -> void:
	queued = [{}, {}]
	joy_triggers.clear()
	_hide_indicators()
	stage.clear_combat_effects()
	director.start(payload, actors, stage)
	stage.set_charge_aura(director.attacker, session.simulation.fighters[director.attacker].position + Vector2(0, .9), director.style, director.style != "kai")
	ui.show_cinematic(FighterCatalog.get_fighter(str(payload.get("fighter_id", "kai"))))
	sound.set_battle(false)


func _cinematic_tick() -> void:
	# No simulation step, meter gain, input buffering or round-clock tick occurs here.
	queued = [{}, {}]
	for beat in director.advance():
		var at := director.effect_point()
		stage.cinematic_effect(at, director.style, beat)
		sound.play_super(beat, director.style)
		if beat > 0:
			sound.play_voice(float(FighterCatalog.get_fighter(session.fighter_ids[director.defender]).voice_pitch), beat >= 3)
			var color: Color = FighterCatalog.get_fighter(director.style).color
			color.a = .09 if beat < 4 else .22
			_flash(color)
	var hero_position: Vector3 = actors[director.attacker].position
	stage.set_charge_aura(director.attacker, Vector2(hero_position.x, hero_position.y + .9), director.style, director.style != "kai")
	if not director.finished: return
	director.cancel()
	stage.clear_combat_effects()
	ui.show_hud(chosen_mode)
	sound.set_battle(true)
	if session.resolve_cinematic():
		for i in range(2):
			actors[i].apply_state(session.simulation.fighters[i], true)
			markers[i].visible = true
			auras[i].visible = true
		for event: Dictionary in session.events: _handle_event(event)
	queued = [{}, {}]
	joy_triggers.clear()
	_refresh_hud()
	_combat_visuals(false)
	_update_debug()


func _combat_visuals(advance: bool) -> void:
	stage.update_projectiles(session.simulation.projectiles)
	for side in range(2):
		var state: Dictionary = session.simulation.fighters[side]
		var move: MoveData = state.move
		stage.set_charge_aura(side, state.position + Vector2(0, .9), str(state.get("style", "kai")), int(state.get("power_frames", 0)) > 0)
		markers[side].position = actors[side].position + Vector3(0, 2.02, 0)
		auras[side].position = Vector3(actors[side].position.x, .018, 0)
		if advance and move and move.phase_at(state.move_frame) == "active" and not active_effect_seen[side]:
			active_effect_seen[side] = true
			var anchor: Vector3 = actors[side].presentation_anchor(move.visual_anchor)
			var effect_at := Vector2(anchor.x, anchor.y)
			stage.move_effect(effect_at, int(state.facing), str(state.get("style", "kai")), move.vfx_cue, move.camera_impulse)
		if advance and prior_heights[side] > .03 and state.position.y <= 0:
			sound.play("land")
		elif advance and prior_heights[side] <= 0 and state.position.y > 0 and state.state == "jump":
			sound.play("jump")
		prior_heights[side] = state.position.y


func _show_intro() -> void:
	ui.show_announcement("ROUND %02d" % session.round_number, "FIRST TO TWO // " + stage.stage_names()[chosen_stage])
	sound.play("round")


func _finish_match() -> void:
	director.cancel()
	stage.clear_combat_effects()
	screen = "result"
	result_time = 0
	queued = [{}, {}]
	var win := maxi(0, session.winner)
	actors[1 - win].visible = false
	actors[win].position = Vector3.ZERO
	actors[win].present(&"victory", 0, -.15)
	stage.set_presentation("victory")
	_hide_indicators()
	ui.show_result(session.winner, chosen_mode, session.arcade_index, session.phase == "arcade_complete")
	sound.set_battle(false)
	sound.play("round")


func _refresh_hud() -> void:
	ui.update_hud(session.simulation.fighters, session.wins, session.remaining_frames, session.round_number, session.arcade_index)


func _hide_indicators() -> void:
	for marker in markers: marker.visible = false
	for aura in auras: aura.visible = false
	debug_mesh.visible = false
	debug_label.visible = false


func _flash(color: Color) -> void:
	if flash_tween: flash_tween.kill()
	flash.color = color
	flash_tween = create_tween()
	flash_tween.tween_property(flash, "color:a", 0.0, .2)


func _player_input(index: int) -> Dictionary:
	var result: Dictionary = input_router.consume_simulation_input(index) if input_router != null else {}
	for key: String in queued[index]:
		result[key] = queued[index][key]
	return result


func _input(event: InputEvent) -> void:
	if command != null and command.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
			_close_command()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F11:
			var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_ESCAPE:
			if ui.handle_back():
				get_viewport().set_input_as_handled()
				return
			if screen == "fight":
				if paused: _resume()
				else: _pause()
			elif screen in ["select", "result"]: _main_menu()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B and (screen != "fight" or paused):
		if not ui.handle_back():
			if paused: _resume()
			elif screen in ["select", "result"]: _main_menu()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START and screen == "fight":
		if paused: _resume()
		else: _pause()
		get_viewport().set_input_as_handled()
		return
	if screen != "fight" or paused: return
	if session != null and session.phase == "cinematic":
		if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
			if input_router: input_router.clear_input_state()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F3:
			debug_visible = not debug_visible
		get_viewport().set_input_as_handled()
	if input_router != null and input_router.handle_event(event):
		get_viewport().set_input_as_handled()


func _update_debug() -> void:
	debug_mesh.visible = debug_visible and screen == "fight" and session.phase != "cinematic"
	debug_label.visible = debug_mesh.visible
	if not debug_mesh.visible: return
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var lines: PackedStringArray = []
	for box: Rect2 in session.simulation.projectile_hitboxes(): _debug_box(mesh, box, Color("ffc85e"))
	for index in range(2):
		for box: Rect2 in session.simulation.hitboxes(index): _debug_box(mesh, box, Color("ff536f"))
		for box: Rect2 in session.simulation.hurtboxes(index): _debug_box(mesh, box, Color("6df68f"))
		var fighter: Dictionary = session.simulation.fighters[index]
		var move: MoveData = fighter.move
		if move and move.is_invulnerable(fighter.move_frame):
			var center: Vector2 = fighter.position + Vector2(move.hurtbox_offset.x * fighter.facing, move.hurtbox_offset.y)
			_debug_box(mesh, Rect2(center - move.hurtbox_size / 2, move.hurtbox_size), Color("62aeff"))
		lines.append("P%d · %s · FRAME %d · STUN %d" % [index + 1, str(fighter.state).to_upper(), maxi(0, int(fighter.move_frame)), int(fighter.stun)])
	mesh.surface_end()
	debug_mesh.mesh = mesh
	debug_label.text = "F3 // COLLISION DISPLAY · GREEN HURT / RED HIT / BLUE INVULNERABLE\n" + "\n".join(lines)


func _debug_box(mesh: ImmediateMesh, box: Rect2, color: Color) -> void:
	var points := [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]
	for i in range(4):
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(Vector3(points[i].x, points[i].y, .18))
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(Vector3(points[(i + 1) % 4].x, points[(i + 1) % 4].y, .18))


func _capture_later() -> void:
	await get_tree().create_timer(3.0).timeout
	var args := OS.get_cmdline_user_args()
	if "--capture-select" in args: _select_mode("cpu")
	if "--capture-fight" in args:
		chosen_mode = "cpu"
		_begin_match()
		session.phase = "fight"
		ui.show_announcement("")
	if "--capture-stage" in args:
		var id := args.find("--capture-stage")
		if id + 1 < args.size():
			chosen_stage = clampi(int(args[id + 1]), 0, stage.stage_names().size() - 1)
			stage.set_stage(chosen_stage)
	await get_tree().create_timer(2.0).timeout
	if "--capture-fight" in args: paused = true
	await RenderingServer.frame_post_draw
	var idx := args.find("--capture")
	var path := args[idx + 1] if idx + 1 < args.size() else "/tmp/rift-game.png"
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURED ", path)
	if "--quit-after-capture" in args: get_tree().quit()


func _capture_tour() -> void:
	# Explicit development-only render tour; normal play never enters this path.
	var args := OS.get_cmdline_user_args()
	var index := args.find("--capture-tour")
	var directory := args[index + 1] if index + 1 < args.size() else "/tmp/rift-tour"
	DirAccess.make_dir_recursive_absolute(directory)
	await get_tree().create_timer(3.0).timeout
	await _save_view(directory.path_join("01-main.png"))
	_select_mode("local")
	await _save_view(directory.path_join("02-fighters.png"))
	ui.show_stages()
	await _save_view(directory.path_join("03-stages.png"))
	for id in range(stage.stage_names().size()):
		_select_stage(id)
		_begin_match()
		paused = true
		ui.show_announcement("")
		await _save_view(directory.path_join("04-arena-%d.png" % id))
	paused = false
	session.winner = 0
	session.wins = [2, 0]
	_finish_match()
	await _save_view(directory.path_join("05-victory.png"))
	print("RENDER TOUR COMPLETE ", directory)
	_main_menu()
	if "--quit-after-capture" in args: get_tree().quit()


func _save_view(path: String, settle: float = 1.2) -> void:
	if settle > 0: await get_tree().create_timer(settle).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _capture_roster() -> void:
	# Explicit development render fixture. It never changes persisted settings.
	var args := OS.get_cmdline_user_args()
	var index := args.find("--capture-roster")
	var directory := args[index + 1] if index + 1 < args.size() else "/tmp/rift-roster-tour"
	var profiles: Array[Dictionary] = FighterCatalog.all()
	var filter_index := args.find("--capture-fighter")
	if filter_index >= 0 and filter_index + 1 < args.size():
		profiles = [FighterCatalog.get_fighter(args[filter_index + 1])]
	DirAccess.make_dir_recursive_absolute(directory)
	await get_tree().create_timer(2.0).timeout
	await _save_view(directory.path_join("main.png"))
	_select_mode("local")
	for profile: Dictionary in profiles:
		ui._preview_fighter(str(profile.id))
		await _save_view(directory.path_join("select-" + str(profile.id) + ".png"))
	# Each super is reached through a real hit confirmation before sampling its camera.
	set_physics_process(false)
	for profile: Dictionary in profiles:
		var id: String = profile.id
		ui.set_fighters([id, "neon" if id != "neon" else "kai"])
		chosen_mode = "local"
		_select_stage(2 if id in ["kai", "yuki", "sora"] else 0)
		_begin_match()
		session.phase = "fight"
		session.simulation.fighters[0].energy = 100.0
		session.simulation.fighters[0].position = Vector2(-.5, 0)
		session.simulation.fighters[1].position = Vector2(.5, 0)
		ui.show_announcement("")
		queued[0] = {"action": "finisher"}
		for tick in range(90):
			_physics_process(1.0 / 60.0)
			if session.phase == "cinematic": break
		if session.phase != "cinematic":
			push_error("Super capture did not confirm: " + id)
			continue
		for tick in range(210):
			_physics_process(1.0 / 60.0)
			if tick == 18 and id == "kai": await _save_view(directory.path_join("super-kai-close.png"), 0)
			if tick == 90: await _save_view(directory.path_join("super-" + id + ".png"), 0)
			if tick == 165 and id == "kai": await _save_view(directory.path_join("super-kai-final.png"), 0)
			await get_tree().process_frame
		ui.show_announcement("")
		if id == "kai": await _save_view(directory.path_join("hallowed-dawn-resumed.png"))
	print("ROSTER RENDER COMPLETE ", directory)
	_main_menu()
	set_physics_process(true)
	if "--quit-after-capture" in args: get_tree().quit()
