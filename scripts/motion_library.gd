class_name MotionLibrary
extends RefCounted
## Authored prototype poses baked into ordinary Godot skeletal animation tracks.
## These clips are keyframed here; they are not motion-capture recordings.
## Limb targets are solved once while building the library, never every frame.

var _skeleton: Skeleton3D
var _path: NodePath
var _rest: Array[Transform3D] = []
var _pose: Array[Transform3D] = []
var _parents: PackedInt32Array = []
var _bones: Dictionary = {}
var _scale: float = 1.0
var _style: String = "kai"
var _active_stance: Dictionary = {}


static func build(skeleton: Skeleton3D, skeleton_path: NodePath, style: String = "kai") -> AnimationLibrary:
	var author := MotionLibrary.new()
	author._skeleton = skeleton
	author._path = skeleton_path
	author._style = style
	for i in skeleton.get_bone_count():
		author._rest.append(skeleton.get_bone_rest(i))
		author._parents.append(skeleton.get_bone_parent(i))
		author._bones[skeleton.get_bone_name(i)] = i
	var hips := skeleton.find_bone("Hips")
	if hips >= 0:
		author._scale = skeleton.get_bone_global_rest(hips).origin.y / 1.026783
	return author._build_library()


func _build_library() -> AnimationLibrary:
	var library := AnimationLibrary.new()
	_add(library, "showcase", 3.8, true, [
		[0.0, {"hips": Vector3(0.025, -0.035, 0), "spine": Vector3(1, -7, 0), "chest": Vector3(0, 3, 0), "head": Vector3(-2, -4, 0), "left_hand": Vector3(0.25, 0.88, 0.06), "right_hand": Vector3(-0.25, 0.88, 0.04), "left_aim": Vector3(0, -1, 0), "right_aim": Vector3(0, -1, 0), "fist": 0.35}],
		[0.5, {"hips": Vector3(0.025, -0.028, 0), "spine": Vector3(0, -7, 0), "chest": Vector3(-1, 3, 0), "head": Vector3(-2, -1, 0), "left_hand": Vector3(0.25, 0.89, 0.06), "right_hand": Vector3(-0.25, 0.89, 0.04), "left_aim": Vector3(0, -1, 0), "right_aim": Vector3(0, -1, 0), "fist": 0.35}],
		[1.0, {"hips": Vector3(0.025, -0.035, 0), "spine": Vector3(1, -7, 0), "chest": Vector3(0, 3, 0), "head": Vector3(-2, -4, 0), "left_hand": Vector3(0.25, 0.88, 0.06), "right_hand": Vector3(-0.25, 0.88, 0.04), "left_aim": Vector3(0, -1, 0), "right_aim": Vector3(0, -1, 0), "fist": 0.35}],
	])
	_add(library, "victory", 3.2, false, [
		[0.0, {}],
		[0.18, {"hips": Vector3(0.02, -0.035, 0), "spine": Vector3(0, -5, 0), "chest": Vector3(0, 5, 0), "left_hand": Vector3(0.26, 0.9, 0.06), "right_hand": Vector3(-0.22, 1.42, 0.20), "left_aim": Vector3(0, -1, 0), "fist": 0.75}],
		[0.42, {"hips": Vector3(0.02, -0.025, 0), "spine": Vector3(-3, -4, -2), "chest": Vector3(-4, 5, 0), "head": Vector3(-12, -5, 0), "left_hand": Vector3(0.26, 0.9, 0.06), "right_hand": Vector3(-0.32, 1.97, 0.1), "left_aim": Vector3(0, -1, 0), "right_aim": Vector3(0, 1, 0), "fist": 1.0}],
		[0.68, {"hips": Vector3(0.02, -0.025, 0), "spine": Vector3(-3, -4, -2), "chest": Vector3(-4, 5, 0), "head": Vector3(-8, -5, 0), "left_hand": Vector3(0.26, 0.9, 0.06), "right_hand": Vector3(-0.32, 1.96, 0.1), "left_aim": Vector3(0, -1, 0), "right_aim": Vector3(0, 1, 0), "fist": 1.0}],
		[1.0, {"hips": Vector3(0.025, -0.035, 0), "spine": Vector3(0, -8, 0), "chest": Vector3(0, 5, 0), "head": Vector3(-2, -8, 0), "left_hand": Vector3(0.26, 0.9, 0.06), "right_hand": Vector3(-0.18, 1.30, 0.24), "left_aim": Vector3(0, -1, 0), "fist": 0.8}],
	])
	_add(library, "finisher", 1.3, false, [
		[0.0, {}],
		[0.2, {"hips": Vector3(0, -0.22, -0.04), "spine": Vector3(17, -24, 0), "chest": Vector3(8, -18, 0), "left_hand": Vector3(0.16, 1.17, 0.04), "right_hand": Vector3(-0.15, 1.15, 0.04), "fist": 0.4}],
		[0.33, {"hips": Vector3(0, -0.05, 0.13), "spine": Vector3(12, 2, 0), "chest": Vector3(8, 4, 0), "left_hand": Vector3(0.12, 1.35, 0.71), "right_hand": Vector3(-0.12, 1.32, 0.72), "left_aim": Vector3(0, 1, 0), "right_aim": Vector3(0, 1, 0), "right_pitch": 30.0, "fist": 0.0}],
		[0.47, {"hips": Vector3(0, -0.05, 0.12), "spine": Vector3(12, 2, 0), "chest": Vector3(8, 4, 0), "left_hand": Vector3(0.12, 1.35, 0.70), "right_hand": Vector3(-0.12, 1.32, 0.71), "left_aim": Vector3(0, 1, 0), "right_aim": Vector3(0, 1, 0), "right_pitch": 28.0, "fist": 0.0}],
		[0.73, {"hips": Vector3(0, -0.1, 0.03), "chest": Vector3(6, 7, 0), "left_hand": Vector3(0.22, 1.28, 0.37), "right_hand": Vector3(-0.22, 1.23, 0.36), "fist": 0.6}],
		[1.0, {}],
	])
	_add(library, "idle", 1.4, true, [
		[0.0, {}],
		[0.25, {"hips": Vector3(-0.008, -0.055, 0.003), "chest": Vector3(3, 14, -1), "left_hand": Vector3(0.19, 1.40, 0.30)}],
		[0.55, {"hips": Vector3(0.005, -0.068, -0.004), "chest": Vector3(4, 11, 1)}],
		[0.8, {"hips": Vector3(0.004, -0.06, 0.002), "right_hand": Vector3(-0.16, 1.34, 0.25)}],
		[1.0, {}],
	])
	_add(library, "walk", 0.62, true, [
		[0.0, {"hips": Vector3(0.015, -0.075, 0), "left_foot": Vector3(0.13, 0.13, 0.27), "right_foot": Vector3(-0.14, 0.15, -0.24), "right_pitch": 18.0}],
		[0.22, {"hips": Vector3(0.01, -0.045, 0.018), "left_foot": Vector3(0.13, 0.13, 0.08), "right_foot": Vector3(-0.14, 0.24, -0.08), "right_pitch": 28.0}],
		[0.5, {"hips": Vector3(-0.015, -0.075, 0), "left_foot": Vector3(0.13, 0.15, -0.24), "right_foot": Vector3(-0.14, 0.13, 0.27), "left_pitch": 18.0}],
		[0.72, {"hips": Vector3(-0.01, -0.045, 0.018), "left_foot": Vector3(0.13, 0.24, -0.08), "right_foot": Vector3(-0.14, 0.13, 0.08), "left_pitch": 28.0}],
		[1.0, {"hips": Vector3(0.015, -0.075, 0), "left_foot": Vector3(0.13, 0.13, 0.27), "right_foot": Vector3(-0.14, 0.15, -0.24), "right_pitch": 18.0}],
	])
	_add(library, "jump", 0.75, false, [
		[0.0, {"hips": Vector3(0, -0.18, 0.02), "spine": Vector3(16, -10, 0)}],
		[0.15, {"hips": Vector3(0, 0.02, 0), "left_foot": Vector3(0.13, 0.13, 0.08), "right_foot": Vector3(-0.14, 0.13, -0.06), "left_pitch": 18.0, "right_pitch": 18.0}],
		[0.4, {"hips": Vector3(0, -0.03, 0), "left_foot": Vector3(0.16, 0.53, 0.19), "right_foot": Vector3(-0.16, 0.43, -0.15), "spine": Vector3(11, -10, 0), "left_hand": Vector3(0.23, 1.48, 0.29), "right_hand": Vector3(-0.25, 1.42, 0.20)}],
		[0.76, {"hips": Vector3(0, -0.07, 0), "left_foot": Vector3(0.15, 0.23, 0.17), "right_foot": Vector3(-0.15, 0.26, -0.16)}],
		[1.0, {}],
	])
	_add(library, "guard", 0.7, true, [
		[0.0, {"hips": Vector3(0, -0.10, -0.02), "left_hand": Vector3(0.11, 1.45, 0.29), "right_hand": Vector3(-0.12, 1.42, 0.29), "chest": Vector3(10, 4, 0), "head": Vector3(-5, 0, 0)}],
		[0.5, {"hips": Vector3(-0.005, -0.105, -0.025), "left_hand": Vector3(0.11, 1.445, 0.28), "right_hand": Vector3(-0.12, 1.415, 0.28), "chest": Vector3(11, 4, 0), "head": Vector3(-5, 0, 0)}],
		[1.0, {"hips": Vector3(0, -0.10, -0.02), "left_hand": Vector3(0.11, 1.45, 0.29), "right_hand": Vector3(-0.12, 1.42, 0.29), "chest": Vector3(10, 4, 0), "head": Vector3(-5, 0, 0)}],
	])
	_add(library, "crouch", 0.6, true, [
		[0.0, {"hips": Vector3(0, -0.29, -0.04), "spine": Vector3(14, -10, 0), "left_hand": Vector3(0.17, 1.20, 0.28), "right_hand": Vector3(-0.16, 1.13, 0.23), "left_foot": Vector3(0.18, 0.13, 0.23), "right_foot": Vector3(-0.19, 0.13, -0.20)}],
		[1.0, {"hips": Vector3(0, -0.29, -0.04), "spine": Vector3(14, -10, 0), "left_hand": Vector3(0.17, 1.20, 0.28), "right_hand": Vector3(-0.16, 1.13, 0.23), "left_foot": Vector3(0.18, 0.13, 0.23), "right_foot": Vector3(-0.19, 0.13, -0.20)}],
	])
	_add(library, "hit", 0.38, false, [
		[0.0, {}],
		[0.16, {"hips": Vector3(0.03, -0.13, -0.05), "spine": Vector3(-15, -16, -7), "chest": Vector3(-12, -8, 6), "head": Vector3(-12, 10, 0), "left_hand": Vector3(0.34, 1.28, 0.05), "right_hand": Vector3(-0.31, 1.19, 0.08), "fist": 0.5}],
		[0.4, {"hips": Vector3(0.02, -0.14, -0.03), "spine": Vector3(-8, -13, -4), "chest": Vector3(-7, 0, 3), "left_hand": Vector3(0.30, 1.26, 0.14), "right_hand": Vector3(-0.26, 1.17, 0.16), "fist": 0.7}],
		[1.0, {}],
	])
	_add(library, "down", 0.75, false, [
		[0.0, {"hips": Vector3(0, -0.14, -0.04), "spine": Vector3(-20, -8, 0), "left_hand": Vector3(0.36, 1.17, 0.05), "right_hand": Vector3(-0.34, 1.10, 0.02), "fist": 0.3}],
		[0.3, {"hips": Vector3(0, -0.48, 0.04), "hip_rotation": Vector3(-48, 0, -5), "spine": Vector3(-8, 0, 0), "chest": Vector3(0, 0, 0), "left_hand": Vector3(0.38, 0.39, -0.32), "right_hand": Vector3(-0.36, 0.35, -0.23), "left_foot": Vector3(0.20, 0.24, 0.64), "right_foot": Vector3(-0.18, 0.25, 0.70), "fist": 0.0}],
		[0.62, {"hips": Vector3(0, -0.86, 0.13), "hip_rotation": Vector3(-86, 0, 0), "spine": Vector3(0, 0, 0), "chest": Vector3(0, 0, 0), "head": Vector3(10, 8, 0), "left_hand": Vector3(0.40, 0.10, -0.37), "right_hand": Vector3(-0.35, 0.10, -0.35), "left_foot": Vector3(0.21, 0.16, 0.92), "right_foot": Vector3(-0.17, 0.16, 0.91), "fist": 0.0}],
		[1.0, {"hips": Vector3(0, -0.86, 0.13), "hip_rotation": Vector3(-86, 0, 0), "spine": Vector3(0, 0, 0), "chest": Vector3(0, 0, 0), "head": Vector3(10, 8, 0), "left_hand": Vector3(0.40, 0.10, -0.37), "right_hand": Vector3(-0.35, 0.10, -0.35), "left_foot": Vector3(0.21, 0.16, 0.92), "right_foot": Vector3(-0.17, 0.16, 0.91), "fist": 0.0}],
	])
	_add(library, "jab", 0.34, false, [
		[0.0, {}],
		[0.15, {"chest": Vector3(4, 23, 0), "left_hand": Vector3(0.21, 1.37, 0.20), "hips": Vector3(0.01, -0.08, -0.02)}],
		[0.29, {"chest": Vector3(7, -18, 0), "hips": Vector3(0.005, -0.055, 0.035), "left_hand": Vector3(0.11, 1.40, 0.63), "left_aim": Vector3(0, 0, 1), "right_hand": Vector3(-0.15, 1.42, 0.25)}],
		[0.40, {"chest": Vector3(7, -17, 0), "hips": Vector3(0.005, -0.055, 0.035), "left_hand": Vector3(0.11, 1.40, 0.62), "left_aim": Vector3(0, 0, 1), "right_hand": Vector3(-0.15, 1.42, 0.25)}],
		[0.68, {"left_hand": Vector3(0.18, 1.36, 0.36), "chest": Vector3(4, 4, 0)}],
		[1.0, {}],
	])
	_add(library, "cross", 0.45, false, [
		[0.0, {}],
		[0.17, {"hip_rotation": Vector3(0, -12, 0), "chest": Vector3(2, -19, -2), "right_hand": Vector3(-0.20, 1.31, 0.12), "hips": Vector3(-0.025, -0.10, -0.02)}],
		[0.34, {"hip_rotation": Vector3(0, 15, 0), "spine": Vector3(10, 14, 0), "chest": Vector3(3, 20, 4), "right_hand": Vector3(-0.08, 1.40, 0.66), "right_aim": Vector3(0, 0, 1), "left_hand": Vector3(0.17, 1.45, 0.28), "hips": Vector3(0.01, -0.04, 0.07), "right_pitch": 28.0}],
		[0.45, {"hip_rotation": Vector3(0, 15, 0), "spine": Vector3(10, 14, 0), "chest": Vector3(3, 20, 4), "right_hand": Vector3(-0.08, 1.40, 0.65), "right_aim": Vector3(0, 0, 1), "left_hand": Vector3(0.17, 1.45, 0.28), "hips": Vector3(0.01, -0.04, 0.07), "right_pitch": 28.0}],
		[0.73, {"chest": Vector3(5, 7, 0), "right_hand": Vector3(-0.15, 1.31, 0.38)}],
		[1.0, {}],
	])
	_add(library, "low_kick", 0.55, false, [
		[0.0, {}],
		[0.2, {"hips": Vector3(0.06, -0.085, -0.01), "right_foot": Vector3(-0.13, 0.43, 0.14), "spine": Vector3(-5, -10, -5), "right_pitch": 15.0}],
		[0.36, {"hips": Vector3(0.06, -0.035, -0.025), "hip_rotation": Vector3(0, 13, 0), "spine": Vector3(-12, -13, -5), "chest": Vector3(3, 18, 0), "right_foot": Vector3(-0.09, 0.34, 0.77), "left_foot": Vector3(0.14, 0.13, 0.08), "right_pitch": 20.0, "right_hand": Vector3(-0.30, 1.22, 0.10)}],
		[0.45, {"hips": Vector3(0.06, -0.035, -0.025), "hip_rotation": Vector3(0, 13, 0), "spine": Vector3(-12, -13, -5), "chest": Vector3(3, 18, 0), "right_foot": Vector3(-0.09, 0.34, 0.76), "left_foot": Vector3(0.14, 0.13, 0.08), "right_pitch": 20.0, "right_hand": Vector3(-0.30, 1.22, 0.10)}],
		[0.68, {"hips": Vector3(0.03, -0.08, 0), "right_foot": Vector3(-0.14, 0.38, 0.20), "spine": Vector3(-3, -10, 0)}],
		[1.0, {}],
	])
	_add(library, "launcher", 0.64, false, [
		[0.0, {}],
		[0.17, {"hips": Vector3(-0.03, -0.24, -0.03), "spine": Vector3(18, -16, 6), "chest": Vector3(8, -15, 0), "right_hand": Vector3(-0.17, 1.04, 0.15), "left_hand": Vector3(0.14, 1.25, 0.27)}],
		[0.36, {"hips": Vector3(0.015, 0.015, 0.06), "hip_rotation": Vector3(0, 16, 0), "spine": Vector3(-4, 14, -4), "chest": Vector3(-7, 20, -6), "right_hand": Vector3(-0.06, 1.79, 0.38), "right_aim": Vector3(0, 1, 0.15), "left_hand": Vector3(0.19, 1.34, 0.23), "right_pitch": 22.0}],
		[0.48, {"hips": Vector3(0.015, 0.005, 0.05), "hip_rotation": Vector3(0, 16, 0), "spine": Vector3(-4, 14, -4), "chest": Vector3(-7, 20, -6), "right_hand": Vector3(-0.07, 1.76, 0.38), "right_aim": Vector3(0, 1, 0.15), "left_hand": Vector3(0.19, 1.34, 0.23)}],
		[0.73, {"hips": Vector3(0, -0.09, 0.015), "right_hand": Vector3(-0.18, 1.45, 0.28), "chest": Vector3(5, 18, 0)}],
		[1.0, {}],
	])
	_add(library, "dodge", 0.43, false, [
		[0.0, {}],
		[0.22, {"hips": Vector3(-0.05, -0.26, -0.10), "spine": Vector3(22, 26, -12), "chest": Vector3(9, 14, -8), "head": Vector3(-12, -30, 0), "left_hand": Vector3(0.10, 1.16, 0.24), "right_hand": Vector3(-0.20, 1.08, 0.12), "left_foot": Vector3(0.20, 0.13, 0.20), "right_foot": Vector3(-0.20, 0.13, -0.24)}],
		[0.55, {"hips": Vector3(-0.04, -0.25, -0.08), "spine": Vector3(22, 26, -12), "chest": Vector3(9, 14, -8), "head": Vector3(-12, -30, 0), "left_hand": Vector3(0.10, 1.17, 0.24), "right_hand": Vector3(-0.20, 1.09, 0.12), "left_foot": Vector3(0.20, 0.13, 0.20), "right_foot": Vector3(-0.20, 0.13, -0.24)}],
		[1.0, {}],
	])
	_add(library, "burst", 0.8, false, [
		[0.0, {}],
		[0.12, {"hips": Vector3(0, -0.18, 0), "spine": Vector3(18, 0, 0), "chest": Vector3(10, 0, 0), "left_hand": Vector3(-0.10, 1.30, 0.28), "right_hand": Vector3(0.10, 1.24, 0.32)}],
		[0.24, {"hips": Vector3(0, -0.025, 0.02), "spine": Vector3(-7, 0, 0), "chest": Vector3(-9, 0, 0), "left_hand": Vector3(0.63, 1.44, 0.12), "right_hand": Vector3(-0.63, 1.44, 0.12), "left_aim": Vector3(1, 0.2, 0), "right_aim": Vector3(-1, 0.2, 0), "fist": 0.0}],
		[0.43, {"hips": Vector3(0, -0.04, 0.01), "spine": Vector3(-6, 0, 0), "chest": Vector3(-7, 0, 0), "left_hand": Vector3(0.60, 1.43, 0.12), "right_hand": Vector3(-0.60, 1.43, 0.12), "left_aim": Vector3(1, 0.2, 0), "right_aim": Vector3(-1, 0.2, 0), "fist": 0.0}],
		[0.72, {"left_hand": Vector3(0.34, 1.32, 0.27), "right_hand": Vector3(-0.32, 1.26, 0.23), "fist": 0.45}],
		[1.0, {}],
	])
	_add_style_clips(library, _style)
	return library


