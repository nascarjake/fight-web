extends SceneTree
## Offline 60 Hz retarget/bake. Source FBXs remain outside the exported game.
const SOURCE_DIR := "res://../work/mixamo/ch02_nonpbr_61bcdb20_7b85_4f2e_a109_2a0fbd54af78"
const OUTPUT := "res://assets/animations/kai_mixamo.tres"
const SPECS := [
	{"source":"kai_idle", "clip":"kai_idle", "loop":true},
	{"source":"kai_step_forward", "clip":"kai_walk", "loop":true},
	{"source":"kai_step_backward", "clip":"kai_walk_back", "loop":true},
	{"source":"kai_jab", "clip":"kai_jab", "move":"jab", "anchor":"LeftHand"},
	{"source":"kai_cross", "clip":"kai_cross", "move":"cross", "anchor":"RightHand"},
	{"source":"kai_low_kick", "clip":"kai_low_kick", "move":"low_kick", "anchor":"RightFoot"},
	{"source":"kai_uppercut", "clip":"kai_launcher", "move":"launcher", "anchor":"RightHand"},
	{"source":"kai_hit", "clip":"kai_hit", "duration":0.4},
	{"source":"kai_knockdown", "clip":"kai_down", "ground":false},
	{"source":"kai_getup", "clip":"kai_getup", "ground":false},
	{"source":"body_hook", "clip":"kai_body_hook", "move":"body_hook", "anchor":"RightHand"},
	{"source":"knee", "clip":"kai_knee", "move":"knee", "anchor":"RightLowerLeg"},
	{"source":"kick_spin", "clip":"kai_spin_kick", "move":"spin_kick", "anchor":"RightFoot"},
	{"source":"kick_side", "clip":"kai_side_kick", "move":"side_kick", "anchor":"RightFoot"},
	{"source":"dodge_advance", "clip":"kai_dodge", "move":"dodge", "anchor":""},
	{"source":"elbow", "clip":"kai_burst", "move":"burst", "anchor":"RightHand"},
	{"source":"hook_rear", "clip":"kai_finisher", "move":"finisher", "anchor":"RightHand"},
]
var target: Skeleton3D
var actor: AvatarActor
var source: Skeleton3D
var source_player: AnimationPlayer
var source_clip: Animation
var mapping: Dictionary
var source_start: Vector3
var source_end: Vector3
var height_ratio: float
var report: Array = []
var library := AnimationLibrary.new()
var neutral_pose: Array[Transform3D] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var folder := ProjectSettings.globalize_path(SOURCE_DIR)
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): folder = args[0]
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("manifest.json")))
	if not manifest is Dictionary:
		push_error("Missing Mixamo collection manifest: " + folder)
		quit(1)
		return
	actor = AvatarActor.new()
	root.add_child(actor)
	actor.setup(false, "kai")
	target = actor.skeleton
	library.set_meta("target_fighter", "kai")
	library.set_meta("target_model", AvatarActor.MODEL_PATH)
	library.set_meta("source", "Mixamo / CH02_NONPBR")
	library.set_meta("bake_fps", 60)
	for spec in SPECS:
		var entry: Dictionary = {}
		for value in manifest.completed.values():
			if value.role == spec.source: entry = value
		if entry.is_empty() or FileAccess.get_sha256(folder.path_join(entry.file)) != entry.sha256:
			push_error("Missing or modified source: " + str(spec.source))
			quit(1)
			return
		var document := FBXDocument.new()
		var state := FBXState.new()
		var error := document.append_from_file(folder.path_join(entry.file), state)
		if error != OK:
			push_error("FBX read failed: " + str(spec.source))
			quit(1)
			return
		var scene := document.generate_scene(state, 60, false, false)
		root.add_child(scene)
		source = scene.find_children("*", "Skeleton3D", true, false)[0]
		source_player = scene.find_children("*", "AnimationPlayer", true, false)[0]
		source_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var name := source_player.get_animation_list()[0]
		source_clip = source_player.get_animation(name)
		source_player.play(name, 0.0)
		mapping = _bone_map()
		height_ratio = target.get_bone_global_rest(target.find_bone("Hips")).origin.y / source.get_bone_global_rest(source.find_bone("mixamorig_Hips")).origin.y
		_sample_source(0)
		source_start = source.get_bone_global_pose(0).origin
		_sample_source(source_clip.length)
		source_end = source.get_bone_global_pose(0).origin
		var baked := _bake(spec)
		baked.set_meta("source_sha256", entry.sha256)
		baked.set_meta("source_description", entry.description)
		library.add_animation(spec.clip, baked)
		scene.free()
	_compose_super()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/animations"))
	var error := ResourceSaver.save(library, OUTPUT)
	if error != OK:
		push_error("Could not save retargeted library.")
		quit(1)
		return
	var output := FileAccess.open("res://assets/animations/kai_mixamo_report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"fighter":"kai", "bake_fps":60, "clips":report}, "  ") + "\n")
	actor.free()
	print("Baked ", library.get_animation_list().size(), " Kai clips to ", OUTPUT)
	quit()

func _bone_map() -> Dictionary:
	var names := {"Hips":"Hips", "Spine":"Spine", "Chest":"Spine1", "UpperChest":"Spine2", "Neck":"Neck", "Head":"Head"}
	for side in ["Left", "Right"]:
		for pair in [["Shoulder","Shoulder"],["UpperArm","Arm"],["LowerArm","ForeArm"],["Hand","Hand"],["UpperLeg","UpLeg"],["LowerLeg","Leg"],["Foot","Foot"],["Toes","ToeBase"]]:
			names[side + pair[0]] = side + pair[1]
		for finger in ["Index", "Middle", "Ring", "Little", "Thumb"]:
			var parts := ["Metacarpal","Proximal","Distal"] if finger == "Thumb" else ["Proximal","Intermediate","Distal"]
			for i in 3:
				names[side + finger + parts[i]] = side + "Hand" + ("Pinky" if finger == "Little" else finger) + str(i + 1)
	var result := {}
	for name in names:
		var to := target.find_bone(name)
		var from := source.find_bone("mixamorig_" + names[name])
		if to >= 0 and from >= 0: result[to] = from
	assert(result.size() >= 50, "Required humanoid bones could not be mapped")
	return result

func _sample_source(time: float) -> void:
	source_player.seek(clampf(time, 0, source_clip.length), true, true)
	source.force_update_all_bone_transforms()

func _retarget(time: float, ground: bool) -> void:
	_sample_source(time)
	target.reset_bone_poses()
	for bone in target.get_bone_count():
		if not mapping.has(bone): continue
		var from: int = mapping[bone]
		var delta := source.get_bone_global_pose(from).basis * source.get_bone_global_rest(from).basis.inverse()
		var desired := delta * target.get_bone_global_rest(bone).basis
		var parent := target.get_bone_parent(bone)
		var parent_basis := target.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
		target.set_bone_pose_rotation(bone, (parent_basis.inverse() * desired).orthonormalized().get_rotation_quaternion())
	var hips := target.find_bone("Hips")
	var displacement := source.get_bone_global_pose(0).origin - source.get_bone_global_rest(0).origin
	# Remove traversal, keep weight shifts and vertical motion. Simulation owns travel.
	var baseline := source_start.lerp(source_end, time / source_clip.length)
	displacement.x = clampf(source.get_bone_global_pose(0).origin.x - baseline.x, -.12, .12)
	displacement.z = clampf(source.get_bone_global_pose(0).origin.z - baseline.z, -.12, .12)
	target.set_bone_pose_position(hips, target.get_bone_rest(hips).origin + displacement * height_ratio)
	if ground:
		_ground()

func _ground() -> void:
	var lowest := INF
	var rest_lowest := INF
	for name in ["LeftFoot", "RightFoot", "LeftToes", "RightToes"]:
		var bone := target.find_bone(name)
		lowest = minf(lowest, target.get_bone_global_pose(bone).origin.y)
		rest_lowest = minf(rest_lowest, target.get_bone_global_rest(bone).origin.y)
	var hips := target.find_bone("Hips")
	var position := target.get_bone_pose_position(hips)
	position.y += rest_lowest - lowest
	target.set_bone_pose_position(hips, position)

func _bake(spec: Dictionary) -> Animation:
	var move: MoveData
	for candidate in FighterCatalog.moves("kai"):
		if candidate.id == spec.get("move", ""): move = candidate
	var peak := 0.0
	var begin := 0.0
	var end := source_clip.length
	if move != null and not str(spec.get("anchor", "")).is_empty():
		var best := -INF
		var bone := source.find_bone("mixamorig_" + ("RightLeg" if spec.anchor == "RightLowerLeg" else str(spec.anchor)))
		for i in int(source_clip.length * 60) + 1:
			var t := float(i) / 60
			_sample_source(t)
			var point := source.get_bone_global_pose(bone).origin - source.get_bone_global_pose(0).origin
			var score := point.z
			if score > best:
				best = score
				peak = t
		begin = maxf(0, peak - .28)
		end = minf(source_clip.length, peak + .55)
	var duration := float(move.total_frames()) / 60 if move != null else float(spec.get("duration", end - begin))
	var clip := Animation.new()
	clip.length = duration
	clip.loop_mode = Animation.LOOP_LINEAR if spec.get("loop", false) else Animation.LOOP_NONE
	var frames := maxi(2, int(ceil(duration * 60)))
	var poses: Array = []
	for frame in frames + 1:
		var progress := float(frame) / frames
		var time := lerpf(begin, end, progress)
		if move != null and move.active > 0:
			var f := progress * move.total_frames()
			var active_end := move.startup + move.active - 1
			if f < move.startup:
				time = lerpf(begin, maxf(begin, peak - .025), f / move.startup)
			elif f <= active_end:
				time = lerpf(peak - .025, peak + .025, (f - move.startup) / maxi(1, move.active - 1))
			else:
				time = lerpf(peak + .025, end, (f - active_end) / (move.total_frames() - active_end))
		_retarget(time, bool(spec.get("ground", true)))
		if move != null:
			var move_frame := progress * move.total_frames()
			# A five-frame jab cannot carry the source recording's full stepping lunge.
			# Keep its base planted; retain more of the weight transfer for the heavy.
			if move.id in ["jab", "cross"]:
				var weight := .3 if move.id == "jab" else .7
				for bone in target.get_bone_count():
					var name := target.get_bone_name(bone)
					if name == "Hips" or name.ends_with("Leg") or name.ends_with("Foot") or name.ends_with("Toes"):
						var grounded := neutral_pose[bone].interpolate_with(target.get_bone_pose(bone), weight)
						target.set_bone_pose_rotation(bone, grounded.basis.get_rotation_quaternion())
						if name == "Hips": target.set_bone_pose_position(bone, grounded.origin)
				_ground()
			if not str(spec.get("anchor", "")).is_empty(): _align_contact(move, move_frame, str(spec.anchor))
			# Enter and leave each technique through the same recorded fighting stance.
			var neutral_weight := 1.0 - smoothstep(0, 3, move_frame)
			neutral_weight = maxf(neutral_weight, smoothstep(move.total_frames() - 5, move.total_frames(), move_frame))
			for bone in target.get_bone_count():
				var blended := target.get_bone_pose(bone).interpolate_with(neutral_pose[bone], neutral_weight)
				target.set_bone_pose_rotation(bone, blended.basis.get_rotation_quaternion())
				if target.get_bone_name(bone) == "Hips": target.set_bone_pose_position(bone, blended.origin)
		var pose: Array[Transform3D] = []
		for bone in target.get_bone_count(): pose.append(target.get_bone_pose(bone))
		poses.append(pose)
	if str(spec.clip) == "kai_idle": neutral_pose = poses[0]
	# Close loops smoothly over the last 120 ms; avoid an end-to-start seam.
	if clip.loop_mode != Animation.LOOP_NONE:
		var seam := mini(frames / 3, 8)
		for frame in range(frames - seam, frames + 1):
			var weight := smoothstep(0, 1, float(frame - (frames - seam)) / seam)
			for bone in target.get_bone_count():
				poses[frame][bone] = poses[frame][bone].interpolate_with(poses[0][bone], weight)
	for bone in target.get_bone_count():
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track, NodePath("Skeleton:" + target.get_bone_name(bone)))
		var constant := true
		var first: Quaternion = poses[0][bone].basis.get_rotation_quaternion()
		for frame in frames + 1:
			if first.angle_to(poses[frame][bone].basis.get_rotation_quaternion()) > .0001:
				constant = false
				break
		for frame in frames + 1:
			if constant and frame not in [0, frames]: continue
			clip.rotation_track_insert_key(track, float(frame) / frames * duration, poses[frame][bone].basis.get_rotation_quaternion())
	var hips := target.find_bone("Hips")
	var track := clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(track, NodePath("Skeleton:Hips"))
	for frame in frames + 1:
		clip.position_track_insert_key(track, float(frame) / frames * duration, poses[frame][hips].origin)
	clip.set_meta("retargeted", true)
	report.append({"clip":spec.clip, "source":spec.source, "source_seconds":source_clip.length, "duration":duration, "source_contact":peak, "trim_start":begin, "trim_end":end, "mapped_bones":mapping.size(), "grounded":spec.get("ground",true)})
	print("BAKED ", spec.clip, " source ", source_clip.length, " contact ",peak, " -> ",duration)
	return clip

