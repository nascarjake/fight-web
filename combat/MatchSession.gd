class_name MatchSession
extends RefCounted
## Match flow and deterministic CPU policy. Call step once per 60 Hz physics tick.
## phase_frames counts down during intro and round_end; fight uses remaining_frames.

const ROUND_FRAMES: int = 99 * 60
const INTRO_FRAMES: int = 180
const ROUND_END_FRAMES: int = 150
const ARCADE_MATCHES: int = 9

var simulation: FightSimulation = FightSimulation.new()
var mode: String = "cpu"
var difficulty: int = 1
var phase: String = "intro"
var phase_frames: int = INTRO_FRAMES
var round_number: int = 1
var wins: Array[int] = [0, 0]
var remaining_frames: int = ROUND_FRAMES
var winner: int = -1
var arcade_index: int = 0
var events: Array[Dictionary] = []
var fighter_ids: Array[String] = ["kai", "neon"]
var arcade_opponents: Array[String] = []
var cpu_policy = preload("res://combat/FootsiesAI.gd").new()


func _init() -> void:
	configure("cpu", 1)


func configure(new_mode: String, new_difficulty: int = 1, p1id: String = "kai", p2id: String = "neon") -> void:
	mode = new_mode if new_mode in ["cpu", "local", "arcade"] else "cpu"
	difficulty = clampi(new_difficulty, 0, 3)
	set_fighters(p1id, p2id)
	start_match()


func set_fighters(p1id: String, p2id: String) -> void:
	fighter_ids = [str(FighterCatalog.get_fighter(p1id)["id"]), str(FighterCatalog.get_fighter(p2id)["id"])]
	arcade_opponents.clear()
	for profile: Dictionary in FighterCatalog.all():
		if profile["id"] != fighter_ids[0]:
			arcade_opponents.append(profile["id"])
	_apply_fighters()


func _apply_fighters() -> void:
	for index: int in range(2):
		simulation.set_fighter_profile(index, FighterCatalog.get_fighter(fighter_ids[index]))
		simulation.set_fighter_moves(index, FighterCatalog.moves(fighter_ids[index]))


func start_match() -> void:
	arcade_index = 0
	if mode == "arcade":
		fighter_ids[1] = arcade_opponents[arcade_index]
	_begin_match()


func rematch() -> void:
	_begin_match()


func next_arcade_match() -> void:
	if mode != "arcade" or phase != "match_end" or winner != 0 or arcade_index >= ARCADE_MATCHES - 1:
		return
	arcade_index += 1
	fighter_ids[1] = arcade_opponents[arcade_index]
	_begin_match()


func step(inputs: Array[Dictionary]) -> void:
	events.clear()
	if phase in ["match_end", "arcade_complete", "cinematic"]:
		return
	if phase == "intro":
		phase_frames -= 1
		if phase_frames <= 0:
			phase = "fight"
			phase_frames = 0
			events.append({"type": "round_started", "round": round_number, "arcade_index": arcade_index})
		return
	if phase == "round_end":
		phase_frames -= 1
		if phase_frames <= 0:
			phase_frames = 0
			if wins[0] >= 2 or wins[1] >= 2:
				winner = 0 if wins[0] >= 2 else 1
				phase = "arcade_complete" if mode == "arcade" and winner == 0 and arcade_index == ARCADE_MATCHES - 1 else "match_end"
				events.append({"type": "match_over", "winner": winner, "wins": wins.duplicate(), "arcade_index": arcade_index, "arcade_complete": phase == "arcade_complete"})
			else:
				if winner >= 0:
					round_number += 1
				_begin_round(true)
		return
	if phase != "fight":
		return
	var player: Dictionary = inputs[0].duplicate() if not inputs.is_empty() else {}
	var opponent: Dictionary = inputs[1].duplicate() if inputs.size() > 1 else {}
	if mode != "local":
		opponent = _cpu_input()
	var frozen: bool = simulation.freeze_frames > 0
	simulation.step([player, opponent])
	events.append_array(simulation.events)
	if not simulation.pending_cinematic.is_empty():
		phase = "cinematic"
		phase_frames = simulation.pending_cinematic["cinematic_frames"]
		return
	if not frozen:
		remaining_frames = maxi(0, remaining_frames - 1)
	_check_round_end()


func resolve_cinematic() -> bool:
	if phase != "cinematic" or simulation.pending_cinematic.is_empty():
		return false
	if not simulation.resolve_cinematic():
		return false
	events.clear()
	events.append_array(simulation.events)
	phase = "fight"
	phase_frames = 0
	_check_round_end()
	return true


func _check_round_end() -> void:
	var first_hp: float = simulation.fighters[0]["hp"]
	var second_hp: float = simulation.fighters[1]["hp"]
	if first_hp <= 0.0 or second_hp <= 0.0 or remaining_frames == 0:
		var round_winner: int = -1
		if first_hp > second_hp:
			round_winner = 0
		elif second_hp > first_hp:
			round_winner = 1
		_end_round(round_winner, "timeout" if remaining_frames == 0 else "knockout")


func _begin_match() -> void:
	wins = [0, 0]
	round_number = 1
	winner = -1
	events.clear()
	_begin_round()


func _begin_round(preserve_meter: bool = false) -> void:
	var previous_meter: Array[float] = [0.0, 0.0]
	if preserve_meter:
		for index: int in range(2):
			previous_meter[index] = simulation.fighters[index]["energy"]
	simulation.reset()
	_apply_fighters()
	for index: int in range(2):
		simulation.fighters[index]["energy"] = previous_meter[index]
	phase = "intro"
	phase_frames = INTRO_FRAMES
	remaining_frames = ROUND_FRAMES
	winner = -1
	cpu_policy.reset(9173 + arcade_index * 7907 + difficulty * 109 + round_number * 31)


func _end_round(round_winner: int, reason: String) -> void:
	winner = round_winner
	if round_winner >= 0:
		wins[round_winner] += 1
	phase = "round_end"
	phase_frames = ROUND_END_FRAMES
	events.append({"type": "round_over", "winner": round_winner, "round": round_number, "wins": wins.duplicate(), "reason": reason, "tie": round_winner < 0})
	# A tie replays the same numbered round and cannot award a win.


func _cpu_input() -> Dictionary:
	return cpu_policy.input_for(simulation, 1, active_cpu_difficulty())


func active_cpu_difficulty() -> int:
	if mode == "arcade":
		# Every circuit begins at Rookie regardless of the Versus setting, then
		# deliberately rises through the full 0–3 skill range by the final bouts.
		return clampi(arcade_index / 2, 0, 3)
	return difficulty
