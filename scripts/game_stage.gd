class_name GameStage
extends Node3D
## Three arenas dressed with downloaded Poly Haven CC0 models and surfaces.
## Background motion and stage layouts are authored here; source meshes are static.

const ASSETS := "res://assets/environments/"
const NAMES := ["NEON OVERPASS", "CINDER WORKS", "HALLOWED DAWN"]
const SKIES := ["shanghai_bund", "industrial_sunset_02", "spruit_sunrise"]
const FighterProfiles = preload("res://combat/FighterCatalog.gd")
const FX_COLORS := {"fire": Color("ff733a"), "sonic": Color("58e6ff"), "ice": Color("b0eeff"), "thorn": Color("69e380"), "crimson": Color("ff3c65"), "seismic": Color("ffca55"), "precision": Color("69b7ff"), "void": Color("b96cff"), "wind": Color("ffa0cf"), "electric": Color("d3ff46")}
const FX_STYLES := {"kai": "fire", "neon": "sonic", "yuki": "ice", "ivy": "thorn", "rook": "crimson", "atlas": "seismic", "zero": "precision", "vex": "void", "sora": "wind", "raijin": "electric"}
const MAX_EFFECTS := 56

var camera: Camera3D
var stage_index: int = 0
var presentation: String = "menu"
var _dressing: Node3D
var _world: WorldEnvironment
var _environment: Environment
var _clock: float = 0.0
var _rotors: Array[Node3D] = []
var _floaters: Array[Dictionary] = []
var _pulses: Array[Dictionary] = []
var _effects: Array[Dictionary] = []
var _projectile_nodes: Dictionary[int, Node3D] = {}
var _charge_nodes: Dictionary[int, Node3D] = {}
var _style_colors: Dictionary[String, Color] = {}
var _trail_shader: Shader
var _scenes: Dictionary = {}
var _textures: Dictionary = {}
var _camera_position := Vector3(0.65, 1.35, 3.7)
var _camera_target := Vector3(-0.65, 0.94, 0)
var _shake: float = 0.0


func setup(index: int = 0) -> void:
	if camera == null:
		camera = Camera3D.new()
		camera.name = "ArenaCamera"
		camera.fov = 36.0
		camera.near = 0.05
		camera.far = 180.0
		add_child(camera)
		camera.current = true
		_world = WorldEnvironment.new()
		_world.name = "ArenaEnvironment"
		add_child(_world)
	set_stage(index)
	set_presentation(presentation)
	_update_camera(1.0)


func set_stage(index: int) -> void:
	if camera == null:
		setup(index)
		return
	stage_index = posmod(index, NAMES.size())
	_rotors.clear()
	_floaters.clear()
	_pulses.clear()
	clear_combat_effects()
	if is_instance_valid(_dressing):
		_dressing.free()
	_dressing = Node3D.new()
	_dressing.name = "ArenaDressing"
	add_child(_dressing)
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = _texture(ASSETS + "skies/" + SKIES[stage_index] + "_2k.hdr")
	var sky := Sky.new()
	sky.sky_material = panorama
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	_environment.sky = sky
	# The Shanghai photograph faces the nearby promenade at zero rotation.
	# Turn toward the river and distant skyline rather than the bright park lamps.
	_environment.sky_rotation = Vector3(0, [PI + 0.4, 3.2, 2.0][stage_index], 0)
	_environment.background_energy_multiplier = [0.10, 0.65, 0.75][stage_index]
	# Panorama exposure includes very bright lamps/sun; a controlled ambient fill
	# keeps those captured light sources from bleaching the fight platform.
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = [Color("718aa5"), Color("9d8171"), Color("b2c2ad")][stage_index]
	_environment.ambient_light_energy = [0.30, 0.34, 0.42][stage_index]
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.tonemap_exposure = [0.9, 0.85, 0.85][stage_index]
	_environment.glow_enabled = true
	_environment.glow_intensity = 0.75
	_environment.glow_bloom = 0.08
	_environment.ssao_enabled = true
	_environment.ssao_intensity = 1.2
	_environment.fog_enabled = true
	_environment.fog_light_color = [Color("152435"), Color("49392c"), Color("78816c")][stage_index]
	_environment.fog_density = [0.0035, 0.004, 0.005][stage_index]
	# Default sky affect is 1: distance fog then replaces the entire HDR skyline.
	_environment.fog_sky_affect = 0.0
	_world.environment = _environment
	_key_lights()
	match stage_index:
		0: _neon_overpass()
		1: _cinder_works()
		2: _hallowed_dawn()


func stage_names() -> PackedStringArray:
	return PackedStringArray(NAMES)


func set_presentation(mode: String) -> void:
	presentation = mode
	if camera == null:
		return
	match mode:
		"fight":
			camera.fov = 36.0
			_camera_position = Vector3(0, 2.05, 7.2)
			_camera_target = Vector3(0, 0.95, -0.1)
		"select":
			camera.fov = 34.0
			_camera_position = Vector3(0.50, 1.4, 3.5)
			_camera_target = Vector3(-0.65, 1.1, 0)
		"victory":
			camera.fov = 32.0
			_camera_position = Vector3(1.0, 1.45, 4.0)
			_camera_target = Vector3(-0.6, 0.98, 0)
		_:
			camera.fov = 35.0
			_camera_position = Vector3(0.65, 1.35, 3.7)
			_camera_target = Vector3(-0.65, 0.94, 0)


func frame_fighters(fighters: Array[Dictionary], delta: float) -> void:
	if camera == null or fighters.is_empty():
		return
	if presentation == "fight":
		var left := 1000.0
		var right := -1000.0
		var height := 0.0
		for fighter in fighters:
			var point: Vector2 = fighter.get("position", Vector2.ZERO)
			left = minf(left, point.x)
			right = maxf(right, point.x)
			height = maxf(height, point.y)
		var center := (left + right) * 0.5
		var aspect := get_viewport().get_visible_rect().size.aspect()
		var width := maxf(5.6, right - left + 3.0)
		var distance := maxf(6.6, width / (2.0 * tan(deg_to_rad(camera.fov * 0.5)) * maxf(1.0, aspect)))
		distance += minf(height * 0.30, 1.1)
		_camera_target = Vector3(center, 0.98 + height * 0.22, 0)
		_camera_position = Vector3(center, 2.05 + height * 0.35, distance)
	_update_camera(delta)


func style_color(style: String) -> Color:
	if FX_STYLES.has(style):
		if not _style_colors.has(style):
			var profile: Dictionary = FighterProfiles.get_fighter(style)
			_style_colors[style] = profile["color"]
		return _style_colors[style]
	return FX_COLORS.get(_fx_style(style), FX_COLORS.fire)


func _fx_style(style: String) -> String:
	return str(FX_STYLES.get(style.to_lower(), style.to_lower()))


func impact(at: Vector2, blocked: bool = false, strong: bool = false, style: String = "fire", impulse: float = 0.0) -> void:
	if _dressing == null:
		return
	var family: String = _fx_style(style)
	var color: Color = Color("b8edff") if blocked else style_color(style)
	var event_root: Node3D = _effect_root(at, 0.48 if strong else 0.28, family)
	_fx_ring(event_root, 0.17 if strong else 0.09, 0.025, color, Vector3.ZERO, 3.8)
	if blocked:
		_fx_ring(event_root, 0.28, 0.018, color, Vector3.ZERO, 1.4)
		_rays(event_root, color, 6, 1.5, 0.22, false)
	else:
		_rays(event_root, color, 15 if strong else 9, 3.2 if strong else 2.4, 0.36 if strong else 0.20, family in ["ice", "precision", "thorn"])
		if strong:
			_fx_ring(event_root, 0.30, 0.02, color.lightened(0.35), Vector3.ZERO, 3.0)
		if family == "electric":
			for i: int in range(4):
				var angle: float = i * TAU / 4.0
				_bolt(event_root, Vector3.ZERO, Vector3(cos(angle), sin(angle), 0) * 0.7, color, i)
		elif family == "void":
			_fx_ring(event_root, 0.40, 0.045, color, Vector3(0, 0, -0.04), -0.7)
		elif family == "seismic":
			_ground_wave(Vector2(at.x, 0.03), color, 1.4 if strong else 0.8)
	var default_shake: float = 0.08 if strong else (0.018 if blocked else 0.035)
	_shake = maxf(maxf(_shake, default_shake), clampf(impulse * (0.22 if strong else 0.15), 0.0, 0.12))


