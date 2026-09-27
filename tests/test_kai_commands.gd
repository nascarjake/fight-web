extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: "+message)
func _run() -> void:
	var sim := FightSimulation.new()
	sim.set_fighter_moves(0,FighterCatalog.moves("kai"))
	sim.set_fighter_moves(1,FighterCatalog.moves("neon"))
	for facing in [-1,1]:
		sim.fighters[0].facing = facing
		for row in [["jab",0,true,"body_hook"],["jab",1,false,"knee"],["cross",1,false,"spin_kick"],["cross",-1,false,"side_kick"],["jab",0,false,"jab"],["cross",0,false,"cross"]]:
			var input := {"action":row[0],"axis":row[1]*facing,"crouch":row[2]}
			check(sim.resolve_command(0,input)==row[3], "directional variant resolves in either facing: "+str(row[3]))
			check(sim.resolve_command(1,input)==row[0], "variants are scoped to the owning moveset")
	sim.fighters[0].position.y = .3
	check(sim.resolve_command(0,{"action":"jab","crouch":true})=="jab","ground command does not steal airborne input")
	sim.reset()
	sim.fighters[0].facing = 1
	sim.freeze_frames = 2
	sim.step([{"action":"cross","axis":-1},{}])
	check(sim.fighters[0]._buffer_action=="side_kick","command resolves before entering hitstop buffer")
	sim.step([{"axis":1},{}])
	sim.step([{},{}])
	check(sim.fighters[0].move != null and sim.fighters[0].move.id=="side_kick","releasing/reversing direction cannot change the buffered move")
	# Prove the advertised close confirm route lands through actual collision and cancels.
	sim.reset()
	sim.fighters[0].position = Vector2(-.32,0)
	sim.fighters[1].position = Vector2(.32,0)
	var route := ["jab","body_hook","knee","launcher"]
	var next := 0
	var contacts: Array[String] = []
	for tick in 180:
		if next < route.size():
			if sim.request_move(0,route[next]): next += 1
		sim.step([{},{}])
		for event in sim.events:
			if event.type == "hit" and event.attacker == 0:
				contacts.append(event.move)
		if next==route.size() and sim.fighters[0].move==null: break
	check(contacts==route,"Jab → Coalbreaker → Furnace Knee → Rising Phoenix is a real confirm route: "+str(contacts))
	for move in FighterCatalog.moves("kai"):
		check(move.validation_errors().is_empty(),move.id+" validates")
	print("Kai command checks: ",failures," failures")
	quit(failures)
