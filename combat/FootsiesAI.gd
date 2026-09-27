class_name FootsiesAI
extends RefCounted
## Seeded policy with delayed public-state observations. Never reads player inputs,
## buffers or random state. The same policy is used in matches and Training.

var intent: String = "Observe"
var preferred_range: float = 1.7
var _rng: int = 1
var _history: Array[Dictionary] = []
var _held: Dictionary = {}
var _decision_frames: int = 0
var _attack_frames: int = 0
var _projectile_frames: int = 0
var _reset_frames: int = 0
var _move_seen: bool = false
var _recent_confirm: bool = false
var _last_attack: String = ""


func reset(seed_value: int = 1) -> void:
	_rng = maxi(1, seed_value)
	_history.clear()
	_held = {"axis": 0.0, "block": false}
	_decision_frames = 0
	_attack_frames = 0
	_projectile_frames = 0
	_reset_frames = 0
	_move_seen = false
	_recent_confirm = false
	_last_attack = ""
	intent = "Observe"


func _random() -> float:
	_rng = (_rng * 48271) % 2147483647
	return float(_rng) / 2147483647.0


func input_for(sim: FightSimulation, side: int, level: int) -> Dictionary:
	var idle: Dictionary = {"axis": 0.0, "block": false}
	if sim.freeze_frames > 0 or not sim.pending_cinematic.is_empty():
		return idle
	level = clampi(level, 0, 3)
	var cpu: Dictionary = sim.fighters[side]
	var opponent: Dictionary = sim.fighters[1 - side]
	var projectile_threat := false
	for projectile: Dictionary in sim.projectiles:
		var to_cpu: float = cpu["position"].x - projectile["position"].x
		if projectile["owner"] != side and to_cpu * float(projectile["direction"]) > 0.0 and absf(to_cpu) < 3.0:
			projectile_threat = true
	_history.append({"position": opponent["position"], "move": opponent["move"], "frame": opponent["move_frame"], "stun": opponent["stun"], "state": opponent["state"], "hp": opponent["hp"], "projectile": projectile_threat})
	var reaction: int = [24, 19, 15, 12][level]
	if _history.size() <= reaction:
		return idle
	var seen: Dictionary = _history.pop_front()
	var health_deficit: float = float(seen["hp"]) - float(cpu["hp"])
	_attack_frames = maxi(0, _attack_frames - 1)
	_projectile_frames = maxi(0, _projectile_frames - 1)
	_reset_frames = maxi(0, _reset_frames - 1)
	# Confirmed contacts are where a fighter earns pressure. The CPU can only
	# buffer routes explicitly allowed by the current move's cancel data.
	if cpu["move"] != null:
		var current: MoveData = cpu["move"]
		var frame: int = int(cpu["move_frame"])
		_recent_confirm = _recent_confirm or bool(cpu["_confirmed"])
		if bool(cpu["_confirmed"]) and current.cancel_start >= 0 and frame >= current.cancel_start and frame <= current.cancel_end:
			var follow_up := _choose_follow_up(sim, side, current, level)
			if not follow_up.is_empty() and _random() < [0.34, 0.62, 0.76, 0.88][level]:
				var confirm_result := result_for_action(follow_up)
				_maybe_activate_overdrive(confirm_result, cpu, health_deficit, level)
				_commit(confirm_result, sim.get_move(side, follow_up), "Confirmed pressure", level)
				return confirm_result
		_move_seen = true
		_held = idle
		return idle
	if cpu["stun"] > 0:
		_held = idle
		return idle
	if _move_seen:
		_move_seen = false
		var reset_base: int = [14, 8, 5, 3][level]
		var reset_variation: float = [11.0, 8.0, 5.0, 4.0][level]
		_reset_frames = reset_base + int(_random() * reset_variation)
		if _recent_confirm:
			_reset_frames = maxi(2, _reset_frames - [0, 3, 4, 5][level])
		_recent_confirm = false
		_decision_frames = 0
	_decision_frames -= 1
	if _decision_frames > 0:
		return _held.duplicate()
	_decision_frames = [15, 11, 8, 6][level] + int(_random() * [6.0, 5.0, 4.0, 3.0][level])
	var difference: float = seen["position"].x - cpu["position"].x
	var distance := absf(difference)
	var direction := signf(difference)
	var special: MoveData = sim.get_move(side, "burst")
	var zoner := special != null and special.behavior == "projectile"
	var poke: MoveData = sim.get_move(side, "low_kick")
	var enemy_poke: MoveData = sim.get_move(1 - side, "low_kick")
	var poke_range := poke.maximum_reach() + 0.24 if poke != null else 1.4
	var enemy_range := enemy_poke.maximum_reach() + 0.24 if enemy_poke != null else 1.4
	# Between projectiles a zoner contests poke range, then withdraws to cast again.
	var comeback_push: float = clampf((health_deficit - 8.0) / 48.0, 0.0, 1.0)
	preferred_range = maxf(poke_range, enemy_range) + (0.65 if zoner and _projectile_frames == 0 else -0.12) - comeback_push * 0.18
	var cornered: bool = absf(cpu["position"].x) > FightSimulation.ARENA_HALF_WIDTH - 0.8 and signf(cpu["position"].x) == -direction
	var threat: MoveData = seen["move"]
	var phase := threat.phase_at(seen["frame"]) if threat != null else "idle"
	var estimated_frame: int = int(seen["frame"]) + reaction
	var anticipated_whiff := threat != null and phase == "active" and distance > attack_range(threat) and threat.phase_at(estimated_frame) == "recovery"
	var threatened := bool(seen["projectile"])
	if threat != null and phase in ["startup", "active"]:
		threatened = threatened or (not anticipated_whiff and distance < attack_range(threat) + 0.25)
	var result: Dictionary = idle.duplicate()
	if threatened and _random() < [0.52, 0.68, 0.8, 0.88][level]:
		intent = "Guard" if cornered or distance < enemy_range else "Bait / retreat"
		result["block"] = intent == "Guard" or bool(seen["projectile"])
		result["axis"] = 0.0 if result["block"] else -direction
		if special != null and special.behavior == "counter" and _attack_frames == 0 and distance < 1.65 and _random() < 0.15 + level * 0.08:
			result["block"] = false
			_commit(result, special, "Counter read", level)
	elif threat != null and (phase == "recovery" or anticipated_whiff) and _attack_frames == 0:
		# Subtract the observation delay: don't punish a recovery which is already
		# over by the time our startup would arrive.
		var available: int = threat.total_frames() - int(seen["frame"]) - reaction
		var punish := _choose_attack(sim, side, distance, available, false)
		if not punish.is_empty() and _random() < 0.45 + level * 0.13:
			_commit(result, sim.get_move(side, punish), "Whiff punish", level)
		elif not cornered and distance < preferred_range:
			result["axis"] = -direction * 0.65
			intent = "Wait outside reach"
	elif _reset_frames > 0:
		intent = "Reset spacing"
		result["axis"] = -direction * 0.7 if distance < preferred_range and not cornered else 0.0
	else:
		var roll := _random()
		var base_attack_chance: float = float([0.36, 0.51, 0.64, 0.72][level] if zoner else [0.43, 0.57, 0.70, 0.78][level])
		var attack_chance: float = minf(0.86, base_attack_chance + comeback_push * [0.04, 0.10, 0.12, 0.14][level])
		if _attack_frames == 0 and roll < attack_chance:
			var attack := _choose_attack(sim, side, distance, 999, zoner and _projectile_frames == 0, str(seen["state"]) in ["block", "blockstun"])
			if not attack.is_empty():
				_commit(result, sim.get_move(side, attack), "Place projectile" if attack == "burst" and zoner else "Check range", level)
				_maybe_activate_overdrive(result, cpu, health_deficit, level)
		if not result.has("action"):
			# Short, separated steps make a readable approach/retreat rhythm.
			if distance > preferred_range + 0.3:
				intent = "Approach" if roll > 0.23 else "Observe"
				result["axis"] = direction * (0.85 if distance > preferred_range + 1.0 else 0.55) if roll > 0.23 else 0.0
			elif distance < preferred_range - 0.25 and not cornered:
				intent = "Give ground" if roll > 0.25 else "Hold ground"
				result["axis"] = -direction * 0.65 if roll > 0.25 else 0.0
			elif roll < 0.3 and not cornered:
				intent = "Bait / retreat"
				result["axis"] = -direction * 0.45
			elif roll > 0.62:
				intent = "Probe forward"
				result["axis"] = direction * 0.5
			else:
				intent = "Observe"
	_held = {"axis": result["axis"], "block": result["block"]}
	return result


