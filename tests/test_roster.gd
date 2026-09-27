extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_test_catalog()
	_test_independent_profiles()
	_test_projectiles_and_control()
	_test_grab_counter_and_armor()
	_test_mobility_and_multihit()
	_test_earned_meter()
	_test_cinematic_lifecycle()
	_test_super_defenses_and_trades()
	_test_arcade_roster()
	_test_each_cpu()
	print("Roster checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _sim(first: String = "kai", second: String = "neon") -> FightSimulation:
	var sim: FightSimulation = FightSimulation.new()
	for index: int in range(2):
		var id: String = first if index == 0 else second
		sim.set_fighter_profile(index, FighterCatalog.get_fighter(id))
		sim.set_fighter_moves(index, FighterCatalog.moves(id))
		sim.fighters[index]["energy"] = 0.0
	sim.fighters[0]["position"] = Vector2(-0.5, 0.0)
	sim.fighters[1]["position"] = Vector2(0.5, 0.0)
	return sim


func _advance(sim: FightSimulation, frames: int, inputs: Array[Dictionary] = [{}, {}]) -> void:
	for frame: int in range(frames):
		sim.step(inputs)


func _test_catalog() -> void:
	var expected: Array[String] = ["kai", "neon", "yuki", "ivy", "rook", "atlas", "zero", "vex", "sora", "raijin"]
	var codes: Array[String] = ["C", "K", "M", "N", "R", "T", "V", "X", "Y", "Z"]
	var catalog: Array[Dictionary] = FighterCatalog.all()
	_expect(catalog.size() == 10, "ten real fighter profiles")
	_expect(FighterCatalog.presentation_errors().is_empty(), "every move owns a unique, correctly prefixed VFX and sound cue")
	var signatures: Dictionary = {}
	var super_names: Dictionary = {}
	for index: int in range(catalog.size()):
		var profile: Dictionary = catalog[index]
		_expect(profile["id"] == expected[index] and profile["model_path"].ends_with("AvatarSample_" + codes[index] + ".vrm"), "roster ID maps to agreed VRM")
		_expect(profile["portrait_path"] == "res://assets/ui/roster/" + expected[index] + ".png", "portrait path follows roster ID")
		_expect(profile["walk_speed"] > 0.0 and not profile["description"].is_empty() and not profile["archetype"].is_empty(), "profile includes playable movement and descriptive data")
		var moves: Array[MoveData] = FighterCatalog.moves(profile["id"])
		_expect(moves.size() == (11 if profile["id"] == "kai" else 7), "base moves and character command variants are present")
		var signature: String = ""
		for move: MoveData in moves:
			_expect(move.validation_errors().is_empty(), profile["id"] + "/" + move.id + " validates: " + "; ".join(move.validation_errors()))
			_expect(move.animation_name == profile["id"] + "_" + move.id, "move uses a character-specific skeletal clip")
			_expect(move.energy_cost == (100.0 if move.id == "finisher" else 0.0), "normal and special moves are free; super costs full meter")
			_expect(move.impact_flash.a > 0.0 and move.camera_impulse >= 0.0, "move carries a visible, data-authored contact response")
			signature += "%d/%d/%d/%s/%s/%s;" % [move.startup, move.active, move.recovery, move.damage, move.behavior, move.hitbox_size]
		_expect(not signatures.has(signature), "fighter mechanics differ beyond labels and tint")
		signatures[signature] = true
		_expect(not super_names.has(profile["super_name"]), "each fighter has a unique super")
		super_names[profile["super_name"]] = true
	var original: Array[MoveData] = FighterCatalog.moves("kai")
	var independent: Array[MoveData] = FighterCatalog.moves("kai")
	original[0].damage = 900.0
	_expect(independent[0].damage == 7.0, "catalog does not share mutable move resources between fighters")


func _test_independent_profiles() -> void:
	var sim: FightSimulation = _sim("raijin", "atlas")
	sim.request_move(0, "jab")
	sim.request_move(1, "jab")
	_expect(sim.fighters[0]["move"].startup == 4 and sim.fighters[1]["move"].startup == 10, "opposing sides execute independent frame data")
	_expect(sim.fighters[0]["move"].animation_name == "raijin_jab" and sim.fighters[1]["move"].animation_name == "atlas_jab", "opposing sides retain independent clip identities")
	sim.reset()
	_expect(sim.fighters[0]["fighter_id"] == "raijin" and sim.get_move(1, "jab").damage == 11.0, "reset preserves selected profiles and move maps")
	sim.fighters[0]["position"] = Vector2(-3, 0)
	sim.fighters[1]["position"] = Vector2(3, 0)
	sim.step([{"axis": 1.0}, {"axis": -1.0}])
	_expect(is_equal_approx(sim.fighters[0]["velocity"].x, 4.1) and is_equal_approx(sim.fighters[1]["velocity"].x, -2.55), "profile walk speeds affect movement")
	sim.set_moves(MoveCatalog.defaults())
	_expect(sim.get_move(0, "jab").damage == sim.get_move(1, "jab").damage, "shared set_moves remains backward compatible for lab")


func _test_projectiles_and_control() -> void:
	var sim: FightSimulation = _sim("neon", "kai")
	sim.fighters[0]["position"] = Vector2(-4, 0)
	sim.fighters[1]["position"] = Vector2(4, 0)
	sim.request_move(0, "burst")
	_advance(sim, 18)
	_expect(sim.projectiles.size() == 1 and sim.hitboxes(0).is_empty(), "sonic special spawns an independent projectile instead of phantom melee hitbox")
	var projectile: Dictionary = sim.projectiles[0]
	_expect(sim.projectile_hitboxes()[0] == Rect2(projectile["position"] - projectile["size"] * 0.5, projectile["size"]), "projectile debug uses the exact world collision volume")
	_expect(projectile["style"] == "neon" and projectile["owner"] == 0 and projectile["velocity"].x == 8.5, "projectile metadata supports authored sonic presentation")
	_advance(sim, 33)
	_expect(sim.fighters[0]["move"] == null and sim.projectiles.size() == 1, "projectile survives move recovery")
	_advance(sim, 40)
	_expect(sim.fighters[1]["hp"] == 86.0 and sim.projectiles.is_empty(), "traveling projectile contacts once then expires")
	sim = _sim("yuki", "kai")
	sim.request_move(0, "burst")
	_advance(sim, 22)
	_expect(sim.fighters[1]["slow_frames"] == 100 and sim.fighters[1]["slow_multiplier"] == 0.55, "ice wave applies real timed movement control")
	sim.freeze_frames = 0
	sim.fighters[1]["stun"] = 0
	sim.step([{}, {"axis": 1.0}])
	_expect(is_equal_approx(sim.fighters[1]["velocity"].x, 3.9 * 0.55), "frost debuff reduces walk speed")
	sim.fighters[1]["slow_frames"] = 1
	sim.step([{}, {"axis": 1.0}])
	_expect(is_equal_approx(sim.fighters[1]["velocity"].x, 3.9), "slow expires and restores movement")
	sim = _sim("ivy", "kai")
	sim.fighters[0]["position"] = Vector2(-1, 0)
	sim.fighters[1]["position"] = Vector2(1, 0)
	sim.request_move(0, "cross")
	_advance(sim, 16)
	_expect(sim.fighters[1]["hp"] < 100.0, "thorn heavy reaches an opponent beyond standard punch range")


func _test_grab_counter_and_armor() -> void:
	var sim: FightSimulation = _sim("rook", "kai")
	sim.fighters[0]["position"] = Vector2(-0.35, 0)
	sim.fighters[1]["position"] = Vector2(0.35, 0)
	sim.request_move(0, "burst")
	_advance(sim, 13, [{}, {"block": true}])
	_expect(sim.fighters[1]["hp"] == 75.0 and sim.fighters[1]["guard"] == 100.0, "grounded command grab bypasses guard")
	sim = _sim("rook", "kai")
	sim.request_move(0, "burst")
	sim.step([{}, {"jump": true}])
	_advance(sim, 14)
	_expect(sim.fighters[1]["hp"] == 100.0, "jumping evades command grab")
	sim = _sim("kai", "zero")
	# Test first-active-frame contact inside the jab's retracted entry box.
	sim.fighters[0]["position"] = Vector2(-0.4, 0)
	sim.fighters[1]["position"] = Vector2(0.4, 0)
	sim.request_move(0, "jab")
	sim.request_move(1, "burst")
	_advance(sim, 6)
	_expect(sim.fighters[1]["hp"] == 100.0 and sim.fighters[0]["hp"] == 78.0, "active counter reverses incoming strike")
	_expect(sim.events[0]["type"] == "counter" and sim.events[0]["fighter_id"] == "zero", "counter emits fighter-specific presentation event")
	sim = _sim("kai", "atlas")
	sim.fighters[0]["position"] = Vector2(-0.4, 0)
	sim.fighters[1]["position"] = Vector2(0.4, 0)
	sim.request_move(0, "jab")
	sim.request_move(1, "cross")
	_advance(sim, 6)
	_expect(sim.fighters[1]["hp"] == 96.5 and sim.fighters[1]["move"] != null and sim.fighters[1]["stun"] == 0, "armored heavy absorbs reduced damage without losing its move")
	_expect(sim.fighters[1]["_armor_remaining"] == 1 and sim.events[0]["type"] == "armored", "armor charge is consumed once")


func _test_mobility_and_multihit() -> void:
	var sim: FightSimulation = _sim("vex", "kai")
	sim.request_move(0, "dodge")
	_advance(sim, 30)
	_expect(sim.fighters[0]["position"].x > sim.fighters[1]["position"].x and sim.fighters[0]["facing"] == -1, "void step crosses through opponent and turns toward them afterward")
	sim = _sim("kai", "atlas")
	var before: float = sim.fighters[0]["position"].x
	sim.request_move(0, "burst")
	_advance(sim, 13)
	_expect(sim.fighters[0]["position"].x > before + 0.3, "fire drive advances during authored lunge frames")
	sim = _sim("sora", "kai")
	sim.step([{"jump": true}, {"jump": true}])
	_expect(sim.fighters[0]["velocity"].y > sim.fighters[1]["velocity"].y, "aerial fighter has a higher jump arc")
	sim = _sim("sora", "kai")
	sim.request_move(0, "launcher")
	_advance(sim, 11)
	_expect(sim.fighters[1]["velocity"].y == 8.5, "wind launcher creates a longer juggle")
	sim = _sim("raijin", "kai")
	sim.request_move(0, "burst")
	var hits: int = 0
	for frame: int in range(90):
		sim.step([{}, {}])
		for event: Dictionary in sim.events:
			if event["type"] == "hit":
				hits += 1
	_expect(hits == 3 and is_equal_approx(sim.fighters[1]["hp"], 81.1), "lightning special hits three times with combo scaling")


func _test_earned_meter() -> void:
	var session: MatchSession = MatchSession.new()
	session.configure("local", 1, "kai", "atlas")
	for frame: int in range(800):
		session.step([{}, {}])
	_expect(session.simulation.fighters[0]["energy"] == 0.0 and session.simulation.fighters[1]["energy"] == 0.0, "waiting cannot charge real-match super meter")
	var sim: FightSimulation = session.simulation
	for strike: int in range(6):
		sim.fighters[0]["position"] = Vector2(-0.5, 0)
		sim.fighters[1]["position"] = Vector2(0.5, 0)
		sim.request_move(0, "jab")
		_advance(sim, 40)
	_expect(sim.fighters[0]["energy"] == 100.0 and sim.fighters[1]["hp"] == 58.0, "confirmed offense earns super before opponent is nearly defeated")
	_expect(sim.fighters[1]["energy"] > 60.0, "taking hits also builds comeback meter")
	sim = _sim()
	sim.request_move(0, "jab")
	sim.fighters[0]["position"] = Vector2(-0.4, 0)
	sim.fighters[1]["position"] = Vector2(0.4, 0)
	_advance(sim, 6, [{}, {"block": true}])
	_expect(sim.fighters[0]["energy"] == 6.0 and sim.fighters[1]["energy"] == 8.0, "blocking builds meter for attacker and defender")
	session.simulation.fighters[0]["energy"] = 73.0
	session.simulation.fighters[1]["hp"] = 0.0
	session.step([{}, {}])
	for frame: int in range(MatchSession.ROUND_END_FRAMES):
		session.step([{}, {}])
	_expect(session.simulation.fighters[0]["energy"] == 73.0, "earned meter carries between rounds")
	session.rematch()
	_expect(session.simulation.fighters[0]["energy"] == 0.0, "new match clears earned meter")


func _test_cinematic_lifecycle() -> void:
	var session: MatchSession = MatchSession.new()
	session.configure("local", 1, "kai", "neon")
	for frame: int in range(MatchSession.INTRO_FRAMES):
		session.step([{}, {}])
	var sim: FightSimulation = session.simulation
	sim.fighters[0]["position"] = Vector2(-0.5, 0)
	sim.fighters[1]["position"] = Vector2(0.5, 0)
	sim.fighters[0]["energy"] = 100.0
	sim.fighters[1]["hp"] = 20.0
	session.step([{"action": "finisher"}, {}])
	for frame: int in range(26):
		session.step([{}, {}])
	_expect(session.phase == "cinematic" and sim.fighters[1]["hp"] == 20.0 and session.wins == [0, 0], "clean super confirms without damage or premature round result")
	_expect(sim.pending_cinematic["move"] is MoveData and sim.pending_cinematic["fighter_id"] == "kai" and sim.pending_cinematic["cinematic_frames"] == 210, "director gets move resource, identity, and duration")
	var clock: int = session.remaining_frames
	var tick: int = sim.tick
	var positions: Array[Vector2] = [sim.fighters[0]["position"], sim.fighters[1]["position"]]
	for frame: int in range(240):
		session.step([{"action": "jab", "axis": 1.0}, {"action": "burst"}])
		sim.step([{}, {}])
	_expect(session.remaining_frames == clock and sim.tick == tick and sim.fighters[0]["position"] == positions[0] and sim.fighters[1]["position"] == positions[1], "cinematic freezes both simulation and match clock even if stepped")
	_expect(session.resolve_cinematic(), "director can resolve pending cinematic")
	_expect(sim.fighters[1]["hp"] == 0.0 and session.phase == "round_end" and session.wins == [1, 0], "cinematic damage commits before exactly one KO decision")
	_expect(session.events[0]["type"] == "hit" and session.events[0]["cinematic"] and session.events[1]["type"] == "cinematic_resolved", "resolution returns ordered combat and director events")
	_expect(not session.resolve_cinematic() and session.wins == [1, 0], "duplicate director completion cannot reapply damage or round award")


func _test_super_defenses_and_trades() -> void:
	for profile: Dictionary in FighterCatalog.all():
		var sim: FightSimulation = _sim(profile["id"], "kai")
		sim.fighters[0]["energy"] = 100.0
		sim.request_move(0, "finisher")
		var move: MoveData = sim.get_move(0, "finisher")
		_advance(sim, move.startup + 1, [{}, {"block": true}])
		_expect(sim.pending_cinematic.is_empty() and sim.fighters[1]["state"] == "blockstun" and sim.fighters[0]["energy"] == 0.0, profile["id"] + " super is guardable and spends meter on block")
		sim = _sim(profile["id"], "kai")
		sim.fighters[0]["position"] = Vector2(-3, 0)
		sim.fighters[1]["position"] = Vector2(3, 0)
		sim.fighters[0]["energy"] = 100.0
		sim.request_move(0, "finisher")
		_advance(sim, move.total_frames() + 2)
		_expect(sim.pending_cinematic.is_empty() and sim.fighters[1]["hp"] == 100.0 and sim.fighters[0]["energy"] == 0.0, profile["id"] + " whiffed super cannot trigger cinematic or refund meter")
	var sim: FightSimulation = _sim("kai", "raijin")
	sim.fighters[0]["energy"] = 100.0
	sim.request_move(0, "finisher")
	sim.request_move(1, "jab")
	_advance(sim, 5)
	_expect(sim.pending_cinematic.is_empty() and sim.fighters[0]["move"] == null and sim.fighters[0]["hp"] == 95.0, "ordinary strike interrupts super startup")
	sim = _sim("kai", "kai")
	sim.fighters[0]["energy"] = 100.0
	sim.request_move(0, "finisher")
	_advance(sim, sim.get_move(0, "finisher").startup - sim.get_move(1, "jab").startup)
	sim.fighters[0]["position"] = Vector2(-0.4, 0)
	sim.fighters[1]["position"] = Vector2(0.4, 0)
	sim.request_move(1, "jab")
	_advance(sim, 6)
	_expect(sim.pending_cinematic.is_empty() and sim.fighters[0]["hp"] == 93.0 and sim.fighters[1]["hp"] == 100.0, "simultaneous strike interrupts super confirmation deterministically")
	sim = _sim("kai", "kai")
	sim.fighters[0]["energy"] = 100.0
	sim.fighters[1]["energy"] = 100.0
	sim.request_move(0, "finisher")
	sim.request_move(1, "finisher")
	_advance(sim, 27)
	_expect(sim.pending_cinematic["attacker"] == 0 and sim.fighters[0]["hp"] == 100.0 and sim.fighters[1]["hp"] == 100.0, "simultaneous supers choose one director deterministically")
	sim.resolve_cinematic()
	_expect(sim.fighters[0]["hp"] == 100.0 and sim.fighters[1]["hp"] == 60.0 and not sim.resolve_cinematic(), "super trade cannot create a second cinematic or damage commit")


func _test_arcade_roster() -> void:
	var session: MatchSession = MatchSession.new()
	session.configure("arcade", 2, "vex", "kai")
	var visited: Dictionary = {}
	for index: int in range(9):
		var opponent: String = session.fighter_ids[1]
		_expect(opponent != "vex" and not visited.has(opponent), "arcade presents a different available opponent excluding player")
		visited[opponent] = true
		_expect(session.simulation.fighters[1]["fighter_id"] == opponent and session.simulation.get_move(1, "jab").animation_name == opponent + "_jab", "arcade applies opponent model identity and moves")
		session.phase = "match_end"
		session.winner = 0
		session.next_arcade_match()
	_expect(visited.size() == 9 and session.arcade_index == 8, "arcade covers every other fighter exactly once")


func _test_each_cpu() -> void:
	for profile: Dictionary in FighterCatalog.all():
		var session: MatchSession = MatchSession.new()
		session.configure("cpu", 2, "kai", profile["id"])
		for frame: int in range(12000):
			session.step([{}, {}])
			if session.phase == "cinematic":
				session.resolve_cinematic()
			if session.phase == "match_end":
				break
		_expect(session.phase == "match_end" and session.winner == 1, profile["id"] + " CPU can close out a match using its actual mechanics")
