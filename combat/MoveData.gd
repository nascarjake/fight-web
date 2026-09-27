class_name MoveData
extends Resource
## Frame data uses zero-based simulation frames. All window endpoints are inclusive.

@export var id: String = "jab"
@export var display_name: String = "Jab"
@export var animation_name: String = "jab"

## Player-facing data is intentionally stored beside the deterministic frame data.
## The command screen, Training Mode, input router and presentation scheduler all
## read this resource, so descriptions cannot drift away from the actual move.
@export_category("Player guidance")
@export var category: String = "Normal"
@export var input_action: String = "light"
@export var command: String = "LIGHT"
## Directional variants resolve once at the input edge, before buffering.
@export var command_base: String = ""
@export_enum("none", "forward", "back", "down") var command_modifier: String = "none"
@export_multiline var purpose: String = "A fast close-range check."
@export_multiline var coaching_note: String = "Use it to interrupt pressure, then confirm into a stronger follow-up."
@export var tags: PackedStringArray = PackedStringArray()

@export_category("Frame data")
@export var startup: int = 6
@export var active: int = 3
@export var recovery: int = 15
@export var damage: float = 8.0
@export var hitstun: int = 15
@export var blockstun: int = 9
@export var hitstop: int = 5
@export var knockback: float = 1.2
@export var energy_cost: float = 0.0
@export var invuln_start: int = -1
@export var invuln_end: int = -1
@export var cancel_start: int = -1
@export var cancel_end: int = -1
@export var cancel_into: PackedStringArray = PackedStringArray()
@export var hitbox_offset: Vector2 = Vector2(0.8, 1.0)
@export var hitbox_size: Vector2 = Vector2(0.7, 0.5)
@export var hurtbox_offset: Vector2 = Vector2(0.0, 0.9)
@export var hurtbox_size: Vector2 = Vector2(0.55, 1.8)
## Local-space collision animation, sampled only by the 60 Hz simulation.
## The base hitbox describes full extension. Entry/exit deltas retract the limb.
@export var animated_hitbox: bool = false
@export var hitbox_entry_delta: Vector2 = Vector2.ZERO
@export var hitbox_exit_delta: Vector2 = Vector2.ZERO
@export var hitbox_edge_scale: Vector2 = Vector2.ONE
@export var exposed_limb_size: Vector2 = Vector2.ZERO
@export var exposed_recovery_frames: int = 0
@export var animation_blend_frames: int = 3
@export_enum("strike", "projectile", "grab", "counter") var behavior: String = "strike"
@export var effect: String = "impact"
@export var lunge_speed: float = 0.0
@export var lunge_start: int = -1
@export var lunge_end: int = -1
@export var cross_through: bool = false
@export var launch_velocity: float = 0.0
@export var projectile_speed: float = 6.0
@export var projectile_lifetime: int = 75
@export var max_hits: int = 1
@export var rehit_frames: int = 6
@export var armor_hits: int = 0
@export var armor_start: int = -1
@export var armor_end: int = -1
@export var slow_frames: int = 0
@export var slow_multiplier: float = 1.0
@export var cinematic_frames: int = 210

@export_category("Presentation")
## These are cue names, rather than assets, so moves remain safe to simulate
## headlessly. Presentation consumers resolve them to VFX, audio and camera work.
@export var vfx_cue: String = "light_strike"
@export var sfx_cue: String = "light_strike"
@export var visual_anchor: String = "hand"
@export_range(0.0, 1.0, 0.01) var camera_impulse: float = 0.08
@export var impact_flash: Color = Color(1.0, 1.0, 1.0, 0.0)


func total_frames() -> int:
	return startup + active + recovery


func phase_at(frame: int) -> String:
	if frame < 0 or frame >= total_frames():
		return "idle"
	if frame < startup:
		return "startup"
	if frame < startup + active:
		return "active"
	return "recovery"


func is_invulnerable(frame: int) -> bool:
	return invuln_start >= 0 and frame >= invuln_start and frame <= invuln_end


func attack_rect_at(frame: int) -> Rect2:
	var offset := hitbox_offset
	var size := hitbox_size
	if animated_hitbox and active > 1:
		var progress := clampf(float(frame - startup) / float(active - 1), 0.0, 1.0)
		# A plateau keeps both frames of an even-length active window at full reach.
		var extension := minf(1.0, minf(progress * 3.0, (1.0 - progress) * 3.0))
		offset += (hitbox_entry_delta if progress < 0.5 else hitbox_exit_delta) * (1.0 - extension)
		size *= hitbox_edge_scale.lerp(Vector2.ONE, extension)
	return Rect2(offset - size * 0.5, size)