func _add(library: AnimationLibrary, clip_name: String, duration: float, loop: bool, keys: Array) -> void:
	var animation := Animation.new()
	animation.resource_name = "Authored prototype: " + clip_name
	animation.length = duration
	animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var tracks: PackedInt32Array = []
	for bone in _rest.size():
		var track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, NodePath("%s:%s" % [_path, _skeleton.get_bone_name(bone)]))
		animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
		tracks.append(track)
	var hip_track := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(hip_track, NodePath("%s:Hips" % _path))
	for key in keys:
		_bake_pose(key[1])
		var time: float = float(key[0]) * duration
		for bone in _rest.size():
			animation.rotation_track_insert_key(tracks[bone], time, _pose[bone].basis.get_rotation_quaternion().normalized())
		if _bones.has("Hips"):
			# AnimationMixer multiplies bone-position keys by Skeleton3D.motion_scale.
			# Our solver uses actual rig metres, so cancel that import normalization.
			animation.position_track_insert_key(hip_track, time, _pose[_bones["Hips"]].origin / maxf(_skeleton.motion_scale, 0.0001))
	library.add_animation(clip_name, animation)


func _bake_pose(overrides: Dictionary) -> void:
	_pose = _rest.duplicate()
	var p := {
		"hips": Vector3(0, -0.065, 0), "hip_rotation": Vector3.ZERO,
		"spine": Vector3(6, -10, 0), "chest": Vector3(4, 12, 0), "head": Vector3(-7, -2, 0),
		"left_hand": Vector3(0.19, 1.40, 0.30), "right_hand": Vector3(-0.16, 1.33, 0.25),
		"left_aim": Vector3(-0.12, 0.75, 0.65), "right_aim": Vector3(0.10, 0.80, 0.60),
		"left_foot": Vector3(0.13, 0.13, 0.18), "right_foot": Vector3(-0.14, 0.13, -0.18),
		"left_pitch": 0.0, "right_pitch": 0.0, "fist": 1.0,
	}
	p.merge(_active_stance, true)
	p.merge(overrides, true)
	if _bones.has("Hips"):
		_pose[_bones["Hips"]].origin += p["hips"] * _scale
	_rotate_local("Hips", p["hip_rotation"])
	_rotate_local("Spine", p["spine"])
	_rotate_local("Chest", p["chest"])
	_rotate_local("Head", p["head"])
	for side in ["Left", "Right"]:
		var prefix: String = side.to_lower()
		var sign_x: float = 1.0 if side == "Left" else -1.0
		var foot: int = _bones.get(side + "Foot", -1)
		var foot_target: Vector3 = p[prefix + "_foot"] * _scale
		if foot >= 0:
			foot_target.y += _skeleton.get_bone_global_rest(foot).origin.y - 0.13 * _scale
		_solve_limb(side + "UpperLeg", side + "LowerLeg", side + "Foot", foot_target, Vector3(0, 0, 1))
		if foot >= 0:
			var rest_global := _skeleton.get_bone_global_rest(foot)
			var turn := Basis(Vector3.UP, deg_to_rad(8.0 * sign_x))
			var pitch := Basis(Vector3.RIGHT, deg_to_rad(p[prefix + "_pitch"]))
			_set_global_basis(foot, turn * pitch * rest_global.basis)
		_solve_limb(side + "UpperArm", side + "LowerArm", side + "Hand", p[prefix + "_hand"] * _scale, Vector3(sign_x * 0.85, -0.8, -0.4))
		var hand: int = _bones.get(side + "Hand", -1)
		if hand >= 0:
			var hand_rest := _skeleton.get_bone_global_rest(hand).basis
			var direction: Vector3 = p[prefix + "_aim"]
			_set_global_basis(hand, Basis(Quaternion(hand_rest.y.normalized(), direction.normalized())) * hand_rest)
		for finger in ["Index", "Middle", "Ring", "Little"]:
			_rotate_local(side + finger + "Proximal", Vector3(70.0 * float(p["fist"]), 0, 0))
			_rotate_local(side + finger + "Intermediate", Vector3(88.0 * float(p["fist"]), 0, 0))
			_rotate_local(side + finger + "Distal", Vector3(64.0 * float(p["fist"]), 0, 0))
		_rotate_local(side + "ThumbMetacarpal", Vector3(15.0 * float(p["fist"]), 0, 18.0 * float(p["fist"])))
		_rotate_local(side + "ThumbProximal", Vector3(32.0 * float(p["fist"]), 0, 0))
		_rotate_local(side + "ThumbDistal", Vector3(34.0 * float(p["fist"]), 0, 0))


