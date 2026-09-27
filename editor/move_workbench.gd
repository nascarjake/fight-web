class_name MoveWorkbench
extends PanelContainer
## Native runtime editor. Edits mutate the supplied resources so playback sees changes immediately.

signal move_selected(move: MoveData)
signal move_changed(move: MoveData)
signal scrubbed(frame: int)
signal playback_toggled(playing: bool)
signal step_requested()
signal reset_requested()
signal debug_toggled(enabled: bool)
signal mode_changed(mode: String)
signal dummy_changed(mode: String)

const TimelineScript = preload("res://editor/frame_timeline.gd")
const ACCENT := Color("d6ed68")
const INK := Color("e5e9e4")
const MUTED := Color("8d9a9f")
const SAVE_DIR := "user://moves"

var save_namespace: String = "":
	set(value):
		if not value.is_empty() and not _safe_id(value):
			_message("Invalid fighter save namespace.", true)
			return
		save_namespace = value
var _moves: Array[MoveData] = []
var _selected: MoveData
var _animation_names: PackedStringArray = []
var _fields: Dictionary[StringName, Control] = {}
var _syncing: bool = false
var _playing: bool = false
var _built: bool = false
var _pending_status: String = "Edits apply immediately to the selected move."
var _pending_color: Color = MUTED
var _mode: String = "preview"
var _move_picker: OptionButton
var _animation_picker: OptionButton
var _timeline: Control
var _phase_label: Label
var _frame_label: Label
var _total_label: Label
var _status: Label
var _play: Button
var _summary: Label
var _form: VBoxContainer
var _preview_button: Button
var _training_button: Button

func _ready() -> void:
	_build()
	_built = true
	_populate_moves()
	set_status(_pending_status)

func setup(moves: Array[MoveData], load_saved: bool = true) -> void:
	_moves = moves
	if load_saved: _load_overrides(false)
	if _built:
		_populate_moves()

func set_save_namespace(value: String) -> void:
	save_namespace = value

func _save_directory() -> String:
	return SAVE_DIR if save_namespace.is_empty() else SAVE_DIR.path_join(save_namespace)

func selected_move() -> MoveData:
	return _selected

func select_move_id(id: String, emit_selection: bool = true) -> bool:
	for index: int in range(_moves.size()):
		if _moves[index].id == id:
			_selected = _moves[index]
			if _built:
				_move_picker.select(index)
				_select_index(index, emit_selection)
			return true
	return false

func set_mode(mode: String) -> void:
	if mode not in ["preview", "training"]:
		return
	_mode = mode
	if _built:
		_preview_button.set_pressed_no_signal(mode == "preview")
		_training_button.set_pressed_no_signal(mode == "training")

func set_animation_names(names: PackedStringArray) -> void:
	_animation_names = names
	if _built:
		_sync_animation_picker()

func set_playing(playing: bool) -> void:
	_playing = playing
	if _built:
		_play.text = "Ⅱ  PAUSE" if playing else "▶  PLAY"

func update_playhead(frame: int, phase: String) -> void:
	if not _built:
		return
	_timeline.set_playhead(frame)
	_frame_label.text = "F %03d" % frame
	_phase_label.text = phase.to_upper()
	var color: Color = MUTED
	match phase.to_lower():
		"startup": color = Color("dfbd66")
		"active": color = Color("f07768")
		"recovery": color = Color("7186a2")
	_phase_label.add_theme_color_override("font_color", color)

func set_status(text_value: String) -> void:
	_pending_status = text_value
	if _built:
		_status.text = text_value
		_status.add_theme_color_override("font_color", _pending_color)

func _message(text_value: String, error: bool = false) -> void:
	_pending_color = Color("fa9788") if error else ACCENT
	set_status(text_value)

func _style(color: Color, border: Color = Color.TRANSPARENT, radius: int = 6) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1 if border.a > 0 else 0)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	return box