func exposed_rect_at(frame: int) -> Rect2:
	if exposed_limb_size.x <= 0.0 or exposed_limb_size.y <= 0.0:
		return Rect2()
	var first := maxi(0, startup - 2)
	var recovery_start := startup + active
	if frame < first or frame >= recovery_start + exposed_recovery_frames:
		return Rect2()
	var center := attack_rect_at(clampi(frame, startup, recovery_start - 1)).get_center()
	if frame >= recovery_start and exposed_recovery_frames > 0:
		center = center.lerp(hurtbox_offset, float(frame - recovery_start + 1) / float(exposed_recovery_frames + 1))
	return Rect2(center - exposed_limb_size * 0.5, exposed_limb_size)


func maximum_reach() -> float:
	var reach := hitbox_offset.x + hitbox_size.x * 0.5
	if animated_hitbox:
		for frame: int in range(startup, startup + active):
			reach = maxf(reach, attack_rect_at(frame).end.x)
	return reach


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if id.strip_edges().is_empty():
		errors.append("Move ID cannot be empty.")
	if display_name.strip_edges().is_empty():
		errors.append("Display name cannot be empty.")
	if animation_name.strip_edges().is_empty():
		errors.append("Animation name cannot be empty.")
	if command_modifier not in ["none", "forward", "back", "down"] or (command_base.is_empty() != (command_modifier == "none")):
		errors.append("Directional commands need a base move and a valid modifier.")
	if category.strip_edges().is_empty() or input_action.strip_edges().is_empty() or command.strip_edges().is_empty():
		errors.append("Player guidance needs a category, input action, and command.")
	if purpose.strip_edges().is_empty() or coaching_note.strip_edges().is_empty():
		errors.append("Player guidance needs a purpose and coaching note.")
	if vfx_cue.strip_edges().is_empty() or sfx_cue.strip_edges().is_empty() or visual_anchor.strip_edges().is_empty():
		errors.append("Presentation needs VFX, sound, and visual-anchor cues.")
	if startup < 0 or active < 0 or recovery < 0 or total_frames() <= 0:
		errors.append("Frame lengths must be nonnegative and total at least one frame.")
	if damage < 0.0 or hitstun < 0 or blockstun < 0 or hitstop < 0 or knockback < 0.0:
		errors.append("Damage, stun, hitstop, and knockback cannot be negative.")
	if energy_cost < 0.0 or energy_cost > 100.0:
		errors.append("Energy cost must be between 0 and 100.")
	if hitbox_size.x <= 0.0 or hitbox_size.y <= 0.0 or hurtbox_size.x <= 0.0 or hurtbox_size.y <= 0.0:
		errors.append("Collision box sizes must be positive.")
	if animation_blend_frames < 0:
		errors.append("Animation blend frames cannot be negative.")
	if camera_impulse < 0.0 or camera_impulse > 1.0:
		errors.append("Camera impulse must be between 0 and 1.")
	if impact_flash.a < 0.0 or impact_flash.a > 1.0:
		errors.append("Impact flash alpha must be between 0 and 1.")
	if hitbox_edge_scale.x <= 0.0 or hitbox_edge_scale.y <= 0.0 or hitbox_edge_scale.x > 1.0 or hitbox_edge_scale.y > 1.0:
		errors.append("Hitbox edge scales must be in (0, 1].")
	if exposed_limb_size.x < 0.0 or exposed_limb_size.y < 0.0 or exposed_recovery_frames < 0 or exposed_recovery_frames > recovery:
		errors.append("Limb exposure must have nonnegative size and fit inside recovery.")
	_validate_window("Invulnerability", invuln_start, invuln_end, errors)
	_validate_window("Cancel", cancel_start, cancel_end, errors)
	_validate_window("Lunge", lunge_start, lunge_end, errors)
	_validate_window("Armor", armor_start, armor_end, errors)
	if behavior not in ["strike", "projectile", "grab", "counter"]:
		errors.append("Unknown move behavior.")
	if behavior == "projectile" and (projectile_speed <= 0.0 or projectile_lifetime <= 0):
		errors.append("Projectiles need positive speed and lifetime.")
	if max_hits < 1 or max_hits > 6 or rehit_frames < 1:
		errors.append("Hit count must be 1–6 and hit spacing positive.")
	if armor_hits < 0 or (armor_hits > 0 and armor_start < 0):
		errors.append("Armor charges require an enabled armor window.")
	if slow_frames < 0 or slow_multiplier <= 0.0 or slow_multiplier > 1.0:
		errors.append("Slow duration must be nonnegative and multiplier in (0, 1].")
	if cinematic_frames < 180 or cinematic_frames > 240:
		errors.append("Cinematic duration must be 180–240 frames.")
	if cancel_start == -1 and not cancel_into.is_empty():
		errors.append("Cancel destinations need an enabled cancel window.")
	return errors


func _validate_window(label: String, first: int, last: int, errors: PackedStringArray) -> void:
	if first == -1 and last == -1:
		return
	if first < 0 or last < first or last >= total_frames():
		errors.append(label + " window must be disabled (-1, -1) or fit inside the move.")
