class_name FightSimulation
extends RefCounted
## Call step exactly once per 60 Hz physics tick. Rendering does not advance combat.
## Positions and Rect2 geometry use x = horizontal and y = height above the floor.

const HZ: int = 60
const DT: float = 1.0 / HZ
const INPUT_BUFFER_FRAMES: int = 6
const WALK_SPEED: float = 3.5
const GRAVITY: float = 22.0
const JUMP_SPEED: float = 7.5
const ARENA_HALF_WIDTH: float = 5.0
const PUSHBOX_WIDTH: float = 0.64

var fighters: Array[Dictionary] = []
var tick: int = 0
var freeze_frames: int = 0
var events: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var pending_cinematic: Dictionary = {}
var _moves: Array[Dictionary] = [{}, {}]
var _profiles: Array[Dictionary] = [{}, {}]
var _projectile_id: int = 0


func _init() -> void:
	set_moves(MoveCatalog.defaults())
	reset()


func set_moves(moves: Array[MoveData]) -> void:
	set_fighter_moves(0, moves)
	set_fighter_moves(1, moves)


func set_fighter_moves(index: int, moves: Array[MoveData]) -> void:
	if index < 0 or index > 1:
		return
	_moves[index].clear()
	for move: MoveData in moves:
		if move != null and move.validation_errors().is_empty():
			_moves[index][move.id] = move


func set_fighter_profile(index: int, profile: Dictionary) -> void:
	if index < 0 or index > 1:
		return
	_profiles[index] = profile.duplicate()
	if fighters.size() > index:
		_apply_profile(index)


func get_move(index: int, id: String) -> MoveData:
	if index < 0 or index > 1:
		return null
	return _moves[index].get(id)


func _apply_profile(index: int) -> void:
	var profile: Dictionary = _profiles[index]
	fighters[index]["fighter_id"] = profile.get("id", "kai")
	fighters[index]["style"] = profile.get("style", "kai")
	fighters[index]["color"] = profile.get("color", Color("ff673d"))
	fighters[index]["walk_speed"] = float(profile.get("walk_speed", WALK_SPEED))
	fighters[index]["jump_speed"] = float(profile.get("jump_speed", JUMP_SPEED))
	fighters[index]["gravity"] = float(profile.get("gravity", GRAVITY))


func reset() -> void:
	tick = 0
	freeze_frames = 0
	events.clear()
	projectiles.clear()
	pending_cinematic.clear()
	_projectile_id = 0
	fighters.clear()
	for index: int in range(2):
		fighters.append({
			"position": Vector2(-1.35 if index == 0 else 1.35, 0.0),
			"velocity": Vector2.ZERO, "hp": 100.0, "guard": 100.0, "energy": 100.0,
			"state": "idle", "move": null, "move_frame": -1, "stun": 0,
			"facing": 1 if index == 0 else -1, "combo": 0,
			"power_frames": 0,
			"slow_frames": 0, "slow_multiplier": 1.0,
			"_hit_count": 0, "_last_hit_frame": -999, "_armor_remaining": 0,
			"_counter_used": false, "_projectile_spawned": false,
			"_fresh": false, "_hit": false, "_confirmed": false,
			"_buffer_action": "", "_buffer_frames": 0,
			"_block": false, "_crouch": false,
		})
		_apply_profile(index)


