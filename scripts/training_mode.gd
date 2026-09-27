class_name TrainingMode
extends Control
## Player-facing practice space. The combat simulation remains authoritative at 60 Hz;
## this scene only translates temporary keyboard input into combat dictionaries.

signal return_to_menu

const Actor = preload("res://scripts/avatar_actor.gd")
const Stage = preload("res://scripts/lab_stage.gd")
const Simulation = preload("res://combat/FightSimulation.gd")
const Roster = preload("res://combat/FighterCatalog.gd")
const InputRouter = preload("res://scripts/input/combat_input_router.gd")
const Footwork = preload("res://combat/FootsiesAI.gd")
const DUMMY_MODES := ["stand", "block", "random", "attack", "footsies", "whiff"]

const ACTION_KEYS := {
	"jab": "J  LIGHT",
	"cross": "K  HEAVY",
	"low_kick": "L  LOW",
	"launcher": "U  SPECIAL I",
	"dodge": "SHIFT  DODGE",
	"burst": "O  SPECIAL II",
	"finisher": "P  SUPER",
}

## Scene transitions do not carry constructor arguments. The command screen sets
## this one-shot request immediately before opening Training, then the scene
## consumes it during _ready without persisting any player preference.
static var _next_player_id: String = ""
static var _next_opponent_id: String = ""
static var _next_move_id: String = ""


static func configure_next(player: String = "", opponent: String = "", move_id: String = "") -> void:
	_next_player_id = player
	_next_opponent_id = opponent
	_next_move_id = move_id


class TrainingInputAdapter:
	## This is deliberately isolated from the scene. A future remapping/router layer can
	## replace TrainingMode.input_provider without touching simulation or presentation.
	var queued_actions: Array[String] = ["", ""]
	var queued_power: Array[bool] = [false, false]

	func queue_action(player: int, action: String) -> void:
		if player < 0 or player >= queued_actions.size():
			return
		queued_actions[player] = action

	func queue_power(player: int) -> void:
		if player >= 0 and player < queued_power.size():
			queued_power[player] = true

	func consume(player: int) -> Dictionary:
		var result: Dictionary = {
			"axis": 0.0,
			"jump": false,
			"crouch": false,
			"block": false,
			"action": queued_actions[player],
			"power": queued_power[player],
		}
		queued_actions[player] = ""
		queued_power[player] = false
		return result


var simulation: FightSimulation
var stage: LabStage
var actors: Array = []
var input_adapter := TrainingInputAdapter.new()
var input_router
## Optional future integration point. It receives a player index and returns the same
## dictionary shape as FightSimulation.step. Leave empty for the temporary defaults.
var input_provider: Callable

var player_id: String = "kai"
var opponent_id: String = "neon"
var dummy_mode: String = "stand"
var paused: bool = false
var debug_visible: bool = false
var swapped_sides: bool = false
var combo_damage: float = 0.0
var combo_count: int = 0
var last_event: String = "READY / Pick a dummy behavior and practice."
var input_history: Array[String] = []
var _last_held: Array[String] = []
var _dummy_block_frames: int = 0
var _rng := RandomNumberGenerator.new()
var footwork = Footwork.new()
var range_label: Label
var opponent_intent_label: Label
var footer_label: Label

var world_viewport: SubViewport
var player_picker: OptionButton
var opponent_picker: OptionButton
var dummy_picker: OptionButton
var pause_button: Button
var boxes_button: Button
var player_name: Label
var opponent_name: Label
var player_subtitle: Label
var opponent_subtitle: Label
var frame_label: Label
var move_label: Label
var phase_label: Label
var combo_label: Label
var status_label: Label
var feedback_label: Label
var input_history_label: Label
var event_log_label: Label
var command_list: VBoxContainer
var health_bars: Array[ProgressBar] = []
var guard_bars: Array[ProgressBar] = []
var energy_bars: Array[ProgressBar] = []


