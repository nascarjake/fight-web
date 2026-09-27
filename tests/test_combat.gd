extends SceneTree
## Run: Godot --headless --path desktop --script res://tests/test_combat.gd

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_test_move_data()
	_test_startup_and_single_hit()
	_test_geometry_and_invulnerability()
	_test_every_default_geometry()
	_test_hitstop_and_buffer()
	_test_cancels()
	_test_guard_and_energy()
	_test_movement_and_trade()
	_test_determinism()
	print("Combat checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _test_move_data() -> void:
	for move: MoveData in MoveCatalog.defaults():
		_expect(move.validation_errors().is_empty(), move.id + " defaults validate")
	var move: MoveData = MoveData.new()
	_expect(move.total_frames() == 24, "move frame total")
	_expect(move.phase_at(-1) == "idle" and move.phase_at(24) == "idle", "outside move is idle")
	_expect(move.phase_at(0) == "startup" and move.phase_at(5) == "startup", "startup uses 0-based endpoints")
	_expect(move.phase_at(6) == "active" and move.phase_at(8) == "active", "active endpoints")
	_expect(move.phase_at(9) == "recovery" and move.phase_at(23) == "recovery", "recovery endpoints")
	move.invuln_start = 1
	move.invuln_end = 3
	_expect(not move.is_invulnerable(0) and move.is_invulnerable(1) and move.is_invulnerable(3) and not move.is_invulnerable(4), "invulnerability window inclusive")
	move.invuln_end = 24
	_expect(not move.validation_errors().is_empty(), "out-of-range window rejected")
	move.invuln_start = -1
	move.invuln_end = -1
	move.startup = -2
	_expect(not move.validation_errors().is_empty(), "negative frame lengths rejected")
	move.startup = 6
	move.hitbox_size.x = 0.0
	_expect(not move.validation_errors().is_empty(), "zero-width hitbox rejected")


func _near_sim(moves: Array[MoveData] = MoveCatalog.defaults()) -> FightSimulation:
	var sim: FightSimulation = FightSimulation.new()
	sim.set_moves(moves)
	sim.fighters[0]["position"] = Vector2(-0.5, 0.0)
	sim.fighters[1]["position"] = Vector2(0.5, 0.0)
	return sim


func _test_startup_and_single_hit() -> void:
	var sim: FightSimulation = _near_sim()
	_expect(sim.request_move(0, "jab"), "neutral attack accepted")
	for frame: int in range(6):
		sim.step([{}, {}])
		_expect(sim.fighters[0]["move_frame"] == frame, "public move frame matches evaluated startup")
		_expect(sim.fighters[1]["hp"] == 100.0 and sim.hitboxes(0).is_empty(), "startup cannot strike")
	sim.step([{}, {}])
	_expect(sim.fighters[0]["move_frame"] == 6, "first active frame")
	_expect(sim.fighters[1]["hp"] == 93.0 and not sim.hitboxes(0).is_empty(), "hit on first overlapping active frame")
	_expect(sim.events.size() == 1 and sim.events[0]["type"] == "hit", "hit emits event")
	for frame: int in range(40):
		sim.step([{}, {}])
	_expect(sim.fighters[1]["hp"] == 93.0, "one hit per move across active frames")
	_expect(sim.fighters[0]["move"] == null and sim.fighters[0]["move_frame"] == -1, "move returns to neutral")
	sim.reset()
	_expect(sim.tick == 0 and sim.freeze_frames == 0 and sim.fighters[1]["hp"] == 100.0, "reset restores training state")


func _test_geometry_and_invulnerability() -> void:
	var sim: FightSimulation = _near_sim()
	sim.request_move(1, "jab")
	for frame: int in range(7):
		sim.step([{}, {}])
	var strike: Rect2 = sim.hitboxes(1)[0]
	_expect(strike.get_center().x < sim.fighters[1]["position"].x, "left-facing hitbox mirrors offset")
	_expect(strike.intersects(sim.hurtboxes(0)[0]) and sim.fighters[0]["hp"] < 100.0, "debug geometry is collision geometry")
	var immune: MoveData = MoveData.new()
	immune.id = "immune"
	immune.active = 0
	immune.damage = 0.0
	immune.invuln_start = 0
	immune.invuln_end = 10
	sim = _near_sim([MoveCatalog.defaults()[0], immune])
	sim.request_move(0, "jab")
	sim.request_move(1, "immune")
	for frame: int in range(11):
		sim.step([{}, {}])
	_expect(sim.fighters[1]["hp"] == 100.0 and sim.hurtboxes(1).is_empty(), "invulnerable fighter cannot be struck")
	sim.step([{}, {}])
	_expect(not sim.hurtboxes(1).is_empty(), "hurtbox returns after invulnerability")
	sim = FightSimulation.new()
	sim.request_move(0, "jab")
	for frame: int in range(30):
		sim.step([{}, {}])
	_expect(sim.fighters[1]["hp"] == 100.0, "out-of-range attack whiffs")


func _test_hitstop_and_buffer() -> void:
	var sim: FightSimulation = _near_sim()
	sim.step([{"action": "jab"}, {}])
	for frame: int in range(6):
		sim.step([{}, {}])
	var frozen_frame: int = sim.fighters[0]["move_frame"]
	var frozen_position: Vector2 = sim.fighters[1]["position"]
	var frozen_stun: int = sim.fighters[1]["stun"]
	var frozen_count: int = sim.freeze_frames
	_expect(frozen_count == 4, "hitstop duration comes from move")
	for frame: int in range(frozen_count):
		sim.step([{"action": "cross"} if frame == 0 else {}, {"axis": 1.0}])
		_expect(sim.fighters[0]["move_frame"] == frozen_frame and sim.fighters[1]["position"] == frozen_position and sim.fighters[1]["stun"] == frozen_stun, "hitstop freezes frames, motion, and stun")
	sim.step([{}, {}])
	_expect(sim.fighters[0]["move"].id == "cross", "input during hitstop buffers into confirmed cancel")
	var wait_move: MoveData = MoveData.new()
	wait_move.id = "wait"
	wait_move.startup = 0
	wait_move.active = 0
	wait_move.recovery = 8
	var jab: MoveData = MoveCatalog.defaults()[0]
	sim = _near_sim([wait_move, jab])
	sim.request_move(0, "wait")
	for frame: int in range(3):
		sim.step([{}, {}])
	sim.step([{"action": "jab"}, {}])
	for frame: int in range(5):
		sim.step([{}, {}])
	_expect(sim.fighters[0]["move"] != null and sim.fighters[0]["move"].id == "jab", "six-frame buffer accepts on sixth available tick")
	wait_move.recovery = 20
	sim = _near_sim([wait_move, jab])
	sim.request_move(0, "wait")
	sim.step([{"action": "jab"}, {}])
	for frame: int in range(25):
		sim.step([{}, {}])
	_expect(sim.fighters[0]["move"] == null and sim.fighters[1]["hp"] == 100.0, "expired buffer does not auto attack later")


func _test_every_default_geometry() -> void:
	for move: MoveData in MoveCatalog.defaults():
		var sim: FightSimulation = _near_sim([move])
		for direction: int in [-1, 1]:
			sim.fighters[0]["facing"] = direction
			sim.fighters[0]["position"] = Vector2(0.3, 0.4)
			sim.fighters[0]["move"] = move
			for frame: int in range(move.total_frames()):
				sim.fighters[0]["move_frame"] = frame
				var active: bool = frame >= move.startup and frame < move.startup + move.active and move.damage > 0.0
				var hits: Array[Rect2] = sim.hitboxes(0)
				_expect(hits.size() == (1 if active else 0), "%s frame %d facing %d has correct debug activation" % [move.id, frame, direction])
				if active:
					var center: Vector2 = sim.fighters[0]["position"] + Vector2(move.hitbox_offset.x * direction, move.hitbox_offset.y)
					_expect(hits[0] == Rect2(center - move.hitbox_size * 0.5, move.hitbox_size), move.id + " debug strike matches exported world geometry")
				var hurts: Array[Rect2] = sim.hurtboxes(0)
				_expect(hurts.size() == (0 if move.is_invulnerable(frame) else 1), move.id + " debug hurtbox obeys current invulnerability frame")
				if not hurts.is_empty():
					var center: Vector2 = sim.fighters[0]["position"] + Vector2(move.hurtbox_offset.x * direction, move.hurtbox_offset.y)
					_expect(hurts[0] == Rect2(center - move.hurtbox_size * 0.5, move.hurtbox_size), move.id + " debug hurtbox matches exported world geometry")
		# Exercise actual collision evaluation, checking the public active frame used
		# immediately by the renderer rather than only constructing preview geometry.
		sim = _near_sim([move])
		sim.request_move(0, move.id)
		for frame: int in range(move.startup + 1):
			sim.step([{}, {}])
		if move.active > 0 and move.damage > 0.0:
			_expect(sim.hitboxes(0)[0].intersects(sim.hurtboxes(1)[0]), move.id + " displayed collision geometry overlaps on contact")
			if move.id == "finisher":
				_expect(sim.fighters[1]["hp"] == 100.0 and not sim.pending_cinematic.is_empty() and sim.fighters[0]["move_frame"] == move.startup, "finisher contact defers damage on the displayed active frame")
			else:
				_expect(sim.fighters[1]["hp"] == 100.0 - move.damage and sim.fighters[0]["move_frame"] == move.startup, move.id + " contact and displayed frame agree")
		else:
			_expect(sim.fighters[1]["hp"] == 100.0 and sim.hitboxes(0).is_empty(), move.id + " non-attacking default cannot create contact")


func _test_cancels() -> void:
	var moves: Array[MoveData] = MoveCatalog.defaults()
	moves[0].hitstop = 0
	var sim: FightSimulation = _near_sim(moves)
	sim.request_move(0, "jab")
	_expect(not sim.request_move(0, "cross"), "cannot cancel startup before contact")
	for frame: int in range(7):
		sim.step([{}, {}])
	_expect(not sim.request_move(0, "dodge"), "cancel destination whitelist enforced")
	_expect(sim.request_move(0, "cross"), "confirmed attack can cancel inside window")
	sim = _near_sim(moves)
	sim.request_move(0, "jab")
	for frame: int in range(7):
		sim.step([{}, {"block": true}])
	_expect(not sim.request_move(0, "cross"), "blocked attacks do not grant hit confirms")
	sim = _near_sim(moves)
	sim.request_move(0, "jab")
	for frame: int in range(17):
		sim.step([{}, {}])
	_expect(not sim.request_move(0, "cross"), "confirmed cancel rejected after inclusive window closes")
	sim.fighters[0]["combo"] = 3
	sim.fighters[1]["combo"] = 3
	sim.fighters[0]["stun"] = 1
	sim.fighters[1]["stun"] = 1
	sim.step([{}, {}])
	_expect(sim.fighters[0]["combo"] == 0 and sim.fighters[1]["combo"] == 0, "combo resets symmetrically on defender recovery")


func _test_guard_and_energy() -> void:
	var sim: FightSimulation = _near_sim()
	sim.request_move(0, "jab")
	for frame: int in range(7):
		sim.step([{}, {"block": true}])
	_expect(is_equal_approx(sim.fighters[1]["hp"], 99.3), "block applies chip damage")
	_expect(sim.fighters[1]["guard"] < 100.0 and sim.fighters[1]["state"] == "blockstun", "block drains guard and applies blockstun")
	_expect(sim.events[0]["type"] == "blocked", "block emits event")
	sim = _near_sim()
	sim.fighters[1]["guard"] = 1.0
	sim.request_move(0, "jab")
	for frame: int in range(7):
		sim.step([{}, {"block": true}])
	_expect(sim.fighters[1]["guard"] == 0.0 and sim.fighters[1]["state"] == "guard_break" and sim.fighters[1]["stun"] >= 30, "guard fatigue causes guard break")
	_expect(sim.events[0]["type"] == "guard_break" and sim.fighters[1]["hp"] == 93.0, "guard break deals full strike damage")
	sim = _near_sim()
	sim.fighters[0]["energy"] = 49.0
	_expect(not sim.request_move(0, "burst"), "insufficient energy rejects move")
	sim.fighters[0]["energy"] = 50.0
	_expect(sim.request_move(0, "burst") and sim.fighters[0]["energy"] == 0.0, "energy cost deducted exactly once")
	_expect(not sim.request_move(-1, "jab") and not sim.request_move(2, "jab") and not sim.request_move(0, "missing"), "invalid requests rejected safely")


func _test_movement_and_trade() -> void:
	var sim: FightSimulation = FightSimulation.new()
	var original_x: float = sim.fighters[0]["position"].x
	sim.step([{"axis": 1.0, "jump": true}, {}])
	_expect(sim.fighters[0]["position"].x > original_x and sim.fighters[0]["position"].y > 0.0, "jump and movement use fixed timestep")
	for frame: int in range(90):
		sim.step([{}, {}])
	_expect(sim.fighters[0]["position"].y == 0.0 and sim.fighters[0]["velocity"].y == 0.0, "jump lands at floor")
	for frame: int in range(200):
		sim.step([{"axis": -1.0}, {"axis": -1.0}])
	_expect(sim.fighters[0]["position"].x >= -5.0 and sim.fighters[1]["position"].x >= -5.0, "movement clamps to arena")
	_expect(absf(sim.fighters[0]["position"].x - sim.fighters[1]["position"].x) >= 0.6399, "pushboxes separate at wall")
	sim = _near_sim()
	sim.step([{"action": "jab"}, {"action": "jab"}])
	for frame: int in range(6):
		sim.step([{}, {}])
	_expect(sim.fighters[0]["hp"] == 93.0 and sim.fighters[1]["hp"] == 93.0, "simultaneous strikes trade without index advantage")


func _test_determinism() -> void:
	var first: FightSimulation = _near_sim()
	var second: FightSimulation = _near_sim()
	for frame: int in range(600):
		var input: Array[Dictionary] = [
			{"axis": 1.0 if frame % 120 < 60 else -1.0, "jump": frame % 90 == 0, "block": frame % 37 < 8, "action": "jab" if frame % 23 == 0 else ("cross" if frame % 41 == 0 else "")},
			{"axis": -1.0 if frame % 100 < 50 else 1.0, "crouch": frame % 45 < 8, "block": frame % 60 < 20, "action": "low_kick" if frame % 29 == 0 else ""},
		]
		first.step(input)
		second.step(input)
		for index: int in range(2):
			for key: String in ["position", "velocity", "hp", "guard", "energy", "state", "move_frame", "stun", "facing", "combo"]:
				if first.fighters[index][key] != second.fighters[index][key]:
					_expect(false, "identical inputs must produce identical " + key)
					return
	_expect(first.tick == second.tick and first.freeze_frames == second.freeze_frames, "600-tick replay is deterministic")
