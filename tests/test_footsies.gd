extends SceneTree

const Policy = preload("res://combat/FootsiesAI.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_geometry()
	_reactions_and_punishes()
	_pressure_tools()
	_neutral_rhythm()
	_live_punishes()
	print("Footsies checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures > 0 else 0)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _sim(first: String, second: String) -> FightSimulation:
	var sim := FightSimulation.new()
	for side in range(2):
		var id := first if side == 0 else second
		sim.set_fighter_profile(side, FighterCatalog.get_fighter(id))
		sim.set_fighter_moves(side, FighterCatalog.moves(id))
	return sim

func _geometry() -> void:
	for id: String in ["kai", "neon"]:
		var sim := _sim(id, id)
		var jab := sim.get_move(0, "jab")
		var low := sim.get_move(0, "low_kick")
		_expect(jab.maximum_reach() < low.maximum_reach() - 0.2, id + " light and low have meaningfully distinct reach")
		for move: MoveData in FighterCatalog.moves(id):
			if not move.animated_hitbox:
				continue
			_expect(move.validation_errors().is_empty(), id + "/" + move.id + " validates")
			sim.fighters[0]["move"] = move
			sim.fighters[0]["position"] = Vector2.ZERO
			sim.fighters[0]["move_frame"] = move.startup - 1
			_expect(sim.hitboxes(0).is_empty(), "no attack before active window")
			var middle := move.startup + move.active / 2
			sim.fighters[0]["move_frame"] = middle
			sim.fighters[0]["facing"] = 1
			var right: Rect2 = sim.hitboxes(0)[0]
			sim.fighters[0]["facing"] = -1
			var left: Rect2 = sim.hitboxes(0)[0]
			_expect(is_equal_approx(left.position.x, -right.end.x) and left.size == right.size, "per-frame hitboxes mirror exactly")
			sim.fighters[0]["move_frame"] = move.startup + move.active
			_expect(sim.hitboxes(0).is_empty() and sim.hurtboxes(0).size() == 2, "early recovery exposes limb but cannot deal damage")
			sim.fighters[0]["move_frame"] += move.exposed_recovery_frames
			_expect(sim.hurtboxes(0).size() == 1, "limb retracts after exposure window")
			if move.id in ["jab", "cross", "low_kick"]:
				_expect(move.attack_rect_at(move.startup).end.x < right.end.x, "normal grows into full reach")
		# At the old jab range this now misses, while the longer low still connects.
		for action: String in ["jab", "low_kick"]:
			sim = _sim(id, id)
			sim.fighters[0]["position"] = Vector2.ZERO
			sim.fighters[1]["position"] = Vector2(1.3, 0)
			sim.request_move(0, action)
			for frame in range(45):
				sim.step([{}, {}])
			_expect((sim.fighters[1]["hp"] == 100.0) == (action == "jab"), "spacing separates jab whiff from low contact")
	# Hitting only an extended limb is a legitimate whiff punish.
	var sim := _sim("neon", "kai")
	var attack := sim.get_move(1, "low_kick")
	sim.fighters[0]["position"] = Vector2.ZERO
	sim.fighters[1]["position"] = Vector2(1.75, 0)
	sim.fighters[1]["move"] = attack
	sim.fighters[1]["move_frame"] = attack.startup + attack.active
	sim.fighters[1]["facing"] = -1
	sim.fighters[0]["move"] = sim.get_move(0, "low_kick")
	sim.fighters[0]["move_frame"] = sim.get_move(0, "low_kick").startup + 1
	sim.step([{}, {}])
	_expect(sim.fighters[1]["hp"] < 100.0, "exposed leg is punishable outside neutral torso range")

func _reactions_and_punishes() -> void:
	var sim := _sim("kai", "neon")
	var ai = Policy.new()
	ai.reset(19)
	sim.fighters[0]["position"] = Vector2(-0.5, 0)
	sim.fighters[1]["position"] = Vector2(0.5, 0)
	sim.request_move(0, "jab")
	for frame in range(12):
		var input: Dictionary = ai.input_for(sim, 1, 3)
		_expect(not input.get("block", false) and not input.has("action"), "no reaction before minimum observation delay")
	_expect(ai._choose_attack(sim, 1, 1.0, 3, false).is_empty(), "CPU cannot punish with startup longer than remaining recovery")
	_expect(not ai._choose_attack(sim, 1, 1.0, 18, false).is_empty(), "CPU finds an in-range punish when recovery allows it")
	_expect(ai._choose_attack(sim, 1, 4.0, 18, false).is_empty(), "CPU does not attempt a melee punish across the screen")
	var history_size: int = ai._history.size()
	sim.freeze_frames = 5
	ai.input_for(sim, 1, 3)
	_expect(ai._history.size() == history_size, "hitstop does not advance CPU reactions")


func _pressure_tools() -> void:
	var sim := _sim("kai", "neon")
	var ai = Policy.new()
	ai.reset(101)
	for frame in range(20):
		ai.input_for(sim, 1, 1)
	var current: MoveData = sim.get_move(1, "jab")
	sim.fighters[1]["move"] = current
	sim.fighters[1]["move_frame"] = current.cancel_start
	sim.fighters[1]["_confirmed"] = true
	var routed: Dictionary = ai.input_for(sim, 1, 3)
	_expect(routed.has("action") and current.cancel_into.has(str(routed["action"])), "CPU only follows confirmed contacts through legal cancel routes")
	var basic := _sim("kai", "neon")
	var trailing := _sim("kai", "neon")
	trailing.fighters[1]["hp"] = 55.0
	var basic_ai = Policy.new()
	var trailing_ai = Policy.new()
	basic_ai.reset(333)
	trailing_ai.reset(333)
	for frame in range(20):
		basic_ai.input_for(basic, 1, 1)
		trailing_ai.input_for(trailing, 1, 1)
	_expect(trailing_ai.preferred_range < basic_ai.preferred_range, "CPU closes distance a little when clearly behind")
	var power_ai = Policy.new()
	power_ai.reset(61)
	var powered := false
	for attempt in range(80):
		var attempt_input: Dictionary = {}
		power_ai._maybe_activate_overdrive(attempt_input, {"energy": 50.0, "power_frames": 0}, 45.0, 1)
		powered = powered or bool(attempt_input.get("power", false))
	_expect(powered, "normal CPU eventually spends earned meter when it needs momentum")

func _neutral_rhythm() -> void:
	for id: String in ["kai", "neon"]:
		for level in range(4):
			var sim := _sim("kai", id)
			var ai = Policy.new()
			ai.reset(9173 + level * 109)
			var forward := 0
			var retreat := 0
			var wait := 0
			var attacks := 0
			var actions: Dictionary = {}
			for frame in range(3600):
				var input: Dictionary = ai.input_for(sim, 1, level)
				var direction: float = signf(sim.fighters[0]["position"].x - sim.fighters[1]["position"].x)
				if sim.fighters[1]["move"] == null and sim.fighters[1]["stun"] == 0 and sim.freeze_frames == 0:
					var axis: float = input.get("axis", 0.0)
					if axis * direction > 0.01: forward += 1
					elif axis * direction < -0.01: retreat += 1
					else: wait += 1
				if input.has("action"):
					attacks += 1
					actions[input["action"]] = true
				sim.step([{}, input])
				sim.fighters[0]["hp"] = 100.0
				if not sim.pending_cinematic.is_empty(): sim.resolve_cinematic()
			print("CPU %s L%d: forward %d / retreat %d / wait %d / attacks %d / moves %s" % [id, level, forward, retreat, wait, attacks, actions.keys()])
			_expect(forward > 60 and retreat > 60 and wait > 60, "CPU approaches, retreats and pauses at every difficulty")
			_expect(forward < (forward + retreat + wait) * 0.72, "neutral is not dominated by constant approach")
			var attack_ceiling: int = [55, 90, 90, 95][level]
			_expect(attacks >= 20 and attacks <= attack_ceiling, "CPU offense rises by tier without becoming an unbroken string")
			_expect(actions.size() >= 2, "CPU contests more than one range")


func _live_punishes() -> void:
	var attempts := 0
	var contacts := 0
	for seed_value in range(12):
		var sim := _sim("kai", "neon")
		var ai = Policy.new()
		ai.reset(9173 + seed_value * 101)
		for frame in range(2400):
			var cpu: Dictionary = ai.input_for(sim, 1, 3)
			if cpu.has("action") and ai.intent == "Whiff punish": attempts += 1
			var distance: float = sim.fighters[1]["position"].x - sim.fighters[0]["position"].x
			var player := {"axis": signf(distance) if absf(distance) > 1.6 else 0.0, "action": "launcher" if frame % 85 == 0 else ""}
			sim.step([player, cpu])
			for event: Dictionary in sim.events:
				if event["type"] == "hit" and event["attacker"] == 1 and ai.intent == "Whiff punish": contacts += 1
			sim.fighters[0]["hp"] = 100.0
			sim.fighters[1]["hp"] = 100.0
			if not sim.pending_cinematic.is_empty(): sim.resolve_cinematic()
	print("Live recovery punishes: %d attempts / %d contacts" % [attempts, contacts])
	_expect(attempts > 0 and contacts > 0, "Delayed CPU sees real whiffs and lands recovery punishes across seeded matches")