func _make_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 13
	result.set_color("font_color", "Label", INK)
	result.set_color("font_color", "Button", INK)
	result.set_color("font_hover_color", "Button", Color.WHITE)
	result.set_color("font_focus_color", "Button", INK)
	result.set_color("font_pressed_color", "Button", Color("12171b"))
	result.set_color("font_disabled_color", "Button", MUTED)
	result.set_stylebox("normal", "Button", _style(Color("292f34"), Color("3a4348")))
	result.set_stylebox("hover", "Button", _style(Color("384148"), Color("6e7b7a")))
	result.set_stylebox("pressed", "Button", _style(ACCENT, ACCENT))
	result.set_stylebox("focus", "Button", _style(Color.TRANSPARENT, ACCENT))
	result.set_stylebox("disabled", "Button", _style(Color("20262b")))
	result.set_color("font_color", "OptionButton", INK)
	result.set_color("font_pressed_color", "OptionButton", INK)
	result.set_stylebox("normal", "OptionButton", _style(Color("252c31"), Color("46524f")))
	result.set_stylebox("hover", "OptionButton", _style(Color("333d40"), ACCENT))
	result.set_stylebox("pressed", "OptionButton", _style(Color("303b39"), ACCENT))
	result.set_stylebox("focus", "OptionButton", _style(Color.TRANSPARENT, ACCENT))
	result.set_color("font_color", "LineEdit", INK)
	result.set_color("font_placeholder_color", "LineEdit", MUTED)
	result.set_color("caret_color", "LineEdit", ACCENT)
	result.set_color("selection_color", "LineEdit", Color("526337"))
	result.set_stylebox("normal", "LineEdit", _style(Color("141a1f"), Color("343e45"), 4))
	result.set_stylebox("focus", "LineEdit", _style(Color("1a2226"), ACCENT, 4))
	result.set_stylebox("panel", "PopupMenu", _style(Color("21292e"), Color("53615d")))
	result.set_color("font_color", "PopupMenu", INK)
	result.set_color("font_hover_color", "PopupMenu", Color("141a1f"))
	result.set_stylebox("hover", "PopupMenu", _style(ACCENT))
	result.set_constant("separation", "VBoxContainer", 8)
	result.set_constant("separation", "HBoxContainer", 8)
	return result

func _build() -> void:
	theme = _make_theme()
	custom_minimum_size = Vector2(366, 0)
	add_theme_stylebox_override("panel", _style(Color("1b2227"), Color("3a4548"), 0))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 11)
	margin.add_child(column)
	var eyebrow := _label("WORKBENCH  /  01", 11, ACCENT)
	column.add_child(eyebrow)
	var title := HBoxContainer.new()
	column.add_child(title)
	var heading := _label("Move lab", 27, INK)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(heading)
	title.add_child(_label("60 HZ", 11, MUTED))
	var mode_row := HBoxContainer.new()
	column.add_child(mode_row)
	_preview_button = _button("PREVIEW", _choose_mode.bind("preview"))
	_training_button = _button("TRAINING", _choose_mode.bind("training"))
	_preview_button.toggle_mode = true
	_training_button.toggle_mode = true
	_preview_button.button_pressed = _mode == "preview"
	_training_button.button_pressed = _mode == "training"
	mode_row.add_child(_preview_button)
	mode_row.add_child(_training_button)
	_move_picker = OptionButton.new()
	_move_picker.custom_minimum_size.y = 39
	_move_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_move_picker.item_selected.connect(_on_move_selected)
	column.add_child(_move_picker)
	var state_row := HBoxContainer.new()
	column.add_child(state_row)
	_frame_label = _label("F 000", 20, INK)
	_frame_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_row.add_child(_frame_label)
	_phase_label = _label("READY", 11, MUTED)
	state_row.add_child(_phase_label)
	_timeline = TimelineScript.new()
	_timeline.scrubbed.connect(_on_scrub)
	column.add_child(_timeline)
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 12)
	column.add_child(legend)
	legend.add_child(_label("■ Startup", 10, Color("dfbd66")))
	legend.add_child(_label("■ Active", 10, Color("f07768")))
	legend.add_child(_label("■ Recovery", 10, Color("7186a2")))
	legend.add_child(_label("━ Invuln", 10, Color("77d9d0")))
	var playback := HBoxContainer.new()
	column.add_child(playback)
	_play = _button("▶  PLAY", _toggle_play)
	playback.add_child(_play)
	playback.add_child(_button("STEP +1", _step))
	playback.add_child(_button("RESET", _reset))
	_total_label = _label("0 frames  ·  frame 0 is the first frame", 10, MUTED)
	column.add_child(_total_label)
	var separator := HSeparator.new()
	column.add_child(separator)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	_form = VBoxContainer.new()
	_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_form.add_theme_constant_override("separation", 10)
	scroll.add_child(_form)
	_build_fields()
	var save_row := HBoxContainer.new()
	column.add_child(save_row)
	var save := _button("SAVE MOVE", _save_move)
	save.add_theme_stylebox_override("normal", _style(ACCENT, ACCENT))
	save.add_theme_color_override("font_color", Color("171e1b"))
	save.add_theme_color_override("font_hover_color", Color("171e1b"))
	save.add_theme_stylebox_override("hover", _style(Color("e3f699"), ACCENT))
	save_row.add_child(save)
	save_row.add_child(_button("RELOAD SAVED", _reload_saved))
	_status = _label(_pending_status, 11, _pending_color)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 32
	column.add_child(_status)

