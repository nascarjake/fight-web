class_name FighterCatalog
extends RefCounted
## Each fighter owns new move resources; stable input IDs do not share mutable data.


static func _collision(move: MoveData, center: Vector2, size: Vector2, entry: Vector2, exit_delta: Vector2, exposure: int) -> void:
	move.hitbox_offset = center
	move.hitbox_size = size
	move.animated_hitbox = true
	move.hitbox_entry_delta = entry
	move.hitbox_exit_delta = exit_delta
	move.hitbox_edge_scale = Vector2(0.82, 0.9)
	move.exposed_limb_size = Vector2(size.x * 0.72, minf(size.y, 0.32))
	move.exposed_recovery_frames = exposure


static func all() -> Array[Dictionary]:
	return [
		_profile("kai", "KAI", "C", "ff673d", "Rushdown", "Advancing flame strikes turn close pressure into confirmed combinations.", "SOLAR REQUIEM", 3.9, 1.0),
		_profile("neon", "NEON", "K", "e55cff", "Sonic zoner", "Fast sonic projectiles control the lane; backsteps protect long-range pressure.", "FINAL FREQUENCY", 3.2, 1.12),
		_profile("yuki", "YUKI", "M", "78dcff", "Frost control", "Ice waves slow enemy footwork and buy space for deliberate follow-ups.", "ABSOLUTE ZERO", 3.1, 1.2),
		_profile("ivy", "IVY", "N", "89d85d", "Long reach", "Extended thorn lashes and creeping ground snares punish careless approaches.", "EDEN'S END", 3.35, 1.08),
		_profile("rook", "ROOK", "R", "ed9153", "Grappler", "Short command grabs defeat grounded guard; closing the distance is the challenge.", "IRON SENTENCE", 2.85, 0.8),
		_profile("atlas", "ATLAS", "T", "dbb875", "Armored heavy", "Slow armored blows and a seismic ground wave trade speed for impact.", "WORLD BREAKER", 2.55, 0.72),
		_profile("zero", "ZERO", "V", "78ffd9", "Counter specialist", "Precise pokes and an active counter stance punish predictable strikes.", "CHECKMATE PROTOCOL", 3.65, 0.92),
		_profile("vex", "VEX", "X", "a384ff", "Void mobility", "Invulnerable cross-through movement and lunging strikes attack from new angles.", "EVENT HORIZON", 4.25, 0.86),
		_profile("sora", "SORA", "Y", "d1f4ff", "Aerial juggler", "High jumps, rising wind strikes, and aerial follow-ups extend juggle routes.", "HEAVEN'S FALL", 3.8, 1.18),
		_profile("raijin", "RAIJIN", "Z", "f5ed55", "Lightning rush", "Fast entries and repeated lightning hits reward sustained close-range pressure.", "THUNDER GOD", 4.1, 1.04),
	]


static func get_fighter(id: String) -> Dictionary:
	for fighter: Dictionary in all():
		if fighter["id"] == id:
			return fighter
	return all()[0]


static func _profile(id: String, label: String, code: String, tint: String, archetype: String, description: String, super_name: String, speed: float, pitch: float) -> Dictionary:
	return {"id": id, "name": label, "model_path": "res://assets/characters/AvatarSample_" + code + ".vrm", "portrait_path": "res://assets/ui/roster/" + id + ".png", "style": id, "color": Color(tint), "description": description, "archetype": archetype, "super_name": super_name, "walk_speed": speed, "voice_pitch": pitch, "jump_speed": 9.0 if id == "sora" else 7.5, "gravity": 19.0 if id == "sora" else 22.0}