func _ready() -> void:
	var requested_move := _next_move_id
	if not _next_player_id.is_empty():
		player_id = _next_player_id
	if not _next_opponent_id.is_empty():
		opponent_id = _next_opponent_id
	_next_player_id = ""
	_next_opponent_id = ""
	_next_move_id = ""
	_rng.randomize()
	_theme()
	_build_layout()
	input_router = InputRouter.new()
	footer_label.text = "Bindings follow CONTROL SETTINGS.   SPACE PAUSE   •   . STEP   •   R RESET   •   B / F3 BOXES + REACH   •   ESC MENU"
	simulation = Simulation.new()
	stage = Stage.new()
	world_viewport.add_child(stage)
	for index in range(2):
		var actor = Actor.new()
		stage.add_child(actor)
		actors.append(actor)
	set_fighters(player_id, opponent_id)
	set_dummy_mode(dummy_mode)
	if not requested_move.is_empty():
		last_event = "COMMAND FOCUS / %s" % requested_move.replace("_", " ").to_upper()
		event_log_label.text = "EVENT / %s" % last_event
		status_label.text = "Practice the selected command, then open its frame data in Fighter Command."
	set_process(true)
	set_physics_process(true)


func _theme() -> void:
	var next_theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue", "Arial"])
	next_theme.default_font = font
	next_theme.default_font_size = 14
	next_theme.set_color("font_color", "Label", Color("e8edf1"))
	next_theme.set_color("font_color", "Button", Color("ecf3f4"))
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("111822")
	panel.border_color = Color("2e3d4d")
	panel.set_border_width_all(1)
	panel.corner_radius_top_left = 4
	panel.corner_radius_top_right = 4
	panel.corner_radius_bottom_left = 4
	panel.corner_radius_bottom_right = 4
	next_theme.set_stylebox("panel", "PanelContainer", panel)
	for state_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var button_box := StyleBoxFlat.new()
		button_box.bg_color = Color("25313d") if state_name == "hover" else Color("1c2732")
		if state_name == "pressed":
			button_box.bg_color = Color("324554")
		if state_name == "disabled":
			button_box.bg_color = Color("16202a")
		button_box.border_color = Color("b9e55b") if state_name == "focus" else Color("3c5060")
		button_box.set_border_width_all(1)
		button_box.content_margin_left = 10
		button_box.content_margin_right = 10
		button_box.content_margin_top = 7
		button_box.content_margin_bottom = 7
		next_theme.set_stylebox(state_name, "Button", button_box)
		next_theme.set_stylebox(state_name, "OptionButton", button_box.duplicate())
	theme = next_theme


func _build_layout() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("090e14")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var app := VBoxContainer.new()
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.add_theme_constant_override("separation", 10)
	add_child(app)
	var edge := MarginContainer.new()
	edge.size_flags_vertical = Control.SIZE_EXPAND_FILL
	edge.add_theme_constant_override("margin_left", 16)
	edge.add_theme_constant_override("margin_right", 16)
	edge.add_theme_constant_override("margin_top", 14)
	edge.add_theme_constant_override("margin_bottom", 8)
	app.add_child(edge)
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 10)
	edge.add_child(shell)
	shell.add_child(_build_header())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	shell.add_child(body)
	body.add_child(_build_arena())
	body.add_child(_build_side_panel())
	shell.add_child(_build_footer())