func step(inputs: Array[Dictionary]) -> void:
	events.clear()
	if not pending_cinematic.is_empty():
		return
	tick += 1
	for index: int in range(2):
		var input: Dictionary = inputs[index] if index < inputs.size() else {}
		var action: String = resolve_command(index, input)
		if not action.is_empty():
			fighters[index]["_buffer_action"] = action
			fighters[index]["_buffer_frames"] = INPUT_BUFFER_FRAMES
	if freeze_frames > 0:
		freeze_frames -= 1
		return

	for index: int in range(2):
		_advance_state(index)
	for index: int in range(2):
		if fighters[1 - index]["stun"] <= 0:
			fighters[index]["combo"] = 0
	for index: int in range(2):
		var input: Dictionary = inputs[index] if index < inputs.size() else {}
		_apply_input(index, input)
	for index: int in range(2):
		_move_fighter(index)
	_resolve_pushboxes()
	_advance_projectiles()
	for index: int in range(2):
		_spawn_projectile(index)
	# Collect both contacts before applying either, allowing simultaneous trades.
	var contacts: Array[Dictionary] = []
	for attacker: int in range(2):
		var defender: int = 1 - attacker
		var move: MoveData = fighters[attacker]["move"]
		if move == null or fighters[attacker]["_hit_count"] >= move.max_hits or fighters[attacker]["move_frame"] - fighters[attacker]["_last_hit_frame"] < move.rehit_frames:
			continue
		for strike: Rect2 in hitboxes(attacker):
			for hurt: Rect2 in hurtboxes(defender):
				if strike.intersects(hurt):
					if move.behavior != "grab" or (fighters[defender]["position"].y <= 0.05 and fighters[defender]["stun"] <= 0):
						contacts.append({"attacker": attacker, "defender": defender, "move": move, "facing": fighters[attacker]["facing"], "projectile_id": -1})
					break
			if not contacts.is_empty() and contacts.back()["attacker"] == attacker:
				break
	for projectile: Dictionary in projectiles:
		var defender: int = 1 - int(projectile["owner"])
		for hurt: Rect2 in hurtboxes(defender):
			if _projectile_box(projectile).intersects(hurt):
				contacts.append({"attacker": projectile["owner"], "defender": defender, "move": projectile["move"], "facing": projectile["direction"], "projectile_id": projectile["id"]})
				break
	_resolve_contacts(contacts)
	for fighter: Dictionary in fighters:
		fighter["_fresh"] = false
		if fighter["_buffer_frames"] > 0:
			fighter["_buffer_frames"] -= 1
			if fighter["_buffer_frames"] == 0:
				fighter["_buffer_action"] = ""


func resolve_command(index: int, input: Dictionary) -> String:
	var action := str(input.get("action", ""))
	if action.is_empty() or fighters[index].position.y > 0.05:
		return action
	var direction := float(input.get("axis", 0)) * int(fighters[index].facing)
	var modifier := "down" if bool(input.get("crouch", false)) else "forward" if direction > .5 else "back" if direction < -.5 else ""
	for move: MoveData in _moves[index].values():
		if not modifier.is_empty() and move.command_base == action and move.command_modifier == modifier:
			return move.id
	return action


func request_move(index: int, id: String) -> bool:
	if index < 0 or index >= fighters.size() or not _moves[index].has(id) or freeze_frames > 0 or not pending_cinematic.is_empty():
		return false
	var fighter: Dictionary = fighters[index]
	var next_move: MoveData = _moves[index][id]
	if fighter["stun"] > 0 or fighter["hp"] <= 0.0 or fighter["energy"] < next_move.energy_cost:
		return false
	var current_move: MoveData = fighter["move"]
	if current_move != null:
		var frame: int = fighter["move_frame"]
		if not fighter["_confirmed"] or current_move.cancel_start < 0 or frame < current_move.cancel_start or frame > current_move.cancel_end or not current_move.cancel_into.has(id):
			return false
	fighter["move"] = next_move
	fighter["move_frame"] = 0
	fighter["state"] = next_move.phase_at(0)
	fighter["energy"] -= next_move.energy_cost
	fighter["_fresh"] = true
	fighter["_hit"] = false
	fighter["_hit_count"] = 0
	fighter["_last_hit_frame"] = -999
	fighter["_armor_remaining"] = next_move.armor_hits
	fighter["_counter_used"] = false
	fighter["_projectile_spawned"] = false
	fighter["_confirmed"] = false
	fighter["_buffer_action"] = ""
	fighter["_buffer_frames"] = 0
	fighter["_block"] = false
	var event: Dictionary = _metadata(index, next_move)
	event.merge({"type": "move_started", "fighter": index, "move": id, "move_data": next_move})
	events.append(event)
	return true


func hitboxes(index: int) -> Array[Rect2]:
	var result: Array[Rect2] = []
	if index < 0 or index >= fighters.size():
		return result
	var fighter: Dictionary = fighters[index]
	var move: MoveData = fighter["move"]
	if move != null and move.behavior in ["strike", "grab"] and move.phase_at(fighter["move_frame"]) == "active" and move.damage > 0.0:
		var rect := move.attack_rect_at(fighter["move_frame"])
		result.append(_box(fighter, rect.get_center(), rect.size))
	return result