func attack_effect(at: Vector2, facing: int, style: String, kind: String = "special") -> void:
	if _dressing == null: return
	var family: String = _fx_style(style)
	var color: Color = style_color(style)
	var charged: bool = kind in ["charge", "super", "finisher"]
	var heavy: bool = kind in ["heavy", "special", "super", "finisher"]
	var radius: float = 0.90 if heavy else 0.52
	var root: Node3D = _effect_root(at, 0.70 if charged else 0.34, family)
	var direction: float = 1.0 if facing >= 0 else -1.0
	if charged:
		for i: int in range(3):
			var halo: MeshInstance3D = _fx_ring(root, 0.30 + i * 0.13, 0.018, color, Vector3(0, 0, i * -0.05), -0.72)
			halo.rotation.z = i * 0.6
		_rays(root, color, 12, -0.8, 0.18, false)
		return
	match family:
		"sonic":
			for i: int in range(3):
				var ring: MeshInstance3D = _fx_ring(root, 0.18 + i * 0.13, 0.025, color, Vector3(direction * (0.28 + i * 0.15), 0, -i * 0.02), 1.0)
				ring.set_meta("velocity", Vector3(direction * 1.8, 0, 0))
		"ice", "precision":
			_trail(root, direction, radius, color, 0.065 if family == "precision" else 0.12)
			for i: int in range(6):
				var shard: MeshInstance3D = _crystal(root, Vector3(direction * (0.15 + i * 0.12), (i % 3 - 1) * 0.13, 0), color, 0.07, 0.28)
				shard.rotation.z = -direction * (PI * 0.5 + (i % 3 - 1) * 0.3)
				shard.set_meta("velocity", Vector3(direction * (1.0 + i * 0.12), (i % 3 - 1) * 0.6, 0))
		"thorn":
			_trail(root, direction, radius, color, 0.07)
			_trail(root, direction, radius * 0.75, color.darkened(0.2), 0.055, 0.8)
			_rays(root, color, 7, 1.7, 0.34, true)
		"crimson":
			_trail(root, direction, radius * 1.15, color, 0.15, -0.5)
			_trail(root, direction, radius * 0.82, color.lightened(0.4), 0.035, 1.1)
		"seismic":
			_ground_wave(Vector2(at.x + direction * 0.5, 0.035), color, 1.6)
			for i: int in range(6):
				var rock: MeshInstance3D = _crystal(root, Vector3(direction * i * 0.15, -at.y + 0.02, 0), color.darkened(0.35), 0.12, 0.36)
				rock.set_meta("velocity", Vector3(direction * (0.4 + i * 0.16), 2.1 + (i % 2) * 0.8, 0))
				rock.set_meta("gravity", Vector3(0, -5, 0))
		"void":
			for i: int in range(2):
				var halo: MeshInstance3D = _fx_ring(root, 0.40 + i * 0.16, 0.035, color, Vector3(direction * 0.45, 0, 0), 0.3)
				halo.scale = Vector3(1.0, 1.0, 0.55)
				halo.rotation.z = i * 1.0
			_trail(root, direction, radius, color.lightened(0.35), 0.06)
		"wind":
			for i: int in range(3):
				_trail(root, direction, radius * (0.65 + i * 0.2), color.lightened(i * 0.14), 0.045, i * 0.35)
		"electric":
			for i: int in range(3):
				_bolt(root, Vector3(direction * 0.1, (i - 1) * 0.15, 0), Vector3(direction * radius * 1.35, (i - 1) * 0.30, 0), color, i)
			_fx_ring(root, 0.2, 0.018, color, Vector3(direction * 0.8, 0, 0), 1.2)
		_:
			_trail(root, direction, radius, color, 0.12)
			_trail(root, direction, radius * 0.76, color.lightened(0.4), 0.04, 0.2)
			_rays(root, color, 8, 1.7, 0.12, false)


