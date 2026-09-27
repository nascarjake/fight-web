extends SceneTree
## Checks real procedural floor geometry and combat VFX/audio lifecycle without GPU assets.

const StageScript = preload("res://scripts/game_stage.gd")
const AudioScript = preload("res://scripts/game_audio.gd")
const FighterCatalog = preload("res://combat/FighterCatalog.gd")

class AssetFreeStage extends StageScript:
	func _pbr(_asset: String, tint: Color, _repeats: float) -> StandardMaterial3D:
		return _plain(tint)
	func _prop(_asset: String, _at: Vector3, _size_value: float = 1.0, _part: String = "", _grounded: bool = true) -> Node3D:
		return null
	func _particles(_at: Vector3, _extent: Vector3, _amount: int, _lifetime: float, _direction: Vector3, _min_speed: float, _max_speed: float, _color: Color, _rain: bool) -> void:
		pass

var checks: int = 0
var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var stage := AssetFreeStage.new()
	root.add_child(stage)
	stage.set_process(false)
	stage._dressing = Node3D.new()
	stage.add_child(stage._dressing)
	stage._hallowed_dawn()
	var tiles: Array[Rect2] = []
	var total_area: float = 0
	for child: Node in stage._dressing.get_children():
		if not child.has_meta("dawn_deck"): continue
		var tile: MeshInstance3D = child as MeshInstance3D
		var shape: BoxMesh = tile.mesh as BoxMesh
		_check(is_equal_approx(tile.position.y + shape.size.y / 2, 0), "Every Dawn deck top must remain at fighter ground y=0.")
		var footprint := Rect2(Vector2(tile.position.x - shape.size.x / 2, tile.position.z - shape.size.z / 2), Vector2(shape.size.x, shape.size.z))
		tiles.append(footprint)
		total_area += footprint.get_area()
	_check(tiles.size() == 5, "Dawn must use five disjoint floor regions, not overlapping full slabs.")
	_check(absf(total_area - 126.0) < 0.0001, "Dawn floor must completely cover its 18×7m footprint.")
	for i: int in range(tiles.size()):
		for j: int in range(i + 1, tiles.size()):
			_check(tiles[i].intersection(tiles[j]).get_area() < 0.00001, "Coplanar Dawn floor footprints must not overlap.")
	var foundation: MeshInstance3D = stage._dressing.get_node("DawnFoundation") as MeshInstance3D
	var foundation_mesh: BoxMesh = foundation.mesh as BoxMesh
	_check(foundation.position.y + foundation_mesh.size.y * 0.5 <= -0.0999, "Foundation top must sit below the renderable floor, preventing coplanar depth fighting.")
	for id: String in ["kai", "neon", "yuki", "ivy", "rook", "atlas", "zero", "vex", "sora", "raijin"]:
		var profile: Dictionary = StageScript.FighterProfiles.get_fighter(id)
		_check(stage.style_color(id) == profile["color"], "VFX colors must agree with the fighter catalog.")
		stage.attack_effect(Vector2(0, 1), 1, id, "special")
		stage.impact(Vector2(0, 1), false, true, id)
		for beat: int in range(5): stage.cinematic_effect(Vector2(0, 1), id, beat)
		var authored_cues: Dictionary = {}
		for move: MoveData in FighterCatalog.moves(id):
			_check(not authored_cues.has(move.vfx_cue), id + " moves must not share a presentation cue.")
			authored_cues[move.vfx_cue] = true
			stage.move_effect(Vector2(0, 1), 1, id, move.vfx_cue, move.camera_impulse)
		_check(authored_cues.size() == FighterCatalog.moves(id).size(), id + " owns a distinct presentation for every move.")
	_check(stage._effects.size() <= StageScript.MAX_EFFECTS, "Repeated cinematic effects must stay within a bounded budget.")
	stage._process(2.0)
	_check(stage._effects.is_empty(), "Transient effects must expire and release all effect records.")
	var projectiles: Array[Dictionary] = [{"id": 7, "owner": 0, "position": Vector2(1, 1.2), "direction": 1, "style": "neon", "size": Vector2(0.6, 0.5)}]
	stage.update_projectiles(projectiles)
	_check(stage._projectile_nodes.size() == 1, "A live projectile must create one visual.")
	var projectile_node: Node3D = stage._projectile_nodes[7]
	projectiles[0]["position"] = Vector2(2, 1.2)
	stage.update_projectiles(projectiles)
	_check(stage._projectile_nodes[7] == projectile_node and is_equal_approx(projectile_node.position.x, 2), "Projectile updates must reuse its visual and track simulation position.")
	var empty_projectiles: Array[Dictionary] = []
	stage.update_projectiles(empty_projectiles)
	_check(stage._projectile_nodes.is_empty(), "Removed or expired projectiles must remove their visual.")
	stage.set_charge_aura(0, Vector2(0, 1), "kai", true)
	_check(stage._charge_nodes.size() == 1, "Charge aura can be explicitly activated.")
	stage.set_charge_aura(0, Vector2(0, 1), "kai", false)
	_check(stage._charge_nodes.is_empty(), "Charge aura can be explicitly removed.")
	stage.clear_combat_effects()
	stage.queue_free()
	await process_frame
	var sound := AudioScript.new()
	sound.playback_enabled = false
	root.add_child(sound)
	sound.set_music(false)
	for id: String in AudioScript.NEW_SOUNDS:
		var stream: AudioStreamWAV = sound.sounds.get(id) as AudioStreamWAV
		_check(stream != null and stream.get_length() > 0.1, "Original sound must load and have audible duration: " + id)
	var first_voice: int = sound._voice_cursor
	sound.play_voice(1.0)
	sound.play_voice(1.0)
	_check(sound._voice_cursor == first_voice + 1, "Duplicate hitstop-frame effort requests must be throttled.")
	sound.play_hit("kai", true, 1.0)
	var hit_time: int = sound._last_hit
	sound.play_hit("kai", true, 1.0)
	_check(sound._last_hit == hit_time, "Repeated contact requests within one hitstop interval must not stack.")
	_check(sound.voices.size() == 14, "Combat sound sources use a fixed pool.")
	for profile: Dictionary in FighterCatalog.all():
		var moves: Array[MoveData] = FighterCatalog.moves(str(profile["id"]))
		for move: MoveData in moves:
			sound._last_swing = -1000
			sound.play_move(move, str(profile["id"]), float(profile["voice_pitch"]))
			_check(sound._last_swing > -1000, str(profile["id"]) + "/" + move.id + " routes through the authored move-audio path.")
	sound.play_super(4)
	_check(sound._priorities.has(4), "Super impact must receive protected high priority.")
	sound.queue_free()
	await process_frame
	print("Stage/audio checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)