func hurtboxes(index: int) -> Array[Rect2]:
	var result: Array[Rect2] = []
	if index < 0 or index >= fighters.size():
		return result
	var fighter: Dictionary = fighters[index]
	var move: MoveData = fighter["move"]
	if move != null and move.is_invulnerable(fighter["move_frame"]):
		return result
	var offset: Vector2 = move.hurtbox_offset if move != null else Vector2(0.0, 0.9)
	var size: Vector2 = move.hurtbox_size if move != null else Vector2(0.55, 1.8)
	if fighter["_crouch"] and move == null and fighter["stun"] == 0:
		offset.y *= 0.55
		size.y *= 0.55
	result.append(_box(fighter, offset, size))
	if move != null:
		var limb := move.exposed_rect_at(fighter["move_frame"])
		if limb.has_area():
			result.append(_box(fighter, limb.get_center(), limb.size))
	return result


func _box(fighter: Dictionary, offset: Vector2, size: Vector2) -> Rect2:
	var center: Vector2 = fighter["position"] + Vector2(offset.x * fighter["facing"], offset.y)
	return Rect2(center - size * 0.5, size)


func _advance_state(index: int) -> void:
	var fighter: Dictionary = fighters[index]
	if fighter["slow_frames"] > 0:
		fighter["slow_frames"] -= 1
		if fighter["slow_frames"] == 0:
			fighter["slow_multiplier"] = 1.0
	if fighter["power_frames"] > 0:
		fighter["power_frames"] -= 1
		if fighter["power_frames"] == 0:
			events.append({"type": "power_ended", "fighter": index})
	if fighter["stun"] > 0:
		fighter["stun"] -= 1
		if fighter["stun"] == 0:
			fighter["state"] = "idle"
	var move: MoveData = fighter["move"]
	if move != null:
		if not fighter["_fresh"]:
			fighter["move_frame"] += 1
		if fighter["move_frame"] >= move.total_frames():
			fighter["move"] = null
			fighter["move_frame"] = -1
			fighter["state"] = "idle"
			events.append({"type": "move_ended", "fighter": index, "move": move.id, "contact": bool(fighter["_hit"])})
		else:
			fighter["state"] = move.phase_at(fighter["move_frame"])


func _apply_input(index: int, input: Dictionary) -> void:
	var fighter: Dictionary = fighters[index]
	var position: Vector2 = fighter["position"]
	var velocity: Vector2 = fighter["velocity"]
	fighter["_block"] = bool(input.get("block", false)) and position.y <= 0.0
	fighter["_crouch"] = bool(input.get("crouch", false)) and position.y <= 0.0
	if bool(input.get("power", false)) and fighter["power_frames"] == 0 and fighter["energy"] >= 50.0 and fighter["move"] == null and fighter["stun"] == 0 and fighter["hp"] > 0.0:
		fighter["energy"] -= 50.0
		fighter["power_frames"] = 360
		events.append({"type": "power_started", "fighter": index, "frames": 360, "damage_multiplier": 1.25})
	if fighter["move"] == null and fighter["stun"] <= 0:
		var opponent_position: Vector2 = fighters[1 - index]["position"]
		if absf(opponent_position.x - position.x) > 0.001:
			fighter["facing"] = 1 if opponent_position.x > position.x else -1
	if fighter["_buffer_frames"] > 0:
		request_move(index, fighter["_buffer_action"])
	if fighter["hp"] <= 0.0:
		fighter["state"] = "down"
		velocity.x = move_toward(velocity.x, 0.0, 0.15)
	elif fighter["stun"] > 0:
		velocity.x = move_toward(velocity.x, 0.0, 0.07)
	elif fighter["move"] != null:
		var move: MoveData = fighter["move"]
		var frame: int = fighter["move_frame"]
		if move.lunge_start >= 0 and frame >= move.lunge_start and frame <= move.lunge_end:
			velocity.x = float(fighter["facing"]) * move.lunge_speed
		else:
			velocity.x = float(fighter["facing"]) * 3.8 if move.id == "dodge" and move.is_invulnerable(frame) else 0.0
	else:
		var axis: float = clampf(float(input.get("axis", 0.0)), -1.0, 1.0)
		velocity.x = axis * float(fighter["walk_speed"]) * float(fighter["slow_multiplier"]) if not fighter["_block"] and not fighter["_crouch"] else 0.0
		if bool(input.get("jump", false)) and position.y <= 0.0 and not fighter["_block"]:
			velocity.y = fighter["jump_speed"]
		if position.y > 0.0 or velocity.y > 0.0:
			fighter["state"] = "jump"
		elif fighter["_block"]:
			fighter["state"] = "block"
		elif fighter["_crouch"]:
			fighter["state"] = "crouch"
		elif absf(axis) > 0.01:
			fighter["state"] = "walk"
		else:
			fighter["state"] = "idle"
		if not fighter["_block"]:
			fighter["guard"] = minf(100.0, fighter["guard"] + 0.18)
	fighter["velocity"] = velocity