static func moves(id: String) -> Array[MoveData]:
	var profile: Dictionary = get_fighter(id)
	id = profile["id"]
	var result: Array[MoveData] = MoveCatalog.defaults()
	var jab: MoveData = result[0]
	var cross: MoveData = result[1]
	var low: MoveData = result[2]
	var launcher: MoveData = result[3]
	var dodge: MoveData = result[4]
	var burst: MoveData = result[5]
	var finisher: MoveData = result[6]
	for move: MoveData in result:
		move.animation_name = id + "_" + move.id
		move.effect = id
		move.energy_cost = 100.0 if move.id == "finisher" else 0.0
		if not move.cancel_into.is_empty():
			move.cancel_into.append("finisher")
	launcher.launch_velocity = 5.8
	_apply_common_guidance(result)
	# Every super has vulnerable, guardable startup. Its clean contact requests the
	# director; damage remains pending until resolve_cinematic is called exactly once.
	finisher.display_name = profile["super_name"]
	finisher.invuln_start = -1
	finisher.invuln_end = -1
	finisher.cinematic_frames = 210
	match id:
		"kai":
			_timing(finisher, 22, 5, 36, 40)
			finisher.hitbox_offset = Vector2(.62, 1.1)
			finisher.hitbox_size = Vector2(.7, .8)
			_names(result, ["Ember Jab", "Flare Cross", "Cinder Sweep", "Rising Phoenix", "Heat Step", "Blazing Drive"])
			_guide(jab, "Normal", "light", "LIGHT", "Fast close-range check.", "Confirm a clean Ember Jab into Flare Cross or Cinder Sweep.", ["Fast", "Chain Starter"], "kai_ember_jab", "kai_light", "left_hand", .05)
			_guide(cross, "Heavy", "heavy", "HEAVY", "Advancing flame hook that carries Kai into pressure.", "Use it after a jab confirm or as a whiff punish; do not throw it out at maximum range.", ["Advances", "Whiff Punish"], "kai_flare_cross", "kai_heavy", "right_hand", .16)
			_guide(low, "Low", "low", "LOW", "A grounded sweep that opens crouching opponents.", "Mix this after close pressure, then reset to Heat Step or cash out with Rising Phoenix.", ["Low", "Chain"], "kai_cinder_sweep", "kai_low", "right_foot", .12)
			_guide(launcher, "Special I", "special_1", "SPECIAL I", "Vertical flame strike that begins an air route.", "Use after a grounded confirm. It is powerful, but unsafe when blocked at point blank.", ["Launcher", "Anti-Air"], "kai_rising_phoenix", "kai_launcher", "right_hand", .22)
			_guide(dodge, "Mobility", "dash", "DODGE", "Quick Heat Step that changes spacing.", "Slip past a predictable button, then punish with Flare Cross.", ["Mobility", "Spacing"], "kai_heat_step", "kai_dodge", "body", .03)
			_guide(burst, "Special II", "special_2", "SPECIAL II", "A committed flame rush for ending confirms.", "Reserve it for a hit confirm or punish. Its recovery is the risk that keeps Kai honest.", ["Advancing", "Combo Ender"], "kai_blazing_drive", "kai_special", "right_hand", .28)
			_timing(jab, 5, 3, 11, 7)
			_timing(cross, 9, 4, 18, 13)
			_lunge(cross, 3.2, 4, 12)
			_timing(burst, 13, 7, 25, 18)
			_lunge(burst, 5.4, 5, 19)
			burst.invuln_start = -1
			burst.invuln_end = -1
			_collision(jab, Vector2(0.58, 1.35), Vector2(0.48, 0.32), Vector2(-0.16, -0.03), Vector2(-0.12, 0), 4)
			_collision(cross, Vector2(0.72, 1.28), Vector2(0.58, 0.4), Vector2(-0.22, -0.1), Vector2(-0.2, 0.06), 9)
			_collision(low, Vector2(0.77, 0.34), Vector2(0.6, 0.32), Vector2(-0.3, 0.08), Vector2(-0.28, 0.06), 8)
			_collision(launcher, Vector2(0.48, 1.42), Vector2(0.5, 1.08), Vector2(-0.1, -0.3), Vector2(-0.06, 0.26), 11)
			_collision(burst, Vector2(0.68, 1.0), Vector2(0.72, 0.65), Vector2(-0.18, -0.06), Vector2(-0.18, 0), 12)
			_lunge(cross, 2.4, 5, 11)
			_lunge(burst, 4.6, 6, 16)
			low.coaching_note = "Sweep at the edge of jab range, then retreat. A missed sweep leaves the leg exposed to a punish."
		"neon":
			_names(result, ["Pulse Tap", "Bass Hammer", "Beat Sweep", "Feedback Rise", "Reverb Step", "Sonic Lance"])
			_guide(jab, "Normal", "light", "LIGHT", "Fast sonic palm that checks approaches.", "Use Pulse Tap to take your turn, then backstep or place Sonic Lance at a safe range.", ["Fast", "Pressure Reset"], "neon_pulse_tap", "neon_light", "left_hand", .05)
			_guide(cross, "Heavy", "heavy", "HEAVY", "Long-range bass strike that controls the outer edge of footsies.", "Stand just outside the opponent's light range and punish their whiff with Bass Hammer.", ["Long Range", "Whiff Punish"], "neon_bass_hammer", "neon_heavy", "right_hand", .14)
			_guide(low, "Low", "low", "LOW", "Low waveform sweep that creates room.", "Use Beat Sweep when someone walks through your projectile spacing.", ["Low", "Space Control"], "neon_beat_sweep", "neon_low", "right_foot", .10)
			_guide(launcher, "Special I", "special_1", "SPECIAL I", "Two-hit rising feedback that converts a close punish.", "Confirm the first hit before committing to a follow-up; use it as Neon’s close anti-air.", ["Two Hit", "Launcher", "Anti-Air"], "neon_feedback_rise", "neon_launcher", "both_hands", .20)
			_guide(dodge, "Mobility", "dash", "DODGE", "A retreating Reverb Step that restores projectile range.", "Backstep after a blocked string, then make the opponent navigate Sonic Lance again.", ["Backstep", "Spacing"], "neon_reverb_step", "neon_dodge", "body", .03)
			_guide(burst, "Special II", "special_2", "SPECIAL II", "A quick Sonic Lance that claims a horizontal lane.", "Use it after a knockback or to force a guarded approach. Protect its startup with Bass Hammer.", ["Projectile", "Zoning"], "neon_sonic_lance", "neon_projectile", "both_hands", .18)
			_timing(jab, 7, 3, 12, 6)
			_timing(cross, 12, 4, 21, 12)
			cross.hitbox_offset.x = 1.0
			_timing(burst, 17, 3, 29, 14)
			_projectile(burst, 8.5, 75, Vector2(0.65, 0.65), Vector2(0.8, 1.0))
			_timing(launcher, 12, 7, 23, 7)
			launcher.max_hits = 2
			launcher.rehit_frames = 4
			launcher.launch_velocity = 4.5
			_lunge(dodge, -4.6, 3, 12)
			finisher.hitbox_size.x = 2.4
			_collision(jab, Vector2(0.62, 1.32), Vector2(0.5, 0.34), Vector2(-0.14, 0), Vector2(-0.18, 0), 4)
			_collision(cross, Vector2(0.8, 1.2), Vector2(0.58, 0.42), Vector2(-0.23, 0.12), Vector2(-0.24, -0.1), 11)
			_collision(low, Vector2(0.83, 0.35), Vector2(0.7, 0.32), Vector2(-0.3, 0.07), Vector2(-0.2, 0), 9)
			_collision(launcher, Vector2(0.53, 1.22), Vector2(0.58, 1.1), Vector2(-0.12, -0.3), Vector2(-0.08, 0.26), 12)
		"yuki":
			_names(result, ["Snow Needle", "Glacier Palm", "Black Ice", "Crystal Rise", "Snowdrift", "Winter Wave"])
			_timing(jab, 7, 4, 13, 6)
			_timing(cross, 13, 5, 22, 14)
			cross.slow_frames = 50
			cross.slow_multiplier = 0.65
			low.slow_frames = 75
			low.slow_multiplier = 0.6
			_timing(burst, 21, 4, 32, 12)
			_projectile(burst, 4.3, 115, Vector2(1.0, 1.0), Vector2(0.7, 0.55))
			burst.slow_frames = 100
			burst.slow_multiplier = 0.55
			finisher.damage = 42
		"ivy":
			_names(result, ["Thorn Prick", "Briar Lash", "Root Cutter", "Vine Spiral", "Petal Slip", "Creeping Garden"])
			_timing(jab, 8, 3, 15, 7)
			jab.hitbox_offset.x = 1.0
			jab.hitbox_size.x = 1.0
			_timing(cross, 15, 5, 25, 15)
			cross.hitbox_offset.x = 1.55
			cross.hitbox_size = Vector2(1.6, 0.5)
			low.hitbox_offset.x = 1.35
			low.hitbox_size.x = 1.4
			_timing(burst, 19, 5, 34, 16)
			_projectile(burst, 3.2, 115, Vector2(0.9, 1.1), Vector2(0.75, 0.55))
			burst.slow_frames = 55
			burst.slow_multiplier = 0.75
			finisher.hitbox_offset.x = 1.45
			finisher.hitbox_size.x = 2.2
		"rook":
			_names(result, ["Knuckle Check", "Iron Hook", "Ankle Break", "Backbreaker", "Shoulder Slip", "Clinch Drive"])
			_timing(jab, 7, 3, 13, 9)
			jab.hitbox_offset.x = 0.58
			_timing(cross, 14, 5, 27, 18)
			_armor(cross, 1, 4, 18)
			_timing(launcher, 8, 3, 29, 20)
			_grab(launcher, 0.48, 0.75)
			launcher.launch_velocity = 6.5
			_timing(burst, 12, 3, 34, 25)
			_grab(burst, 0.5, 0.8)
			_lunge(burst, 2.2, 2, 13)
			jab.cancel_into = PackedStringArray(["cross", "low_kick", "finisher"])
			finisher.damage = 46
			finisher.hitbox_offset.x = 0.65
			finisher.hitbox_size.x = 1.15
		"atlas":
			_names(result, ["Stone Fist", "Fault Hammer", "Quake Sweep", "Mountain Rise", "Braced Step", "Seismic Break"])
			_timing(jab, 10, 4, 18, 11)
			_timing(cross, 20, 6, 32, 23)
			_armor(cross, 2, 5, 25)
			cross.knockback = 3.0
			cross.hitbox_size = Vector2(1.3, 0.9)
			_timing(launcher, 19, 6, 30, 23)
			launcher.launch_velocity = 7.2
			_timing(burst, 26, 5, 38, 22)
			_projectile(burst, 5.0, 100, Vector2(1.5, 0.7), Vector2(0.9, 0.35))
			burst.launch_velocity = 4.0
			_armor(burst, 1, 7, 27)
			finisher.damage = 48
			_timing(finisher, 32, 11, 49, 48)
		"zero":
			_names(result, ["Vector Jab", "Check Hook", "Circuit Sweep", "Axis Cutter", "Phase Read", "Perfect Reversal"])
			_timing(jab, 5, 2, 12, 6)
			_timing(cross, 10, 3, 18, 13)
			cross.hitbox_offset.x = 1.05
			_timing(burst, 2, 18, 25, 22)
			burst.behavior = "counter"
			burst.hitstun = 32
			burst.invuln_start = -1
			burst.invuln_end = -1
			finisher.damage = 41
		"vex":
			_names(result, ["Void Flick", "Rift Elbow", "Shadow Reap", "Abyss Rise", "Event Step", "Rift Ambush"])
			_timing(jab, 5, 3, 11, 6)
			_timing(cross, 11, 4, 20, 12)
			_lunge(cross, 5.0, 3, 13)
			_timing(dodge, 2, 0, 24, 0)
			dodge.invuln_start = 2
			dodge.invuln_end = 11
			dodge.cross_through = true
			_lunge(dodge, 11.0, 2, 11)
			_timing(burst, 11, 6, 27, 17)
			_lunge(burst, 8.5, 1, 16)
			burst.invuln_start = 3
			burst.invuln_end = 8
			finisher.damage = 38
		"sora":
			_names(result, ["Breeze Palm", "Cyclone Hook", "Gale Sweep", "Sky Ascent", "Cloud Step", "Tempest Rise"])
			_timing(jab, 6, 3, 11, 6)
			_timing(cross, 10, 5, 20, 11)
			cross.launch_velocity = 3.7
			_timing(launcher, 10, 8, 23, 13)
			launcher.launch_velocity = 8.5
			launcher.hitbox_size.y = 1.8
			_timing(burst, 12, 12, 27, 8)
			burst.max_hits = 3
			burst.rehit_frames = 4
			burst.hitbox_offset = Vector2(0.8, 1.3)
			burst.hitbox_size = Vector2(1.2, 2.4)
			burst.launch_velocity = 5.2
			_lunge(burst, 2.5, 5, 23)
			burst.invuln_start = -1
			burst.invuln_end = -1
			finisher.hitbox_size.y = 2.6
		"raijin":
			_names(result, ["Spark Jab", "Thunder Cross", "Arc Sweep", "Storm Rise", "Flash Step", "Chain Lightning"])
			_timing(jab, 4, 2, 10, 5)
			_timing(cross, 8, 7, 20, 7)
			cross.max_hits = 2
			cross.rehit_frames = 4
			_lunge(cross, 4.0, 1, 14)
			_timing(burst, 10, 13, 27, 7)
			burst.max_hits = 3
			burst.rehit_frames = 5
			burst.knockback = 0.6
			burst.hitbox_size.x = 1.4
			_lunge(burst, 4.7, 3, 22)
			burst.invuln_start = -1
			burst.invuln_end = -1
			finisher.damage = 39
	# Rebuild legal windows after character-specific timing edits.
	for move: MoveData in result:
		if not move.cancel_into.is_empty():
			move.cancel_start = move.startup
			move.cancel_end = mini(move.total_frames() - 1, move.startup + move.active + 8)
	_apply_style_presentation(id, result)
	_apply_impact_flashes(profile, result)
	if id == "kai":
		_add_kai_commands(result)
	return result