static func attack_range(move: MoveData) -> float:
	var travel := 0.0
	if move.lunge_start >= 0 and move.lunge_speed > 0.0:
		travel = maxf(0.0, mini(move.lunge_end, move.startup + move.active - 1) - move.lunge_start + 1) * move.lunge_speed / 60.0
	return move.maximum_reach() + 0.24 + travel


func _choose_attack(sim: FightSimulation, side: int, distance: float, available: int, allow_projectile: bool, guarding: bool = false) -> String:
	var choices: Array[String] = []
	for id: String in ["jab", "cross", "low_kick", "body_hook", "knee", "side_kick", "spin_kick", "launcher", "burst", "finisher"]:
		var move: MoveData = sim.get_move(side, id)
		if move == null or move.damage <= 0.0 or move.behavior == "counter" or move.energy_cost > float(sim.fighters[side]["energy"]):
			continue
		if move.startup + 2 > available:
			continue
		if move.behavior == "projectile":
			if allow_projectile and distance > 2.0 and distance < minf(5.5, move.projectile_speed * move.projectile_lifetime / 60.0):
				choices.append(id)
			continue
		if distance > attack_range(move) - 0.08:
			continue
		# Slow finishers and advancing specials need an opening, not a neutral coin flip.
		if available == 999 and id in ["finisher", "burst", "launcher", "spin_kick"] and not (move.behavior == "grab" and guarding):
			continue
		choices.append(id)
	if choices.is_empty():
		return ""
	if choices.size() > 1:
		choices.erase(_last_attack)
	return choices[mini(choices.size() - 1, int(_random() * choices.size()))]