func _align_contact(move: MoveData, frame: float, anchor: String) -> void:
	var weight := smoothstep(0, move.startup, frame)
	if frame > move.startup + move.active - 1:
		weight = 1.0 - smoothstep(move.startup + move.active - 1, move.startup + move.active + 8, frame)
	if weight <= 0: return
	var bone := target.find_bone(anchor)
	var current := target.get_bone_global_pose(bone)
	var local_to_actor := actor.global_transform.affine_inverse() * target.global_transform
	var point := local_to_actor * current.origin
	var box := move.attack_rect_at(clampi(int(frame), move.startup, move.startup + move.active - 1))
	var goal := Vector3(point.x, box.get_center().y, box.get_center().x)
	if move.id == "launcher":
		goal.y += lerpf(-.22, .32, clampf((frame - move.startup) / (move.active - 1), 0, 1))
	goal = current.origin.lerp(local_to_actor.affine_inverse() * goal, weight)
	if anchor == "RightLowerLeg":
		_aim(target.find_bone("RightUpperLeg"), bone, goal)
		return
	var side := "Left" if anchor.begins_with("Left") else "Right"
	var limb := "Leg" if anchor.ends_with("Foot") else "Arm"
	var upper := target.find_bone(side + "Upper" + limb)
	var lower := target.find_bone(side + "Lower" + limb)
	var origin := target.get_bone_global_pose(upper).origin
	var middle := target.get_bone_global_pose(lower).origin
	var length_a := origin.distance_to(middle)
	var length_b := middle.distance_to(current.origin)
	var direction := (goal - origin).normalized()
	var distance := clampf(origin.distance_to(goal), absf(length_a - length_b) + .001, length_a + length_b - .001)
	var pole := middle - origin
	var bend := (pole - direction * pole.dot(direction)).normalized()
	if bend.length_squared() < .01: bend = Vector3.DOWN
	var along := (length_a * length_a - length_b * length_b + distance * distance) / (2 * distance)
	var elbow := origin + direction * along + bend * sqrt(maxf(0, length_a * length_a - along * along))
	_aim(upper, lower, elbow)
	_aim(lower, bone, origin + direction * distance)
	# Preserve the captured wrist/ankle orientation after adjusting its parent chain.
	_global_basis(bone, current.basis)