## Phase-one move signatures use the authored cue from MoveData. They are kept
## separate from hit impact so a player reads the attack before contact happens.
func move_effect(at: Vector2, facing: int, style: String, cue: String, intensity: float = 0.08) -> void:
	if _dressing == null:
		return
	var color: Color = style_color(style)
	var bright: Color = color.lightened(0.32)
	var direction: float = 1.0 if facing >= 0 else -1.0
	var root: Node3D
	match cue:
		"kai_body_hook", "kai_knee", "kai_spin_kick", "kai_side_kick":
			root = _effect_root(at, .25 if cue == "kai_body_hook" else .38, "fire")
			var angle := PI * .48 if cue == "kai_knee" else -.7 if cue == "kai_spin_kick" else 0.0
			var reach := .38 if cue == "kai_body_hook" else .55 if cue == "kai_knee" else 1.05 if cue == "kai_spin_kick" else .75
			_trail(root, direction, reach, color, .04, angle)
			_trail(root, direction, reach * .8, bright, .013, angle + .12)
			_rays(root, bright, 6 if cue == "kai_spin_kick" else 3, 2.4, .13, false)
		"kai_ember_jab":
			root = _effect_root(at, 0.22, "fire")
			_trail(root, direction, 0.38, color, 0.042, -0.12)
			_fx_ring(root, 0.095, 0.016, bright, Vector3(direction * 0.22, 0.0, 0.0), 2.0)
			_rays(root, color, 4, 1.4, 0.12, false)
		"kai_flare_cross":
			root = _effect_root(at, 0.34, "fire")
			_trail(root, direction, 0.84, color, 0.062, -0.46)
			_trail(root, direction, 0.68, bright, 0.018, 0.18)
			_rays(root, color, 6, 2.2, 0.16, false)
		"kai_cinder_sweep":
			root = _effect_root(at, 0.38, "fire")
			_trail(root, direction, 0.74, color.darkened(0.06), 0.068, -1.08)
			_trail(root, direction, 0.62, bright, 0.018, -1.08)
			_ground_wave(Vector2(at.x + direction * 0.28, 0.028), color, 0.78)
		"kai_rising_phoenix":
			root = _effect_root(at, 0.46, "fire")
			_trail(root, direction, 0.98, color, 0.068, PI * 0.46)
			_trail(root, direction, 0.72, bright, 0.018, PI * 0.46)
			_rays(root, color, 7, 2.2, 0.17, false)
		"kai_heat_step":
			root = _effect_root(at, 0.26, "fire")
			for i: int in range(2):
				var echo: MeshInstance3D = _fx_ring(root, 0.16 + i * 0.10, 0.012, color, Vector3(-direction * i * 0.16, -0.04, -i * 0.03), 1.6)
				echo.rotation.z = 0.44 * i
		"kai_blazing_drive":
			root = _effect_root(at, 0.54, "fire")
			_trail(root, direction, 1.20, color, 0.082, -0.22)
			_trail(root, direction, 0.98, bright, 0.025, 0.42)
			for i: int in range(3):
				var flare: MeshInstance3D = _fx_ring(root, 0.15 + i * 0.10, 0.012, bright, Vector3(direction * (0.24 + i * 0.20), 0.02, -i * 0.025), 1.2)
				flare.set_meta("velocity", Vector3(direction * (1.8 + i * 0.4), 0.0, 0.0))
		"neon_pulse_tap":
			root = _effect_root(at, 0.24, "sonic")
			for i: int in range(2):
				var pulse: MeshInstance3D = _fx_ring(root, 0.11 + i * 0.08, 0.010, bright, Vector3(direction * (0.18 + i * 0.10), 0.0, -i * 0.02), 1.8)
				pulse.set_meta("velocity", Vector3(direction * 1.5, 0.0, 0.0))
		"neon_bass_hammer":
			root = _effect_root(at, 0.38, "sonic")
			_trail(root, direction, 0.90, color, 0.033, 0.04)
			for i: int in range(3):
				var bass: MeshInstance3D = _fx_ring(root, 0.18 + i * 0.09, 0.014, color, Vector3(direction * (0.28 + i * 0.16), 0.0, -i * 0.02), 1.4)
				bass.scale = Vector3(1.0, 0.56, 1.0)
				bass.set_meta("velocity", Vector3(direction * 1.2, 0.0, 0.0))
		"neon_beat_sweep":
			root = _effect_root(at, 0.34, "sonic")
			_trail(root, direction, 0.84, color, 0.048, -1.14)
			_fx_ring(root, 0.25, 0.012, bright, Vector3(direction * 0.32, -0.18, 0.0), 1.9)
		"neon_feedback_rise":
			root = _effect_root(at, 0.46, "sonic")
			for i: int in range(4):
				var feedback: MeshInstance3D = _fx_ring(root, 0.16 + i * 0.07, 0.011, color, Vector3(direction * 0.10, i * 0.15, -i * 0.018), 1.0)
				feedback.set_meta("velocity", Vector3(direction * 0.42, 1.35, 0.0))
		"neon_reverb_step":
			root = _effect_root(at, 0.28, "sonic")
			for i: int in range(3):
				var echo: MeshInstance3D = _fx_ring(root, 0.13 + i * 0.09, 0.010, color, Vector3(-direction * i * 0.13, -0.05, -i * 0.025), 1.4)
				echo.scale = Vector3(1.0, 0.7, 1.0)
		"neon_sonic_lance":
			root = _effect_root(at, 0.40, "sonic")
			_trail(root, direction, 1.08, color, 0.026, 0.0)
			for i: int in range(4):
				var lance: MeshInstance3D = _fx_ring(root, 0.12 + i * 0.045, 0.009, bright, Vector3(direction * (0.25 + i * 0.19), 0.0, -i * 0.016), 0.9)
				lance.scale = Vector3(1.0, 0.48, 1.0)
				lance.set_meta("velocity", Vector3(direction * 2.4, 0.0, 0.0))
		_:
			if cue.begins_with(style + "_"):
				_character_move_effect(at, facing, style, cue.trim_prefix(style + "_"), intensity)
			else:
				attack_effect(at, facing, style, "super" if cue == "super" else "special")
			return
	_shake = maxf(_shake, clampf(intensity * 0.42, 0.012, 0.10))


## Full-roster move signatures use a small authored vocabulary instead of the
## old generic fallback. This keeps the visual language consistent while making
## ice, thorns, grapples, stone, precision, void, wind, and lightning readable
## at a glance before they connect.
func _character_move_effect(at: Vector2, facing: int, style: String, token: String, intensity: float) -> void:
	var family: String = _fx_style(style)
	var color: Color = style_color(style)
	var bright: Color = color.lightened(0.32)
	var direction: float = 1.0 if facing >= 0 else -1.0
	var special: bool = token in ["winter_wave", "creeping_garden", "clinch_drive", "seismic_break", "perfect_reversal", "rift_ambush", "tempest_rise", "chain_lightning", "super"]
	var rise: bool = token in ["crystal_rise", "vine_spiral", "backbreaker", "mountain_rise", "axis_cutter", "abyss_rise", "sky_ascent", "storm_rise"]
	var dodge: bool = token in ["snowdrift", "petal_slip", "shoulder_slip", "braced_step", "phase_read", "event_step", "cloud_step", "flash_step"]
	var low: bool = token in ["black_ice", "root_cutter", "ankle_break", "quake_sweep", "circuit_sweep", "shadow_reap", "gale_sweep", "arc_sweep"]
	if token == "super":
		attack_effect(at, facing, style, "super")
		return
	var root: Node3D = _effect_root(at, 0.66 if special else (0.42 if rise else 0.30), family)
	if dodge:
		for i: int in range(3):
			var echo: MeshInstance3D = _fx_ring(root, 0.13 + i * 0.08, 0.012, color, Vector3(-direction * i * 0.14, 0.02 * i, -i * 0.025), 1.4)
			echo.rotation.z = i * 0.48
		if family == "void":
			_fx_ring(root, 0.42, 0.03, bright, Vector3(direction * 0.25, 0.0, -0.08), -0.35)
		elif family == "electric":
			_bolt(root, Vector3.ZERO, Vector3(direction * 0.88, 0.10, 0), color, 7)
		elif family == "ice":
			_rays(root, color, 5, -0.65, 0.13, true)
		_shake = maxf(_shake, 0.012)
		return
	match family:
		"ice":
			_trail(root, direction, 0.78 if special else 0.52, color, 0.06 if low else 0.09, -0.92 if low else 0.22)
			for i: int in range(10 if special else 6):
				var shard: MeshInstance3D = _crystal(root, Vector3(direction * (0.12 + i * 0.09), (i % 3 - 1) * 0.12, 0), color, 0.055, 0.20 + (i % 2) * 0.10)
				shard.rotation.z = direction * (PI * 0.5 + (i % 3 - 1) * 0.34)
				shard.set_meta("velocity", Vector3(direction * (0.85 + i * 0.10), 0.25 * (i % 3 - 1), 0))
			if rise:
				for i: int in range(4):
					var pillar: MeshInstance3D = _crystal(root, Vector3(direction * 0.18, i * 0.27, 0), bright, 0.12, 0.46)
					pillar.set_meta("velocity", Vector3(direction * 0.18, 1.25, 0))
			if low or special:
				_ground_wave(Vector2(at.x + direction * 0.34, 0.03), color, 1.45 if special else 0.84)
		"thorn":
			_trail(root, direction, 0.96 if special else 0.70, color, 0.046 if low else 0.07, -0.92 if low else 0.10)
			for i: int in range(9 if special else 5):
				var thorn: MeshInstance3D = _crystal(root, Vector3(direction * (0.12 + i * 0.11), sin(i * 2.0) * 0.16, 0), bright if i % 2 == 0 else color.darkened(0.18), 0.05, 0.29)
				thorn.rotation.z = -direction * (PI * 0.5 + sin(i * 2.0) * 0.42)
				thorn.set_meta("velocity", Vector3(direction * (0.8 + i * 0.12), 0.16 * sin(i), 0))
			if rise:
				_fx_ring(root, 0.33, 0.02, color, Vector3(direction * 0.18, 0.34, 0), 1.1)
			if special:
				_ground_wave(Vector2(at.x + direction * 0.38, 0.03), color, 1.55)
		"crimson":
			_trail(root, direction, 1.02 if special else 0.74, color, 0.13 if special else 0.095, -0.58 if low else -0.16)
			_trail(root, direction, 0.76 if special else 0.52, bright, 0.026, 0.84)
			if token in ["backbreaker", "clinch_drive"]:
				for i: int in range(4):
					var lock: MeshInstance3D = _fx_ring(root, 0.16 + i * 0.07, 0.014, color, Vector3(direction * 0.24, 0.10 + i * 0.08, -i * 0.02), 0.9)
					lock.rotation.y = i * 0.55
		"seismic":
			_ground_wave(Vector2(at.x + direction * 0.34, 0.03), color, 1.75 if special else 1.05)
			for i: int in range(11 if special else 6):
				var rock: MeshInstance3D = _crystal(root, Vector3(direction * i * 0.11, -at.y + 0.05, 0), color.darkened(0.30), 0.07 + (i % 3) * 0.025, 0.22 + (i % 2) * 0.16)
				rock.set_meta("velocity", Vector3(direction * (0.28 + i * 0.11), 1.6 + (i % 3) * 0.45, 0))
				rock.set_meta("gravity", Vector3(0, -5.0, 0))
			if rise:
				_trail(root, direction, 0.70, bright, 0.08, PI * 0.48)
		"precision":
			_trail(root, direction, 0.94 if special else 0.66, color, 0.038, -0.18)
			for i: int in range(4 if not special else 8):
				var marker: MeshInstance3D = _fx_ring(root, 0.09 + i * 0.045, 0.008, bright, Vector3(direction * (0.18 + i * 0.12), (i % 2) * 0.12, -i * 0.018), 0.9)
				marker.scale = Vector3(1.0, 0.64, 1.0)
			if token == "perfect_reversal":
				_fx_ring(root, 0.48, 0.028, bright, Vector3(direction * 0.18, 0.12, 0), -0.6)
				_rays(root, bright, 10, 2.0, 0.16, true)
		"void":
			for i: int in range(3 if special else 2):
				var halo: MeshInstance3D = _fx_ring(root, 0.22 + i * 0.14, 0.025, color, Vector3(direction * (0.20 + i * 0.16), 0.0, -i * 0.04), 0.26)
				halo.scale = Vector3(1.0, 1.0, 0.52)
				halo.rotation.z = i * 0.78
			_trail(root, direction, 1.0 if special else 0.65, bright, 0.048, -0.38)
			if rise:
				_rays(root, color, 8, 2.15, 0.22, false)
		"wind":
			for i: int in range(5 if special else 3):
				_trail(root, direction, (0.52 + i * 0.13) * (1.18 if special else 1.0), color.lightened(i * 0.10), 0.032 + i * 0.005, -0.80 if low else i * 0.42)
			if rise or special:
				for i: int in range(5):
					var spiral: MeshInstance3D = _fx_ring(root, 0.14 + i * 0.075, 0.010, bright, Vector3(direction * 0.13, i * 0.17, -i * 0.025), 0.9)
					spiral.set_meta("velocity", Vector3(direction * 0.18, 0.75, 0))
		"electric":
			var bolts: int = 7 if special else (5 if rise else 3)
			for i: int in range(bolts):
				_bolt(root, Vector3(direction * 0.06, (i - bolts / 2.0) * 0.08, 0), Vector3(direction * (0.55 + i * 0.12), (i % 3 - 1) * 0.24, 0), color, i)
			_fx_ring(root, 0.15 if not special else 0.27, 0.014, bright, Vector3(direction * 0.48, 0.0, 0), 1.1)
			if low:
				_ground_wave(Vector2(at.x + direction * 0.28, 0.03), color, 0.84)
	_shake = maxf(_shake, clampf(intensity * (0.90 if special else 0.55), 0.014, 0.11))