func _rotate_local(bone_name: String, degrees: Vector3) -> void:
	var bone: int = _bones.get(bone_name, -1)
	if bone >= 0:
		_pose[bone].basis = _rest[bone].basis * Basis.from_euler(degrees * PI / 180.0)


func _global(bone: int) -> Transform3D:
	if bone < 0:
		return Transform3D.IDENTITY
	var parent: int = _parents[bone]
	return _global(parent) * _pose[bone]


func _set_global_basis(bone: int, desired: Basis) -> void:
	_pose[bone].basis = (_global(_parents[bone]).basis.inverse() * desired).orthonormalized()


func _aim(bone: int, child: int, direction: Vector3) -> void:
	var current := _global(bone)
	var old_direction := (_global(child).origin - current.origin).normalized()
	if direction.length_squared() > 0.000001:
		_set_global_basis(bone, Basis(Quaternion(old_direction, direction.normalized())) * current.basis)


func _solve_limb(upper_name: String, lower_name: String, end_name: String, target: Vector3, pole: Vector3) -> void:
	var upper: int = _bones.get(upper_name, -1)
	var lower: int = _bones.get(lower_name, -1)
	var end: int = _bones.get(end_name, -1)
	if upper < 0 or lower < 0 or end < 0:
		return
	var origin := _global(upper).origin
	var length_a := _rest[lower].origin.length()
	var length_b := _rest[end].origin.length()
	var delta := target - origin
	var distance := clampf(delta.length(), absf(length_a - length_b) + 0.002, length_a + length_b - 0.002)
	var direction := delta.normalized()
	if direction.length_squared() < 0.01:
		direction = Vector3.DOWN
	var bend := pole - direction * pole.dot(direction)
	if bend.length_squared() < 0.0001:
		bend = direction.cross(Vector3.RIGHT)
	bend = bend.normalized()
	var along := (length_a * length_a - length_b * length_b + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(0.0, length_a * length_a - along * along))
	var elbow := origin + direction * along + bend * height
	var clamped_target := origin + direction * distance
	_aim(upper, lower, elbow - origin)
	_aim(lower, end, clamped_target - _global(lower).origin)


