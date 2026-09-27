extends SceneTree
## Standalone smoke test for the player-facing command list.

var checks := 0
var failures := 0
var command: FighterCommand
var last_training: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/fighter_command.tscn") as PackedScene
	_expect(packed != null, "fighter command scene loads")
	if packed == null:
		quit(1)
		return
	command = packed.instantiate() as FighterCommand
	root.add_child(command)
	await process_frame
	await process_frame
	_expect(command.get_fighter_id() == "kai", "command list defaults to Kai")
	_expect(command.moves.size() == 11, "command list reads every catalog move")
	_expect(command._move_buttons.size() == 11, "all eleven Kai moves are visible by default")
	_expect(command.get_selected_move_id() == "jab", "first command is selected by default")
	_expect(command._detail_text.text.contains("TIMING") and command._detail_text.text.contains("CANCEL ROUTE"), "detail includes frame timing and cancel information")
	command.set_binding_labels({"light": "F", "special_2": "R", "super": "T"})
	command.select_move("jab")
	_expect(command._detail_input.text.contains("[F]"), "semantic control binding updates command input: " + command._detail_input.text)
	command.select_move("body_hook")
	_expect(command._detail_input.text.contains("[F]") and command._detail_input.text.contains("DOWN + LIGHT"), "directional command retains modifier after rebinding")
	command.select_move("knee")
	_expect(command._detail_input.text.contains("[F]") and command._detail_input.text.contains("FORWARD + LIGHT"), "knee command is discoverable with current controls")
	command.select_move("burst")
	_expect(command._detail_input.text.contains("[R]"), "special binding updates command input: " + command._detail_input.text)
	command._select_category("special")
	_expect(command._move_buttons.has("launcher") and command._move_buttons.has("burst") and command._move_buttons.size() == 2, "special tab filters to special commands")
	command._select_category("all")
	command.set_fighter("neon", "burst")
	await process_frame
	_expect(command.get_fighter_id() == "neon" and command.get_selected_move_id() == "burst", "fighter switch preserves requested move")
	_expect(command._detail_title.text == "SONIC LANCE", "fighter-specific catalog labels reach command detail")
	command.training_requested.connect(_training_requested)
	command._open_training()
	_expect(last_training.get("fighter", "") == "neon" and last_training.get("move", "") == "burst", "training signal carries fighter and move context")
	command.queue_free()
	await process_frame
	print("Fighter command checks: %d passed, %d failed" % [checks - failures, failures])
	quit(1 if failures > 0 else 0)


func _training_requested(fighter: String, move: String) -> void:
	last_training = {"fighter": fighter, "move": move}


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
