extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_test_intro_and_local()
	_test_rounds_and_rematch()
	_test_ties_and_timeout()
	_test_arcade()
	_test_cpu_progress()
	_test_determinism()
	_test_power_and_finisher()
	print("Match checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _enter_fight(session: MatchSession) -> void:
	for frame: int in range(MatchSession.INTRO_FRAMES):
		session.step([{}, {}])


func _finish_pause(session: MatchSession) -> void:
	for frame: int in range(MatchSession.ROUND_END_FRAMES):
		session.step([{}, {}])


func _award_round(session: MatchSession, player: int) -> void:
	_enter_fight(session)
	session.simulation.fighters[1 - player]["hp"] = 0.0
	session.step([{}, {}])
	_finish_pause(session)


func _test_intro_and_local() -> void:
	var session: MatchSession = MatchSession.new()
	session.configure("local", 2)
	var original: Vector2 = session.simulation.fighters[1]["position"]
	for frame: int in range(179):
		session.step([{"action": "jab"}, {"axis": -1.0}])
	_expect(session.phase == "intro" and session.phase_frames == 1, "three-second intro counts down exact frames")
	_expect(session.simulation.tick == 0 and session.simulation.fighters[1]["position"] == original, "intro does not move combat or consume input")
	session.step([{}, {}])
	_expect(session.phase == "fight" and session.events.size() == 1 and session.events[0]["type"] == "round_started", "intro emits one round-start event")
	_expect(session.remaining_frames == 5940 and session.simulation.fighters[0]["energy"] == 0.0, "match begins with 99 seconds and zero earned meter")
	session.step([{}, {"axis": -1.0, "action": "jab"}])
	_expect(session.simulation.fighters[1]["move"].id == "jab", "local mode passes second-player action through")
	_expect(session.remaining_frames == 5939, "fight timer advances at 60 Hz")
	session.simulation.freeze_frames = 3
	var frames: int = session.remaining_frames
	for frame: int in range(3):
		session.step([{}, {}])
	_expect(session.remaining_frames == frames, "round clock freezes with hitstop")
	session.configure("invalid", 9)
	_expect(session.mode == "cpu" and session.difficulty == 3 and session.phase == "intro", "configuration normalizes mode and difficulty")


func _test_rounds_and_rematch() -> void:
	var session: MatchSession = MatchSession.new()
	session.configure("local")
	_enter_fight(session)
	session.simulation.fighters[1]["hp"] = 0.0
	session.step([{}, {}])
	_expect(session.phase == "round_end" and session.wins == [1, 0] and session.winner == 0, "knockout awards a round once")
	_expect(session.round_number == 1 and session.events.back()["type"] == "round_over", "round-end preserves current number and emits event")
	for frame: int in range(10):
		session.step([{}, {}])
	_expect(session.wins == [1, 0] and session.events.is_empty(), "KO cannot repeatedly award wins during pause")
	for frame: int in range(140):
		session.step([{}, {}])
	_expect(session.phase == "intro" and session.round_number == 2 and session.simulation.fighters[1]["hp"] == 100.0, "next round resets combat after pause")
	_award_round(session, 0)
	_expect(session.phase == "match_end" and session.wins == [2, 0] and session.winner == 0, "first to two ends match")
	_expect(session.events.size() == 1 and session.events[0]["type"] == "match_over", "match-over emitted once")
	session.step([{"action": "jab"}, {}])
	_expect(session.phase == "match_end" and session.events.is_empty() and session.wins == [2, 0], "completed match is stable")
	session.rematch()
	_expect(session.phase == "intro" and session.wins == [0, 0] and session.round_number == 1 and session.winner == -1, "rematch resets match state")


func _test_ties_and_timeout() -> void:
	var session: MatchSession = MatchSession.new()
	session.configure("local")
	_enter_fight(session)
	session.remaining_frames = 1
	session.step([{}, {}])
	_expect(session.phase == "round_end" and session.winner == -1 and session.wins == [0, 0], "equal-health timeout awards nobody")
	_expect(session.events.back()["tie"] and session.events.back()["reason"] == "timeout", "tie records timeout reason")
	_finish_pause(session)
	_expect(session.phase == "intro" and session.round_number == 1, "tie replays same numbered round")
	_enter_fight(session)
	session.remaining_frames = 1
	session.simulation.fighters[0]["hp"] = 30.0
	session.simulation.fighters[1]["hp"] = 60.0
	session.step([{}, {}])
	_expect(session.winner == 1 and session.wins == [0, 1], "timeout awards higher health")
	_finish_pause(session)
	_enter_fight(session)
	session.simulation.fighters[0]["hp"] = 0.0
	session.simulation.fighters[1]["hp"] = 0.0
	session.step([{}, {}])
	_expect(session.winner == -1 and session.wins == [0, 1], "double KO is a tie")


func _test_arcade() -> void:
	var session: MatchSession = MatchSession.new()
	session.configure("arcade", 1)
	var arcade_tiers: Array[int] = [0, 0, 1, 1, 2, 2, 3, 3, 3]
	for bout: int in range(arcade_tiers.size()):
		session.arcade_index = bout
		_expect(session.active_cpu_difficulty() == arcade_tiers[bout], "arcade bout %d uses its intended rising CPU tier" % (bout + 1))
	session.arcade_index = 0
	session.next_arcade_match()
	_expect(session.arcade_index == 0, "arcade cannot skip unfinished rival")
	for rival: int in range(9):
		_expect(session.arcade_index == rival, "arcade rival index follows progression")
		_award_round(session, 0)
		_award_round(session, 0)
		if rival < 8:
			_expect(session.phase == "match_end" and session.winner == 0, "arcade wins await next-rival action")
			session.next_arcade_match()
			_expect(session.wins == [0, 0] and session.phase == "intro", "next rival begins a fresh match")
		else:
			_expect(session.phase == "arcade_complete" and session.events[0]["arcade_complete"], "ninth victory completes arcade")
	session.next_arcade_match()
	_expect(session.arcade_index == 8 and session.phase == "arcade_complete", "arcade cannot overflow final rival")
	session.rematch()
	_expect(session.arcade_index == 8 and session.phase == "intro", "rematch retries current rival")
	session.start_match()
	_expect(session.arcade_index == 0 and session.wins == [0, 0], "start_match starts a new arcade run")
	_award_round(session, 1)
	_award_round(session, 1)
	session.next_arcade_match()
	_expect(session.arcade_index == 0 and session.winner == 1 and session.phase == "match_end", "arcade loss cannot advance")


func _test_cpu_progress() -> void:
	for level: int in range(4):
		var session: MatchSession = MatchSession.new()
		session.configure("cpu", level)
		var hits: int = 0
		var actions: Dictionary = {}
		for frame: int in range(12000):
			session.step([{}, {"axis": 1.0, "action": "finisher"}])
			if session.phase == "cinematic":
				session.resolve_cinematic()
			for event: Dictionary in session.events:
				if event["type"] == "hit" and event["attacker"] == 1:
					hits += 1
				if event["type"] == "move_started" and event["fighter"] == 1:
					actions[event["move"]] = true
			if session.phase == "match_end":
				break
		_expect(session.phase == "match_end" and session.winner == 1 and hits > 0, "CPU level %d approaches and completes a match" % level)
		_expect(actions.size() >= 2, "CPU level %d varies attacks" % level)


func _test_determinism() -> void:
	var first: MatchSession = MatchSession.new()
	var second: MatchSession = MatchSession.new()
	first.configure("cpu", 3)
	second.configure("cpu", 3)
	for frame: int in range(2000):
		var input: Array[Dictionary] = [{"axis": 1.0 if frame % 120 < 60 else -1.0, "block": frame % 80 < 20, "action": "low_kick" if frame % 29 == 0 else ""}, {}]
		first.step(input)
		second.step(input)
		if first.phase == "cinematic":
			first.resolve_cinematic()
			second.resolve_cinematic()
		if first.phase != second.phase or first.wins != second.wins or first.remaining_frames != second.remaining_frames or _event_values(first.events) != _event_values(second.events):
			_expect(false, "same input and seed reproduce match flow and events")
			return
		for index: int in range(2):
			for key: String in ["hp", "energy", "guard", "power_frames", "position", "move_frame", "state"]:
				if first.simulation.fighters[index][key] != second.simulation.fighters[index][key]:
					_expect(false, "CPU replay reproduces " + key)
					return
	_expect(true, "2000-tick CPU match replay is deterministic")


func _test_power_and_finisher() -> void:
	var sim: FightSimulation = FightSimulation.new()
	sim.fighters[0]["position"] = Vector2(-0.5, 0.0)
	sim.fighters[1]["position"] = Vector2(0.5, 0.0)
	sim.fighters[0]["energy"] = 50.0
	sim.step([{"power": true, "action": "jab"}, {}])
	_expect(sim.fighters[0]["power_frames"] == 360 and sim.fighters[0]["energy"] == 0.0, "power costs 50 and lasts six seconds")
	_expect(sim.events[0]["type"] == "power_started", "power activation emits presentation metadata")
	for frame: int in range(6):
		sim.step([{}, {}])
	_expect(sim.fighters[1]["hp"] == 91.25, "power increases strike damage by 25 percent")
	var power: int = sim.fighters[0]["power_frames"]
	for frame: int in range(sim.freeze_frames):
		sim.step([{}, {}])
	_expect(sim.fighters[0]["power_frames"] == power, "power timer pauses during hitstop")
	sim.fighters[0]["power_frames"] = 1
	sim.step([{}, {}])
	_expect(sim.fighters[0]["power_frames"] == 0 and sim.events[0]["type"] == "power_ended", "power expires deterministically")
	sim.reset()
	sim.fighters[0]["energy"] = 49.0
	sim.step([{"power": true}, {}])
	_expect(sim.fighters[0]["power_frames"] == 0, "insufficient meter rejects power")
	sim.reset()
	sim.fighters[0]["position"] = Vector2(-0.5, 0.0)
	sim.fighters[1]["position"] = Vector2(0.5, 0.0)
	sim.fighters[0]["energy"] = 99.0
	_expect(not sim.request_move(0, "finisher"), "finisher requires full meter")
	sim.fighters[0]["energy"] = 100.0
	_expect(sim.request_move(0, "finisher") and sim.fighters[0]["energy"] == 0.0, "finisher consumes full meter")
	for frame: int in range(27):
		sim.step([{}, {}])
	_expect(sim.fighters[1]["hp"] == 100.0 and not sim.pending_cinematic.is_empty(), "finisher confirms before cinematic damage")
	sim.resolve_cinematic()
	_expect(sim.fighters[1]["hp"] == 60.0 and sim.fighters[0]["move"].animation_name == "finisher", "finisher commits one authored-clip strike after resolution")
	sim.reset()
	sim.fighters[0]["position"] = Vector2(-0.5, 0.0)
	sim.fighters[1]["position"] = Vector2(0.5, 0.0)
	sim.request_move(0, "finisher")
	for frame: int in range(27):
		sim.step([{}, {"block": true}])
	_expect(sim.fighters[1]["guard"] == 20.0 and sim.fighters[1]["state"] == "blockstun" and sim.fighters[1]["hp"] == 96.0, "fresh guard can block a telegraphed finisher")
	sim.reset()
	sim.fighters[0]["position"] = Vector2(-0.5, 0.0)
	sim.fighters[1]["position"] = Vector2(0.5, 0.0)
	sim.fighters[1]["guard"] = 75.0
	sim.request_move(0, "finisher")
	for frame: int in range(27):
		sim.step([{}, {"block": true}])
	_expect(sim.fighters[1]["guard"] == 0.0 and sim.fighters[1]["state"] == "guard_break", "finisher can break fatigued guard")


func _event_values(value: Variant) -> Variant:
	if value is MoveData:
		return {"id": value.id, "animation_name": value.animation_name}
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[key] = _event_values(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_event_values(item))
		return result
	return value
