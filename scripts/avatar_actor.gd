class_name AvatarActor
extends Node3D
## A visual actor driven by simulation ticks, never by render-frame delta.

const MODEL_PATH := "res://assets/characters/AvatarSample_C.vrm"
const EXTERNAL_ANIMATIONS := "res://assets/animations"
const TICK := 1.0 / 60.0
const RESTING_HEIGHT := 1.72
const MotionAuthor = preload("res://scripts/motion_library.gd")
const MODEL_LETTERS := {"kai":"C", "neon":"K", "yuki":"M", "ivy":"N", "rook":"R", "atlas":"T", "zero":"V", "vex":"X", "sora":"Y", "raijin":"Z"}

var skeleton: Skeleton3D
var player: AnimationPlayer
var fighter_id: String = "kai"
var _opponent: bool = false
var _model: Node3D
var _clip: StringName = &""
var _last_move: MoveData
var _last_move_frame: int = -1
var _last_stun: int = 0
var _preview: bool = false


func setup(is_opponent: bool = false, selected_fighter: String = "kai") -> void:
	var tint_changed := _opponent != is_opponent
	_opponent = is_opponent
	set_fighter(selected_fighter, tint_changed)
	rotation.y = PI * 0.5 * (-1.0 if _opponent else 1.0)


func set_fighter(selected_fighter: String, force_reload: bool = false) -> void:
	selected_fighter = selected_fighter if MODEL_LETTERS.has(selected_fighter) else "kai"
	if is_instance_valid(player) and fighter_id == selected_fighter and not force_reload:
		return
	var model_path := "res://assets/characters/AvatarSample_%s.vrm" % MODEL_LETTERS[selected_fighter]
	if not ResourceLoader.exists(model_path):
		push_error("AvatarActor: local VRM is missing: " + model_path)
		return
	var packed := load(model_path) as PackedScene
	if packed == null:
		push_error("AvatarActor: VRM import did not produce a scene.")
		return
	if is_instance_valid(player): player.free()
	if is_instance_valid(_model): _model.free()
	skeleton = null
	player = null
	fighter_id = selected_fighter
	_model = packed.instantiate() as Node3D
	_model.name = "Model"
	add_child(_model)
	_normalize_visual_model()
	if _opponent:
		_apply_alternate_tint()
	# Imported spring-bone processors and expression players must not continue
	# on render ticks during hitstop or exact frame previews.
	_model.process_mode = Node.PROCESS_MODE_DISABLED
	for node in _model.find_children("*", "AnimationPlayer", true, false):
		(node as AnimationPlayer).stop()
		(node as AnimationPlayer).active = false
	var found := _model.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		push_error("AvatarActor: the local model has no Skeleton3D.")
		return
	skeleton = found[0] as Skeleton3D
	player = AnimationPlayer.new()
	player.name = "CombatAnimationPlayer"
	add_child(player)
	player.root_node = NodePath("..")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.playback_auto_capture = false
	var skeleton_path := get_path_to(skeleton)
	var library: AnimationLibrary = MotionAuthor.build(skeleton, skeleton_path, fighter_id)
	_load_external_clips(library, skeleton_path)
	player.add_animation_library(&"", library)
	reset_pose()


func apply_state(state: Dictionary, advance: bool = true) -> void:
	var location: Vector2 = state.get("position", Vector2.ZERO)
	position = Vector3(location.x, location.y, 0)
	if not is_instance_valid(player):
		return
	rotation.y = PI * 0.5 * (1.0 if int(state.get("facing", 1)) >= 0 else -1.0)
	# Freeze both playback time and crossfade time. The simulation owns position.
	if not advance and not _clip.is_empty():
		return
	var move: MoveData = state.get("move") as MoveData
	var frame: int = int(state.get("move_frame", -1))
	var stun: int = int(state.get("stun", 0))
	var requested := _clip_for_state(state, move)
	var restarting := _preview or requested != _clip
	if move != null:
		restarting = restarting or move != _last_move or frame < _last_move_frame
	elif String(requested).ends_with("hit"):
		restarting = restarting or stun > _last_stun
	var rate: float = 1.0
	if move != null:
		rate = player.get_animation(requested).length * 60.0 / maxf(1.0, float(move.total_frames()))
	var blend: float = float(move.animation_blend_frames) * TICK if move != null else 3.0 * TICK
	if restarting:
		player.play(requested, maxf(0.0, blend), rate)
		_clip = requested
		if move != null:
			player.seek(_attack_time(move, frame, requested), false)
		player.advance(0.0)
	elif advance:
		if move != null:
			# Advance the crossfade by one real simulation tick while sampling the
			# incoming clip at its exact move-frame coordinate.
			var desired := _attack_time(move, frame, requested)
			player.seek(maxf(0.0, desired - rate * TICK), false)
		# Locomotion/reactions have no MoveData and still advance every live tick.
		player.advance(TICK)
	_preview = false
	_last_move = move
	_last_move_frame = frame
	_last_stun = stun