func _build_fields() -> void:
	_section("01", "MOVE PROPERTIES")
	_summary = _label("", 11, MUTED)
	_form.add_child(_summary)
	_text_field("Display name", &"display_name")
	_form.add_child(_label("Animation clip", 11, MUTED))
	_animation_picker = OptionButton.new()
	_animation_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_animation_picker.item_selected.connect(_on_animation_selected)
	_form.add_child(_animation_picker)
	_pair("Startup", &"startup", 0, 240, "Active", &"active", 0, 240)
	_pair("Recovery", &"recovery", 0, 360, "Blend frames", &"animation_blend_frames", 0, 60)
	_section("02", "HIT & RESOURCE DATA")
	_pair("Damage", &"damage", 0, 1000, "Energy cost", &"energy_cost", 0, 1000, 1, 1)
	_pair("Hitstun", &"hitstun", 0, 600, "Blockstun", &"blockstun", 0, 600)
	_pair("Hitstop", &"hitstop", 0, 120, "Knockback", &"knockback", 0, 30, 1, 0.1)
	_section("03", "FRAME WINDOWS")
	_note("Inclusive frame indices · -1 disables a window.")
	_pair("Invuln from", &"invuln_start", -1, 600, "Through", &"invuln_end", -1, 600)
	_pair("Cancel from", &"cancel_start", -1, 600, "Through", &"cancel_end", -1, 600)
	_text_field("Cancel into · comma-separated move IDs", &"cancel_into")
	_note("Cyan = invulnerability · acid = cancel window")
	_section("04", "HITBOX")
	_note("World units · X follows facing · Y is height")
	_vector_pair("Offset X", "Offset Y", &"hitbox_offset", -10, 10)
	_vector_pair("Width", "Height", &"hitbox_size", 0.05, 10)
	var animate := CheckButton.new()
	animate.text = "Animate extension / retraction"
	animate.toggled.connect(func(value: bool) -> void:
		if not _syncing and _selected != null:
			_selected.animated_hitbox = value
			_on_edited())
	_form.add_child(animate)
	_fields[&"animated_hitbox"] = animate
	_vector_pair("Entry delta X", "Entry delta Y", &"hitbox_entry_delta", -5, 5)
	_vector_pair("Exit delta X", "Exit delta Y", &"hitbox_exit_delta", -5, 5)
	_vector_pair("Edge width scale", "Edge height scale", &"hitbox_edge_scale", 0.05, 1)
	_note("Base box = full extension. First/last active frames use the edge scales and offsets.")
	_section("05", "HURTBOX")
	_vector_pair("Offset X", "Offset Y", &"hurtbox_offset", -10, 10)
	_vector_pair("Width", "Height", &"hurtbox_size", 0.05, 10)
	_vector_pair("Exposed limb width", "Limb height", &"exposed_limb_size", 0, 5)
	var exposure := HBoxContainer.new()
	_form.add_child(exposure)
	_spin(_field_column(exposure, "Exposed recovery frames"), &"exposed_recovery_frames", 0, 120, 1)
	_note("The limb becomes vulnerable two frames before contact and retracts during recovery. Zero size disables it.")
	_section("06", "TRAINING OPTIONS")
	var debug := CheckButton.new()
	debug.text = "Show hitboxes & hurtboxes"
	debug.button_pressed = true
	debug.toggled.connect(func(value: bool) -> void: debug_toggled.emit(value))
	_form.add_child(debug)
	_form.add_child(_label("Dummy behavior", 11, MUTED))
	var dummy := OptionButton.new()
	dummy.add_item("Stand")
	dummy.add_item("Block")
	dummy.add_item("Attack")
	dummy.item_selected.connect(func(index: int) -> void: dummy_changed.emit(["stand", "block", "attack"][index]))
	_form.add_child(dummy)
	_note("Save writes this move to the app's user data folder. Reload restores saved overrides.")

func _label(value: String, font_size: int = 13, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 34
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 11)
	button.pressed.connect(action)
	return button

