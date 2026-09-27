class_name SuperDirector
extends Node3D
## Presentation-only cinematic clock. It never modifies combat state or HP.

var active: bool = false
var finished: bool = false
var frame: int = 0
var duration: int = 210
var camera: Camera3D
var attacker: int = 0
var defender: int = 1
var style: String = "kai"
var _actors: Array[AvatarActor] = []
var _stage: GameStage
var _original: Array[Transform3D] = []
var _saved_camera: Transform3D
var _saved_fov: float = 36.0
var _bases: Array[Vector3] = []
var _facing: float = 1.0
var _beats: PackedInt32Array = PackedInt32Array([0, 50, 88, 127, 165])


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "SuperCamera"
	camera.near = .04
	camera.far = 180
	add_child(camera)


func start(payload: Dictionary, fighters: Array[AvatarActor], arena: GameStage) -> void:
	cancel()
	_actors = fighters
	_stage = arena
	attacker = int(payload.get("attacker", 0))
	defender = int(payload.get("defender", 1 - attacker))
	style = str(payload.get("style", _actors[attacker].fighter_id))
	_beats = PackedInt32Array([0, 42, 70, 108, 160] if style == "kai" else [0, 50, 88, 127, 165])
	duration = maxi(1, int(payload.get("cinematic_frames", 210)))
	_original.clear()
	_bases.clear()
	for actor in _actors:
		_original.append(actor.transform)
		_bases.append(actor.position)
	_saved_camera = _stage.camera.global_transform
	_saved_fov = _stage.camera.fov
	_facing = 1.0 if _bases[defender].x >= _bases[attacker].x else -1.0
	frame = 0
	active = true
	finished = false
	camera.make_current()
	_sample()


func advance() -> PackedInt32Array:
	var beats := PackedInt32Array()
	if not active: return beats
	for index in _beats.size():
		if frame == int(float(_beats[index]) * float(duration) / 210.0): beats.append(index)
	_sample()
	frame += 1
	finished = frame >= duration
	return beats


func cancel() -> void:
	if active:
		for i in _actors.size():
			if is_instance_valid(_actors[i]) and i < _original.size():
				_actors[i].transform = _original[i]
		if is_instance_valid(_stage) and is_instance_valid(_stage.camera):
			_stage.camera.global_transform = _saved_camera
			_stage.camera.fov = _saved_fov
			_stage.camera.make_current()
	active = false
	finished = false
	frame = 0


func effect_point() -> Vector2:
	if _actors.size() < 2: return Vector2.ZERO
	if style == "kai":
		var anchor := _actors[defender].presentation_anchor("body")
		return Vector2(anchor.x, anchor.y)
	var at := _actors[defender].position
	return Vector2(at.x, at.y + 1.1)


func _sample() -> void:
	if style == "kai":
		_sample_kai()
		return
	var progress := clampf(float(frame) / float(duration), 0.0, 1.0)
	var seconds := progress * 3.5
	var hero := _actors[attacker]
	var victim := _actors[defender]
	var motion := AvatarActor.cinematic_motion(style, seconds)
	hero.position = _bases[attacker] + Vector3(motion.x * _facing, motion.y, motion.z)
	hero.rotation = Vector3(0, PI * .5 * _facing, 0)
	hero.present_cinematic(hero.fighter_id, seconds, "attacker")
	var lift: float = 0.0
	var recoil: float = 0.0
	if progress > .23 and progress < .87:
		var pulse := maxf(0, sin((progress - .23) * TAU * 5.5))
		recoil = .11 * pulse
		if style in ["sora", "yuki", "kai", "rook"]:
			lift = maxf(0, sin((progress - .23) / .64 * PI)) * (1.15 if style == "sora" else .7 if style == "rook" else .45)
		elif style == "atlas": lift = .16 * pulse
	victim.position = _bases[defender] + Vector3(_facing * recoil, lift, 0)
	victim.rotation = Vector3(0, -PI * .5 * _facing, 0)
	victim.present_cinematic(victim.fighter_id, seconds, "victim")
	var face := _bone_point(hero, "Head", Vector3(0, 1.5, 0))
	var middle := (hero.position + victim.position) * .5 + Vector3(0, .95, 0)
	var target: Vector3
	var eye: Vector3
	if progress < .22:
		# Opening portrait push-in; the combat plane remains stationary underneath.
		target = face + Vector3(0, -.1, 0)
		eye = target + Vector3(_facing * 1.45, .12, lerpf(2.05, 1.5, progress / .22))
		camera.fov = 34
	elif progress < .57:
		var t := (progress - .22) / .35
		target = middle
		eye = middle + Vector3(_facing * lerpf(-.6, .65, t), .55, 4.2)
		camera.fov = 39
	elif progress < .78:
		var t := (progress - .57) / .21
		target = middle + Vector3(0, .15, 0)
		eye = middle + Vector3(_facing * 1.5, lerpf(2.8, 1.5, t), 3.7)
		camera.fov = 43
	else:
		target = middle
		eye = middle + Vector3(-_facing * .8, .35, 3.9)
		camera.fov = 42
	# Bounded impact jitter is visual only, and pauses with the cinematic clock.
	if frame in [50, 51, 88, 89, 127, 128, 165, 166, 167]:
		eye += Vector3(sin(frame * 8.7), cos(frame * 3.7), 0) * .065
	camera.global_position = eye
	camera.look_at(target, Vector3.UP)
	if progress > .9:
		var blend := smoothstep(.9, 1.0, progress)
		camera.global_transform = camera.global_transform.interpolate_with(_saved_camera, blend)
		camera.fov = lerpf(camera.fov, _saved_fov, blend)