# Each row is an authored technique, not a retimed copy of another character.
# Positions use the reference body's metres; the baker scales them to this rig.
func _form(hips: Vector3, left_hand: Vector3, right_hand: Vector3, left_foot: Vector3, right_foot: Vector3, spine: Vector3, chest: Vector3, turn: float = 0.0, fist: float = 1.0) -> Dictionary:
	return {"hips":hips, "left_hand":left_hand, "right_hand":right_hand, "left_foot":left_foot, "right_foot":right_foot, "spine":spine, "chest":chest, "hip_rotation":Vector3(0,turn,0), "fist":fist}


func _style_forms(style: String) -> Array:
	# Order: jab, cross, low kick, launcher, dodge, burst, finisher.
	match style:
		"neon": # Open palms, circular redirects and broad sound projection.
			return [
				_form(Vector3(.02,-.07,.04),Vector3(.16,1.37,.66),Vector3(-.34,1.1,.12),Vector3(.19,.13,.23),Vector3(-.19,.13,-.17),Vector3(3,-5,-4),Vector3(2,-20,0),0,0),
				_form(Vector3(-.03,-.09,.08),Vector3(.36,1.23,.45),Vector3(-.12,1.32,.72),Vector3(.23,.13,.26),Vector3(-.24,.13,-.15),Vector3(6,17,0),Vector3(0,30,8),15,0),
				_form(Vector3(.09,-.14,0),Vector3(.40,1.34,.13),Vector3(-.45,1.30,.15),Vector3(.17,.13,.06),Vector3(-.35,.25,.68),Vector3(-9,14,-10),Vector3(0,-5,0),23,0),
				_form(Vector3(0,.04,.06),Vector3(.10,1.87,.38),Vector3(-.10,1.83,.38),Vector3(.25,.13,.15),Vector3(-.25,.17,-.08),Vector3(-7,0,0),Vector3(-8,0,0),0,0),
				_form(Vector3(-.12,-.15,-.11),Vector3(.45,1.1,.12),Vector3(-.35,1.37,.3),Vector3(.33,.13,.1),Vector3(-.31,.13,-.22),Vector3(-8,28,-16),Vector3(4,19,-12),-24,0),
				_form(Vector3(0,-.08,.08),Vector3(.30,1.36,.63),Vector3(-.30,1.36,.63),Vector3(.31,.13,.23),Vector3(-.31,.13,-.20),Vector3(7,0,0),Vector3(-4,0,0),0,0),
				_form(Vector3(0,-.10,.16),Vector3(.12,1.39,.78),Vector3(-.12,1.39,.78),Vector3(.32,.13,.35),Vector3(-.32,.13,-.3),Vector3(15,0,0),Vector3(7,0,0),0,0)]
		"yuki": # Fencing hands and a kick-led, balanced ice-dance silhouette.
			return [
				_form(Vector3(.025,-.035,.03),Vector3(.06,1.54,.65),Vector3(-.38,1.11,-.02),Vector3(.10,.13,.27),Vector3(-.13,.13,-.27),Vector3(0,-12,5),Vector3(-4,-15,0),-8,.15),
				_form(Vector3(.045,-.06,.01),Vector3(.30,1.52,.23),Vector3(-.07,1.59,.63),Vector3(.14,.13,.27),Vector3(-.16,.13,-.15),Vector3(-6,22,-4),Vector3(2,18,-5),18,.2),
				_form(Vector3(-.08,-.04,-.04),Vector3(.46,1.50,.1),Vector3(-.45,1.46,.06),Vector3(.08,.38,.76),Vector3(-.16,.13,.02),Vector3(-15,-14,8),Vector3(-2,-11,0),-15,.1),
				_form(Vector3(-.04,.16,-.05),Vector3(.43,1.66,.05),Vector3(-.46,1.39,.05),Vector3(.07,1.03,.6),Vector3(-.15,.24,.02),Vector3(-18,-10,4),Vector3(-7,-17,3),-8,.1),
				_form(Vector3(.10,-.05,-.16),Vector3(.53,1.48,-.04),Vector3(-.27,1.61,.17),Vector3(.18,.2,-.20),Vector3(-.17,.13,.17),Vector3(-22,-30,12),Vector3(-8,-25,0),-30,.1),
				_form(Vector3(0,-.1,0),Vector3(.54,1.69,.17),Vector3(-.54,1.69,.17),Vector3(.27,.13,.10),Vector3(-.27,.13,-.10),Vector3(-4,0,0),Vector3(-9,0,0),0,0),
				_form(Vector3(-.07,.22,-.05),Vector3(.47,1.85,.06),Vector3(-.49,1.51,-.02),Vector3(.03,1.15,.67),Vector3(-.20,.34,-.12),Vector3(-20,-8,10),Vector3(-6,-15,0),-25,0)]
		"ivy": # Long alternating whip-like arm arcs and low, rooted footwork.
			return [
				_form(Vector3(-.04,-.12,.07),Vector3(.37,1.25,.58),Vector3(-.25,1.00,-.15),Vector3(.24,.13,.28),Vector3(-.26,.13,-.3),Vector3(14,-18,-5),Vector3(8,-27,0),-14,.2),
				_form(Vector3(.06,-.12,.03),Vector3(.49,1.20,-.09),Vector3(.12,1.48,.67),Vector3(.25,.13,.30),Vector3(-.30,.13,-.2),Vector3(12,25,5),Vector3(0,32,8),20,.25),
				_form(Vector3(.12,-.22,-.03),Vector3(.45,1.06,.19),Vector3(-.25,1.48,.18),Vector3(.19,.13,.05),Vector3(-.38,.19,.76),Vector3(1,27,-15),Vector3(9,-6,-8),25,.2),
				_form(Vector3(.02,-.015,.04),Vector3(.03,1.91,.38),Vector3(-.44,1.08,.14),Vector3(.28,.13,.27),Vector3(-.31,.13,-.26),Vector3(-4,-26,0),Vector3(-10,-20,-7),-15,.2),
				_form(Vector3(-.13,-.36,-.07),Vector3(.48,.78,.23),Vector3(-.41,.87,.10),Vector3(.32,.13,.34),Vector3(-.36,.13,-.28),Vector3(31,25,-17),Vector3(14,16,-8),18,.2),
				_form(Vector3(0,-.12,.02),Vector3(.65,1.27,.29),Vector3(-.65,1.46,.14),Vector3(.33,.13,.24),Vector3(-.33,.13,-.3),Vector3(6,-18,0),Vector3(-3,-22,-7),-10,0),
				_form(Vector3(-.03,-.20,.13),Vector3(.25,1.64,.67),Vector3(-.32,1.13,.64),Vector3(.32,.13,.37),Vector3(-.35,.13,-.34),Vector3(17,-15,4),Vector3(2,-24,0),-12,0)]
		"rook": # Squared grappler: short elbows, hook, knee, lift and body press.
			return [
				_form(Vector3(.06,-.14,.10),Vector3(.04,1.40,.28),Vector3(-.36,1.19,.16),Vector3(.27,.13,.3),Vector3(-.29,.13,-.2),Vector3(13,-23,-5),Vector3(5,-35,0),-25,.85),
				_form(Vector3(-.05,-.13,.11),Vector3(.29,1.34,.22),Vector3(.13,1.38,.52),Vector3(.30,.13,.25),Vector3(-.31,.13,-.15),Vector3(16,26,4),Vector3(5,30,10),27,1),
				_form(Vector3(.06,-.08,.04),Vector3(.22,1.37,.32),Vector3(-.20,1.37,.32),Vector3(.21,.13,.1),Vector3(-.17,.49,.54),Vector3(-4,2,-5),Vector3(13,0,0),5,1),
				_form(Vector3(0,-.01,.09),Vector3(.28,1.75,.42),Vector3(-.28,1.75,.42),Vector3(.34,.13,.17),Vector3(-.34,.13,-.18),Vector3(-14,0,0),Vector3(-12,0,0),0,.35),
				_form(Vector3(.12,-.30,-.02),Vector3(.15,1.17,.2),Vector3(-.12,1.22,.23),Vector3(.36,.13,.21),Vector3(-.31,.13,-.3),Vector3(22,-10,20),Vector3(14,-7,12),-10,1),
				_form(Vector3(0,-.18,.1),Vector3(.44,1.25,.47),Vector3(-.44,1.25,.47),Vector3(.38,.13,.26),Vector3(-.38,.13,-.22),Vector3(14,0,0),Vector3(14,0,0),0,.2),
				_form(Vector3(0,-.39,.14),Vector3(.26,.77,.65),Vector3(-.26,.77,.65),Vector3(.39,.13,.38),Vector3(-.39,.13,-.3),Vector3(36,0,0),Vector3(16,0,0),0,.65)]
		"atlas": # Wide heavy base: body blow, hammerfist, stamp and double slam.
			return [
				_form(Vector3(.03,-.19,.11),Vector3(.14,1.07,.62),Vector3(-.38,1.21,.14),Vector3(.30,.13,.24),Vector3(-.32,.13,-.23),Vector3(19,-12,-4),Vector3(13,-18,0),-10,1),
				_form(Vector3(-.03,-.24,.12),Vector3(.33,1.19,.23),Vector3(-.05,1.16,.66),Vector3(.32,.13,.28),Vector3(-.34,.13,-.22),Vector3(25,15,0),Vector3(15,19,-8),10,1),
				_form(Vector3(.10,-.20,.08),Vector3(.38,1.31,.08),Vector3(-.38,1.20,.07),Vector3(.31,.13,-.07),Vector3(-.23,.16,.62),Vector3(18,8,-10),Vector3(13,-2,0),8,1),
				_form(Vector3(0,.02,.08),Vector3(.34,1.88,.27),Vector3(-.34,1.88,.27),Vector3(.39,.13,.18),Vector3(-.39,.13,-.15),Vector3(-12,0,0),Vector3(-16,0,0),0,1),
				_form(Vector3(.14,-.36,-.09),Vector3(.28,1.13,.21),Vector3(-.21,1.06,.25),Vector3(.40,.13,.20),Vector3(-.38,.13,-.24),Vector3(26,-7,18),Vector3(19,0,8),0,1),
				_form(Vector3(0,-.32,.1),Vector3(.60,.95,.17),Vector3(-.60,.95,.17),Vector3(.42,.13,.25),Vector3(-.42,.13,-.25),Vector3(25,0,0),Vector3(12,0,0),0,1),
				_form(Vector3(0,-.46,.13),Vector3(.13,.55,.69),Vector3(-.13,.55,.69),Vector3(.43,.13,.38),Vector3(-.43,.13,-.29),Vector3(43,0,0),Vector3(23,0,0),0,1)]
		"zero": # Restrained fencing/boxing, precise parries and a heel-led counter.
			return [
				_form(Vector3(0,-.035,.04),Vector3(.03,1.41,.68),Vector3(-.12,1.5,.18),Vector3(.12,.13,.26),Vector3(-.14,.13,-.3),Vector3(3,-14,0),Vector3(1,-18,0),-7,.6),
				_form(Vector3(.025,-.05,.06),Vector3(.06,1.43,.27),Vector3(-.05,1.46,.69),Vector3(.13,.13,.28),Vector3(-.16,.13,-.28),Vector3(5,16,-3),Vector3(3,16,0),12,.7),
				_form(Vector3(-.08,-.065,-.03),Vector3(.15,1.50,.30),Vector3(-.15,1.41,.24),Vector3(.06,.27,.81),Vector3(-.15,.13,-.1),Vector3(-10,-17,7),Vector3(0,4,0),-12,.7),
				_form(Vector3(0,-.01,.06),Vector3(.03,1.63,.54),Vector3(-.06,1.25,.48),Vector3(.14,.13,.27),Vector3(-.18,.13,-.2),Vector3(-2,-12,0),Vector3(-7,-10,0),-7,.2),
				_form(Vector3(-.06,-.11,-.15),Vector3(.02,1.47,.39),Vector3(-.17,1.47,.23),Vector3(.19,.13,.04),Vector3(-.20,.13,-.36),Vector3(-12,14,-9),Vector3(-7,13,0),10,.6),
				_form(Vector3(0,-.09,.01),Vector3(-.08,1.49,.33),Vector3(.08,1.27,.35),Vector3(.19,.13,.28),Vector3(-.23,.13,-.3),Vector3(3,0,0),Vector3(-2,0,0),0,.2),
				_form(Vector3(.025,-.085,.14),Vector3(.02,1.44,.78),Vector3(-.18,1.19,.18),Vector3(.17,.13,.39),Vector3(-.24,.13,-.33),Vector3(10,-11,0),Vector3(2,-16,0),-8,0)]
		"vex": # Off-axis low stance, backhand cuts and an evasive corkscrew.
			return [
				_form(Vector3(-.08,-.19,.04),Vector3(.34,1.37,.49),Vector3(-.23,.95,.03),Vector3(.29,.13,.27),Vector3(-.32,.13,-.26),Vector3(18,-27,-11),Vector3(0,-24,0),-18,.2),
				_form(Vector3(.09,-.17,.02),Vector3(.29,1.14,-.1),Vector3(.22,1.46,.50),Vector3(.28,.13,.3),Vector3(-.32,.13,-.25),Vector3(14,28,12),Vector3(-4,32,7),28,.2),
				_form(Vector3(.12,-.32,-.06),Vector3(.5,.8,.03),Vector3(-.25,1.24,.14),Vector3(.20,.13,-.08),Vector3(-.48,.18,.68),Vector3(15,35,-22),Vector3(10,-5,-15),35,.1),
				_form(Vector3(-.06,.04,.03),Vector3(.43,1.86,.21),Vector3(-.29,1.08,-.06),Vector3(.2,.13,.12),Vector3(-.18,.5,.23),Vector3(-7,-25,-10),Vector3(-8,-28,-7),-22,.2),
				_form(Vector3(-.17,-.44,-.1),Vector3(.50,.69,.2),Vector3(-.42,.71,.11),Vector3(.37,.13,.4),Vector3(-.37,.13,-.38),Vector3(35,28,-22),Vector3(21,24,-12),32,.1),
				_form(Vector3(0,-.24,-.02),Vector3(.55,1.12,-.09),Vector3(-.55,1.42,-.09),Vector3(.36,.13,.27),Vector3(-.36,.13,-.34),Vector3(15,-25,0),Vector3(-4,-25,-8),-20,0),
				_form(Vector3(-.04,-.16,.14),Vector3(.30,1.63,.63),Vector3(-.2,.96,.38),Vector3(.34,.13,.43),Vector3(-.32,.13,-.36),Vector3(22,-24,-8),Vector3(-2,-24,0),-22,.1)]
		"sora": # Capoeira-inspired open guard, kicks and birdlike aerial balance.
			return [
				_form(Vector3(.06,-.07,.03),Vector3(.18,1.33,.66),Vector3(-.50,1.26,-.03),Vector3(.23,.13,.29),Vector3(-.25,.17,-.26),Vector3(6,-15,-7),Vector3(0,-18,0),-12,0),
				_form(Vector3(-.06,-.05,0),Vector3(.52,1.36,-.05),Vector3(-.05,1.32,.69),Vector3(.21,.19,-.2),Vector3(-.25,.13,.2),Vector3(1,25,10),Vector3(-6,25,0),28,0),
				_form(Vector3(-.08,-.10,-.06),Vector3(.53,1.31,.08),Vector3(-.48,1.5,-.02),Vector3(.33,.33,.73),Vector3(-.20,.13,-.06),Vector3(-13,-20,13),Vector3(-2,-16,0),-24,0),
				_form(Vector3(.06,.14,-.03),Vector3(.54,1.60,.06),Vector3(-.50,1.56,-.03),Vector3(.21,.3,-.03),Vector3(-.08,1.04,.60),Vector3(-19,12,-8),Vector3(-5,16,0),19,0),
				_form(Vector3(.12,-.20,-.12),Vector3(.57,1.15,-.08),Vector3(-.40,1.55,.04),Vector3(.27,.13,.2),Vector3(-.31,.23,-.35),Vector3(-17,-27,24),Vector3(-6,-18,15),-20,0),
				_form(Vector3(0,.08,0),Vector3(.65,1.63,.03),Vector3(-.65,1.63,.03),Vector3(.25,.3,.15),Vector3(-.25,.33,-.15),Vector3(-5,0,0),Vector3(-9,0,0),0,0),
				_form(Vector3(.05,.29,-.06),Vector3(.54,1.81,.02),Vector3(-.47,1.63,-.02),Vector3(.22,.49,-.15),Vector3(-.04,1.25,.70),Vector3(-24,17,-12),Vector3(-6,19,0),28,0)]
		"raijin": # Narrow, coiled speed stance; spear-hand and snapping high knee.
			return [
				_form(Vector3(.025,-.11,.09),Vector3(.06,1.47,.73),Vector3(-.15,1.21,.06),Vector3(.15,.13,.32),Vector3(-.17,.13,-.3),Vector3(15,-14,-3),Vector3(5,-17,0),-10,.2),
				_form(Vector3(-.025,-.13,.10),Vector3(.17,1.40,.18),Vector3(-.03,1.51,.73),Vector3(.17,.13,.34),Vector3(-.19,.13,-.29),Vector3(18,18,2),Vector3(8,21,0),16,.3),
				_form(Vector3(.065,-.09,.015),Vector3(.15,1.49,.18),Vector3(-.29,1.12,.07),Vector3(.13,.13,.11),Vector3(-.07,.43,.80),Vector3(-10,11,-6),Vector3(7,8,0),14,.4),
				_form(Vector3(.025,.12,.07),Vector3(.15,1.35,.3),Vector3(-.04,1.92,.29),Vector3(.14,.13,.12),Vector3(-.13,.6,.28),Vector3(-9,18,-8),Vector3(-11,22,-6),15,1),
				_form(Vector3(-.08,-.28,-.07),Vector3(.16,1.01,.10),Vector3(-.27,.92,-.12),Vector3(.27,.13,.36),Vector3(-.27,.13,-.36),Vector3(35,-20,-12),Vector3(18,-15,-6),-18,.2),
				_form(Vector3(0,-.09,0),Vector3(.45,1.66,.24),Vector3(-.45,1.23,.34),Vector3(.26,.13,.27),Vector3(-.28,.13,-.25),Vector3(5,-18,0),Vector3(-5,-22,0),-10,0),
				_form(Vector3(.02,-.26,.17),Vector3(.20,1.12,.28),Vector3(-.03,.91,.78),Vector3(.27,.13,.41),Vector3(-.3,.13,-.33),Vector3(32,19,-4),Vector3(16,24,0),18,1)]
		_: # Kai: tight boxing, rising right uppercut and a forward knuckle rush.
			return [
				_form(Vector3(.01,-.05,.05),Vector3(.1,1.41,.68),Vector3(-.14,1.44,.23),Vector3(.15,.13,.22),Vector3(-.16,.13,-.2),Vector3(7,-8,0),Vector3(4,-22,0),-5,1),
				_form(Vector3(.02,-.06,.09),Vector3(.18,1.45,.26),Vector3(-.07,1.41,.70),Vector3(.16,.13,.26),Vector3(-.18,.15,-.2),Vector3(11,15,-3),Vector3(6,25,5),18,1),
				_form(Vector3(.075,-.04,-.03),Vector3(.22,1.40,.23),Vector3(-.32,1.22,.10),Vector3(.14,.13,.05),Vector3(-.08,.34,.81),Vector3(-13,-12,-6),Vector3(3,20,0),15,1),
				_form(Vector3(.02,.025,.07),Vector3(.2,1.34,.24),Vector3(-.05,1.86,.40),Vector3(.17,.13,.2),Vector3(-.17,.2,-.12),Vector3(-7,16,-5),Vector3(-9,25,-7),19,1),
				_form(Vector3(-.05,-.27,-.12),Vector3(.09,1.17,.24),Vector3(-.2,1.07,.13),Vector3(.22,.13,.25),Vector3(-.22,.13,-.25),Vector3(24,25,-13),Vector3(10,17,-9),8,1),
				_form(Vector3(0,-.035,.04),Vector3(.58,1.45,.17),Vector3(-.58,1.45,.17),Vector3(.27,.13,.23),Vector3(-.27,.13,-.23),Vector3(-8,0,0),Vector3(-10,0,0),0,1),
				_form(Vector3(.03,-.11,.18),Vector3(.2,1.35,.17),Vector3(-.06,1.38,.84),Vector3(.25,.13,.38),Vector3(-.28,.13,-.31),Vector3(23,20,-3),Vector3(10,28,5),22,1)]