func cinematic_effect(at: Vector2, style: String, beat: int) -> void:
	if _dressing == null: return
	var color: Color = style_color(style)
	if style == "kai":
		var root := _effect_root(at, .18 if beat < 4 else .5, "fire")
		if beat > 0:
			# Irregular tapered embers keep the contact visible; avoid a radial wheel of bars.
			for i in (12 if beat < 4 else 32):
				var angle := i * 2.39996 + beat
				var direction := Vector3(cos(angle), sin(angle), sin(i * 3.7) * .3)
				var ember := _crystal(root, direction * (.015 + .04 * absf(sin(i * 7.1))), Color(1,.55 + .3 * absf(sin(i)),.2), .006, .025 + .055 * absf(sin(i * 2.7)))
				ember.rotation.z = -angle
				ember.set_meta("velocity", direction * (1.5 + absf(sin(i * 5.3)) * (2.8 if beat == 4 else 1.0)))
				ember.set_meta("shrink", true)
			_trail(root, 1, .35 if beat < 4 else .8, color, .018, PI * .5 if beat == 3 else -.3)
			_shake = maxf(_shake, .045 if beat < 4 else .09)
		return
	if beat == 0:
		attack_effect(at, 1, style, "charge")
		_ground_wave(Vector2(at.x, 0.025), color, 2.2)
	elif beat == 1:
		var root: Node3D = _effect_root(at, 0.65, _fx_style(style))
		for i: int in range(3):
			_trail(root, 1.0 if i % 2 == 0 else -1.0, 1.05 + i * 0.24, color, 0.085, i * 1.3)
		_rays(root, color, 20, 3.1, 0.36, _fx_style(style) in ["ice", "thorn", "precision"])
		if _fx_style(style) == "electric":
			for i: int in range(7):
				var angle: float = i * TAU / 7.0
				_bolt(root, Vector3.ZERO, Vector3(cos(angle), sin(angle), 0) * 1.4, color, i)
	elif beat == 2:
		attack_effect(at, 1, style, "special")
		impact(at + Vector2(0.15, 0.1), false, false, style)
	elif beat == 3:
		var root: Node3D = _effect_root(at, 0.62, _fx_style(style))
		_trail(root, 1, 1.0, color, 0.11, PI * 0.5)
		for i: int in range(9):
			var shard: MeshInstance3D = _crystal(root, Vector3((i - 4) * 0.12, 0, 0), color, 0.035, 0.35)
			shard.set_meta("velocity", Vector3((i - 4) * 0.13, 2.6 + (i % 3) * 0.5, 0))
			shard.set_meta("shrink", true)
		_ground_wave(Vector2(at.x, 0.025), color, 1.7)
	else:
		impact(at, false, true, style)
		_ground_wave(Vector2(at.x, 0.025), color, 2.9)
		var root: Node3D = _effect_root(at, 0.60, _fx_style(style))
		_fx_ring(root, 0.42, 0.045, color, Vector3.ZERO, 3.4)
		_rays(root, color.lightened(0.2), 26, 4.3, 0.4, _fx_style(style) in ["ice", "precision", "thorn"])
		_shake = maxf(_shake, 0.095)