func _bone_point(actor: AvatarActor, bone_name: String, fallback: Vector3) -> Vector3:
	if actor.skeleton:
		var bone := actor.skeleton.find_bone(bone_name)
		if bone >= 0:
			return actor.skeleton.global_transform * actor.skeleton.get_bone_global_pose(bone).origin
	return actor.global_position + fallback


func _sample_kai() -> void:
	var f := float(frame) * 210.0 / duration
	for contact in [42,70,108,160]:
		if f >= contact and f <= contact + 3: f = contact
	var hero := _actors[attacker]
	var victim := _actors[defender]
	var center := (_bases[attacker] + _bases[defender]) * .5
	center.y = 0
	var gap := .9
	var gaps := [[0,.9],[24,.72],[42,.55],[70,.52],[108,.62],[136,.9],[160,.98],[184,1.3],[210,1.3]]
	for i in range(1, gaps.size()):
		if f <= gaps[i][0]:
			gap = lerpf(gaps[i-1][1], gaps[i][1], smoothstep(gaps[i-1][0], gaps[i][0], f))
			break
	var settle := smoothstep(184, 210, f)
	var enter := smoothstep(0, 24, f)
	hero.position = _bases[attacker].lerp(center + Vector3(-.42 * _facing,0,0), enter).lerp(_bases[attacker], settle)
	hero.rotation = Vector3(0, PI * .5 * _facing, 0)
	hero.present_cinematic("kai", f / 60, "attacker")
	# The rising blow launches once. Subsequent motion is a fall, not sinusoidal bobbing.
	var lift := 0.0
	if f >= 108 and f < 171:
		var t := (f - 108) / 63
		lift = 4 * .52 * t * (1-t)
	victim.position = _bases[defender].lerp(hero.position + Vector3(gap * _facing, lift, 0), enter).lerp(_bases[defender], settle)
	victim.rotation = Vector3(0, -PI * .5 * _facing, 0)
	var last_hit := -1.0
	for hit in [42,70,108,160]:
		if f >= hit: last_hit = hit
	if last_hit < 0:
		victim.present("guard", 0, victim.rotation.y)
	else:
		# Hold the contact pose for three frames, then release the struck body.
		var hit_time := minf(.28, maxf(0, f - last_hit - 3) / 60 + .055)
		victim.present("hit", hit_time, victim.rotation.y)
		var recoil := .1 * exp(-maxf(0,f-last_hit) / 9)
		victim.position.x += recoil * _facing * (1-settle)
	var face := _bone_point(hero,"Head",Vector3(0,1.5,0))
	var middle := (hero.position + victim.position) * .5 + Vector3(0,1.05,0)
	var eye: Vector3
	var target := middle
	if f < 24:
		target = face + Vector3(0,-.08,0)
		eye = target + Vector3(_facing * 1.0,.12,lerpf(1.7,1.3,f/24))
		camera.fov = 35
	elif f < 91:
		eye = middle + Vector3(_facing * lerpf(-.65,.45,(f-24)/67),.08,lerpf(2.75,3.05,(f-24)/67))
		camera.fov = 43
	elif f < 136:
		target += Vector3(0,.15,0)
		eye = middle + Vector3(_facing * .85,-.35,3.2)
		camera.fov = 46
	else:
		eye = middle + Vector3(-_facing * .65,.4,3.35)
		camera.fov = lerpf(46,39,smoothstep(160,184,f))
	if last_hit >= 0 and f-last_hit < 4:
		eye += Vector3(_facing * .055, .025, 0) * (1-(f-last_hit)/4)
	camera.global_position = eye
	camera.look_at(target)
	if settle > 0:
		camera.global_transform = camera.global_transform.interpolate_with(_saved_camera,settle)
		camera.fov = lerpf(camera.fov,_saved_fov,settle)