func preview_move(move: MoveData, frame: int) -> void:
	if not is_instance_valid(player):
		return
	var requested: StringName = _resolve_clip(move.animation_name) if move != null else &"idle"
	player.stop(true)
	player.play(requested, 0.0)
	player.seek(_attack_time(move, frame, requested) if move != null else 0.0, true, true)
	_clip = requested
	_preview = true
	_last_move = move
	_last_move_frame = frame


func animation_names() -> PackedStringArray:
	return player.get_animation_list() if is_instance_valid(player) else PackedStringArray()


func present(clip_name: StringName, time: float, face_angle: float = 0.0) -> void:
	# Menu and victory presentation use their own clock; combat never calls this.
	if not is_instance_valid(player):
		return
	var requested := _resolve_clip(_style_clip(String(clip_name)))
	var animation := player.get_animation(requested)
	if requested != _clip:
		player.stop(true)
		player.play(requested, 0.0)
		_clip = requested
	var sample := fmod(time, animation.length) if animation.loop_mode != Animation.LOOP_NONE else minf(time, animation.length)
	player.seek(sample, true, true)
	rotation.y = face_angle
	_preview = true


func present_cinematic(selected_fighter: String, time: float, role: String = "attacker") -> void:
	if selected_fighter != fighter_id:
		set_fighter(selected_fighter)
	var face_angle := rotation.y
	present(&"cinematic_victim" if role == "victim" else StringName(fighter_id + "_cinematic"), time, face_angle)


static func cinematic_motion(style: String, time: float) -> Vector3:
	return MotionAuthor.cinematic_motion(style, time)


func reset_pose() -> void:
	if not is_instance_valid(player):
		return
	skeleton.reset_bone_poses()
	player.stop(true)
	var idle := _style_clip("idle")
	player.play(idle, 0.0)
	player.seek(0.0, true, true)
	_clip = idle
	_last_move = null
	_last_move_frame = -1
	_last_stun = 0
	_preview = false


## Returns a presentation-only point in the fight plane. Combat collision still
## uses FightSimulation boxes; this only gives effects a place to originate.
func presentation_anchor(anchor: String = "body") -> Vector3:
	var fallback := global_position + Vector3(0.0, 1.12, 0.0)
	match anchor.to_lower():
		"right_hand":
			return _presentation_bone("RightHand", fallback + Vector3(0.30, 0.22, 0.0))
		"left_hand":
			return _presentation_bone("LeftHand", fallback + Vector3(-0.30, 0.22, 0.0))
		"right_foot":
			return _presentation_bone("RightFoot", fallback + Vector3(0.20, -0.58, 0.0))
		"right_knee":
			return _presentation_bone("RightLowerLeg", fallback)
		"left_foot":
			return _presentation_bone("LeftFoot", fallback + Vector3(-0.20, -0.58, 0.0))
		"both_hands":
			var left := _presentation_bone("LeftHand", fallback + Vector3(-0.20, 0.16, 0.0))
			var right := _presentation_bone("RightHand", fallback + Vector3(0.20, 0.16, 0.0))
			return left.lerp(right, 0.5)
		"head":
			return _presentation_bone("Head", fallback + Vector3(0.0, 0.56, 0.0))
	return _presentation_bone("Chest", fallback)


func _presentation_bone(bone_name: String, fallback: Vector3) -> Vector3:
	if skeleton != null:
		var bone := skeleton.find_bone(bone_name)
		if bone >= 0:
			return skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin
	return fallback


func _attack_time(move: MoveData, frame: int, clip_name: StringName) -> float:
	var length: float = player.get_animation(clip_name).length
	return clampf(float(maxi(frame, 0)) / maxf(1.0, float(move.total_frames())), 0.0, 1.0) * length


func _apply_alternate_tint() -> void:
	# Per-instance material copies keep the P1 avatar and imported asset untouched.
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null: continue
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface)
			if source == null: continue
			var material := source.duplicate(true) as Material
			if material is ShaderMaterial:
				var tint = material.get_shader_parameter("_Color")
				if tint is Color: material.set_shader_parameter("_Color", tint * Color(.68, .83, 1.0))
				material.set_shader_parameter("_RimColor", Color(.16, .42, .8, 1))
			elif material is StandardMaterial3D:
				material.albedo_color *= Color(.68, .83, 1.0)
			mesh.set_surface_override_material(surface, material)