static func _add_kai_commands(result: Array[MoveData]) -> void:
	var rows := [
		["body_hook", "Coalbreaker", "jab", "down", "light", "DOWN + LIGHT", 8, 4, 16, 8.0, Vector2(.48, .88), Vector2(.48, .4), "right_hand", "Compact body hook for extending close confirms.", "Ember Jab → Coalbreaker → Furnace Knee → Rising Phoenix."],
		["knee", "Furnace Knee", "jab", "forward", "light", "FORWARD + LIGHT", 10, 5, 19, 11.0, Vector2(.4, 1.0), Vector2(.5, .55), "right_knee", "Close knee strike with long hitstun and little pushback.", "Use after Coalbreaker, then cancel into Rising Phoenix or Blazing Drive."],
		["spin_kick", "Helios Breaker", "cross", "forward", "heavy", "FORWARD + HEAVY", 18, 5, 25, 18.0, Vector2(.86, 1.12), Vector2(.64, .48), "right_foot", "Committed spinning kick with a hard knockback finish.", "Cash out after Flare Cross. A whiff leaves a long punish window."],
		["side_kick", "Searing Lance", "cross", "back", "heavy", "BACK + HEAVY", 13, 4, 22, 12.0, Vector2(.94, .98), Vector2(.58, .4), "right_foot", "Long side kick for checking approaches and punishing whiffs.", "Hold away and press Heavy. Keep its tip at the opponent's approach range."],
	]
	for row in rows:
		var move := MoveCatalog._move(row[0], row[1], row[6], row[7], row[8], row[9], 25, 12, 7, .35 if row[0] in ["body_hook", "knee"] else 2.0)
		move.animation_name = "kai_" + move.id
		move.command_base = row[2]
		move.command_modifier = row[3]
		move.effect = "kai"
		move.animation_blend_frames = 2
		_guide(move, "Normal" if row[4] == "light" else "Heavy", row[4], row[5], row[13], row[14], ["Directional", "Combo" if row[4] == "light" else "Range"], "kai_rising_phoenix" if move.id == "knee" else "kai_flare_cross", "kai_heavy", row[12], .16)
		_collision(move, row[10], row[11], Vector2(-.12, 0), Vector2(-.1, 0), 7)
		move.vfx_cue = "kai_" + move.id
		move.sfx_cue = "kai_" + move.id
		if move.id != "spin_kick":
			move.cancel_start = move.startup
			move.cancel_end = move.startup + move.active + 7
			move.cancel_into = PackedStringArray(["knee", "launcher", "burst", "finisher"] if move.id == "body_hook" else ["launcher", "burst", "finisher"])
		move.impact_flash = Color(1, .4, .12, .09)
		result.append(move)
	result[0].cancel_into.append_array(PackedStringArray(["body_hook", "knee"]))
	result[1].cancel_into.append("spin_kick")