func update_projectiles(projectiles: Array[Dictionary]) -> void:
	if _dressing == null: return
	var alive: Dictionary[int, bool] = {}
	for projectile: Dictionary in projectiles:
		var id: int = int(projectile.get("id", -1))
		if id < 0: continue
		alive[id] = true
		var style: String = str(projectile.get("style", "fire"))
		var color: Color = projectile.get("color", style_color(style))
		var at: Vector2 = projectile.get("position", Vector2.ZERO)
		var size_value: Vector2 = projectile.get("size", Vector2(0.46, 0.46))
		var facing: int = int(projectile.get("direction", 1))
		if _projectile_nodes.has(id) and str(_projectile_nodes[id].get_meta("style", "")) != style:
			_projectile_nodes[id].queue_free()
			_projectile_nodes.erase(id)
		if not _projectile_nodes.has(id):
			var root := Node3D.new()
			root.name = "Projectile_%d" % id
			root.set_meta("style", style)
			root.set_meta("last_trail", _clock)
			root.set_meta("last_position", at)
			_dressing.add_child(root)
			_projectile_nodes[id] = root
			var core: MeshInstance3D
			if _fx_style(style) in ["ice", "precision", "thorn"]:
				core = _crystal(root, Vector3.ZERO, color, 0.38, 1.0)
				core.rotation.z = -float(facing) * PI * 0.5
				if _fx_style(style) == "thorn":
					for i: int in range(3):
						var thorn: MeshInstance3D = _crystal(root, Vector3(-facing * 0.15, (i - 1) * 0.21, 0), color.darkened(0.15), 0.13, 0.7)
						thorn.rotation.z = -facing * (PI * 0.5 + (i - 1) * 0.28)
			elif _fx_style(style) == "seismic":
				core = _crystal(root, Vector3.ZERO, color.darkened(0.3), 0.48, 0.95)
				for i: int in range(3):
					var stone: MeshInstance3D = _box(root, Vector3((i - 1) * 0.32, -0.20, 0), Vector3(0.24, 0.43 + (i % 2) * 0.2, 0.34), _fx_material(color, 1.1))
					stone.rotation.z = (i - 1) * 0.24
			else:
				core = _sphere(root, Vector3.ZERO, 0.45, _fx_material(color, 1.6))
			core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for i: int in range(2):
				var ring: MeshInstance3D = _fx_ring(root, 0.46 + i * 0.12, 0.025, color, Vector3.ZERO, 0)
				ring.rotation.y = i * 0.9
		var node: Node3D = _projectile_nodes[id]
		node.position = Vector3(at.x, at.y, 0.18)
		node.scale = Vector3(maxf(size_value.x, 0.1), maxf(size_value.y, 0.1), maxf(minf(size_value.x, size_value.y), 0.12))
		node.rotation.z = sin(_clock * 11 + id) * 0.12
		var previous: Vector2 = node.get_meta("last_position", at)
		if _clock - float(node.get_meta("last_trail", 0)) > 0.055 and previous.distance_to(at) > 0.06:
			var trail: Node3D = _effect_root(at - Vector2(facing * size_value.x * 0.35, 0), 0.20, _fx_style(style))
			_fx_ring(trail, size_value.y * 0.35, 0.018, color, Vector3.ZERO, -0.7)
			node.set_meta("last_trail", _clock)
			node.set_meta("last_position", at)
	for id: int in _projectile_nodes.keys():
		if not alive.has(id):
			_projectile_nodes[id].queue_free()
			_projectile_nodes.erase(id)


func set_charge_aura(slot: int, at: Vector2, style: String, enabled: bool) -> void:
	if _dressing == null: return
	if not enabled:
		if _charge_nodes.has(slot):
			_charge_nodes[slot].queue_free()
			_charge_nodes.erase(slot)
		return
	if not _charge_nodes.has(slot):
		var root := Node3D.new()
		_dressing.add_child(root)
		_charge_nodes[slot] = root
		for i: int in range(3):
			var ring: MeshInstance3D = _fx_ring(root, 0.42 + i * 0.11, 0.012, style_color(style), Vector3(0, 0, i * -0.04), 0)
			ring.rotation.y = i * 0.55
	var node: Node3D = _charge_nodes[slot]
	node.position = Vector3(at.x, at.y, -0.10)
	node.scale = Vector3.ONE * (0.96 + sin(_clock * 10) * 0.06)
	node.rotation.z = _clock * (1.4 if slot == 0 else -1.4)


func clear_combat_effects() -> void:
	for effect: Dictionary in _effects:
		var node: Node3D = effect.get("node") as Node3D
		if is_instance_valid(node): node.queue_free()
	_effects.clear()
	for node: Node3D in _projectile_nodes.values():
		if is_instance_valid(node): node.queue_free()
	_projectile_nodes.clear()
	for node: Node3D in _charge_nodes.values():
		if is_instance_valid(node): node.queue_free()
	_charge_nodes.clear()


func _effect_root(at: Vector2, lifetime: float, family: String) -> Node3D:
	while _effects.size() >= MAX_EFFECTS:
		var old: Dictionary = _effects.pop_front()
		var old_node: Node3D = old.node
		if is_instance_valid(old_node): old_node.queue_free()
	var root := Node3D.new()
	root.position = Vector3(at.x, at.y, 0.22)
	root.set_meta("family", family)
	_dressing.add_child(root)
	_effects.append({"node": root, "age": 0.0, "lifetime": lifetime})
	return root


func _fx_material(color: Color, energy: float = 1.8) -> StandardMaterial3D:
	# StandardMaterial's unshaded path outputs albedo alone. Keep the emission
	# path active so HDR energy reaches glow, and add light instead of hiding actors.
	var material: StandardMaterial3D = _glow(color.lightened(0.08), energy * 2.6)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.albedo_color = Color(0.0, 0.0, 0.0, 0.72)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.disable_fog = true
	material.disable_ambient_light = true
	material.metallic_specular = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _trail_material(color: Color) -> ShaderMaterial:
	if _trail_shader == null:
		_trail_shader = Shader.new()
		_trail_shader.code = """shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
uniform vec4 energy_color : source_color = vec4(1.0, 0.3, 0.1, 1.0);
void fragment() {
	float edge = max(0.0, 1.0 - abs(UV.y * 2.0 - 1.0));
	float feather = smoothstep(0.0, 0.75, edge);
	float core = pow(edge, 8.0);
	float tip = smoothstep(0.0, 0.08, UV.x) * (1.0 - smoothstep(0.86, 1.0, UV.x));
	ALBEDO = vec3(0.0);
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
	EMISSION = energy_color.rgb * (1.8 + core * 4.5) + vec3(core * 1.6);
	ALPHA = feather * tip * (0.34 + core * 0.60) * energy_color.a;
}
"""
	var material := ShaderMaterial.new()
	material.shader = _trail_shader
	material.set_shader_parameter("energy_color", color)
	return material


func _fx_ring(parent: Node3D, radius: float, thickness: float, color: Color, at: Vector3, growth: float) -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(radius - thickness, 0.004)
	torus.outer_radius = radius
	torus.rings = 28
	torus.ring_segments = 6
	var ring: MeshInstance3D = _mesh(parent, at, torus, _fx_material(color))
	ring.rotation.x = PI * 0.5
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.set_meta("growth", growth)
	return ring


func _crystal(parent: Node3D, at: Vector3, color: Color, radius: float, height: float) -> MeshInstance3D:
	var crystal := CylinderMesh.new()
	crystal.top_radius = 0
	crystal.bottom_radius = radius
	crystal.height = height
	crystal.radial_segments = 4
	var shard: MeshInstance3D = _mesh(parent, at, crystal, _fx_material(color, 1.3))
	shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return shard


func _rays(parent: Node3D, color: Color, count: int, speed: float, length: float, crystal: bool) -> void:
	for i: int in range(count):
		var angle: float = TAU * i / float(count) + _clock * 0.5
		var direction := Vector3(sin(angle), cos(angle), sin(i * 2.8) * 0.28)
		var start: Vector3 = direction * (0.55 if speed < 0 else 0.015)
		var shard: MeshInstance3D = _crystal(parent, start, color, 0.045, length) if crystal else _box(parent, start, Vector3(0.018, length, 0.018), _fx_material(color))
		shard.rotation.z = -angle
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shard.set_meta("velocity", direction * speed)
		shard.set_meta("shrink", true)


func _trail(parent: Node3D, facing: float, radius: float, color: Color, width: float, rotation: float = 0) -> void:
	radius *= 0.88
	width *= 0.70
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i: int in range(25):
		var progress: float = i / 24.0
		var angle: float = lerpf(-1.25, 1.5, progress)
		var thickness: float = width * sin(progress * PI)
		for edge: int in range(2):
			var distance: float = radius + thickness * (-1.0 if edge == 0 else 1.0)
			mesh.surface_set_uv(Vector2(progress, float(edge)))
			mesh.surface_add_vertex(Vector3(cos(angle) * distance * facing, sin(angle) * distance * 0.65, 0))
	mesh.surface_end()
	var ribbon: MeshInstance3D = _mesh(parent, Vector3.ZERO, mesh, _trail_material(color))
	ribbon.rotation.z = rotation
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ribbon.set_meta("growth", 0.26)


