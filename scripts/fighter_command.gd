class_name FighterCommand
extends Control
## Player-facing command list and exact-frame move preview.
##
## The game owns navigation and control persistence.  This screen is deliberately
## self-contained so it can be opened from Character Select, Pause, Results, or
## Training without duplicating fighter data.  It reads the current fighter's
## MoveData resources on demand and accepts already-formatted binding labels.

signal back_requested
signal training_requested(fighter_id: String, move_id: String)

const Actor = preload("res://scripts/avatar_actor.gd")
const Roster = preload("res://combat/FighterCatalog.gd")

const DEFAULT_BINDINGS := {
	"jab": "J",
	"cross": "K",
	"low_kick": "L",
	"launcher": "U",
	"dodge": "SHIFT",
	"burst": "O",
	"finisher": "P",
}

const CATEGORIES := [
	{"id": "all", "label": "ALL"},
	{"id": "normal", "label": "NORMAL"},
	{"id": "special", "label": "SPECIAL"},
	{"id": "movement", "label": "MOVE"},
	{"id": "super", "label": "SUPER"},
]

var fighter_id: String = "kai"
var profile: Dictionary = {}
var moves: Array[MoveData] = []
var selected_move: MoveData
var binding_labels: Dictionary = DEFAULT_BINDINGS.duplicate(true)

var _category: String = "all"
var _search: String = ""
var _preview_time: float = 0.0
var _preview_frame: int = 0
var _preview_playing: bool = true
var _category_buttons: Dictionary = {}
var _move_buttons: Dictionary = {}

var _fighter_picker: OptionButton
var _fighter_name: Label
var _fighter_role: Label
var _fighter_description: Label
var _move_count: Label
var _move_list: VBoxContainer
var _search_box: LineEdit
var _detail_title: Label
var _detail_input: Label
var _detail_badges: Label
var _detail_text: RichTextLabel
var _frame_label: Label
var _frame_slider: HSlider
var _play_button: Button
var _preview_host: SubViewportContainer
var _viewport: SubViewport
var _actor: AvatarActor


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(960, 640)
	_theme()
	_build_interface()
	_build_preview()
	set_fighter(fighter_id)


## Opens the command list.  Passing an empty move ID preserves the current move
## when possible, otherwise it selects the fighter's first listed command.
func open_command(id: String = "kai", move_id: String = "") -> void:
	visible = true
	set_fighter(id, move_id)
	call_deferred("_focus_current_move")


func close_command() -> void:
	visible = false


## Updates the fighter and rebuilds its roster from the authoritative catalog.
func set_fighter(id: String, preferred_move_id: String = "") -> void:
	profile = Roster.get_fighter(id)
	fighter_id = str(profile.get("id", "kai"))
	moves = Roster.moves(fighter_id)
	var desired := preferred_move_id
	if desired.is_empty() and selected_move != null:
		desired = selected_move.id
	selected_move = _move_for_id(desired)
	if selected_move == null and not moves.is_empty():
		selected_move = moves[0]
	_preview_time = 0.0
	_preview_frame = 0
	if not is_node_ready():
		return
	if is_instance_valid(_actor) and _actor.fighter_id != fighter_id:
		_actor.setup(false, fighter_id)
	elif is_instance_valid(_actor):
		_actor.reset_pose()
	_sync_fighter_picker()
	_refresh_fighter_summary()
	_refresh_move_list()
	_refresh_detail()
	_preview_selected_frame()


## Bindings are presentation strings, usually keyed by move ID:
## {"jab":"J", "cross":"K", "finisher":"P"}.
## Nested profiles are also accepted, such as {"p1":{"jab":"F"}} or
## {"actions":{"jab":{"label":"X"}}}; this keeps the list independent of
## the future control-settings storage format.
func set_binding_labels(labels: Dictionary) -> void:
	# Do not merge defaults here: a semantic label such as {"light":"F"}
	# needs to supersede the fallback Jab key. `_binding_for_move` supplies the
	# defaults only when a caller did not provide any usable binding.
	binding_labels = labels.duplicate(true)
	if is_node_ready():
		_refresh_move_list()
		_refresh_detail()


func get_fighter_id() -> String:
	return fighter_id