func _stance_for(style: String) -> Dictionary:
	var p: Dictionary = _style_forms(style)[0].duplicate(true)
	p["hips"] = Vector3(0,-.07,0)
	p["left_hand"] = Vector3(.20,1.40,.30)
	p["right_hand"] = Vector3(-.20,1.31,.23)
	p["spine"] = Vector3(5,-8,0)
	p["chest"] = Vector3(3,10,0)
	p["hip_rotation"] = Vector3.ZERO
	match style:
		"neon": p.merge({"left_hand":Vector3(.35,1.36,.28),"right_hand":Vector3(-.36,1.16,.25),"fist":0.0,"chest":Vector3(-2,2,0)},true)
		"yuki": p.merge({"hips":Vector3(.04,-.03,0),"left_hand":Vector3(.19,1.51,.32),"right_hand":Vector3(-.36,1.03,.03),"fist":.1,"spine":Vector3(0,-16,5)},true)
		"ivy": p.merge({"hips":Vector3(-.04,-.14,0),"left_hand":Vector3(.37,1.14,.35),"right_hand":Vector3(-.3,.97,.04),"fist":.15,"spine":Vector3(13,-15,-4)},true)
		"rook": p.merge({"hips":Vector3(0,-.16,0),"left_hand":Vector3(.30,1.25,.4),"right_hand":Vector3(-.3,1.25,.4),"fist":.5,"chest":Vector3(11,0,0)},true)
		"atlas": p.merge({"hips":Vector3(0,-.19,0),"left_hand":Vector3(.34,1.10,.24),"right_hand":Vector3(-.34,1.1,.24),"spine":Vector3(15,0,0),"chest":Vector3(9,0,0)},true)
		"zero": p.merge({"hips":Vector3(0,-.035,0),"left_hand":Vector3(.09,1.47,.35),"right_hand":Vector3(-.11,1.45,.2),"spine":Vector3(2,-14,0),"fist":.6},true)
		"vex": p.merge({"hips":Vector3(-.06,-.2,0),"left_hand":Vector3(.35,1.19,.26),"right_hand":Vector3(-.27,.9,-.04),"spine":Vector3(18,-24,-9),"fist":.15},true)
		"sora": p.merge({"hips":Vector3(.035,-.06,0),"left_hand":Vector3(.43,1.35,.18),"right_hand":Vector3(-.43,1.3,.1),"spine":Vector3(3,-12,-5),"fist":0.0},true)
		"raijin": p.merge({"hips":Vector3(0,-.12,0),"left_hand":Vector3(.15,1.43,.39),"right_hand":Vector3(-.18,1.16,.09),"spine":Vector3(15,-14,0),"fist":.4},true)
	return p