func _bolt(parent: Node3D, first: Vector3, last: Vector3, color: Color, seed_value: int) -> void:
	var previous: Vector3 = first
	for i: int in range(1, 9):
		var progress: float = i / 8.0
		var point: Vector3 = first.lerp(last, progress)
		point.y += sin(i * 18.3 + seed_value * 8.7) * 0.11 * sin(progress * PI)
		point.z += cos(i * 7.5 + seed_value) * 0.06 * sin(progress * PI)
		var delta: Vector3 = point - previous
		var segment: MeshInstance3D = _box(parent, (point + previous) * 0.5, Vector3(0.024, maxf(delta.length(), 0.01), 0.024), _fx_material(color, 2.0))
		segment.quaternion = Quaternion(Vector3.UP, delta.normalized())
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		previous = point


func _ground_wave(at: Vector2, color: Color, radius: float) -> void:
	var root: Node3D = _effect_root(at, 0.58, "ground_wave")
	var ring: MeshInstance3D = _fx_ring(root, 0.26, 0.03, color, Vector3.ZERO, radius / 0.26 - 1.0)
	ring.rotation.x = 0


func _process(delta: float) -> void:
	_clock += delta
	for rotor in _rotors:
		if is_instance_valid(rotor): rotor.rotate_y(delta * 3.2)
	for item in _floaters:
		var node: Node3D = item.node
		if is_instance_valid(node):
			var base: Vector3 = item.origin
			node.position = base + Vector3(sin(_clock * item.speed + item.phase) * item.width, sin(_clock * 1.4 + item.phase) * 0.10, 0)
	for item in _pulses:
		var lamp: OmniLight3D = item.node
		if is_instance_valid(lamp):
			lamp.light_energy = item.energy * (0.88 + 0.12 * sin(_clock * item.speed + item.phase))
	for i in range(_effects.size() - 1, -1, -1):
		var effect: Dictionary = _effects[i]
		effect.age += delta
		var node: Node3D = effect.node
		if not is_instance_valid(node):
			_effects.remove_at(i)
			continue
		var progress: float = effect.age / effect.lifetime
		if progress >= 1.0:
			node.queue_free()
			_effects.remove_at(i)
			continue
		for child: Node in node.get_children():
			if not child is MeshInstance3D: continue
			var mesh: MeshInstance3D = child as MeshInstance3D
			if not mesh.has_meta("origin"):
				mesh.set_meta("origin", mesh.position)
				mesh.set_meta("base_scale", mesh.scale)
			var origin: Vector3 = mesh.get_meta("origin")
			var velocity: Vector3 = mesh.get_meta("velocity", Vector3.ZERO)
			var gravity: Vector3 = mesh.get_meta("gravity", Vector3.ZERO)
			mesh.position = origin + velocity * float(effect.age) + gravity * float(effect.age) * float(effect.age) * 0.5
			var base_scale: Vector3 = mesh.get_meta("base_scale")
			mesh.scale = base_scale * maxf(0.01, 1.0 + float(mesh.get_meta("growth", 0.0)) * progress)
			if bool(mesh.get_meta("shrink", false)): mesh.scale *= 1.0 - progress * 0.75
			mesh.transparency = smoothstep(0.25, 1.0, progress)
	_shake = move_toward(_shake, 0.0, delta * 0.65)
	if presentation != "fight":
		_update_camera(delta)


func _update_camera(delta: float) -> void:
	if camera == null or not is_inside_tree():
		return
	var desired := _camera_position
	if presentation == "menu":
		desired += Vector3(sin(_clock * 0.16) * 0.28, sin(_clock * 0.21) * 0.035, cos(_clock * 0.16) * 0.1)
	elif presentation == "select":
		desired.x += sin(_clock * 0.17) * 0.12
	var blend := 1.0 - exp(-maxf(delta, 0.0) * 7.0)
	camera.position = camera.position.lerp(desired, blend)
	if _shake > 0.0:
		camera.position += Vector3(sin(_clock * 110.0), cos(_clock * 93.0), 0) * _shake
	camera.look_at(_camera_target)


func _key_lights() -> void:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = [Vector3(-32, -25, 0), Vector3(-25, -40, 0), Vector3(-28, -55, 0)][stage_index]
	key.light_color = [Color("b9d4ff"), Color("ffcc96"), Color("fff2ce")][stage_index]
	key.light_energy = [0.85, 1.1, 1.05][stage_index]
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 32.0
	_dressing.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-24, 150, 0)
	fill.light_color = [Color("aa8dff"), Color("86b8dd"), Color("acdac0")][stage_index]
	fill.light_energy = 0.38
	_dressing.add_child(fill)


func _neon_overpass() -> void:
	var concrete := _pbr("hangar_concrete_floor", Color("465969"), 0.50)
	concrete.roughness = 0.9
	concrete.metallic_specular = 0.18
	var steel := _pbr("rusty_metal_sheet", Color("4e6576"), 0.55)
	var dark := _plain(Color("15222e"), 0.6, 0.35)
	_box(_dressing, Vector3(0, -0.20, 0), Vector3(19, 0.4, 7), concrete)
	for z in [-2.6, 2.7]:
		_box(_dressing, Vector3(0, 0.025, z), Vector3(18, 0.05, 0.12), steel)
		_box(_dressing, Vector3(0, 0.06, z + 0.06), Vector3(17.8, 0.025, 0.027), _glow(Color("3adfff"), 2.0))
	for x in [-6.8, -4.4, -2.0, 2.0, 4.4, 6.8]:
		_prop("concrete_road_barrier", Vector3(x, 0.03, -2.65), 1.2)
	for x in [-6.5, 6.5]:
		_box(_dressing, Vector3(x, 2.6, -3.5), Vector3(0.36, 5.2, 0.50), steel)
		_box(_dressing, Vector3(x + 0.20, 2.6, -3.20), Vector3(0.035, 4.8, 0.025), _glow(Color("e954fa"), 2.4))
		for y in [0.25, 1.6, 3.0, 4.6]:
			_box(_dressing, Vector3(x, y, -3.5), Vector3(0.56, 0.10, 0.68), dark)
	_box(_dressing, Vector3(0, 5.0, -3.5), Vector3(13.3, 0.28, 0.5), steel)
	# A smaller hanging marker stays visible through the closer menu camera.
	_box(_dressing, Vector3(0.55, 2.10, -3.12), Vector3(1.28, 0.72, 0.18), dark)
	_box(_dressing, Vector3(0.55, 2.49, -3.12), Vector3(0.045, 0.17, 0.07), steel)
	_text("09 / EAST", Vector3(0.55, 2.20, -3.01), 0.0028, Color("8ee9ff"))
	_text("NIGHT CIRCUIT", Vector3(0.55, 2.00, -3.00), 0.0018, Color("f193df"))
	_box(_dressing, Vector3(0.55, 1.80, -3.01), Vector3(1.14, 0.025, 0.022), _glow(Color("da60ce"), 1.7))
	_box(_dressing, Vector3(-4.5, 2.2, -3.3), Vector3(1.3, 2.3, 0.24), dark)
	for y in [1.35, 1.65, 1.95, 2.25, 2.55, 2.85]:
		_box(_dressing, Vector3(-4.5, y, -3.14), Vector3(1.04, 0.035, 0.025), _glow(Color("cf5bbf"), 1.7))
	_pipe_network(steel, -5.3, -3.6, 2.2)
	for x in [-3.6, 3.6]:
		_omni(Vector3(x, 2.0, -1.4), Color("a57efa") if x < 0 else Color("55dcff"), 2.0, 5.0)
	_drone(Vector3(-1.8, 2.65, -4.6), 3.0, 0.22, Color("71eaff"))
	_particles(Vector3(0, 5.0, -3.0), Vector3(9, 0.5, 1.2), 240, 0.72, Vector3(0.05, -1, 0), 10.0, 14.0, Color(0.6, 0.85, 1.0, 0.32), true)
	for x in range(-7, 8, 2):
		_box(_dressing, Vector3(x, 0.007, 1.9), Vector3(0.65, 0.008, 0.06), _plain(Color("acbfc4")))