static func _apply_common_guidance(moveset: Array[MoveData]) -> void:
	var labels := [
		["Normal", "light", "LIGHT", "A fast close-range check.", "Use it to interrupt pressure and begin a confirm.", ["Fast", "Chain Starter"], "light_strike", "light_strike", "right_hand", .05],
		["Heavy", "heavy", "HEAVY", "A slower, stronger strike with meaningful reach.", "Use it to punish a whiff or extend a confirmed string.", ["Heavy", "Whiff Punish"], "heavy_strike", "heavy_strike", "right_hand", .13],
		["Low", "low", "LOW", "A low-reaching grounded attack.", "Use it to check movement and change the rhythm of close pressure.", ["Low", "Chain"], "low_strike", "low_strike", "right_foot", .10],
		["Special I", "special_1", "SPECIAL I", "A rising special that changes the vertical fight.", "Use it as an anti-air or after a grounded confirm.", ["Launcher", "Anti-Air"], "launcher", "launcher", "right_hand", .20],
		["Mobility", "dash", "DODGE", "A fast movement tool for changing range.", "Use it to escape a predictable button, then take your turn back.", ["Mobility"], "dodge", "dodge", "body", .03],
		["Special II", "special_2", "SPECIAL II", "A fighter-defining special move.", "Use it when its tactical condition is met instead of spending it on every opening.", ["Signature"], "signature", "special", "right_hand", .22],
	]
	for index: int in range(mini(6, moveset.size())):
		var item: Array = labels[index]
		_guide(moveset[index], str(item[0]), str(item[1]), str(item[2]), str(item[3]), str(item[4]), item[5] as Array, str(item[6]), str(item[7]), str(item[8]), float(item[9]))
	if moveset.size() > 6:
		_guide(moveset[6], "Super", "super", "SUPER", "A full-meter cinematic finishing attack.", "It must connect cleanly. Blocked or missed supers still spend the meter.", ["100 Meter", "Cinematic"], "super", "super", "body", .45)