func _move_fighter(index: int) -> void:
	var fighter: Dictionary = fighters[index]
	var position: Vector2 = fighter["position"]
	var velocity: Vector2 = fighter["velocity"]
	if position.y > 0.0 or velocity.y > 0.0:
		velocity.y -= float(fighter["gravity"]) * DT
	position += velocity * DT
	position.x = clampf(position.x, -ARENA_HALF_WIDTH, ARENA_HALF_WIDTH)
	if position.y <= 0.0:
		position.y = 0.0
		velocity.y = 0.0
	fighter["position"] = position
	fighter["velocity"] = velocity


func _resolve_pushboxes() -> void:
	for fighter: Dictionary in fighters:
		var move: MoveData = fighter["move"]
		if move != null and move.cross_through and move.is_invulnerable(fighter["move_frame"]):
			return
	var left: Vector2 = fighters[0]["position"]
	var right: Vector2 = fighters[1]["position"]
	if absf(left.y - right.y) >= 1.5:
		return
	var distance: float = right.x - left.x
	if absf(distance) >= PUSHBOX_WIDTH:
		return
	var direction: float = 1.0 if distance >= 0.0 else -1.0
	var overlap: float = (PUSHBOX_WIDTH - absf(distance)) * 0.5
	left.x = clampf(left.x - overlap * direction, -ARENA_HALF_WIDTH, ARENA_HALF_WIDTH)
	right.x = clampf(right.x + overlap * direction, -ARENA_HALF_WIDTH, ARENA_HALF_WIDTH)
	# At an arena wall, the free fighter takes the remaining separation.
	if absf(right.x - left.x) < PUSHBOX_WIDTH:
		if absf(left.x) >= ARENA_HALF_WIDTH:
			right.x = left.x + PUSHBOX_WIDTH * direction
		else:
			left.x = right.x - PUSHBOX_WIDTH * direction
	fighters[0]["position"] = left
	fighters[1]["position"] = right


func _metadata(index: int, move: MoveData) -> Dictionary:
	return {"fighter_id": fighters[index]["fighter_id"], "style": fighters[index]["style"], "color": fighters[index]["color"], "effect": move.effect}


func projectile_hitboxes(index: int = -1) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for projectile: Dictionary in projectiles:
		if index < 0 or projectile["owner"] == index:
			result.append(_projectile_box(projectile))
	return result


func _projectile_box(projectile: Dictionary) -> Rect2:
	return Rect2(projectile["position"] - projectile["size"] * 0.5, projectile["size"])


func _spawn_projectile(index: int) -> void:
	var fighter: Dictionary = fighters[index]
	var move: MoveData = fighter["move"]
	if move == null or move.behavior != "projectile" or fighter["_projectile_spawned"] or move.phase_at(fighter["move_frame"]) != "active":
		return
	fighter["_projectile_spawned"] = true
	_projectile_id += 1
	var position: Vector2 = fighter["position"] + Vector2(move.hitbox_offset.x * fighter["facing"], move.hitbox_offset.y)
	var projectile: Dictionary = _metadata(index, move)
	projectile.merge({"id": _projectile_id, "owner": index, "position": position, "velocity": Vector2(move.projectile_speed * fighter["facing"], 0.0), "direction": fighter["facing"], "size": move.hitbox_size, "life": move.projectile_lifetime, "move": move})
	projectiles.append(projectile)
	var event: Dictionary = _metadata(index, move)
	event.merge({"type": "projectile_spawned", "projectile_id": _projectile_id, "fighter": index, "position": position})
	events.append(event)


func _advance_projectiles() -> void:
	var remove: Array[int] = []
	for projectile: Dictionary in projectiles:
		projectile["position"] += projectile["velocity"] * DT
		projectile["life"] -= 1
		if projectile["life"] <= 0 or absf(projectile["position"].x) > ARENA_HALF_WIDTH + 2.0:
			remove.append(projectile["id"])
	for id: int in remove:
		_remove_projectile(id)


