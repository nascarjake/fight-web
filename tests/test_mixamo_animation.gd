extends SceneTree
## Runtime acceptance checks for the first retargeted content batch.
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("_run")
func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
func _run() -> void:
	var actor := AvatarActor.new()
	root.add_child(actor)
	actor.setup(false, "kai")
	var library := load("res://assets/animations/kai_mixamo.tres") as AnimationLibrary
	_check(library.get_meta("target_fighter") == "kai", "library is scoped to Kai's target rig")
	for name in library.get_animation_list():
		var clip := actor.player.get_animation(name)
		_check(clip.get_meta("retargeted", false), "runtime actually loads retargeted " + name)
		_check(str(clip.get_meta("source_sha256", "")).length() == 64, name + " records source provenance")
		for track in clip.get_track_count():
			_check(clip.track_get_type(track) in [Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D], name + " contains only safe bone tracks")
			if clip.track_get_type(track) == Animation.TYPE_POSITION_3D:
				_check(clip.track_get_path(track).get_subname(0) == "Hips", "root travel cannot move actor or stretch limbs")
		if clip.loop_mode != Animation.LOOP_NONE:
			for track in clip.get_track_count():
				var last := clip.track_get_key_count(track) - 1
				var a = clip.track_get_key_value(track, 0)
				var b = clip.track_get_key_value(track, last)
				_check(a.is_equal_approx(b), name + " loop endpoints match")
	for move in FighterCatalog.moves("kai"):
		if move.id not in ["jab", "cross", "low_kick", "launcher", "body_hook", "knee", "spin_kick", "side_kick", "burst"]: continue
		for facing in [-1, 1]:
			for frame in range(move.startup, move.startup + move.active):
				actor.apply_state({"position":Vector2.ZERO, "facing":facing, "move":move, "move_frame":frame})
				actor.preview_move(move, frame)
				var anchor := actor.presentation_anchor(move.visual_anchor)
				var point := Vector2(anchor.x * facing, anchor.y)
				_check(move.attack_rect_at(frame).grow(.08).has_point(point), move.id + " contact stays within its active hitbox at frame " + str(frame))
		actor.preview_move(move, move.total_frames())
		var recovered := _snapshot(actor)
		actor.reset_pose()
		_check(recovered == _snapshot(actor), move.id + " recovers to shared guard without a pose pop")
	for facing in [-1, 1]:
		for direction in [-1, 1]:
			var state := {"position":Vector2.ZERO, "facing":facing, "state":"walk", "velocity":Vector2(direction * facing * 3.9, 0)}
			actor.apply_state(state)
			_check(actor.player.current_animation == ("kai_walk" if direction > 0 else "kai_walk_back"), "walk direction follows facing")
			for tick in 8: actor.apply_state(state)
			var pose := _snapshot(actor)
			var time := actor.player.current_animation_position
			for tick in 8: actor.apply_state(state, false)
			_check(pose == _snapshot(actor) and is_equal_approx(time,actor.player.current_animation_position), "hitstop freezes locomotion and transition")
	actor.reset_pose()
	for name in ["kai_idle", "kai_walk", "kai_walk_back", "kai_jab", "kai_cross", "kai_low_kick", "kai_launcher"]:
		actor.player.play(name, 0)
		for frame in int(actor.player.get_animation(name).length * 60) + 1:
			actor.player.seek(float(frame) / 60, true, true)
			var lowest := INF
			for foot in ["LeftFoot", "RightFoot", "LeftToes", "RightToes"]:
				lowest = minf(lowest, actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone(foot)).origin).y)
			_check(lowest >= -.005 and lowest < .16, name + " supporting foot remains near the floor")
	actor.set_fighter("neon")
	_check(not actor.player.get_animation("neon_idle").get_meta("retargeted", false), "Kai's retargeting cannot replace Neon's content")
	_check(not actor.player.has_animation("kai_jab"), "Kai's rig-specific library is not installed on Neon")
	actor.free()
	print("Mixamo animation: %d checks; %d failures." % [checks,failures])
	quit(failures)
func _snapshot(actor: AvatarActor) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	for bone in actor.skeleton.get_bone_count():
		var q := actor.skeleton.get_bone_pose_rotation(bone)
		var p := actor.skeleton.get_bone_pose_position(bone)
		# Float32 roundoff from interpolation should not masquerade as a visible seam.
		for value in [q.x,q.y,q.z,q.w,p.x,p.y,p.z]: result.append(snappedf(value,.00001))
	return result