## Kai and Neon received bespoke presentation during the first combat pass. The
## remaining roster now owns the same readable contract: a named attack cue,
## a distinct sound cue, and a camera weight that matches its combat role.
static func _apply_style_presentation(id: String, moveset: Array[MoveData]) -> void:
	if id in ["kai", "neon"]:
		var established_super: MoveData = moveset[6]
		established_super.vfx_cue = id + "_super"
		established_super.sfx_cue = id + "_super"
		established_super.visual_anchor = "body"
		established_super.camera_impulse = .45
		return
	var data: Array = []
	match id:
		"yuki":
			data = [
				["Snow Needle", "A precise frost poke that checks an approach.", "Freeze their walk with Winter Wave, then take the space they give you.", "yuki_snow_needle", "yuki_frost_light", "right_hand", .05],
				["Glacier Palm", "A heavy palm that leaves the opponent slowed.", "Land it at the edge of their range, then press while their movement is reduced.", "yuki_glacier_palm", "yuki_frost_heavy", "right_hand", .14],
				["Black Ice", "A low slide that makes forward movement costly.", "Use it after a blocked poke to stop a walk-in, then reset your distance.", "yuki_black_ice", "yuki_frost_low", "right_foot", .12],
				["Crystal Rise", "A vertical ice pillar that starts an air route.", "Keep it for anti-air calls or a confirmed close hit.", "yuki_crystal_rise", "yuki_frost_rise", "both_hands", .20],
				["Snowdrift", "A drifting retreat that re-establishes frost range.", "Drift away after pressure rather than challenging every turn.", "yuki_snowdrift", "yuki_frost_dodge", "body", .03],
				["Winter Wave", "A slow-moving wave that freezes the lane.", "Throw it from range, then walk behind it to make the next choice difficult.", "yuki_winter_wave", "yuki_frost_special", "both_hands", .22],
			]
		"ivy":
			data = [
				["Thorn Prick", "A long thorn check that contests mid-range steps.", "Touch them with the tip, then use Briar Lash when they try to answer.", "ivy_thorn_prick", "ivy_thorn_light", "right_hand", .05],
				["Briar Lash", "A far-reaching lash for whiff punishes.", "Stand outside their light range; the long recovery means this must be deliberate.", "ivy_briar_lash", "ivy_thorn_heavy", "right_hand", .15],
				["Root Cutter", "A low vine sweep that controls the ground.", "Use it once they respect your high-reaching thorn attacks.", "ivy_root_cutter", "ivy_thorn_low", "right_foot", .11],
				["Vine Spiral", "A rising vine that catches airborne entries.", "Save it for a jump or a grounded confirm; it is your vertical answer.", "ivy_vine_spiral", "ivy_thorn_rise", "both_hands", .20],
				["Petal Slip", "A quick retreat that protects Ivy's preferred range.", "Slip back after a string and make them cross the garden again.", "ivy_petal_slip", "ivy_thorn_dodge", "body", .03],
				["Creeping Garden", "A crawling snare that slows a lane.", "Place it where the opponent wants to walk, then threaten Briar Lash above it.", "ivy_creeping_garden", "ivy_thorn_special", "both_hands", .22],
			]
		"rook":
			data = [
				["Knuckle Check", "A short, fast check that starts Rook's pressure.", "Use it after walking into range; Rook wins once he gets close.", "rook_knuckle_check", "rook_crimson_light", "right_hand", .06],
				["Iron Hook", "An armored hook that dares opponents to interrupt.", "Absorb one predictable poke, then make them respect the follow-up.", "rook_iron_hook", "rook_crimson_heavy", "right_hand", .18],
				["Ankle Break", "A grounded kick that keeps a blocking opponent honest.", "Alternate it with a clinch attempt while you are close.", "rook_ankle_break", "rook_crimson_low", "right_foot", .13],
				["Backbreaker", "A command grab that beats grounded guard.", "Walk into throw range; opponents can jump it, so scout first.", "rook_backbreaker", "rook_crimson_grab", "body", .26],
				["Shoulder Slip", "A compact movement tool for getting through a button.", "Use it to breach a predictable poke, not as a retreat.", "rook_shoulder_slip", "rook_crimson_dodge", "body", .04],
				["Clinch Drive", "A lunging command grab with huge payoff.", "Spend the risk after conditioning them to block your strikes.", "rook_clinch_drive", "rook_crimson_special", "body", .30],
			]
		"atlas":
			data = [
				["Stone Fist", "A solid close check with Atlas's weight behind it.", "Use it to start pressure only after you have claimed space.", "atlas_stone_fist", "atlas_seismic_light", "right_hand", .06],
				["Fault Hammer", "An armored hammer that wins trades.", "Let a lighter hit bounce off the armor, then take the damage lead.", "atlas_fault_hammer", "atlas_seismic_heavy", "right_hand", .22],
				["Quake Sweep", "A low sweep that sends a warning through the floor.", "Place it at the end of pressure to keep opponents from walking forward.", "atlas_quake_sweep", "atlas_seismic_low", "right_foot", .16],
				["Mountain Rise", "A towering launcher for close anti-air calls.", "Commit after you see the jump or a grounded hit connect.", "atlas_mountain_rise", "atlas_seismic_rise", "both_hands", .24],
				["Braced Step", "A measured step that holds Atlas's ground.", "Use it to stay just outside a whiff, then answer with Fault Hammer.", "atlas_braced_step", "atlas_seismic_dodge", "body", .04],
				["Seismic Break", "An armored ground wave that controls a whole lane.", "Use it after a knockdown or read, then advance behind the rubble.", "atlas_seismic_break", "atlas_seismic_special", "both_hands", .30],
			]
		"zero":
			data = [
				["Vector Jab", "A precise jab for interrupting loose pressure.", "Use it as a fast check, then decide whether to reset or confirm.", "zero_vector_jab", "zero_precision_light", "right_hand", .05],
				["Check Hook", "A long, measured hook that tags a whiff.", "Hold the outer edge of range and punish their missed button.", "zero_check_hook", "zero_precision_heavy", "right_hand", .14],
				["Circuit Sweep", "A low circuit cut that checks movement.", "Make them hesitate to walk, then take space with your faster poke.", "zero_circuit_sweep", "zero_precision_low", "right_foot", .11],
				["Axis Cutter", "A vertical cut for anti-air and conversions.", "Confirm grounded contact before committing to the full rise.", "zero_axis_cutter", "zero_precision_rise", "right_hand", .20],
				["Phase Read", "A small reposition that invites a predictable answer.", "Move out, bait a button, then use Perfect Reversal.", "zero_phase_read", "zero_precision_dodge", "body", .03],
				["Perfect Reversal", "A counter stance that turns an attack against its owner.", "Use it only when you have read a strike; empty use gives up your turn.", "zero_perfect_reversal", "zero_precision_counter", "right_hand", .28],
			]
		"vex":
			data = [
				["Void Flick", "A fast flick that starts close void pressure.", "Touch them, then vanish through their predictable response.", "vex_void_flick", "vex_void_light", "right_hand", .05],
				["Rift Elbow", "A lunging elbow that punishes a retreat.", "Use it after a whiff or a space-changing Event Step.", "vex_rift_elbow", "vex_void_heavy", "right_hand", .16],
				["Shadow Reap", "A low strike that changes Vex's approach angle.", "Mix it into close pressure before teleporting through them.", "vex_shadow_reap", "vex_void_low", "right_foot", .12],
				["Abyss Rise", "A rising void strike for catches and launches.", "Use it as an anti-air or when a grounded string confirms.", "vex_abyss_rise", "vex_void_rise", "right_hand", .22],
				["Event Step", "An invulnerable cross-through movement tool.", "Pass through a commitment, turn, and punish their recovery.", "vex_event_step", "vex_void_dodge", "body", .05],
				["Rift Ambush", "A long lunge that reappears inside the opponent's space.", "Spend it when their movement is committed; missed Ambush is punishable.", "vex_rift_ambush", "vex_void_special", "right_hand", .28],
			]
		"sora":
			data = [
				["Breeze Palm", "A quick palm that begins Sora's air-oriented pressure.", "Use it to confirm before choosing a vertical follow-up.", "sora_breeze_palm", "sora_wind_light", "right_hand", .05],
				["Cyclone Hook", "A wind hook that lifts on a clean hit.", "Catch a grounded whiff, then convert with Sky Ascent.", "sora_cyclone_hook", "sora_wind_heavy", "right_hand", .15],
				["Gale Sweep", "A low gust that checks grounded movement.", "Use it to open room for your higher jump and air route.", "sora_gale_sweep", "sora_wind_low", "right_foot", .11],
				["Sky Ascent", "A rising special built for anti-air and juggles.", "Use it from a grounded confirm or to cut off a jump.", "sora_sky_ascent", "sora_wind_rise", "right_hand", .23],
				["Cloud Step", "An evasive step that shifts Sora into open space.", "Drift to a safer lane before returning with an aerial threat.", "sora_cloud_step", "sora_wind_dodge", "body", .04],
				["Tempest Rise", "A multi-hit wind column for extending a juggle.", "Use it after a launcher or close hit; it rewards clean timing.", "sora_tempest_rise", "sora_wind_special", "both_hands", .28],
			]
		"raijin":
			data = [
				["Spark Jab", "An extremely fast lightning check.", "Use it to take small turns and keep the opponent reacting.", "raijin_spark_jab", "raijin_electric_light", "right_hand", .05],
				["Thunder Cross", "A two-hit cross that carries Raijin forward.", "Confirm the early hit, then stay close for the second spark.", "raijin_thunder_cross", "raijin_electric_heavy", "right_hand", .16],
				["Arc Sweep", "A low electric sweep that stops backward movement.", "Use it after fast checks to keep your rushdown turn alive.", "raijin_arc_sweep", "raijin_electric_low", "right_foot", .12],
				["Storm Rise", "A lightning launcher with a tall hit area.", "Call out an air approach or turn a grounded confirm into a juggle.", "raijin_storm_rise", "raijin_electric_rise", "right_hand", .22],
				["Flash Step", "A sudden burst of movement into striking range.", "Use it to close after making an opponent freeze with Arc Sweep.", "raijin_flash_step", "raijin_electric_dodge", "body", .04],
				["Chain Lightning", "A rapid multi-hit rush that rewards close pressure.", "Spend it on a confirmed opening and carry the opponent to the corner.", "raijin_chain_lightning", "raijin_electric_special", "both_hands", .28],
			]
	if data.is_empty():
		return
	for index: int in range(mini(6, moveset.size())):
		var item: Array = data[index]
		var move: MoveData = moveset[index]
		move.display_name = str(item[0])
		move.purpose = str(item[1])
		move.coaching_note = str(item[2])
		move.vfx_cue = str(item[3])
		move.sfx_cue = str(item[4])
		move.visual_anchor = str(item[5])
		move.camera_impulse = float(item[6])
	# Supers inherit the character family rather than the generic placeholder.
	var super_move: MoveData = moveset[6]
	super_move.vfx_cue = id + "_super"
	super_move.sfx_cue = id + "_super"
	super_move.visual_anchor = "body"
	super_move.camera_impulse = .45


