class_name MoveCatalog
extends RefCounted


static func defaults() -> Array[MoveData]:
	var jab: MoveData = _move("jab", "Jab", 6, 3, 12, 7.0, 16, 9, 4, 0.8)
	jab.cancel_start = 6
	jab.cancel_end = 15
	jab.cancel_into = PackedStringArray(["cross", "low_kick", "launcher", "burst"])
	jab.hitbox_offset = Vector2(0.7, 1.45)
	jab.hitbox_size = Vector2(0.7, 0.38)

	var cross: MoveData = _move("cross", "Cross", 10, 4, 19, 12.0, 22, 12, 6, 1.6)
	cross.cancel_start = 10
	cross.cancel_end = 22
	cross.cancel_into = PackedStringArray(["launcher", "burst"])
	cross.hitbox_offset = Vector2(0.9, 1.1)
	cross.hitbox_size = Vector2(0.9, 0.55)

	var low_kick: MoveData = _move("low_kick", "Low Kick", 9, 5, 17, 10.0, 19, 11, 5, 1.0)
	low_kick.hitbox_offset = Vector2(1.0, 0.4)
	low_kick.hitbox_size = Vector2(1.05, 0.5)
	low_kick.cancel_start = 9
	low_kick.cancel_end = 19
	low_kick.cancel_into = PackedStringArray(["cross", "burst"])

	var launcher: MoveData = _move("launcher", "Rising Strike", 14, 5, 26, 18.0, 32, 16, 8, 1.4)
	launcher.hitbox_offset = Vector2(0.8, 1.2)
	launcher.hitbox_size = Vector2(0.9, 1.1)
	launcher.energy_cost = 15.0
	launcher.cancel_start = 14
	launcher.cancel_end = 24
	launcher.cancel_into = PackedStringArray(["burst"])

	var dodge: MoveData = _move("dodge", "Slip Step", 3, 0, 21, 0.0, 0, 0, 0, 0.0)
	dodge.invuln_start = 3
	dodge.invuln_end = 12
	dodge.energy_cost = 10.0
	dodge.animation_blend_frames = 2

	var burst: MoveData = _move("burst", "Rift Burst", 18, 7, 32, 28.0, 37, 20, 10, 3.8)
	burst.hitbox_offset = Vector2(1.1, 1.0)
	burst.hitbox_size = Vector2(1.8, 1.7)
	burst.energy_cost = 50.0
	burst.invuln_start = 0
	burst.invuln_end = 7
	var finisher: MoveData = _move("finisher", "Rift Breaker", 26, 11, 44, 40.0, 45, 24, 14, 5.0)
	finisher.energy_cost = 100.0
	finisher.hitbox_offset = Vector2(1.1, 1.0)
	finisher.hitbox_size = Vector2(2.0, 1.8)
	return [jab, cross, low_kick, launcher, dodge, burst, finisher]


static func _move(move_id: String, label: String, start: int, duration: int, recover: int, power: float, hit_stun: int, block_stun: int, pause: int, push: float) -> MoveData:
	var result: MoveData = MoveData.new()
	result.id = move_id
	result.display_name = label
	result.animation_name = move_id
	result.startup = start
	result.active = duration
	result.recovery = recover
	result.damage = power
	result.hitstun = hit_stun
	result.blockstun = block_stun
	result.hitstop = pause
	result.knockback = push
	return result