func _section(number: String, title: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if _form.get_child_count() > 0:
		var spacer := Control.new()
		spacer.custom_minimum_size.y = 4
		_form.add_child(spacer)
	_form.add_child(row)
	row.add_child(_label(number, 11, ACCENT))
	row.add_child(_label(title, 11, INK))

func _note(value: String) -> void:
	var note := _label(value, 10, MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_form.add_child(note)

func _field_column(parent: HBoxContainer, title: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.0
	parent.add_child(column)
	column.add_child(_label(title, 11, MUTED))
	return column

func _spin(parent: VBoxContainer, property: StringName, minimum: float, maximum: float, step: float, component: int = -1) -> void:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.allow_greater = true
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.get_line_edit().alignment = HORIZONTAL_ALIGNMENT_LEFT
	spin.value_changed.connect(_on_number_changed.bind(property, component))
	parent.add_child(spin)
	var key: StringName = StringName("%s_%d" % [property, component]) if component >= 0 else property
	_fields[key] = spin

func _pair(left_label: String, left: StringName, min_left: float, max_left: float, right_label: String, right: StringName, min_right: float, max_right: float, left_step: float = 1, right_step: float = 1) -> void:
	var row := HBoxContainer.new()
	_form.add_child(row)
	_spin(_field_column(row, left_label), left, min_left, max_left, left_step)
	_spin(_field_column(row, right_label), right, min_right, max_right, right_step)

func _vector_pair(x_label: String, y_label: String, property: StringName, minimum: float, maximum: float) -> void:
	var row := HBoxContainer.new()
	_form.add_child(row)
	_spin(_field_column(row, x_label), property, minimum, maximum, 0.05, 0)
	_spin(_field_column(row, y_label), property, minimum, maximum, 0.05, 1)

func _text_field(title: String, property: StringName) -> void:
	_form.add_child(_label(title, 11, MUTED))
	var field := LineEdit.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.text_changed.connect(_on_text_changed.bind(property))
	_form.add_child(field)
	_fields[property] = field

func _populate_moves() -> void:
	_move_picker.clear()
	for move: MoveData in _moves:
		_move_picker.add_item(move.display_name)
	if not _moves.is_empty():
		var index: int = maxi(_moves.find(_selected), 0)
		_move_picker.select(index)
		_on_move_selected(index)

func _on_move_selected(index: int) -> void:
	_select_index(index, true)

func _select_index(index: int, emit_selection: bool) -> void:
	if index < 0 or index >= _moves.size():
		return
	_selected = _moves[index]
	_sync_fields()
	update_playhead(0, _selected.phase_at(0))
	if emit_selection:
		move_selected.emit(_selected)

func _sync_fields() -> void:
	if _selected == null:
		return
	_syncing = true
	for key: StringName in _fields:
		var control: Control = _fields[key]
		if control is SpinBox:
			var spin: SpinBox = control as SpinBox
			var property_name: String = str(key)
			if property_name.ends_with("_0") or property_name.ends_with("_1"):
				var property: StringName = StringName(property_name.left(-2))
				var vector: Vector2 = _selected.get(property)
				spin.set_value_no_signal(vector.x if property_name.ends_with("_0") else vector.y)
			else:
				spin.set_value_no_signal(float(_selected.get(key)))
		elif control is CheckButton:
			(control as CheckButton).set_pressed_no_signal(bool(_selected.get(key)))
		elif control is LineEdit:
			var edit: LineEdit = control as LineEdit
			edit.text = ", ".join(_selected.cancel_into) if key == &"cancel_into" else str(_selected.get(key))
	_sync_animation_picker()
	_syncing = false
	_refresh_move_summary()

func _sync_animation_picker() -> void:
	if _animation_picker == null:
		return
	_animation_picker.clear()
	var names: PackedStringArray = _animation_names.duplicate()
	if _selected != null and not names.has(_selected.animation_name):
		names.append(_selected.animation_name)
	if names.is_empty():
		names.append("idle")
	for name_value: String in names:
		_animation_picker.add_item(name_value)
	if _selected != null:
		_animation_picker.select(names.find(_selected.animation_name))

func _refresh_move_summary() -> void:
	_timeline.set_move(_selected)
	_total_label.text = "%d frames  ·  %.3f s  ·  first frame = 0" % [_selected.total_frames(), float(_selected.total_frames()) / 60.0]
	_summary.text = "ID  /  " + _selected.id
	var index: int = _moves.find(_selected)
	if index >= 0:
		_move_picker.set_item_text(index, _selected.display_name)

func _on_number_changed(value: float, property: StringName, component: int) -> void:
	if _syncing or _selected == null:
		return
	if component >= 0:
		var vector: Vector2 = _selected.get(property)
		if component == 0:
			vector.x = value
		else:
			vector.y = value
		_selected.set(property, vector)
	elif property in [&"damage", &"knockback", &"energy_cost"]:
		_selected.set(property, value)
	else:
		_selected.set(property, int(value))
	_on_edited()

func _on_text_changed(value: String, property: StringName) -> void:
	if _syncing or _selected == null:
		return
	if property == &"cancel_into":
		var ids: PackedStringArray = []
		for part: String in value.split(",", false):
			var id: String = part.strip_edges()
			if not id.is_empty():
				ids.append(id)
		_selected.cancel_into = ids
	else:
		_selected.set(property, value)
	_on_edited()

func _on_animation_selected(index: int) -> void:
	if _selected != null and not _syncing:
		_selected.animation_name = _animation_picker.get_item_text(index)
		_on_edited()

func _on_edited() -> void:
	_refresh_move_summary()
	var errors: PackedStringArray = _selected.validation_errors()
	if errors.is_empty():
		_message("Unsaved changes · applied to live playback.")
	else:
		_message("Check move: " + "; ".join(errors), true)
	move_changed.emit(_selected)

func _choose_mode(mode: String) -> void:
	set_mode(mode)
	mode_changed.emit(mode)

func _toggle_play() -> void:
	set_playing(not _playing)
	playback_toggled.emit(_playing)

func _on_scrub(frame: int) -> void:
	set_playing(false)
	playback_toggled.emit(false)
	if _selected != null:
		update_playhead(frame, _selected.phase_at(frame))
	scrubbed.emit(frame)

func _step() -> void:
	set_playing(false)
	playback_toggled.emit(false)
	step_requested.emit()

func _reset() -> void:
	set_playing(false)
	playback_toggled.emit(false)
	reset_requested.emit()

func _safe_id(id: String) -> bool:
	if id.is_empty() or id.length() > 80:
		return false
	for character: String in id:
		if not "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-".contains(character):
			return false
	return true

func _save_move() -> void:
	if _selected == null:
		_message("Select a move before saving.", true)
		return
	var errors: PackedStringArray = _selected.validation_errors()
	if not errors.is_empty():
		_message("Save blocked: " + "; ".join(errors), true)
		return
	if not _safe_id(_selected.id):
		_message("Save blocked: move ID must contain only letters, numbers, hyphens, and underscores.", true)
		return
	var directory: String = _save_directory()
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if directory_error != OK:
		_message("Could not create save folder: " + error_string(directory_error), true)
		return
	var path: String = directory.path_join(_selected.id + ".tres")
	var result: Error = ResourceSaver.save(_selected, path)
	if result != OK:
		_message("Save failed: " + error_string(result), true)
		return
	_message("Saved " + _selected.id + ".tres · " + directory)
	_status.tooltip_text = ProjectSettings.globalize_path(path)

func _reload_saved() -> void:
	_load_overrides(true)
	_sync_fields()
	if _selected != null:
		move_changed.emit(_selected)

func _load_overrides(report: bool) -> void:
	var loaded_count: int = 0
	var failures: PackedStringArray = []
	for move: MoveData in _moves:
		if not _safe_id(move.id):
			failures.append("Unsafe move ID: " + move.id)
			continue
		var path: String = _save_directory().path_join(move.id + ".tres")
		# Only Kai can inherit the original single-fighter workbench saves.
		if not FileAccess.file_exists(path) and save_namespace == "kai":
			path = SAVE_DIR.path_join(move.id + ".tres")
		if not FileAccess.file_exists(path):
			continue
		var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if not resource is MoveData:
			failures.append(move.id + ": file is not a MoveData resource")
			continue
		var override: MoveData = resource as MoveData
		var errors: PackedStringArray = override.validation_errors()
		if override.id != move.id:
			errors.append("ID does not match filename")
		if not errors.is_empty():
			failures.append(move.id + ": " + "; ".join(errors))
			continue
		for property: Dictionary in override.get_property_list():
			var usage: int = int(property["usage"])
			var property_name: StringName = StringName(property["name"])
			if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_STORAGE:
				move.set(property_name, override.get(property_name))
		loaded_count += 1
	if not failures.is_empty():
		_message("Loaded %d · Rejected: %s" % [loaded_count, " | ".join(failures)], true)
	elif report or loaded_count > 0:
		_message("Loaded %d saved move%s." % [loaded_count, "" if loaded_count == 1 else "s"])