static func _apply_impact_flashes(profile: Dictionary, moveset: Array[MoveData]) -> void:
	var color: Color = profile["color"]
	for move: MoveData in moveset:
		var alpha: float = 0.035
		if move.category in ["Heavy", "Low", "Special I"]:
			alpha = 0.075
		elif move.category in ["Special II", "Super"]:
			alpha = 0.14
		move.impact_flash = Color(color.r, color.g, color.b, alpha)


## A lightweight data audit used by automated checks and editor integrations.
## It prevents typoed ownership prefixes or duplicate cue names from silently
## turning an authored move into the stage's compatibility fallback.
static func presentation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var vfx_cues: Dictionary = {}
	var sfx_cues: Dictionary = {}
	for profile: Dictionary in all():
		var id: String = str(profile["id"])
		for move: MoveData in moves(id):
			if not move.vfx_cue.begins_with(id + "_"):
				errors.append(id + "/" + move.id + " VFX cue must use its fighter prefix.")
			if not move.sfx_cue.begins_with(id + "_"):
				errors.append(id + "/" + move.id + " sound cue must use its fighter prefix.")
			if vfx_cues.has(move.vfx_cue):
				errors.append("Duplicate VFX cue: " + move.vfx_cue)
			if sfx_cues.has(move.sfx_cue):
				errors.append("Duplicate sound cue: " + move.sfx_cue)
			vfx_cues[move.vfx_cue] = true
			sfx_cues[move.sfx_cue] = true
	return errors