func _blend_pose(a: Dictionary, b: Dictionary, weight: float) -> Dictionary:
	var result := a.duplicate(true)
	for key in b:
		if result.has(key) and b[key] is Vector3:
			result[key] = (result[key] as Vector3).lerp(b[key],weight)
		elif result.has(key) and (b[key] is float or b[key] is int):
			result[key] = lerpf(float(result[key]),float(b[key]),weight)
		else: result[key] = b[key]
	return result


func _turn_pose(pose: Dictionary, degrees: float, rise: float = 0.0) -> Dictionary:
	var result := pose.duplicate(true)
	var turn := Basis(Vector3.UP,deg_to_rad(degrees))
	for key in ["left_hand","right_hand","left_foot","right_foot"]:
		result[key] = turn * result[key] + Vector3.UP * rise
	result["hips"] = turn * result["hips"] + Vector3.UP * rise
	result["hip_rotation"] += Vector3(0,degrees,0)
	return result


func _add_style_clips(library: AnimationLibrary, style: String) -> void:
	var forms := _style_forms(style)
	var stance := _stance_for(style)
	_active_stance = stance
	var breath := stance.duplicate(true)
	breath["hips"] += Vector3(0,.012,0)
	breath["chest"] += Vector3(-1.8,1.0,0)
	breath["left_hand"] += Vector3(0,.012,.006)
	_add(library,style+"_idle",1.7,true,[[0.0,stance],[.48,breath],[1.0,stance]])
	var showcase := _blend_pose(stance,forms[5],.12)
	showcase["head"] = Vector3(-3,-6,0)
	var looking := showcase.duplicate(true)
	looking["head"] = Vector3(-5,8,0)
	looking["hips"] += Vector3(.014,.015,0)
	_add(library,style+"_showcase",4.0,true,[[0.0,showcase],[.4,looking],[.7,showcase],[1.0,showcase]])
	var ids := ["jab","cross","low_kick","launcher","dodge","burst","finisher"]
	var lengths := [.36,.50,.59,.67,.48,.88,1.28]
	var move_data := FighterCatalog.moves(style)
	for i in ids.size():
		var anticipation := _blend_pose(stance,forms[4],.32 if i < 4 else .72)
		anticipation["hips"] += Vector3(0,-.035,-.035)
		if i in [1,3,6]:
			anticipation["right_hand"] = Vector3(-.23,1.17,.04)
			anticipation["chest"] += Vector3(5,-17,0)
		if style in ["yuki","sora"] and i in [2,3,6]:
			anticipation["left_foot" if style == "yuki" else "right_foot"] = Vector3(.1 if style == "yuki" else -.1,.54,.15)
		var hit: Dictionary = forms[i].duplicate(true)
		if float(hit.fist) < .6:
			hit["left_aim"] = Vector3(0,1,.05)
			hit["right_aim"] = Vector3(0,1,.05)
		var recoil := _blend_pose(stance,hit,.44)
		var contact := .31 if i < 2 else (.35 if i < 4 else .28)
		var keys := _attack_keys(style, i, stance, forms, anticipation, hit, recoil, contact)
		if style in ["kai", "neon"] and move_data[i].animated_hitbox:
			keys = _align_contact_keys(keys, move_data[i])
		_add(library,style+"_"+ids[i],lengths[i],false,keys)
	var victory: Dictionary = forms[5].duplicate(true)
	victory["head"] = Vector3(-12,-8,0)
	match style:
		"kai": victory["right_hand"] = Vector3(-.27,1.97,.05)
		"neon": victory["left_hand"] = Vector3(.43,1.79,.16)
		"yuki": victory = _turn_pose(forms[3],-30)
		"ivy": victory["left_hand"] = Vector3(.22,1.84,.16)
		"rook": victory["left_hand"] = Vector3(.46,1.73,.05); victory["right_hand"] = Vector3(-.46,1.73,.05)
		"atlas": victory["left_hand"] = Vector3(.38,1.28,.13); victory["right_hand"] = Vector3(-.38,1.28,.13); victory["hips"] = Vector3(0,-.11,0)
		"zero": victory["left_hand"] = Vector3(.06,1.62,.2); victory["right_hand"] = Vector3(-.23,.95,.03)
		"vex": victory["right_hand"] = Vector3(-.17,1.55,.24); victory["left_hand"] = Vector3(.34,.88,-.04)
		"sora": victory = _turn_pose(forms[5],-25,.05)
		"raijin": victory["right_hand"] = Vector3(-.09,1.92,.06); victory["left_hand"] = Vector3(.24,1.19,.06)
	_add(library,style+"_victory",3.6,false,[[0.0,stance],[.18,_blend_pose(stance,victory,.35)],[.43,victory],[.76,victory],[1.0,_blend_pose(showcase,victory,.5)]])
	_add(library,style+"_cinematic",3.5,false,_cinematic_keys(style,stance,forms))
	_active_stance = {}
	_add(library,"cinematic_victim",3.5,false,[
		[0.0,{}],[.14,{"hips":Vector3(0,-.1,-.08),"spine":Vector3(-18,10,-7),"head":Vector3(-16,-8,0),"left_hand":Vector3(.39,1.3,.08),"right_hand":Vector3(-.38,1.17,.06),"fist":.1}],
		[.28,{"hips":Vector3(.05,-.18,-.06),"spine":Vector3(19,-22,12),"chest":Vector3(14,-15,5),"head":Vector3(12,14,0)}],
		[.42,{"hips":Vector3(-.05,-.14,-.09),"spine":Vector3(-23,25,-12),"head":Vector3(-15,-17,0),"left_hand":Vector3(.43,1.23,.02),"right_hand":Vector3(-.43,1.32,.02),"fist":.15}],
		[.56,{"hips":Vector3(0,.08,0),"spine":Vector3(-26,0,0),"chest":Vector3(-16,0,0),"left_foot":Vector3(.24,.44,.18),"right_foot":Vector3(-.24,.43,-.05),"left_hand":Vector3(.49,1.39,-.06),"right_hand":Vector3(-.49,1.39,-.06),"fist":0}],
		[.7,{"hips":Vector3(0,-.04,-.04),"spine":Vector3(20,15,9),"chest":Vector3(15,15,0)}],
		[.83,{"hips":Vector3(0,-.48,.04),"hip_rotation":Vector3(-53,0,-8),"left_hand":Vector3(.4,.3,-.2),"right_hand":Vector3(-.36,.3,-.2),"left_foot":Vector3(.25,.3,.67),"right_foot":Vector3(-.22,.28,.75),"fist":0}],
		[1.0,{"hips":Vector3(0,-.85,.10),"hip_rotation":Vector3(-85,0,0),"spine":Vector3.ZERO,"chest":Vector3.ZERO,"left_hand":Vector3(.4,.12,-.3),"right_hand":Vector3(-.37,.12,-.3),"left_foot":Vector3(.24,.15,.92),"right_foot":Vector3(-.22,.16,.94),"fist":0}]])