func _build_header() -> Control:
	var header := PanelContainer.new()
	header.custom_minimum_size.y = 72
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 14)
	header.add_child(margin)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	var brand := _label("RIFT//RIOT", 22, Color("cbe85b"))
	row.add_child(brand)
	var title := _label("TRAINING", 12, Color("91a2b0"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(_label("PLAYER", 10, Color("8193a1")))
	player_picker = _fighter_picker("Player fighter")
	player_picker.item_selected.connect(_on_player_selected)
	row.add_child(player_picker)
	row.add_child(_label("DUMMY", 10, Color("8193a1")))
	opponent_picker = _fighter_picker("Dummy fighter")
	opponent_picker.item_selected.connect(_on_opponent_selected)
	row.add_child(opponent_picker)
	var menu := _button("RETURN TO MENU", _request_return, false)
	menu.custom_minimum_size.x = 142
	row.add_child(menu)
	return header


func _fighter_picker(tip: String) -> OptionButton:
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(112, 40)
	picker.tooltip_text = tip
	for profile: Dictionary in Roster.all():
		picker.add_item(str(profile["name"]))
		var index := picker.item_count - 1
		picker.set_item_metadata(index, profile["id"])
		picker.set_item_tooltip(index, "%s — %s" % [profile["archetype"], profile["description"]])
	return picker


func _build_arena() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(690, 510)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.focus_mode = Control.FOCUS_ALL
	stack.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			stack.grab_focus()
	)
	panel.add_child(stack)
	var viewport_container := SubViewportContainer.new()
	viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_container.stretch = true
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(viewport_container)
	world_viewport = SubViewport.new()
	world_viewport.size = Vector2i(1120, 710)
	world_viewport.own_world_3d = true
	world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world_viewport.msaa_3d = Viewport.MSAA_4X
	viewport_container.add_child(world_viewport)
	_build_arena_overlay(stack)
	return panel


func _build_arena_overlay(stack: Control) -> void:
	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("margin_left", 22)
	top.add_theme_constant_override("margin_right", 22)
	top.add_theme_constant_override("margin_top", 18)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 56)
	top.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	player_name = _label("P1  KAI", 17, Color("cbe85b"))
	left.add_child(player_name)
	player_subtitle = _label("RUSHDOWN", 10, Color("a4b3bf"))
	left.add_child(player_subtitle)
	health_bars.append(_bar(left, Color("d8ed53"), 8))
	guard_bars.append(_bar(left, Color("8db9d5"), 4))
	energy_bars.append(_bar(left, Color("be8cfd"), 4))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	opponent_name = _label("NEON  DUMMY", 17, Color("c9dcf5"))
	opponent_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(opponent_name)
	opponent_subtitle = _label("SONIC ZONER", 10, Color("a4b3bf"))
	opponent_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(opponent_subtitle)
	health_bars.append(_bar(right, Color("a8c6e8"), 8))
	guard_bars.append(_bar(right, Color("719ec8"), 4))
	energy_bars.append(_bar(right, Color("a77bea"), 4))
	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	center.position = Vector2(-175, 124)
	center.size = Vector2(350, 90)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(center)
	feedback_label = _label("READY", 22, Color("fff1b3"))
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(feedback_label)
	status_label = _label("Practice at your own pace.", 11, Color("b8c8cf"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(status_label)
	var history_panel := PanelContainer.new()
	history_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	history_panel.position = Vector2(18, -126)
	history_panel.size = Vector2(420, 106)
	history_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(history_panel)
	var history_margin := MarginContainer.new()
	history_margin.add_theme_constant_override("margin_left", 12)
	history_margin.add_theme_constant_override("margin_right", 12)
	history_margin.add_theme_constant_override("margin_top", 9)
	history_margin.add_theme_constant_override("margin_bottom", 9)
	history_panel.add_child(history_margin)
	var history_column := VBoxContainer.new()
	history_column.add_theme_constant_override("separation", 4)
	history_margin.add_child(history_column)
	history_column.add_child(_label("INPUT HISTORY", 10, Color("cbe85b")))
	input_history_label = _label("—", 14, Color("edf3f3"))
	input_history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	history_column.add_child(input_history_label)
	event_log_label = _label("EVENT / No contact yet", 10, Color("9dafbb"))
	event_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	history_column.add_child(event_log_label)
	var legend := _label("RED HIT  •  GREEN HURT  •  BLUE INVULN  •  FLOOR: LOW REACH", 9, Color("c7d3d3"))
	legend.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	legend.position = Vector2(-450, -27)
	legend.size.x = 430
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(legend)


func _build_side_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(348, 0)
	var settings_scroll := ScrollContainer.new()
	settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(settings_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	settings_scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	column.add_child(_label("TRAINING SETTINGS", 13, Color("cbe85b")))
	column.add_child(_label("DUMMY BEHAVIOR", 10, Color("8fa0ad")))
	dummy_picker = OptionButton.new()
	dummy_picker.custom_minimum_size.y = 42
	for option: String in ["STAND", "BLOCK", "RANDOM BLOCK", "ATTACK", "FOOTSIES CPU", "WHIFF PRACTICE"]:
		dummy_picker.add_item(option)
	dummy_picker.item_selected.connect(_on_dummy_selected)
	column.add_child(dummy_picker)
	column.add_child(_label("FOOTSIES uses the match CPU. WHIFF PRACTICE repeats a heavy: step outside its reach, then punish the recovery.", 11, Color("9dacb8"), true))
	column.add_child(_divider())
	var tools := GridContainer.new()
	tools.columns = 2
	tools.add_theme_constant_override("h_separation", 8)
	tools.add_theme_constant_override("v_separation", 8)
	tools.add_child(_button("RESET ALL", reset_all, true))
	tools.add_child(_button("SWAP SIDES", swap_sides, false))
	tools.add_child(_button("METER 0", func() -> void: set_meter(0.0), false))
	tools.add_child(_button("METER 100", func() -> void: set_meter(100.0), true))
	pause_button = _button("PAUSE", toggle_pause, false)
	tools.add_child(pause_button)
	tools.add_child(_button("STEP  .", step_once, true))
	boxes_button = _button("HITBOXES OFF", toggle_hitboxes, false)
	tools.add_child(boxes_button)
	column.add_child(tools)
	column.add_child(_divider())
	column.add_child(_label("LIVE TELEMETRY", 10, Color("8fa0ad")))
	frame_label = _label("FRAME 00   •   TICK 0", 16, Color("e9eef2"))
	column.add_child(frame_label)
	move_label = _label("MOVE / IDLE", 15, Color("cbe85b"))
	move_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(move_label)
	phase_label = _label("PHASE / READY", 11, Color("a9bbc8"))
	column.add_child(phase_label)
	range_label = _label("GAP / —", 11, Color("88d9ff"), true)
	column.add_child(range_label)
	opponent_intent_label = _label("DUMMY / STAND", 11, Color("a9bbc8"), true)
	column.add_child(opponent_intent_label)
	combo_label = _label("COMBO 0   •   0.0 DAMAGE", 15, Color("fff0ab"))
	column.add_child(combo_label)
	column.add_child(_divider())
	column.add_child(_label("COMMANDS", 10, Color("8fa0ad")))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 150
	column.add_child(scroll)
	command_list = VBoxContainer.new()
	command_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	command_list.add_theme_constant_override("separation", 7)
	scroll.add_child(command_list)
	return panel


func _build_footer() -> Control:
	var footer := PanelContainer.new()
	footer.custom_minimum_size.y = 44
	footer_label = _label("", 10, Color("b0c0c9"))
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(footer_label)
	return footer


func _label(value: String, font_size: int = 14, color: Color = Color("e8edf1"), wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(value: String, callback: Callable, accent: bool) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 40
	if accent:
		button.add_theme_color_override("font_color", Color("dff78d"))
	button.pressed.connect(callback)
	return button


func _bar(parent: Node, color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = height
	bar.show_percentage = false
	bar.max_value = 100.0
	var background := StyleBoxFlat.new()
	background.bg_color = Color("26323f")
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar


func _divider() -> HSeparator:
	var divider := HSeparator.new()
	divider.add_theme_constant_override("separation", 5)
	return divider


func _on_player_selected(index: int) -> void:
	set_fighters(str(player_picker.get_item_metadata(index)), opponent_id)


func _on_opponent_selected(index: int) -> void:
	set_fighters(player_id, str(opponent_picker.get_item_metadata(index)))


func _on_dummy_selected(index: int) -> void:
	set_dummy_mode(DUMMY_MODES[clampi(index, 0, DUMMY_MODES.size() - 1)])


func set_fighters(next_player: String, next_opponent: String) -> void:
	player_id = str(Roster.get_fighter(next_player)["id"])
	opponent_id = str(Roster.get_fighter(next_opponent)["id"])
	swapped_sides = false
	if simulation == null:
		return
	for index in range(2):
		var id := player_id if index == 0 else opponent_id
		simulation.set_fighter_profile(index, Roster.get_fighter(id))
		simulation.set_fighter_moves(index, Roster.moves(id))
	simulation.reset()
	if actors.size() == 2:
		actors[0].setup(false, player_id)
		actors[1].setup(true, opponent_id)
	_set_picker_selection(player_picker, player_id)
	_set_picker_selection(opponent_picker, opponent_id)
	_update_identity()
	_rebuild_command_list()
	_reset_display_state()
	_refresh_all()


func _set_picker_selection(picker: OptionButton, id: String) -> void:
	if picker == null:
		return
	for index in range(picker.item_count):
		if str(picker.get_item_metadata(index)) == id:
			picker.select(index)
			return


func set_dummy_mode(mode: String) -> void:
	dummy_mode = mode if mode in DUMMY_MODES else "stand"
	_dummy_block_frames = 0
	footwork.reset(9173)
	if dummy_picker != null:
		var index := DUMMY_MODES.find(dummy_mode)
		dummy_picker.select(maxi(0, index))
	status_label.text = "DUMMY / %s" % dummy_mode.to_upper()


func queue_action(player: int, action: String) -> void:
	if action.is_empty():
		return
	input_adapter.queue_action(player, action)


func queue_power(player: int = 0) -> void:
	input_adapter.queue_power(player)


func set_meter(value: float) -> void:
	if simulation == null:
		return
	for fighter: Dictionary in simulation.fighters:
		fighter["energy"] = clampf(value, 0.0, 100.0)
	_record_input("METER %d" % int(value))
	_refresh_all()


func reset_all() -> void:
	if simulation == null:
		return
	swapped_sides = false
	simulation.reset()
	for index in range(2):
		simulation.fighters[index]["energy"] = 100.0
	_reset_display_state()
	_record_input("RESET")
	_refresh_all()


func reset_positions() -> void:
	if simulation == null:
		return
	var meters: Array[float] = [float(simulation.fighters[0]["energy"]), float(simulation.fighters[1]["energy"])]
	simulation.reset()
	for index in range(2):
		simulation.fighters[index]["energy"] = meters[index]
	if swapped_sides:
		simulation.fighters[0]["position"] = Vector2(1.35, 0.0)
		simulation.fighters[1]["position"] = Vector2(-1.35, 0.0)
		simulation.fighters[0]["facing"] = -1
		simulation.fighters[1]["facing"] = 1
	_reset_display_state()
	_refresh_all()


func swap_sides() -> void:
	if simulation == null:
		return
	swapped_sides = not swapped_sides
	var left: float = 1.35 if swapped_sides else -1.35
	var right: float = -1.35 if swapped_sides else 1.35
	simulation.fighters[0]["position"] = Vector2(left, 0.0)
	simulation.fighters[1]["position"] = Vector2(right, 0.0)
	simulation.fighters[0]["velocity"] = Vector2.ZERO
	simulation.fighters[1]["velocity"] = Vector2.ZERO
	simulation.fighters[0]["facing"] = -1 if swapped_sides else 1
	simulation.fighters[1]["facing"] = 1 if swapped_sides else -1
	simulation.projectiles.clear()
	_record_input("SWAP SIDES")
	_refresh_all()


func set_paused(value: bool) -> void:
	paused = value
	if input_router != null:
		input_router.clear_input_state()
	if pause_button != null:
		pause_button.text = "RESUME" if paused else "PAUSE"
	status_label.text = "FRAME STEP ACTIVE — use STEP or ." if paused else "LIVE TRAINING — combat runs at 60 Hz."


func toggle_pause() -> void:
	set_paused(not paused)


func step_once() -> void:
	set_paused(true)
	_simulation_tick()


func toggle_hitboxes() -> void:
	debug_visible = not debug_visible
	if boxes_button != null:
		boxes_button.text = "HITBOXES ON" if debug_visible else "HITBOXES OFF"
	_refresh_boxes()


func _physics_process(_delta: float) -> void:
	if simulation == null:
		return
	if not paused:
		_simulation_tick()


func _process(_delta: float) -> void:
	if stage != null and simulation != null:
		stage.frame_fighters(simulation.fighters)


func _simulation_tick() -> void:
	var held := _held_input_tokens()
	if held != _last_held:
		if not held.is_empty():
			_record_input(" ".join(held))
		_last_held = held
	var frozen: bool = simulation.freeze_frames > 0
	var pressed_buttons: Array[String] = []
	if input_router != null and not input_provider.is_valid():
		for semantic: String in ControlProfile.MOVE_ACTIONS:
			if input_router.is_just_pressed(0, semantic):
				pressed_buttons.append(ControlProfile.action_label(semantic).to_upper())
	if not pressed_buttons.is_empty():
		_record_input("%d  %s" % [simulation.tick, " + ".join(pressed_buttons)])
	var p1 := _input_for_player(0)
	var action: String = str(p1.get("action", ""))
	if not action.is_empty() and pressed_buttons.is_empty():
		var command_move: MoveData = simulation.get_move(0, action)
		var label := "%s %s" % [_binding_for_move(command_move), command_move.command] if command_move != null else action.to_upper()
		_record_input("%d  %s" % [simulation.tick, label])
	if bool(p1.get("power", false)):
		_record_input("%d  POWER" % simulation.tick)
	var p2 := _dummy_input()
	simulation.step([p1, p2])
	if not simulation.pending_cinematic.is_empty():
		feedback_label.text = "SUPER CONFIRMED — TRAINING RESOLVE"
		status_label.text = "Cinematic damage resolves immediately in Training."
		simulation.resolve_cinematic()
	for index in range(2):
		actors[index].apply_state(simulation.fighters[index], not frozen)
	for event: Dictionary in simulation.events:
		_handle_event(event)
	if simulation.fighters[1]["stun"] <= 0 and combo_count > 0:
		combo_count = 0
		combo_damage = 0.0
	_refresh_all()


func _input_for_player(player: int) -> Dictionary:
	if input_provider.is_valid():
		var supplied = input_provider.call(player)
		if supplied is Dictionary:
			return supplied
	var result: Dictionary = input_router.consume_simulation_input(player) if input_router != null else {}
	var queued: Dictionary = input_adapter.consume(player)
	if not str(queued.get("action", "")).is_empty():
		result["action"] = queued["action"]
	if bool(queued.get("power", false)):
		result["power"] = true
	return result


func _dummy_input() -> Dictionary:
	var result := input_adapter.consume(1)
	result["axis"] = 0.0
	result["jump"] = false
	result["crouch"] = false
	result["block"] = false
	match dummy_mode:
		"block":
			result["block"] = true
		"random":
			if _dummy_block_frames <= 0:
				_dummy_block_frames = 30
				result["block"] = _rng.randi_range(0, 1) == 1
			else:
				_dummy_block_frames -= 1
				result["block"] = bool(simulation.fighters[1].get("_block", false))
		"attack":
			var distance := float(simulation.fighters[0]["position"].x) - float(simulation.fighters[1]["position"].x)
			if absf(distance) > 1.05:
				result["axis"] = signf(distance)
			elif simulation.tick % 48 == 0:
				result["action"] = "jab"
		"footsies":
			return footwork.input_for(simulation, 1, 1)
		"whiff":
			if simulation.freeze_frames == 0 and simulation.tick % 100 == 0 and simulation.fighters[1]["move"] == null and simulation.fighters[1]["stun"] == 0:
				result["action"] = "cross"
	return result


func _held_input_tokens() -> Array[String]:
	var tokens: Array[String] = []
	if input_router == null:
		return tokens
	for item: Array in [["move_left", "←"], ["move_right", "→"], ["jump", "↑"], ["crouch", "↓"], ["block", "BLOCK"]]:
		if input_router.is_pressed(0, str(item[0])):
			tokens.append(str(item[1]))
	return tokens


func _handle_event(event: Dictionary) -> void:
	var type := str(event.get("type", ""))
	if type == "move_ended" and int(event.get("fighter", -1)) == 0:
		var ended: MoveData = simulation.get_move(0, str(event.get("move", "")))
		if ended != null and ended.damage > 0.0 and ended.behavior == "strike" and not bool(event.get("contact", true)):
			last_event = "WHIFF / %s" % ended.display_name.to_upper()
			feedback_label.text = "WHIFF"
			event_log_label.text = "EVENT / " + last_event
			status_label.text = "No contact. Step closer or choose a longer poke."
		return
	if type == "move_started":
		var fighter: int = int(event.get("fighter", 0))
		if fighter == 0:
			var move_data: MoveData = event.get("move_data") as MoveData
			feedback_label.text = move_data.display_name.to_upper() if move_data != null else str(event.get("move", "")).to_upper()
			status_label.text = "EXECUTING / %s" % str(event.get("move", "")).to_upper()
		return
	if type in ["hit", "blocked", "guard_break", "armored", "counter"]:
		var attacker: int = int(event.get("attacker", 0))
		var defender: int = int(event.get("defender", 1))
		var point: Vector2 = simulation.fighters[defender]["position"] + Vector2(0.0, 1.15)
		stage.impact(point, type == "blocked")
		var headline := type.to_upper().replace("_", " ")
		feedback_label.text = headline
		last_event = "%s / %s" % [headline, str(event.get("move", "")).to_upper()]
		event_log_label.text = "EVENT / %s" % last_event
		if attacker == 0 and type in ["hit", "guard_break"]:
			var event_combo: int = int(event.get("combo", 1))
			var damage: float = float(event.get("damage", 0.0))
			if event_combo <= 1:
				combo_damage = damage
			else:
				combo_damage += damage
			combo_count = event_combo
		if type == "counter":
			status_label.text = "DUMMY COUNTERED — try a different timing."
		else:
			status_label.text = "%s / %.1f DAMAGE" % [headline, float(event.get("damage", 0.0))]
	elif type == "projectile_spawned":
		feedback_label.text = "PROJECTILE ACTIVE"
		status_label.text = "Watch its lane in the hitbox view."


func _refresh_all() -> void:
	if simulation == null:
		return
	var p1: Dictionary = simulation.fighters[0]
	var p2: Dictionary = simulation.fighters[1]
	for index in range(2):
		var fighter: Dictionary = simulation.fighters[index]
		health_bars[index].value = fighter["hp"]
		guard_bars[index].value = fighter["guard"]
		energy_bars[index].value = fighter["energy"]
	var move: MoveData = p1.get("move") as MoveData
	var frame: int = int(p1.get("move_frame", -1))
	frame_label.text = "FRAME %02d   •   TICK %d" % [maxi(0, frame), simulation.tick]
	if move == null:
		move_label.text = "MOVE / IDLE"
		phase_label.text = "PHASE / %s" % str(p1.get("state", "idle")).to_upper()
	else:
		move_label.text = "MOVE / %s" % move.display_name.to_upper()
		phase_label.text = "PHASE / %s   •   %d / %d / %d" % [move.phase_at(frame).to_upper(), move.startup, move.active, move.recovery]
	combo_label.text = "COMBO %d   •   %.1f DAMAGE" % [combo_count, combo_damage]
	var gap: float = absf(p1["position"].x - p2["position"].x)
	var light: MoveData = simulation.get_move(0, "jab")
	var low: MoveData = simulation.get_move(0, "low_kick")
	var light_reach := light.maximum_reach() + 0.275
	var low_reach := low.maximum_reach() + 0.275
	range_label.text = "GAP %.2f  •  GROUNDED TIP REACH\nLIGHT %.2f %s  •  LOW %.2f %s" % [gap, light_reach, "IN" if gap < light_reach else "OUT", low_reach, "IN" if gap < low_reach else "OUT"]
	opponent_intent_label.text = "CPU / %s" % footwork.intent.to_upper() if dummy_mode == "footsies" else "DUMMY / %s" % dummy_mode.to_upper()
	_refresh_boxes()


func _refresh_boxes() -> void:
	if stage == null or simulation == null:
		return
	var hits: Array = []
	var hurts: Array = []
	var invulnerable: Array = []
	for index in range(2):
		hits.append_array(simulation.hitboxes(index))
		hurts.append_array(simulation.hurtboxes(index))
		var fighter: Dictionary = simulation.fighters[index]
		var move: MoveData = fighter.get("move") as MoveData
		if move != null and move.is_invulnerable(int(fighter.get("move_frame", -1))):
			var center: Vector2 = fighter["position"] + Vector2(move.hurtbox_offset.x * fighter["facing"], move.hurtbox_offset.y)
			invulnerable.append(Rect2(center - move.hurtbox_size * 0.5, move.hurtbox_size))
	hits.append_array(simulation.projectile_hitboxes())
	stage.draw_boxes(hits, hurts, invulnerable, debug_visible)
	stage.show_reach(simulation.fighters, [simulation.get_move(0, "low_kick").maximum_reach(), simulation.get_move(1, "low_kick").maximum_reach()], debug_visible)


func _update_identity() -> void:
	var p1: Dictionary = Roster.get_fighter(player_id)
	var p2: Dictionary = Roster.get_fighter(opponent_id)
	player_name.text = "P1  %s" % p1["name"]
	player_name.add_theme_color_override("font_color", p1["color"])
	player_subtitle.text = str(p1["archetype"]).to_upper()
	opponent_name.text = "%s  DUMMY" % p2["name"]
	opponent_name.add_theme_color_override("font_color", p2["color"])
	opponent_subtitle.text = str(p2["archetype"]).to_upper()


func _rebuild_command_list() -> void:
	if command_list == null or simulation == null:
		return
	for child in command_list.get_children():
		child.free()
	for move: MoveData in Roster.moves(player_id):
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)
		var action: String = _binding_for_move(move)
		row.add_child(_label("%s  /  %s" % [action, move.display_name.to_upper()], 11, Color("e7eff0")))
		var notes: Array[String] = ["%df startup" % move.startup, "%df active" % move.active, "%df recovery" % move.recovery]
		if move.energy_cost > 0.0:
			notes.append("%d meter" % int(move.energy_cost))
		if move.behavior != "strike":
			notes.append(move.behavior.to_upper())
		row.add_child(_label(" • ".join(notes), 10, Color("91a4b1")))
		if move.command_modifier != "none":
			row.add_child(_label(move.coaching_note, 10, Color("c8b78f"), true))
		command_list.add_child(row)


func _binding_for_move(move: MoveData) -> String:
	if input_router != null and not move.input_action.is_empty():
		var label: String = str(input_router.bindings_label(0, move.input_action))
		if not label.is_empty():
			return (move.command_modifier.to_upper() + " + " if move.command_modifier != "none" else "") + label.to_upper()
	return move.command if move.command_modifier != "none" else ACTION_KEYS.get(move.id, move.id.to_upper())


func _reset_display_state() -> void:
	combo_count = 0
	combo_damage = 0.0
	last_event = "RESET / Ready."
	feedback_label.text = "READY"
	status_label.text = "Practice at your own pace."
	event_log_label.text = "EVENT / %s" % last_event
	input_history.clear()
	input_history_label.text = "—"
	_last_held.clear()
	_dummy_block_frames = 0
	footwork.reset(9173)
	if input_router != null:
		input_router.clear_input_state()
	input_adapter = TrainingInputAdapter.new()
	for actor in actors:
		actor.reset_pose()


func _record_input(value: String) -> void:
	if value.is_empty():
		return
	input_history.push_front(value)
	while input_history.size() > 8:
		input_history.pop_back()
	input_history_label.text = "  •  ".join(input_history)


func _request_return() -> void:
	return_to_menu.emit()
	# The scene is also useful when launched directly from the project browser. Game
	# integration may connect the signal and keep its own navigation stack; otherwise
	# use the native game scene as a safe standalone destination.
	if return_to_menu.get_connections().is_empty():
		get_tree().change_scene_to_file("res://scenes/game.tscn")


func _unhandled_input(event: InputEvent) -> void:
	# A remapped combat key wins over optional training shortcuts such as R or B.
	if input_router != null and input_router.handle_event(event):
		if input_router.consume_pressed(0, "pause"):
			_request_return()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var code: Key = event.physical_keycode
		match code:
			KEY_ESCAPE:
				_request_return()
				get_viewport().set_input_as_handled()
				return
			KEY_SPACE:
				toggle_pause()
				get_viewport().set_input_as_handled()
				return
			KEY_PERIOD:
				step_once()
				get_viewport().set_input_as_handled()
				return
			KEY_R:
				reset_all()
				get_viewport().set_input_as_handled()
				return
			KEY_B, KEY_F3:
				toggle_hitboxes()
				get_viewport().set_input_as_handled()
				return