func get_selected_move_id() -> String:
	return selected_move.id if selected_move != null else ""


func select_move(move_id: String) -> void:
	var next := _move_for_id(move_id)
	if next == null:
		return
	selected_move = next
	_preview_time = 0.0
	_preview_frame = 0
	_preview_playing = true
	_refresh_move_list()
	_refresh_detail()
	_preview_selected_frame()


func _theme() -> void:
	var palette := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Avenir Next", "Helvetica Neue", "Arial"])
	palette.default_font = font
	palette.default_font_size = 15
	palette.set_color("font_color", "Label", Color("eef2ed"))
	palette.set_color("font_color", "Button", Color("edf3ed"))
	palette.set_color("font_placeholder_color", "LineEdit", Color("7c8990"))
	palette.set_stylebox("normal", "Button", _box(Color("1a222a"), Color("34424e"), 1, 8, 10))
	palette.set_stylebox("hover", "Button", _box(Color("26333d"), Color("7fe3ff"), 1, 8, 10))
	palette.set_stylebox("pressed", "Button", _box(Color("344753"), Color("d9fb65"), 1, 8, 10))
	palette.set_stylebox("focus", "Button", _box(Color("26333d"), Color("d9fb65"), 2, 8, 10))
	palette.set_stylebox("normal", "LineEdit", _box(Color("11181f"), Color("31404a"), 1, 6, 10))
	palette.set_stylebox("focus", "LineEdit", _box(Color("11181f"), Color("7fe3ff"), 1, 6, 10))
	theme = palette


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("080d12")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var accent := ColorRect.new()
	accent.color = Color("d8ee58")
	accent.set_anchors_preset(Control.PRESET_TOP_WIDE)
	accent.offset_bottom = 4
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(accent)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24 if edge != "top" else 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 58
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var brand := _label("RIFT//RIOT", 23, Color("dff568"))
	brand.custom_minimum_size.x = 146
	header.add_child(brand)
	var title := _label("FIGHTER COMMAND", 13, Color("b5c4cd"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_fighter_picker = OptionButton.new()
	_fighter_picker.custom_minimum_size = Vector2(160, 39)
	for entry: Dictionary in Roster.all():
		_fighter_picker.add_item(str(entry.get("name", "FIGHTER")))
		var index := _fighter_picker.item_count - 1
		_fighter_picker.set_item_metadata(index, entry.get("id", "kai"))
		_fighter_picker.set_item_tooltip(index, str(entry.get("archetype", "")))
	_fighter_picker.item_selected.connect(_fighter_changed)
	header.add_child(_fighter_picker)
	var back := Button.new()
	back.text = "BACK  ESC"
	back.custom_minimum_size = Vector2(108, 39)
	back.pressed.connect(func(): back_requested.emit())
	header.add_child(back)

	var divider := HSeparator.new()
	root.add_child(divider)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)
	_build_preview_column(body)
	_build_move_column(body)
	_build_detail_column(body)

	var footer := _label("SELECT A MOVE TO PREVIEW ITS EXACT 60 Hz TIMING  •  OPEN TRAINING TO PRACTICE IT  •  ESC TO GO BACK", 11, Color("80919a"))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.custom_minimum_size.y = 23
	root.add_child(footer)


func _build_preview_column(parent: HBoxContainer) -> void:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(410, 0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	parent.add_child(column)
	var identity := PanelContainer.new()
	identity.add_theme_stylebox_override("panel", _box(Color("111a21"), Color("32424c"), 1, 9, 14))
	column.add_child(identity)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	identity.add_child(info)
	_fighter_name = _label("KAI", 31, Color("f4f8ed"))
	info.add_child(_fighter_name)
	_fighter_role = _label("RUSHDOWN", 12, Color("dff568"))
	info.add_child(_fighter_role)
	_fighter_description = _label("", 12, Color("aebbc2"))
	_fighter_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fighter_description.custom_minimum_size.y = 38
	info.add_child(_fighter_description)

	var preview_panel := PanelContainer.new()
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.add_theme_stylebox_override("panel", _box(Color("0e161c"), Color("3d5360"), 1, 10, 2))
	column.add_child(preview_panel)
	var preview_root := Control.new()
	preview_root.custom_minimum_size = Vector2(410, 300)
	preview_panel.add_child(preview_root)
	_preview_host = SubViewportContainer.new()
	_preview_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_host.stretch = true
	_preview_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_root.add_child(_preview_host)
	var overlay := MarginContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_theme_constant_override("margin_left", 14)
	overlay.add_theme_constant_override("margin_right", 14)
	overlay.add_theme_constant_override("margin_top", 12)
	overlay.add_theme_constant_override("margin_bottom", 12)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_root.add_child(overlay)
	var overlay_stack := VBoxContainer.new()
	overlay.add_child(overlay_stack)
	var preview_label := _label("LIVE MOVE PREVIEW", 11, Color("dff568"))
	overlay_stack.add_child(preview_label)
	_frame_label = _label("FRAME 01 / 01", 12, Color("cdd9df"))
	overlay_stack.add_child(_frame_label)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	column.add_child(controls)
	_play_button = Button.new()
	_play_button.text = "PAUSE"
	_play_button.custom_minimum_size = Vector2(100, 37)
	_play_button.pressed.connect(_toggle_preview)
	controls.add_child(_play_button)
	_frame_slider = HSlider.new()
	_frame_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_frame_slider.step = 1.0
	_frame_slider.value_changed.connect(_scrub_preview)
	controls.add_child(_frame_slider)


func _build_move_column(parent: HBoxContainer) -> void:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(270, 0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	parent.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := _label("MOVE LIST", 16, Color("ecf2ed"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	_move_count = _label("0 MOVES", 11, Color("8ba0ab"))
	heading.add_child(_move_count)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 4)
	column.add_child(filters)
	for entry: Dictionary in CATEGORIES:
		var category := str(entry.id)
		var button := Button.new()
		button.text = str(entry.label)
		button.toggle_mode = true
		button.custom_minimum_size.y = 30
		button.pressed.connect(_select_category.bind(category))
		filters.add_child(button)
		_category_buttons[category] = button
	_search_box = LineEdit.new()
	_search_box.placeholder_text = "Search commands, traits, effects…"
	_search_box.custom_minimum_size.y = 38
	_search_box.text_changed.connect(_search_changed)
	column.add_child(_search_box)
	var list_panel := PanelContainer.new()
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.add_theme_stylebox_override("panel", _box(Color("101820"), Color("32404b"), 1, 8, 5))
	column.add_child(list_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_panel.add_child(scroll)
	_move_list = VBoxContainer.new()
	_move_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_move_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_move_list)


func _build_detail_column(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(350, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(Color("111921"), Color("3d4c57"), 1, 10, 16))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	panel.add_child(column)
	var overline := _label("COMMAND DETAIL", 11, Color("91a6b0"))
	column.add_child(overline)
	_detail_title = _label("—", 27, Color("f2f7ef"))
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_detail_title)
	_detail_input = _label("—", 16, Color("dff568"))
	_detail_input.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_detail_input)
	_detail_badges = _label("", 11, Color("88d9ff"))
	_detail_badges.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_detail_badges)
	var detail_line := HSeparator.new()
	column.add_child(detail_line)
	_detail_text = RichTextLabel.new()
	_detail_text.bbcode_enabled = true
	_detail_text.fit_content = false
	_detail_text.scroll_active = true
	_detail_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_text.custom_minimum_size.y = 210
	_detail_text.add_theme_font_size_override("normal_font_size", 13)
	_detail_text.add_theme_color_override("default_color", Color("ccd7dc"))
	column.add_child(_detail_text)
	var train := Button.new()
	train.text = "OPEN TRAINING  ↗"
	train.custom_minimum_size.y = 43
	train.pressed.connect(_open_training)
	column.add_child(train)


func _build_preview() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "MovePreviewViewport"
	_viewport.size = Vector2i(960, 680)
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X
	_preview_host.add_child(_viewport)

	var world := Node3D.new()
	world.name = "MovePreviewStage"
	_viewport.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("071119")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9bb5c3")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	var environment_node := WorldEnvironment.new()
	environment_node.environment = environment
	world.add_child(environment_node)
	_add_preview_light(world, Vector3(-3.2, 4.0, 3.5), Color("f0e6b4"), 5.5)
	_add_preview_light(world, Vector3(3.0, 2.8, 1.2), Color("7ae5ff"), 4.2)
	_add_preview_light(world, Vector3(-1.0, 1.3, -3.0), Color("ca78ff"), 2.4)
	var floor := MeshInstance3D.new()
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 3.5
	floor_mesh.bottom_radius = 3.5
	floor_mesh.height = 0.14
	floor_mesh.radial_segments = 48
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("142630")
	floor_material.metallic = 0.7
	floor_material.roughness = 0.36
	floor_material.emission_enabled = true
	floor_material.emission = Color("123641")
	floor_material.emission_energy_multiplier = 0.28
	floor_mesh.material = floor_material
	floor.mesh = floor_mesh
	floor.position.y = -0.08
	world.add_child(floor)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 2.68
	ring_mesh.outer_radius = 2.72
	ring_mesh.rings = 48
	ring_mesh.ring_segments = 8
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = Color("d9f262")
	ring_material.emission_enabled = true
	ring_material.emission = Color("d9f262")
	ring_material.emission_energy_multiplier = 1.5
	ring_mesh.material = ring_material
	ring.mesh = ring_mesh
	ring.position.y = 0.02
	world.add_child(ring)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.3, 5.4)
	camera.fov = 31.0
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 1.02, 0.0))
	camera.current = true
	_actor = Actor.new()
	_actor.name = "CommandPreviewActor"
	world.add_child(_actor)
	_actor.setup(false, fighter_id)
	# 3/4 portrait angle, independent from combat-facing orientation.
	_actor.rotation.y = deg_to_rad(202.0)