func _cinder_works() -> void:
	var concrete := _pbr("hangar_concrete_floor", Color("969083"), 0.50)
	var steel := _pbr("rusty_metal_sheet", Color("857566"), 0.70)
	var dark := _plain(Color("292d31"), 0.6, 0.4)
	_box(_dressing, Vector3(0, -0.22, 0), Vector3(19, 0.44, 8), concrete)
	for x in [-7.0, -4.2, 4.2, 7.0]:
		_box(_dressing, Vector3(x, 2.1, -4.3), Vector3(2.7, 4.2, 0.4), steel)
		_box(_dressing, Vector3(x, 4.25, -4.0), Vector3(2.8, 0.18, 0.8), dark)
		_pipe_network(steel, x - 0.45, -3.93, 2.0)
		for y in [0.8, 2.0, 3.2]:
			_box(_dressing, Vector3(x, y, -3.94), Vector3(2.5, 0.06, 0.03), dark)
	for x in [-6.0, 6.0]:
		_box(_dressing, Vector3(x, 2.7, -2.5), Vector3(0.35, 5.4, 0.4), steel)
		_box(_dressing, Vector3(x, 0.18, -2.5), Vector3(0.72, 0.35, 0.75), dark)
	_box(_dressing, Vector3(0, 5.3, -2.5), Vector3(12.4, 0.25, 0.50), steel)
	_box(_dressing, Vector3(0, 2.2, -4.6), Vector3(3.0, 4.4, 0.7), dark)
	var chamber := _cylinder(_dressing, Vector3(0, 2.45, -4.1), 1.20, 0.38, dark)
	chamber.rotation.x = PI * 0.5
	var aperture := _cylinder(_dressing, Vector3(0, 2.45, -3.88), 1.04, 0.04, _glow(Color("ff7933"), 1.7))
	aperture.rotation.x = PI * 0.5
	var turbine := _prop("ceiling_fan", Vector3(0, 2.45, -3.72), 1.4, "", false)
	if turbine != null:
		turbine.rotation.x = -PI * 0.5
		var blades := turbine.find_child("ceiling_fan_blades", true, false) as Node3D
		if blades != null: _rotors.append(blades)
	_text("CINDER WORKS", Vector3(0, 4.55, -4.03), 0.0065, Color("fbc88b"))
	_text("FURNACE  06  /  KEEP CLEAR", Vector3(0, 0.60, -4.02), 0.0032, Color("ecc280"))
	for x in [-3.3, 3.3]:
		_prop("concrete_road_barrier", Vector3(x, 0.015, -2.3), 1.1)
		_omni(Vector3(x, 2.7, -2.8), Color("ff8b3d"), 2.5, 5.0, 3.0)
		_particles(Vector3(x, 3.6, -3.0), Vector3(0.08, 0.08, 0.06), 24, 1.1, Vector3(0.5, -0.6, 0), 1.0, 2.1, Color("ffc97e"), false)
	for i in range(-8, 9):
		var stripe := _box(_dressing, Vector3(float(i) * 0.85, 0.009, 2.15), Vector3(0.35, 0.012, 0.34), _plain(Color("b99945")))
		stripe.rotation.y = 0.5
	_omni(Vector3(0, 2.4, -2.7), Color("ff7643"), 2.4, 5.5, 2.1)
	var overhead := _prop("ceiling_fan", Vector3(-3.7, 4.6, -0.8), 1.0, "", false)
	if overhead != null:
		var blades := overhead.find_child("ceiling_fan_blades", true, false) as Node3D
		if blades != null: _rotors.append(blades)


func _hallowed_dawn() -> void:
	var stone := _pbr("medieval_blocks_02", Color("8e9984"), 0.65)
	var floor_mat := _pbr("hangar_concrete_floor", Color("9da58a"), 0.48)
	var trim := _plain(Color("717e67"), 0.82)
	# A lower foundation supports five disjoint deck pieces. The previous full
	# stone top and concrete overlay both ended at y=0, causing depth fighting.
	var foundation: MeshInstance3D = _box(_dressing, Vector3(0, -0.27, 0), Vector3(18, 0.34, 7), stone)
	foundation.name = "DawnFoundation"
	_dawn_deck("Center", Vector3.ZERO, Vector2(14.8, 4.3), floor_mat)
	_dawn_deck("West", Vector3(-8.2, 0, 0), Vector2(1.6, 7), stone)
	_dawn_deck("East", Vector3(8.2, 0, 0), Vector2(1.6, 7), stone)
	_dawn_deck("North", Vector3(0, 0, -2.825), Vector2(14.8, 1.35), stone)
	_dawn_deck("South", Vector3(0, 0, 2.825), Vector2(14.8, 1.35), stone)
	for z in [-2.6, 2.6]:
		_box(_dressing, Vector3(0, 0.03, z), Vector3(17, 0.08, 0.32), stone)
	for x in [-5.3, 5.3]:
		_cylinder(_dressing, Vector3(x, 2.0, -3.0), 0.38, 4.0, stone)
		for y in [0.12, 0.35, 3.7, 3.93]:
			_cylinder(_dressing, Vector3(x, y, -3.0), 0.52, 0.16, stone)
		_box(_dressing, Vector3(x, 4.16, -3.0), Vector3(1.15, 0.32, 1.1), stone)
		_box(_dressing, Vector3(x, 0.12, -3.0), Vector3(1.3, 0.24, 1.3), stone)
	# Stone voussoirs make a broken monumental arch behind the fight plane.
	for i in range(15):
		if i in [2, 12]: continue
		var angle := PI * float(i) / 14.0
		var block := _box(_dressing, Vector3(cos(angle) * 4.4, 1.7 + sin(angle) * 3.5, -5.0), Vector3(0.95, 0.60, 0.85), stone)
		block.rotation.z = angle - PI * 0.5
	_box(_dressing, Vector3(0, 0.20, -4.7), Vector3(2.4, 0.4, 2.1), stone)
	_prop("gothic_statue", Vector3(0, 0.40, -4.7), 2.05)
	for i in range(8):
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * (4.4 + float(i / 2) * 1.08)
		var rock := _prop("rock_moss_set_01", Vector3(x, -0.05, -2.5 - float(i % 3) * 0.80), 0.52 + float(i % 3) * 0.19, "rock_moss_set_01_rock%02d" % (i % 6 + 1))
		if rock != null: rock.rotation.y = float(i) * 1.3
	for x in [-3.3, 3.3]:
		_cylinder(_dressing, Vector3(x, 0.55, -2.6), 0.14, 1.1, trim)
		_cylinder(_dressing, Vector3(x, 1.13, -2.6), 0.25, 0.17, trim)
		var flame := _sphere(_dressing, Vector3(x, 1.34, -2.6), 0.15, _glow(Color("ffcd79"), 2.6))
		flame.scale = Vector3(0.75, 1.4, 0.75)
		_omni(Vector3(x, 1.4, -2.6), Color("ffbd75"), 1.7, 3.0, 6.0)
	_particles(Vector3(0, 3.4, -3.0), Vector3(7.5, 1.6, 2.0), 44, 5.0, Vector3(0.7, -0.35, 0.1), 0.15, 0.45, Color(0.92, 0.83, 0.64, 0.65), false)