static func _guide(move: MoveData, new_category: String, action: String, notation: String, new_purpose: String, note: String, new_tags: Array, new_vfx: String, new_sfx: String, anchor: String, impulse: float) -> void:
	move.category = new_category
	move.input_action = action
	move.command = notation
	move.purpose = new_purpose
	move.coaching_note = note
	move.tags = PackedStringArray(new_tags)
	move.vfx_cue = new_vfx
	move.sfx_cue = new_sfx
	move.visual_anchor = anchor
	move.camera_impulse = impulse


static func _names(moveset: Array[MoveData], labels: Array) -> void:
	for index: int in range(6):
		moveset[index].display_name = labels[index]


static func _timing(move: MoveData, startup: int, active: int, recovery: int, damage: float) -> void:
	move.startup = startup
	move.active = active
	move.recovery = recovery
	move.damage = damage


static func _lunge(move: MoveData, speed: float, first: int, last: int) -> void:
	move.lunge_speed = speed
	move.lunge_start = first
	move.lunge_end = last


static func _projectile(move: MoveData, speed: float, lifetime: int, size: Vector2, offset: Vector2) -> void:
	move.behavior = "projectile"
	move.projectile_speed = speed
	move.projectile_lifetime = lifetime
	move.hitbox_size = size
	move.hitbox_offset = offset
	move.invuln_start = -1
	move.invuln_end = -1


static func _grab(move: MoveData, reach: float, width: float) -> void:
	move.behavior = "grab"
	move.hitbox_offset = Vector2(reach, 0.9)
	move.hitbox_size = Vector2(width, 1.3)
	move.invuln_start = -1
	move.invuln_end = -1


static func _armor(move: MoveData, count: int, first: int, last: int) -> void:
	move.armor_hits = count
	move.armor_start = first
	move.armor_end = last