func _align_contact_keys(keys: Array, move: MoveData) -> Array:
	# The two authored contact poses occupy entries 3/4. Bake them at the full
	# extension frames of this move, rather than a shared fraction of clip length.
	var first: float = keys[3][0]
	var last: float = keys[4][0]
	var peak_start := float(move.startup + 1) / move.total_frames()
	var peak_end := float(move.startup + maxi(1, move.active - 2)) / move.total_frames()
	var result: Array = []
	for key: Array in keys:
		var time: float = key[0]
		var mapped := 0.0
		if time <= first:
			mapped = remap(time, 0.0, first, 0.0, peak_start)
		elif time <= last:
			mapped = remap(time, first, last, peak_start, peak_end)
		else:
			mapped = remap(time, last, 1.0, peak_end, 1.0)
		if not result.is_empty() and is_equal_approx(result.back()[0], mapped):
			continue
		result.append([mapped, key[1]])
	return result


## The vertical-slice fighters carry extra key poses so their attacks have a
## readable load, contact and follow-through instead of sharing one rhythm.
func _attack_keys(style: String, index: int, stance: Dictionary, forms: Array, anticipation: Dictionary, hit: Dictionary, recoil: Dictionary, contact: float) -> Array:
	if style not in ["kai", "neon"]:
		return [[0.0, stance], [contact * .55, anticipation], [contact, hit], [contact + .11, hit], [.75, recoil], [1.0, stance]]
	var load := _blend_pose(stance, anticipation, .82)
	var settle := _blend_pose(stance, recoil, .84)
	if style == "kai":
		match index:
			0: # Ember Jab: shoulder feint into a compact snap.
				var snap := hit.duplicate(true)
				snap["hips"] += Vector3(.015, .012, .035)
				snap["chest"] += Vector3(-3, 7, 0)
				return [[0.0, stance], [.10, _blend_pose(stance, load, .35)], [.20, load], [.29, snap], [.36, snap], [.48, _blend_pose(snap, recoil, .60)], [.67, settle], [1.0, stance]]
			1: # Flare Cross: hip coil, chest whip and a visible overshoot.
				load["hips"] += Vector3(-.025, -.025, -.055)
				load["hip_rotation"] += Vector3(0, -11, 0)
				var extension := hit.duplicate(true)
				extension["right_hand"] += Vector3(0, .02, .10)
				extension["chest"] += Vector3(2, 6, 0)
				var overshoot := _blend_pose(extension, recoil, .32)
				overshoot["hips"] += Vector3(.02, 0, .03)
				return [[0.0, stance], [.13, load], [.25, load], [.34, extension], [.42, extension], [.52, overshoot], [.72, settle], [1.0, stance]]
			2: # Cinder Sweep: squat, pivot and low leg extension.
				load["hips"] += Vector3(-.025, -.11, -.03)
				var sweep := hit.duplicate(true)
				sweep["right_foot"] += Vector3(0, -.02, .10)
				return [[0.0, stance], [.14, load], [.27, load], [.38, sweep], [.49, sweep], [.62, _blend_pose(sweep, recoil, .48)], [.80, settle], [1.0, stance]]
			3: # Rising Phoenix: deep crouch and explosive uppercut peak.
				load["hips"] += Vector3(-.045, -.14, -.05)
				load["right_hand"] = Vector3(-.18, 1.04, .12)
				var rise := hit.duplicate(true)
				rise["hips"] += Vector3(.02, .07, .065)
				rise["right_hand"] += Vector3(.02, .12, .06)
				return [[0.0, stance], [.12, _blend_pose(stance, load, .48)], [.25, load], [.38, rise], [.51, rise], [.65, _blend_pose(rise, recoil, .42)], [.83, settle], [1.0, stance]]
			4: # Heat Step: duck into a low travel pose, then return cleanly.
				load["hips"] += Vector3(-.07, -.12, -.10)
				load["head"] = Vector3(-15, -24, 0)
				var slip: Dictionary = forms[4].duplicate(true)
				slip["hips"] += Vector3(-.08, -.04, -.08)
				return [[0.0, stance], [.16, load], [.34, slip], [.58, slip], [.74, _blend_pose(slip, stance, .58)], [1.0, stance]]
			5: # Blazing Drive: both hands load into a long shoulder rush.
				load["hips"] += Vector3(-.03, -.10, -.11)
				load["left_hand"] = Vector3(.14, 1.24, .15)
				load["right_hand"] = Vector3(-.14, 1.20, .15)
				var drive := hit.duplicate(true)
				drive["hips"] += Vector3(.03, .02, .11)
				drive["right_hand"] = Vector3(-.1, 1.25, .8)
				drive["left_hand"] = Vector3(.14, 1.36, .28)
				drive["spine"] = Vector3(12, 12, -3)
				drive["chest"] = Vector3(5, 18, 0)
				return [[0.0, stance], [.09, _blend_pose(stance, load, .35)], [.19, load], [.31, drive], [.48, drive], [.64, _blend_pose(drive, recoil, .42)], [.82, settle], [1.0, stance]]
			_: # Solar Requiem keeps a deliberate cinematic release.
				load["hips"] += Vector3(-.04, -.08, -.10)
				var release := hit.duplicate(true)
				release["right_hand"] += Vector3(0, .08, .12)
				return [[0.0, stance], [.12, load], [.28, load], [.46, release], [.62, release], [.79, _blend_pose(release, recoil, .48)], [1.0, stance]]
	# Neon uses open-palm signal language, pulse holds and circular recovery.
	match index:
		0:
			load["left_hand"] += Vector3(-.05, .01, -.07)
			var tap := hit.duplicate(true)
			tap["left_hand"] += Vector3(.04, 0, .08)
			return [[0.0, stance], [.12, load], [.24, load], [.34, tap], [.41, tap], [.55, _blend_pose(tap, recoil, .38)], [.73, settle], [1.0, stance]]
		1:
			load["hips"] += Vector3(-.04, -.03, -.06)
			load["hip_rotation"] += Vector3(0, -16, 0)
			var hammer := hit.duplicate(true)
			hammer["right_hand"] += Vector3(0, .04, .10)
			return [[0.0, stance], [.14, load], [.29, load], [.40, hammer], [.50, hammer], [.62, _turn_pose(hammer, -12)], [.80, settle], [1.0, stance]]
		2:
			load["hips"] += Vector3(-.05, -.12, -.025)
			var wave := hit.duplicate(true)
			wave["left_hand"] += Vector3(.06, -.10, .11)
			wave["right_foot"] = Vector3(-.12, .3, .88)
			return [[0.0, stance], [.13, load], [.28, load], [.39, wave], [.49, wave], [.63, _blend_pose(wave, recoil, .48)], [.80, settle], [1.0, stance]]
		3:
			load["hips"] += Vector3(-.03, -.12, -.04)
			load["left_hand"] = Vector3(.15, 1.19, .17)
			load["right_hand"] = Vector3(-.15, 1.15, .17)
			var rise := hit.duplicate(true)
			rise["left_hand"] += Vector3(.02, .08, .06)
			rise["right_hand"] += Vector3(-.02, .08, .06)
			return [[0.0, stance], [.14, load], [.29, load], [.40, rise], [.53, rise], [.67, _blend_pose(rise, recoil, .42)], [.84, settle], [1.0, stance]]
		4:
			load["hips"] += Vector3(.04, -.11, -.10)
			var echo: Dictionary = forms[4].duplicate(true)
			echo["hips"] += Vector3(-.06, -.02, -.08)
			return [[0.0, stance], [.14, load], [.32, echo], [.54, echo], [.70, _blend_pose(echo, stance, .52)], [1.0, stance]]
		5:
			load["hips"] += Vector3(-.02, -.09, -.07)
			load["left_hand"] = Vector3(.16, 1.31, .12)
			load["right_hand"] = Vector3(-.16, 1.29, .12)
			var lance := hit.duplicate(true)
			lance["left_hand"] += Vector3(0, .02, .12)
			lance["right_hand"] += Vector3(0, .02, .12)
			return [[0.0, stance], [.10, _blend_pose(stance, load, .42)], [.24, load], [.36, lance], [.57, lance], [.71, _blend_pose(lance, recoil, .40)], [.86, settle], [1.0, stance]]
		_:
			load["hips"] += Vector3(-.02, -.10, -.12)
			var finale := hit.duplicate(true)
			finale["left_hand"] += Vector3(0, .02, .14)
			finale["right_hand"] += Vector3(0, .02, .14)
			return [[0.0, stance], [.14, load], [.32, load], [.52, finale], [.68, finale], [.84, _blend_pose(finale, recoil, .42)], [1.0, stance]]