func _normalize_visual_model() -> void:
	# Imported avatars have different authored metre heights. Normalize the child
	# visual only, leaving the simulation actor and its collision units untouched.
	var inverse := _model.global_transform.affine_inverse()
	var bounds := AABB()
	var valid := false
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null: continue
		var local_bounds: AABB = (inverse * mesh.global_transform) * mesh.get_aabb()
		bounds = bounds.merge(local_bounds) if valid else local_bounds
		valid = true
	if not valid or bounds.size.y < 0.1:
		return
	var factor := RESTING_HEIGHT / bounds.size.y
	_model.scale *= factor
	_model.position.y -= bounds.position.y * factor


func _resolve_clip(requested: StringName) -> StringName:
	if player.has_animation(requested): return requested
	var styled := _style_clip(String(requested))
	if player.has_animation(styled): return styled
	var bare := String(requested).get_slice("_", 0)
	if MODEL_LETTERS.has(bare):
		var fallback := String(requested).trim_prefix(bare + "_")
		if player.has_animation(fallback): return StringName(fallback)
	return _style_clip("idle")


func _style_clip(requested: String) -> StringName:
	var styled := StringName(fighter_id + "_" + requested)
	return styled if player.has_animation(styled) else StringName(requested)


func _clip_for_state(state: Dictionary, move: MoveData) -> StringName:
	if move != null:
		return _resolve_clip(move.animation_name)
	match String(state.get("state", "idle")):
		"walk":
			var velocity: Vector2 = state.get("velocity", Vector2.ZERO)
			if velocity.x * int(state.get("facing", 1)) < -0.01:
				var backward := _style_clip("walk_back")
				if player.has_animation(backward): return backward
			return _style_clip("walk")
		"crouch":
			return _style_clip("crouch")
		"block", "guard", "blockstun":
			return _style_clip("guard")
		"jump", "airborne":
			return _style_clip("jump")
		"hit", "hitstun", "guard_break":
			return _style_clip("hit")
		"down", "knockdown":
			return _style_clip("down")
		"dodge":
			return _style_clip("dodge")
		"burst":
			return _style_clip("burst")
	return _style_clip("idle")


func _load_external_clips(library: AnimationLibrary, skeleton_path: NodePath) -> void:
	if not DirAccess.dir_exists_absolute(EXTERNAL_ANIMATIONS):
		return
	# Resource filenames stay stable here when exports remap .tres to binaries.
	var files := ResourceLoader.list_directory(EXTERNAL_ANIMATIONS)
	files.sort()
	for filename in files:
		if filename.get_extension().to_lower() != "tres":
			continue
		var resource := ResourceLoader.load(EXTERNAL_ANIMATIONS.path_join(filename))
		if not resource is AnimationLibrary:
			push_warning("AvatarActor: skipping non-library animation asset " + filename)
			continue
		var external := resource as AnimationLibrary
		if external.has_meta("target_fighter") and str(external.get_meta("target_fighter")) != fighter_id:
			continue
		for clip_name in external.get_animation_list():
			var original := external.get_animation(clip_name)
			var clip := original.duplicate(true) as Animation
			var rotations := 0
			# External files must already be retargeted to this humanoid's rests.
			# Remap only bone tracks. Event tracks and scene transforms cannot
			# move the actor or execute callbacks during a preview seek.
			for track in range(clip.get_track_count() - 1, -1, -1):
				var type := clip.track_get_type(track)
				var path := clip.track_get_path(track)
				if type not in [Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D, Animation.TYPE_SCALE_3D] or path.get_subname_count() != 1:
					clip.remove_track(track)
					continue
				var bone_name := String(path.get_subname(0))
				if skeleton.find_bone(bone_name) < 0:
					clip.remove_track(track)
					continue
				clip.track_set_path(track, NodePath("%s:%s" % [skeleton_path, bone_name]))
				if type == Animation.TYPE_ROTATION_3D:
					rotations += 1
			if rotations == 0 or clip.length <= 0.0 or clip_name == &"RESET":
				push_warning("AvatarActor: keeping authored fallback for invalid external clip " + String(clip_name))
				continue
			if library.has_animation(clip_name):
				library.remove_animation(clip_name)
			library.add_animation(clip_name, clip)