func _choose_follow_up(sim: FightSimulation, side: int, current: MoveData, level: int) -> String:
	var routes: Array[String] = []
	for id: String in current.cancel_into:
		var move: MoveData = sim.get_move(side, id)
		if move == null or move.energy_cost > float(sim.fighters[side]["energy"]):
			continue
		if id == "finisher" and level < 2:
			continue
		routes.append(id)
	if routes.is_empty():
		return ""
	# Higher tiers convert with stronger routes more often, but never invent a combo.
	if level >= 2:
		for preferred: String in ["finisher", "burst", "launcher", "cross", "low_kick"]:
			if routes.has(preferred):
				return preferred
	return routes[mini(routes.size() - 1, int(_random() * routes.size()))]


static func result_for_action(action: String) -> Dictionary:
	return {"axis": 0.0, "block": false, "action": action}


func _maybe_activate_overdrive(result: Dictionary, cpu: Dictionary, health_deficit: float, level: int) -> void:
	if level == 0 or float(cpu["energy"]) < 50.0 or int(cpu["power_frames"]) > 0:
		return
	var comeback_bonus: float = clampf((health_deficit - 12.0) / 50.0, 0.0, 1.0) * 0.12
	var chance: float = [0.0, 0.055, 0.11, 0.16][level] + comeback_bonus
	if _random() < chance:
		result["power"] = true
		intent += " / Overdrive"


func _commit(result: Dictionary, move: MoveData, reason: String, level: int = 1) -> void:
	result["action"] = move.id
	result["axis"] = 0.0
	_last_attack = move.id
	_attack_frames = move.total_frames() + [12, 6, 4, 3][level] + int(_random() * [10.0, 8.0, 5.0, 4.0][level])
	if move.behavior == "projectile":
		_projectile_frames = move.total_frames() + [130, 108, 88, 72][level] + int(_random() * 30.0)
	intent = reason