func _remove_projectile(id: int) -> void:
	for index: int in range(projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = projectiles[index]
		if projectile["id"] == id:
			var event: Dictionary = _metadata(projectile["owner"], projectile["move"])
			event.merge({"type": "projectile_removed", "projectile_id": id, "fighter": projectile["owner"], "position": projectile["position"]})
			events.append(event)
			projectiles.remove_at(index)
			return


func _guarding(contact: Dictionary) -> bool:
	var attacker: Dictionary = fighters[contact["attacker"]]
	var defender: Dictionary = fighters[contact["defender"]]
	var move: MoveData = contact["move"]
	var from_front: bool = (attacker["position"].x - defender["position"].x) * defender["facing"] >= 0.0
	if int(contact.get("projectile_id", -1)) >= 0:
		from_front = int(contact["facing"]) != int(defender["facing"])
	return move.behavior != "grab" and defender["_block"] and defender["move"] == null and defender["state"] not in ["hitstun", "guard_break"] and defender["hp"] > 0.0 and from_front


func _countering(contact: Dictionary) -> bool:
	var defender: Dictionary = fighters[contact["defender"]]
	var defense: MoveData = defender["move"]
	var incoming: MoveData = contact["move"]
	return not contact.get("counter_resolved", false) and incoming.behavior != "grab" and defense != null and defense.behavior == "counter" and defense.phase_at(defender["move_frame"]) == "active" and not defender["_counter_used"]


func _armored(contact: Dictionary) -> bool:
	var defender: Dictionary = fighters[contact["defender"]]
	var defense: MoveData = defender["move"]
	var incoming: MoveData = contact["move"]
	return incoming.behavior != "grab" and defense != null and defender["_armor_remaining"] > 0 and defense.armor_start >= 0 and defender["move_frame"] >= defense.armor_start and defender["move_frame"] <= defense.armor_end


func _resolve_contacts(contacts: Array[Dictionary]) -> void:
	# A simultaneous normal strike interrupts super confirmation. Two clean supers
	# choose the lower fighter index deterministically; only one director can own time.
	var interrupted_supers: Array[int] = []
	for contact: Dictionary in contacts:
		var move: MoveData = contact["move"]
		if move.id != "finisher" or _guarding(contact) or _countering(contact) or _armored(contact):
			continue
		var interrupted: bool = false
		for other: Dictionary in contacts:
			var incoming: MoveData = other["move"]
			if other["defender"] == contact["attacker"] and incoming.id != "finisher" and not _countering(other) and not _armored(other):
				interrupted = true
				break
		if interrupted:
			interrupted_supers.append(contact["attacker"])
		else:
			_request_cinematic(contact)
			return
	for contact: Dictionary in contacts:
		var move: MoveData = contact["move"]
		if move.id == "finisher" and interrupted_supers.has(contact["attacker"]):
			continue
		_apply_contact(contact)


func _mark_contact(contact: Dictionary) -> void:
	if int(contact.get("projectile_id", -1)) >= 0:
		_remove_projectile(contact["projectile_id"])
		return
	var attacker: Dictionary = fighters[contact["attacker"]]
	attacker["_hit"] = true
	attacker["_hit_count"] += 1
	attacker["_last_hit_frame"] = attacker["move_frame"]


func _request_cinematic(contact: Dictionary) -> void:
	var attacker_index: int = contact["attacker"]
	var defender_index: int = contact["defender"]
	var move: MoveData = contact["move"]
	_mark_contact(contact)
	var attacker: Dictionary = fighters[attacker_index]
	var damage: float = move.damage * (1.25 if attacker["power_frames"] > 0 else 1.0) * maxf(0.35, 1.0 - 0.1 * int(attacker["combo"]))
	pending_cinematic = _metadata(attacker_index, move)
	pending_cinematic.merge({"type": "cinematic_requested", "attacker": attacker_index, "defender": defender_index, "move": move, "move_id": move.id, "damage": damage, "cinematic_frames": move.cinematic_frames, "attacker_position": attacker["position"], "defender_position": fighters[defender_index]["position"], "defender_id": fighters[defender_index]["fighter_id"], "contact": contact.duplicate()})
	attacker["state"] = "cinematic"
	fighters[defender_index]["state"] = "cinematic"
	events.append(pending_cinematic.duplicate())


func resolve_cinematic() -> bool:
	if pending_cinematic.is_empty():
		return false
	events.clear()
	var pending: Dictionary = pending_cinematic
	pending_cinematic = {}
	var contact: Dictionary = pending["contact"]
	contact["cinematic_resolve"] = true
	contact["damage_override"] = pending["damage"]
	var attacker: Dictionary = fighters[contact["attacker"]]
	var move: MoveData = contact["move"]
	attacker["move"] = move
	attacker["move_frame"] = move.startup + move.active
	attacker["state"] = "recovery"
	attacker["_fresh"] = false
	attacker["_hit_count"] = move.max_hits
	attacker["_buffer_action"] = ""
	attacker["_buffer_frames"] = 0
	fighters[contact["defender"]]["_buffer_action"] = ""
	fighters[contact["defender"]]["_buffer_frames"] = 0
	_apply_contact(contact)
	events.append({"type": "cinematic_resolved", "attacker": contact["attacker"], "defender": contact["defender"], "move": move.id, "fighter_id": attacker["fighter_id"]})
	return true


func _apply_contact(contact: Dictionary) -> void:
	var attacker_index: int = contact["attacker"]
	var defender_index: int = contact["defender"]
	var attacker: Dictionary = fighters[attacker_index]
	var defender: Dictionary = fighters[defender_index]
	var move: MoveData = contact["move"]
	var cinematic: bool = bool(contact.get("cinematic_resolve", false))
	if not cinematic:
		_mark_contact(contact)
	if not cinematic and _countering(contact):
		defender["_counter_used"] = true
		var counter: MoveData = defender["move"]
		var counter_event: Dictionary = _metadata(defender_index, counter)
		counter_event.merge({"type": "counter", "attacker": defender_index, "defender": attacker_index, "move": counter.id})
		events.append(counter_event)
		_apply_contact({"attacker": defender_index, "defender": attacker_index, "move": counter, "facing": defender["facing"], "projectile_id": -1, "counter_resolved": true})
		return
	var facing: int = contact["facing"]
	var damage: float = move.damage * (1.25 if attacker["power_frames"] > 0 else 1.0)
	var guarding: bool = not cinematic and _guarding(contact)
	var armor: bool = not cinematic and _armored(contact)
	var dealt: float = 0.0
	var type: String = "hit"
	if guarding:
		var guard_drain: float = damage * (1.8 if move.id == "finisher" else 2.4) + 8.0
		defender["guard"] = maxf(0.0, defender["guard"] - guard_drain)
		if defender["guard"] <= 0.0:
			dealt = damage
			defender["stun"] = maxi(30, move.hitstun)
			defender["state"] = "guard_break"
			type = "guard_break"
			attacker["combo"] += 1
		else:
			dealt = damage * 0.1
			defender["stun"] = move.blockstun
			defender["state"] = "blockstun"
			type = "blocked"
	elif armor:
		dealt = damage * 0.5
		defender["_armor_remaining"] -= 1
		type = "armored"
	else:
		attacker["combo"] += 1
		dealt = float(contact.get("damage_override", damage * maxf(0.35, 1.0 - 0.1 * (attacker["combo"] - 1))))
		defender["stun"] = move.hitstun
		defender["state"] = "hitstun"
		if move.slow_frames > 0:
			defender["slow_frames"] = maxi(defender["slow_frames"], move.slow_frames)
			defender["slow_multiplier"] = minf(defender["slow_multiplier"], move.slow_multiplier)
	if type in ["hit", "guard_break"] and attacker["move"] == move:
		attacker["_confirmed"] = true
	var event: Dictionary = _metadata(attacker_index, move)
	event.merge({"type": type, "attacker": attacker_index, "defender": defender_index, "move": move.id, "move_data": move, "damage": dealt, "combo": attacker["combo"], "cinematic": cinematic, "behavior": move.behavior, "defender_id": defender["fighter_id"]})
	events.append(event)
	defender["hp"] = maxf(0.0, defender["hp"] - dealt)
	if not armor:
		defender["move"] = null
		defender["move_frame"] = -1
		defender["_fresh"] = false
		var velocity: Vector2 = defender["velocity"]
		velocity.x = facing * move.knockback * (0.5 if guarding else 1.0)
		if not guarding:
			var launch: float = move.launch_velocity if move.launch_velocity > 0.0 else (5.8 if move.id == "launcher" else 0.0)
			if launch > 0.0:
				velocity.y = launch
		defender["velocity"] = velocity
	if move.id != "finisher":
		attacker["energy"] = minf(100.0, attacker["energy"] + (6.0 if guarding else 13.0 + dealt * 0.6))
	defender["energy"] = minf(100.0, defender["energy"] + (8.0 if guarding else 8.0 + dealt * 0.5))
	freeze_frames = maxi(freeze_frames, move.hitstop)
	if defender["hp"] <= 0.0:
		defender["state"] = "down"