func _cinematic_keys(style: String, stance: Dictionary, f: Array) -> Array:
	var keys: Array = [[0.0,stance],[.09,f[4]]]
	match style:
		"neon": keys += [[.20,f[5]],[.30,_turn_pose(f[5],90)],[.40,_turn_pose(f[5],180)],[.50,_turn_pose(f[5],270)],[.60,_turn_pose(f[5],360)],[.72,f[0]],[.82,f[6]]]
		"yuki": keys += [[.20,f[2]],[.32,_turn_pose(f[2],90,.12)],[.44,_turn_pose(f[3],180,.2)],[.56,_turn_pose(f[3],270,.12)],[.67,_turn_pose(f[3],360)],[.82,f[6]]]
		"ivy": keys += [[.20,f[0]],[.32,f[1]],[.44,_turn_pose(f[5],-70)],[.55,_turn_pose(f[5],55)],[.67,f[3]],[.82,f[6]]]
		"rook": keys += [[.20,f[5]],[.32,_blend_pose(f[5],f[3],.45)],[.45,f[3]],[.58,_turn_pose(f[3],90)],[.67,_turn_pose(f[3],0)],[.82,f[6]]]
		"atlas": keys += [[.21,f[0]],[.33,f[2]],[.45,f[3]],[.57,_turn_pose(f[3],0,.32)],[.68,_turn_pose(f[3],0,.08)],[.82,f[6]]]
		"zero": keys += [[.20,f[5]],[.31,f[0]],[.41,f[1]],[.52,f[2]],[.65,f[4]],[.82,f[6]]]
		"vex": keys += [[.20,_turn_pose(f[5],-80)],[.31,_turn_pose(f[1],-140)],[.42,_turn_pose(f[2],-220)],[.53,_turn_pose(f[3],-300,.15)],[.67,_turn_pose(f[5],-360)],[.82,f[6]]]
		"sora": keys += [[.20,f[5]],[.32,_turn_pose(f[3],0,.13)],[.44,_turn_pose(f[2],90,.30)],[.55,_turn_pose(f[3],180,.25)],[.68,_turn_pose(f[6],270,.1)],[.82,_turn_pose(f[6],360)]]
		"raijin": keys += [[.17,f[0]],[.24,f[1]],[.31,f[0]],[.38,f[2]],[.46,f[1]],[.57,f[3]],[.69,_turn_pose(f[3],0,.25)],[.82,f[6]]]
		_: keys += [[.18,f[0]],[.26,f[1]],[.34,f[0]],[.42,f[1]],[.55,f[3]],[.68,_turn_pose(f[3],0,.12)],[.82,f[6]]]
	keys += [[.89,f[6]],[1.0,_blend_pose(stance,f[6],.3)]]
	return keys


static func cinematic_motion(style: String, time: float) -> Vector3:
	# Director displacement: X forward, Y up, Z lateral. Caller applies facing.
	var t := clampf(time/3.5,0.0,1.0)
	var points: Array = [[0.0,Vector3.ZERO],[.12,Vector3(0,0,-.18)],[.24,Vector3(0,0,.55)],[.60,Vector3(0,0,.70)],[.82,Vector3(0,0,1.1)],[1.0,Vector3(0,0,.75)]]
	match style:
		"neon": points = [[0.0,Vector3.ZERO],[.2,Vector3(0,0,.2)],[.45,Vector3(.35,0,.35)],[.6,Vector3.ZERO],[.82,Vector3(0,0,.65)],[1.0,Vector3(0,0,.4)]]
		"yuki": points = [[0.0,Vector3.ZERO],[.2,Vector3(0,0,.3)],[.44,Vector3(.15,.5,.45)],[.65,Vector3(-.1,.3,.6)],[.82,Vector3(0,.15,.8)],[1.0,Vector3(0,0,.6)]]
		"ivy": points = [[0.0,Vector3.ZERO],[.2,Vector3(-.2,0,.2)],[.44,Vector3(.25,0,.35)],[.65,Vector3(-.15,0,.5)],[.82,Vector3(0,0,.8)],[1.0,Vector3(0,0,.5)]]
		"rook": points = [[0.0,Vector3.ZERO],[.2,Vector3(0,0,.7)],[.45,Vector3(0,0,.75)],[.67,Vector3(.25,.12,.6)],[.82,Vector3(0,0,.85)],[1.0,Vector3(0,0,.6)]]
		"atlas": points = [[0.0,Vector3.ZERO],[.3,Vector3(0,0,.35)],[.45,Vector3(0,.15,.45)],[.57,Vector3(0,.70,.65)],[.82,Vector3(0,0,1.0)],[1.0,Vector3(0,0,.8)]]
		"zero": points = [[0.0,Vector3.ZERO],[.2,Vector3(0,0,-.15)],[.31,Vector3(0,0,.5)],[.52,Vector3(0,0,.65)],[.65,Vector3(0,0,.25)],[.82,Vector3(0,0,1.0)],[1.0,Vector3(0,0,.7)]]
		"vex": points = [[0.0,Vector3.ZERO],[.2,Vector3(-.4,0,.2)],[.31,Vector3(.3,0,.9)],[.53,Vector3(-.25,.25,.6)],[.67,Vector3(.15,0,.35)],[.82,Vector3(0,0,1.05)],[1.0,Vector3(0,0,.6)]]
		"sora": points = [[0.0,Vector3.ZERO],[.2,Vector3(0,.15,.15)],[.44,Vector3(.15,.85,.55)],[.55,Vector3(-.15,.95,.7)],[.68,Vector3(.15,.5,.9)],[.82,Vector3(0,.2,1.0)],[1.0,Vector3(0,0,.7)]]
		"raijin": points = [[0.0,Vector3.ZERO],[.12,Vector3(0,0,-.15)],[.17,Vector3(0,0,.55)],[.46,Vector3(0,0,.70)],[.69,Vector3(0,.6,.85)],[.82,Vector3(0,0,1.15)],[1.0,Vector3(0,0,.75)]]
	for i in range(1,points.size()):
		if t <= float(points[i][0]):
			var weight := inverse_lerp(float(points[i-1][0]),float(points[i][0]),t)
			var offset := (points[i-1][1] as Vector3).lerp(points[i][1],smoothstep(0.0,1.0,weight))
			return Vector3(clampf(offset.z*.52,-.6,.6),offset.y,offset.x)
	var last: Vector3 = points[-1][1]
	return Vector3(clampf(last.z*.52,-.6,.6),last.y,last.x)