func _aim(bone: int, child: int, point: Vector3) -> void:
	var pose := target.get_bone_global_pose(bone)
	var from := (target.get_bone_global_pose(child).origin - pose.origin).normalized()
	var to := (point - pose.origin).normalized()
	_global_basis(bone, Basis(Quaternion(from, to)) * pose.basis)

func _global_basis(bone: int, basis: Basis) -> void:
	var parent := target.get_bone_parent(bone)
	var parent_basis := target.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	target.set_bone_pose_rotation(bone, (parent_basis.inverse() * basis).orthonormalized().get_rotation_quaternion())


func _compose_super() -> void:
	# Paired with SuperDirector's four actual contact beats, not a repeating pose loop.
	var segments := [[24,62,42,"body_hook"], [62,91,70,"knee"], [91,136,108,"launcher"], [136,184,160,"spin_kick"]]
	var clip := Animation.new()
	clip.length = 3.5
	var idle := library.get_animation("kai_idle")
	for track in idle.get_track_count():
		var type := idle.track_get_type(track)
		clip.add_track(type)
		clip.track_set_path(track, idle.track_get_path(track))
		for frame in 211:
			var sample := idle
			var time := float(frame) / 60
			for segment in segments:
				if frame < segment[0] or frame >= segment[1]: continue
				sample = library.get_animation("kai_" + segment[3])
				var move: MoveData
				for candidate in FighterCatalog.moves("kai"):
					if candidate.id == segment[3]: move = candidate
				var contact := float(move.startup + move.active / 2) / 60
				if frame <= segment[2]: time = remap(frame, segment[0], segment[2], 0, contact)
				elif frame <= segment[2] + 3: time = contact
				else: time = remap(frame, segment[2] + 3, segment[1], contact, sample.length)
				break
			if type == Animation.TYPE_ROTATION_3D:
				clip.rotation_track_insert_key(track, float(frame) / 60, sample.rotation_track_interpolate(track, minf(time, sample.length)))
			else:
				clip.position_track_insert_key(track, float(frame) / 60, sample.position_track_interpolate(track, minf(time, sample.length)))
	clip.set_meta("retargeted", true)
	clip.set_meta("source_description", "Solar Requiem: body hook, knee, rising strike, spinning back kick")
	var sources := {}
	for segment in segments:
		var key: String = "kai_" + segment[3]
		sources[key] = library.get_animation(key).get_meta("source_sha256")
	clip.set_meta("source_sha256", JSON.stringify(sources).sha256_text())
	clip.set_meta("source_hashes", sources)
	report.append({"clip":"kai_cinematic", "duration":3.5, "contact_frames":[42,70,108,160], "source_hashes":sources})
	library.add_animation("kai_cinematic", clip)