func _dawn_deck(label: String, at: Vector3, footprint: Vector2, material: Material) -> void:
	var tile: MeshInstance3D = _box(_dressing, at + Vector3(0, -0.05, 0), Vector3(footprint.x, 0.1, footprint.y), material)
	tile.name = "DawnDeck" + label
	tile.set_meta("dawn_deck", true)


func _pipe_network(material: Material, x: float, z: float, y: float) -> void:
	for offset in [0.0, 0.37]:
		_prop("modular_industrial_pipes_01", Vector3(x + offset, y, z), 1.45, "modular_industrial_pipes_01_pipe02", false)
	for height in [0.7, 2.9]:
		var pipe := _prop("modular_industrial_pipes_01", Vector3(x + 0.2, height, z - 0.04), 1.3, "modular_industrial_pipes_01_pipe01", false)
		if pipe != null: pipe.rotation.z = PI * 0.5
	_box(_dressing, Vector3(x + 0.2, y, z - 0.08), Vector3(0.8, 0.12, 0.25), material)


func _drone(at: Vector3, width: float, speed: float, color: Color) -> void:
	var drone := Node3D.new()
	_dressing.add_child(drone)
	drone.position = at
	var shell := _plain(Color("374757"), 0.32, 0.7)
	_sphere(drone, Vector3.ZERO, 0.16, shell).scale = Vector3(1.5, 0.7, 1.0)
	_sphere(drone, Vector3(0, 0, 0.14), 0.055, _glow(color, 3.0))
	for x in [-0.35, 0.35]:
		_cylinder(drone, Vector3(x, 0.01, 0), 0.22, 0.05, shell)
		_box(drone, Vector3(x * 0.5, 0, 0), Vector3(0.35, 0.05, 0.06), shell)
		var rotor := Node3D.new()
		drone.add_child(rotor)
		rotor.position = Vector3(x, 0.05, 0)
		_box(rotor, Vector3.ZERO, Vector3(0.39, 0.015, 0.035), _plain(Color("b1bac0"), 0.4, 0.65))
		_box(rotor, Vector3.ZERO, Vector3(0.035, 0.015, 0.39), _plain(Color("b1bac0"), 0.4, 0.65))
		_rotors.append(rotor)
	_floaters.append({"node": drone, "origin": at, "width": width, "speed": speed, "phase": 0.8})


func _particles(at: Vector3, extent: Vector3, amount: int, lifetime: float, direction: Vector3, min_speed: float, max_speed: float, color: Color, rain: bool) -> void:
	var particles := GPUParticles3D.new()
	particles.position = at
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = lifetime
	particles.visibility_aabb = AABB(Vector3(-12, -7, -7), Vector3(24, 16, 14))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = extent
	process.direction = direction
	process.spread = 5.0 if rain else 24.0
	process.initial_velocity_min = min_speed
	process.initial_velocity_max = max_speed
	process.gravity = Vector3(0, -0.25 if rain else -0.12, 0)
	process.scale_min = 0.7
	process.scale_max = 1.2
	process.color = color
	particles.process_material = process
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0025 if rain else 0.012
	mesh.bottom_radius = mesh.top_radius
	mesh.height = 0.15 if rain else 0.018
	mesh.radial_segments = 4
	var mat := _glow(Color.WHITE, 0.8 if rain else 2.2)
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	particles.draw_pass_1 = mesh
	_dressing.add_child(particles)


func _prop(asset: String, at: Vector3, size_value: float = 1.0, part: String = "", grounded: bool = true) -> Node3D:
	var packed := _asset_scene(asset)
	if packed == null: return null
	var source := packed.instantiate() as Node3D
	var node: Node3D = source
	if not part.is_empty():
		var piece := source.find_child(part, true, false) as Node3D
		if piece == null and source.name == part: piece = source
		if piece == null:
			push_warning("Stage prop has no part: " + part)
			source.free()
			return null
		node = piece.duplicate() as Node3D
		node.transform = Transform3D.IDENTITY
		source.free()
	var wrapper := Node3D.new()
	wrapper.name = asset
	_dressing.add_child(wrapper)
	wrapper.add_child(node)
	node.scale = Vector3.ONE * size_value
	wrapper.position = at
	if grounded:
		var bounds := _bounds(node, Transform3D.IDENTITY)
		node.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	return wrapper


func _bounds(node: Node3D, parent_transform: Transform3D) -> AABB:
	var transform := parent_transform * node.transform
	var result := AABB()
	var valid := false
	if node is MeshInstance3D:
		result = transform * (node as MeshInstance3D).get_aabb()
		valid = true
	for child in node.get_children():
		if child is Node3D:
			var child_bounds := _bounds(child, transform)
			if child_bounds.size.length_squared() > 0.0:
				result = result.merge(child_bounds) if valid else child_bounds
				valid = true
	return result


func _asset_scene(asset: String) -> PackedScene:
	if _scenes.has(asset): return _scenes[asset] as PackedScene
	var path := ASSETS + "models/" + asset + "/" + asset + ".gltf"
	var packed: PackedScene
	if FileAccess.file_exists(path + ".import"):
		packed = load(path) as PackedScene
	else:
		# Permit a fresh checkout to render before the editor's import pass.
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		if document.append_from_file(path, state) == OK:
			var source := document.generate_scene(state)
			packed = PackedScene.new()
			packed.pack(source)
			source.free()
	if packed == null:
		push_warning("Unable to load downloaded stage asset: " + asset)
		return null
	_scenes[asset] = packed
	return packed


func _texture(path: String) -> Texture2D:
	if _textures.has(path): return _textures[path] as Texture2D
	var texture: Texture2D
	if FileAccess.file_exists(path + ".import"):
		texture = load(path) as Texture2D
	else:
		var image := Image.load_from_file(path)
		if image != null:
			image.generate_mipmaps()
			texture = ImageTexture.create_from_image(image)
	_textures[path] = texture
	return texture


func _pbr(asset: String, tint: Color, repeats: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.albedo_texture = _texture(ASSETS + "textures/" + asset + "_diff.jpg")
	mat.normal_enabled = true
	mat.normal_texture = _texture(ASSETS + "textures/" + asset + "_normal.jpg")
	mat.normal_scale = 0.8
	mat.roughness_texture = _texture(ASSETS + "textures/" + asset + "_rough.jpg")
	mat.roughness = 0.90
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * repeats
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat


func _plain(color: Color, roughness: float = 0.7, metal: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metal
	return mat


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var mat := _plain(color)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat


func _box(parent: Node3D, at: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return _mesh(parent, at, mesh, material)


func _sphere(parent: Node3D, at: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return _mesh(parent, at, mesh, material)


func _cylinder(parent: Node3D, at: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	return _mesh(parent, at, mesh, material)


func _mesh(parent: Node3D, at: Vector3, mesh: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node


func _text(value: String, at: Vector3, pixels: float, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.font_size = 64
	label.pixel_size = pixels
	label.modulate = color
	label.outline_size = 0
	label.position = at
	_dressing.add_child(label)
	return label


func _omni(at: Vector3, color: Color, energy: float, reach: float, pulse_speed: float = 0.0) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	_dressing.add_child(light)
	if pulse_speed > 0.0:
		_pulses.append({"node": light, "energy": energy, "speed": pulse_speed, "phase": at.x})
	return light