func _add_preview_light(parent: Node3D, at: Vector3, color: Color, energy: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 9.0
	light.shadow_enabled = true
	parent.add_child(light)


func _process(delta: float) -> void:
	if not visible or selected_move == null or not is_instance_valid(_actor):
		return
	if _preview_playing:
		_preview_time += delta
		var total := maxi(1, selected_move.total_frames())
		_preview_frame = int(floor(_preview_time * 60.0)) % total
		_preview_selected_frame()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		back_requested.emit()
	elif event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		_toggle_preview()


func _fighter_changed(index: int) -> void:
	set_fighter(str(_fighter_picker.get_item_metadata(index)))


func _select_category(category: String) -> void:
	_category = category
	_refresh_move_list()


func _search_changed(value: String) -> void:
	_search = value.strip_edges().to_lower()
	_refresh_move_list()


func _toggle_preview() -> void:
	_preview_playing = not _preview_playing
	_play_button.text = "PAUSE" if _preview_playing else "PLAY"


func _scrub_preview(value: float) -> void:
	_preview_playing = false
	_play_button.text = "PLAY"
	_preview_frame = int(value)
	_preview_time = float(_preview_frame) / 60.0
	_preview_selected_frame()


func _open_training() -> void:
	if selected_move != null:
		training_requested.emit(fighter_id, selected_move.id)


func _refresh_fighter_summary() -> void:
	if _fighter_name == null:
		return
	var accent: Color = profile.get("color", Color("dff568"))
	_fighter_name.text = str(profile.get("name", "KAI")).to_upper()
	_fighter_name.add_theme_color_override("font_color", accent.lightened(0.28))
	_fighter_role.text = str(profile.get("archetype", "FIGHTER")).to_upper()
	_fighter_role.add_theme_color_override("font_color", accent)
	_fighter_description.text = str(profile.get("description", ""))
	_move_count.text = "%02d MOVES" % moves.size()


func _refresh_move_list() -> void:
	if _move_list == null:
		return
	for child: Node in _move_list.get_children():
		_move_list.remove_child(child)
		child.queue_free()
	_move_buttons.clear()
	for category: String in _category_buttons:
		var category_button: Button = _category_buttons[category]
		category_button.set_pressed_no_signal(category == _category)
	for move: MoveData in moves:
		if not _move_visible(move):
			continue
		var card := _make_move_card(move)
		_move_list.add_child(card)
		_move_buttons[move.id] = card
	if _move_buttons.is_empty():
		var empty := _label("NO COMMANDS MATCH THIS FILTER.", 12, Color("7d8b94"))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.custom_minimum_size.y = 72
		_move_list.add_child(empty)


func _make_move_card(move: MoveData) -> Button:
	var card := Button.new()
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.custom_minimum_size.y = 68
	card.tooltip_text = "Preview %s" % move.display_name
	var selected := move == selected_move
	var accent: Color = profile.get("color", Color("dff568"))
	card.add_theme_stylebox_override("normal", _box(Color("243440") if selected else Color("152029"), accent if selected else Color("344650"), 2 if selected else 1, 7, 10))
	card.add_theme_stylebox_override("hover", _box(Color("2a3a46"), Color("8aeaff"), 1, 7, 10))
	card.add_theme_stylebox_override("pressed", _box(Color("344954"), accent, 2, 7, 10))
	var input := _input_for(move)
	var line_two := "%s  •  %s" % [_category_label(move).to_upper(), _short_properties(move)]
	card.text = "[%s]  %s\n%s" % [input, move.display_name.to_upper(), line_two]
	card.pressed.connect(select_move.bind(move.id))
	return card


func _refresh_detail() -> void:
	if selected_move == null or _detail_title == null:
		return
	var move := selected_move
	var accent: Color = profile.get("color", Color("dff568"))
	_detail_title.text = move.display_name.to_upper()
	_detail_title.add_theme_color_override("font_color", accent.lightened(0.25))
	_detail_input.text = "INPUT  %s" % _input_for(move)
	_detail_badges.text = "  •  ".join(_property_tags(move)).to_upper()
	_detail_text.text = _detail_bbcode(move, accent)
	var total := maxi(1, move.total_frames())
	_frame_slider.max_value = total - 1
	_frame_slider.set_value_no_signal(clampf(float(_preview_frame), 0.0, float(total - 1)))
	_frame_label.text = "FRAME %02d / %02d  •  %s" % [_preview_frame + 1, total, move.phase_at(_preview_frame).to_upper()]


func _preview_selected_frame() -> void:
	if selected_move == null or not is_instance_valid(_actor):
		return
	_preview_frame = clampi(_preview_frame, 0, maxi(0, selected_move.total_frames() - 1))
	_actor.preview_move(selected_move, _preview_frame)
	if _frame_slider != null:
		_frame_slider.set_value_no_signal(_preview_frame)
	if _frame_label != null:
		_frame_label.text = "FRAME %02d / %02d  •  %s" % [_preview_frame + 1, selected_move.total_frames(), selected_move.phase_at(_preview_frame).to_upper()]


func _move_visible(move: MoveData) -> bool:
	if _category != "all" and _category_label(move) != _category:
		return false
	if _search.is_empty():
		return true
	var content := "%s %s %s %s %s" % [move.id, move.display_name, _purpose_for(move), _short_properties(move), " ".join(_property_tags(move))]
	return content.to_lower().contains(_search)


func _category_label(move: MoveData) -> String:
	var authored := str(_move_field(move, "category", "")).to_lower()
	if authored in ["normal", "heavy", "low", "light"]:
		return "normal"
	if authored in ["special", "special i", "special ii", "special_1", "special_2"]:
		return "special"
	if authored in ["movement", "mobility", "dodge"]:
		return "movement"
	if authored in ["super", "overdrive", "finisher"]:
		return "super"
	match move.id:
		"jab", "cross", "low_kick": return "normal"
		"dodge": return "movement"
		"finisher": return "super"
	return "special"


func _purpose_for(move: MoveData) -> String:
	var authored := str(_move_field(move, "purpose", "")).strip_edges()
	if not authored.is_empty():
		return authored
	if move.id == "finisher":
		return "Spend a full Power meter on a clean opening hit to trigger %s." % str(profile.get("super_name", move.display_name))
	if move.behavior == "projectile":
		return "A traveling special that controls the lane and forces an approach."
	if move.behavior == "grab":
		return "A close command grab that defeats grounded guard when you are in range."
	if move.behavior == "counter":
		return "Hold this counter stance to punish a predictable incoming strike."
	match move.id:
		"jab": return "Fast close-range check. Use it to interrupt advances and start pressure."
		"cross": return "Heavier reach and reward. Use it when a quick check will not reach."
		"low_kick": return "A low-line strike for checking movement and extending a simple string."
		"launcher": return "A vertical special that creates an airborne opening for a follow-up."
		"dodge": return "A movement reset. Use its evasive window to escape a committed attack."
		"burst": return "Your character signature special; use it to convert spacing into advantage."
	return "A core tool in this fighter's game plan."


func _coaching_for(move: MoveData) -> String:
	var authored := str(_move_field(move, "coaching_note", "")).strip_edges()
	if not authored.is_empty():
		return authored
	if move.energy_cost >= 100.0:
		return "Build Power through clean combat, then land the opening hit—guarding or whiffing will not start the cinematic."
	if move.behavior == "projectile":
		return "Use it from a distance where its travel time protects your recovery."
	if move.behavior == "grab":
		return "Condition the opponent to guard first, then step into its short range."
	if move.behavior == "counter":
		return "Do not throw it at random; wait for a repeatable attack timing."
	if move.invuln_start >= 0:
		return "The blue invulnerability window is a timing tool, not a passive shield."
	if move.launch_velocity > 0.0:
		return "Confirm the launch, then advance before the opponent lands."
	return "Practice the contact frame and recovery before relying on this move in a string."


func _property_tags(move: MoveData) -> PackedStringArray:
	var authored: Variant = _move_field(move, "tags", PackedStringArray())
	var tags: PackedStringArray = PackedStringArray()
	if authored is PackedStringArray:
		for tag: String in authored:
			tags.append(tag)
	elif authored is Array:
		for tag: Variant in authored:
			tags.append(str(tag))
	if tags.is_empty():
		tags.append({"strike": "STRIKE", "projectile": "PROJECTILE", "grab": "THROW", "counter": "COUNTER"}.get(move.behavior, "STRIKE"))
		if move.max_hits > 1: tags.append("%d-HIT" % move.max_hits)
		if move.launch_velocity > 0.0: tags.append("LAUNCH")
		if move.invuln_start >= 0: tags.append("INVULN")
		if move.armor_hits > 0: tags.append("ARMOR")
		if move.slow_frames > 0: tags.append("SLOW")
		if move.cross_through: tags.append("CROSS-THROUGH")
	return tags


func _short_properties(move: MoveData) -> String:
	var labels := _property_tags(move)
	var short: Array[String] = []
	for index: int in mini(2, labels.size()):
		short.append(labels[index])
	return " / ".join(short)


func _detail_bbcode(move: MoveData, accent: Color) -> String:
	var color := accent.to_html(false)
	var input := _input_for(move)
	var meter := "FREE"
	if move.energy_cost > 0.0:
		meter = "%d POWER" % roundi(move.energy_cost)
	var contact := "F%d–F%d" % [move.startup + 1, move.startup + move.active]
	var timing := "Startup [b]%df[/b]  •  Active [b]%df[/b]  •  Recovery [b]%df[/b]  •  Total [b]%df[/b]" % [move.startup, move.active, move.recovery, move.total_frames()]
	if move.active <= 0:
		contact = "No strike window"
	var properties := "Damage [b]%.1f[/b]  •  Hitstun [b]%df[/b]  •  Blockstun [b]%df[/b]  •  Hitstop [b]%df[/b]" % [move.damage, move.hitstun, move.blockstun, move.hitstop]
	var conditional: Array[String] = []
	if move.behavior == "strike" and move.damage > 0.0:
		conditional.append("Tip reach %.2f world units from origin (before movement)" % move.maximum_reach())
		if move.animated_hitbox:
			conditional.append("Attack box extends / retracts across active frames")
		if move.exposed_recovery_frames > 0:
			conditional.append("Limb exposed for first %df of recovery" % move.exposed_recovery_frames)
	if move.lunge_speed != 0.0:
		conditional.append("Lunge %.1f from F%d–F%d" % [move.lunge_speed, move.lunge_start + 1, move.lunge_end + 1])
	if move.invuln_start >= 0:
		conditional.append("Invulnerable F%d–F%d" % [move.invuln_start + 1, move.invuln_end + 1])
	if move.armor_hits > 0:
		conditional.append("Armor ×%d from F%d–F%d" % [move.armor_hits, move.armor_start + 1, move.armor_end + 1])
	if move.launch_velocity > 0.0:
		conditional.append("Launch %.1f" % move.launch_velocity)
	if move.slow_frames > 0:
		conditional.append("Slow %df × %.0f%%" % [move.slow_frames, move.slow_multiplier * 100.0])
	if move.max_hits > 1:
		conditional.append("%d hits / %df re-hit" % [move.max_hits, move.rehit_frames])
	if move.cross_through:
		conditional.append("Crosses through")
	if conditional.is_empty():
		conditional.append("Standard grounded interaction")
	var cancels := "No cancel route. Commit to the recovery."
	if move.cancel_start >= 0 and not move.cancel_into.is_empty():
		var destinations: Array[String] = []
		for id: String in move.cancel_into:
			var destination := _move_for_id(id)
			destinations.append(destination.display_name if destination != null else id.replace("_", " ").capitalize())
		cancels = "F%d–F%d → %s" % [move.cancel_start + 1, move.cancel_end + 1, ", ".join(destinations)]
	return "[color=#%s][b]PURPOSE[/b][/color]\n%s\n\n[color=#%s][b]COACHING[/b][/color]\n%s\n\n[color=#%s][b]INPUT & METER[/b][/color]\n[b][%s][/b]  •  %s\n\n[color=#%s][b]TIMING[/b][/color]\n%s\nContact: [b]%s[/b]\n\n[color=#%s][b]ON CONTACT[/b][/color]\n%s\n%s\n\n[color=#%s][b]CANCEL ROUTE[/b][/color]\n%s" % [color, _purpose_for(move), color, _coaching_for(move), color, input, meter, color, timing, contact, color, properties, " • ".join(conditional), color, cancels]


func _input_for(move: MoveData) -> String:
	var authored := str(_move_field(move, "command", "")).strip_edges()
	var binding := "[%s]" % _binding_for_move(move.id)
	return binding if authored.is_empty() or authored.to_upper() == _binding_for_move(move.id) else "%s  %s" % [binding, authored]


func _binding_for_move(move_id: String) -> String:
	var value: Variant = binding_labels.get(move_id, null)
	var move := _move_for_id(move_id)
	var action := str(_move_field(move, "input_action", "")) if move != null else ""
	if value == null and not action.is_empty():
		value = binding_labels.get(action, null)
	if value == null and move != null and not move.command_base.is_empty():
		value = binding_labels.get(move.command_base, null)
	if value == null:
		value = binding_labels.get("p1_" + move_id, null)
	if value == null:
		for parent_key: String in ["p1", "player1", "player_1", "keyboard", "actions", "moves"]:
			var nested: Variant = binding_labels.get(parent_key, null)
			if nested is Dictionary and nested.has(move_id):
				value = nested[move_id]
				break
			if nested is Dictionary and not action.is_empty() and nested.has(action):
				value = nested[action]
				break
	if value is Dictionary:
		value = value.get("label", value.get("primary", value.get("display", "")))
	var label := str(value).strip_edges()
	return label.to_upper() if not label.is_empty() else str(DEFAULT_BINDINGS.get(move_id, "—"))


func _move_field(move: MoveData, field: String, fallback: Variant) -> Variant:
	# MoveData gains presentation fields over time.  Probe by property-list rather
	# than hard-reference them so this screen remains compatible with saved moves
	# from earlier prototype builds.
	for property: Dictionary in move.get_property_list():
		if str(property.get("name", "")) == field:
			return move.get(field)
	return fallback


func _move_for_id(move_id: String) -> MoveData:
	for move: MoveData in moves:
		if move.id == move_id:
			return move
	return null


func _sync_fighter_picker() -> void:
	if _fighter_picker == null:
		return
	for index: int in range(_fighter_picker.item_count):
		if str(_fighter_picker.get_item_metadata(index)) == fighter_id:
			_fighter_picker.select(index)
			return


func _focus_current_move() -> void:
	var current: Button = _move_buttons.get(get_selected_move_id(), null)
	if current != null:
		current.grab_focus()


func _label(value: String, size: int = 14, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _box(fill: Color, border: Color = Color.TRANSPARENT, width: int = 0, radius: int = 6, padding: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box
