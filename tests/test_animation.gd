extends SceneTree
## Run with Godot --headless --path desktop --script tests/test_animation.gd.

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var actor := AvatarActor.new()
	root.add_child(actor)
	actor.setup()
	_check(actor.skeleton != null, "local avatar imports with a skeleton")
	_check(actor.player != null, "native AnimationPlayer is initialized")
	if actor.skeleton == null or actor.player == null:
		actor.queue_free()
		await process_frame
		quit(failures)
		return
	for clip in ["idle", "walk", "jump", "guard", "hit", "down", "jab", "cross", "low_kick", "launcher", "dodge", "burst"]:
		_check(actor.animation_names().has(clip), "required clip exists: " + clip)
	var state := {"position": Vector2(1.2, 0.4), "facing": 1, "state": "startup", "move": null, "move_frame": 0}
	for move in MoveCatalog.defaults():
		state.move = move
		for frame in move.total_frames():
			state.move_frame = frame
			actor.apply_state(state)
			var expected := actor.player.get_animation(move.animation_name).length * float(frame) / float(move.total_frames())
			_check(absf(actor.player.current_animation_position - expected) < 0.0001, "%s follows simulation frame %d" % [move.id, frame])
		_check(actor.position.is_equal_approx(Vector3(1.2, 0.4, 0)), "simulation position maps to the fight plane")
		var held_time := actor.player.current_animation_position
		var held_pose: Array[Quaternion] = []
		for bone in actor.skeleton.get_bone_count():
			held_pose.append(actor.skeleton.get_bone_pose_rotation(bone))
		for tick in 8:
			actor.apply_state(state, false)
		_check(is_equal_approx(actor.player.current_animation_position, held_time), "hitstop freezes clip time")
		for bone in actor.skeleton.get_bone_count():
			_check(actor.skeleton.get_bone_pose_rotation(bone).is_equal_approx(held_pose[bone]), "hitstop freezes bone %d" % bone)
		actor.preview_move(move, move.startup)
		var scrub_time := actor.player.get_animation(move.animation_name).length * float(move.startup) / float(move.total_frames())
		_check(absf(actor.player.current_animation_position - scrub_time) < 0.0001, "preview seeks to the requested exact frame")
		var elbow := actor.skeleton.find_bone("LeftLowerArm")
		var scrub_pose := actor.skeleton.get_bone_pose_rotation(elbow)
		actor.preview_move(move, move.total_frames() - 1)
		actor.preview_move(move, move.startup)
		_check(actor.skeleton.get_bone_pose_rotation(elbow).is_equal_approx(scrub_pose), "preview does not depend on the previous frame")
	for clip in actor.animation_names():
		actor.player.stop(true)
		actor.player.play(clip, 0.0)
		for sample in 11:
			actor.player.seek(actor.player.get_animation(clip).length * float(sample) / 10.0, true)
			for bone in actor.skeleton.get_bone_count():
				var transform := actor.skeleton.get_bone_global_pose(bone)
				_check(transform.origin.is_finite() and transform.basis.is_finite(), "finite %s pose at bone %d" % [clip, bone])
	for neutral_state in ["idle", "walk", "jump", "block", "crouch", "hitstun", "down"]:
		actor.reset_pose()
		var neutral := {"position": Vector2.ZERO, "facing": 1, "state": neutral_state, "move": null, "move_frame": -1, "stun": 20 if neutral_state == "hitstun" else 0}
		actor.apply_state(neutral)
		var initial_time := actor.player.current_animation_position
		for tick in 6:
			actor.apply_state(neutral)
		_check(absf(actor.player.current_animation_position - initial_time - .1) < .0001, neutral_state + " progresses without MoveData")
		var paused_time := actor.player.current_animation_position
		var paused_poses: Array[Transform3D] = []
		for bone in actor.skeleton.get_bone_count():
			paused_poses.append(actor.skeleton.get_bone_pose(bone))
		for tick in 8:
			actor.apply_state(neutral, false)
		_check(is_equal_approx(actor.player.current_animation_position, paused_time), neutral_state + " time freezes during hitstop")
		for bone in actor.skeleton.get_bone_count():
			_check(actor.skeleton.get_bone_pose(bone).is_equal_approx(paused_poses[bone]), neutral_state + " pose freezes during hitstop")
	actor.reset_pose()
	for bone_name in ["LeftLowerArm", "RightLowerArm", "LeftLowerLeg", "RightLowerLeg", "LeftIndexIntermediate", "RightIndexIntermediate"]:
		var bone := actor.skeleton.find_bone(bone_name)
		var rest := actor.skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
		var posed := actor.skeleton.get_bone_pose_rotation(bone)
		_check(rest.angle_to(posed) > 0.15, "idle articulates the joint: " + bone_name)
	print("Animation checks: %d failures; %d native skeletal clips." % [failures, actor.animation_names().size()])
	actor.queue_free()
	await process_frame
	quit(failures)
