class_name GameUI
extends Control
## Native front end and combat HUD. The parent owns the 3D scene and gameplay input.

signal mode_selected(mode: String)
signal fighter_confirmed
signal fighter_changed(id: String, slot: int)
signal stage_selected(index: int)
signal fight_requested
signal menu_requested
signal rematch_requested
signal next_requested
signal lab_requested
signal training_requested
signal command_requested
signal control_settings_requested
signal quit_requested
signal pause_requested
signal resume_requested
signal music_toggled(enabled: bool)
signal difficulty_changed(index: int)
signal selection_step_changed(step: String)

const ACID := Color("dcf344")
const WHITE := Color("f4f2e9")
const RED := Color("fa4d48")
const INK := Color("111416")
const MUTED := Color("91969a")
const BLUE := Color("8fbde2")

class SlashPanel extends Control:
	var fill := Color(0.025, 0.03, 0.033, 0.9)
	var cut: float = 76.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x - cut, size.y), Vector2(0, size.y)]), fill)
		draw_line(Vector2(size.x - 7, 0), Vector2(size.x - cut - 7, size.y), Color(0.86, 0.95, 0.26, 0.22), 1)

class SlashButton extends Button:
	var title_font: Font
	var body_font: Font
	var caption: String = ""
	var title_size: int = 29
	var primary: bool = false
	func _ready() -> void:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for style_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
		for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			add_theme_color_override(color_name, Color.TRANSPARENT)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		toggled.connect(func(_value: bool) -> void: queue_redraw())
		resized.connect(queue_redraw)
	func _draw() -> void:
		var hot: bool = (has_focus() or is_hovered() or button_pressed or primary) and not disabled
		var fill: Color = GameUI.ACID if hot else Color(0.08, 0.095, 0.1, 0.85)
		var foreground: Color = GameUI.INK if hot else GameUI.WHITE
		draw_colored_polygon(PackedVector2Array([Vector2(8, 0), Vector2(size.x, 0), Vector2(size.x - 12, size.y), Vector2(0, size.y)]), fill)
		draw_line(Vector2(8, 0), Vector2(size.x, 0), Color(1, 1, 1, 0.12), 1)
		var baseline: float = size.y * 0.5 + title_size * 0.35 if caption.is_empty() else 31.0
		draw_string(title_font, Vector2(22, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, maxf(size.x - 64, 1), title_size, foreground)
		if not caption.is_empty():
			draw_string(body_font, Vector2(23, size.y - 11), caption, HORIZONTAL_ALIGNMENT_LEFT, maxf(size.x - 52, 1), 11, Color("39402d") if hot else GameUI.MUTED)
		draw_string(body_font, Vector2(size.x - 37, size.y * 0.5 + 5), "/", HORIZONTAL_ALIGNMENT_LEFT, 22, 23, foreground)

var _built: bool = false
var _mode: String = "cpu"
var _music_enabled: bool = true
var _difficulty: int = 1
var _stage_index: int = 0
var _stage_names: PackedStringArray = []
var _display_font: Font
var _body_font: Font
var _main: Control
var _select: Control
var _fighter_select: Control
var _stage_select: Control
var _hud: Control
var _result: Control
var _pause: Control
var _settings: Control
var _controls: Control
var _announcement: Control
var _main_panel: SlashPanel
var _main_content: VBoxContainer
var _main_title: Label
var _main_name: VBoxContainer
var _main_nameplate: SlashPanel
var _main_note: Label
var _main_note_backing: SlashPanel
var _select_left_backing: ColorRect
var _select_opponent_backing: SlashPanel
var _select_heading: Label
var _select_bio: VBoxContainer
var _select_opponent: VBoxContainer
var _roster: GridContainer
var _roster_backing: ColorRect
var _select_footer: HBoxContainer
var _select_mode_label: Label
var _stage_heading: Label
var _stage_note: Label
var _stage_cards: HBoxContainer
var _stage_footer: HBoxContainer
var _stage_buttons: Array[SlashButton] = []
var _hud_top: HBoxContainer
var _hud_backing: ColorRect
var _health: Array[ProgressBar] = []
var _guard: Array[ProgressBar] = []
var _energy: Array[ProgressBar] = []
var _gauge_labels: Array[Label] = []
var _power_labels: Array[Label] = []
var _win_markers: Array[Label] = []
var _combo_labels: Array[Label] = []
var _p2_identity: Label
var _timer: Label
var _round: Label
var _hud_mode: Label
var _hud_pause: Button
var _result_panel: SlashPanel
var _result_content: VBoxContainer
var _result_title: Label
var _result_caption: Label
var _result_actions: VBoxContainer
var _music_check: CheckButton
var _difficulty_picker: OptionButton
var _announcement_title: Label
var _announcement_subtitle: Label
var _announcement_tween: Tween
var _modal_return: Control
var _fighter_ids: Array[String] = ["kai", "neon"]
var _selection_slot: int = 0
var _roster_buttons: Array[Button] = []
var _roster_ids: Array[String] = []
var _confirm_button: SlashButton
var _player_names: Array[Label] = []
var _bio_role: Label
var _bio_name: Label
var _bio_style: Label
var _bio_description: Label
var _bio_moves: Label
var _matchup_name: Label
var _matchup_description: Label
var _cinematic: Control
var _cinematic_name: Label
var _cinematic_fighter: Label
var _cinematic_rule: ColorRect

func _ready() -> void:
	_ensure_built()
	resized.connect(_layout)
	_layout()

func _ensure_built() -> void:
	if _built:
		return
	_built = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_create_theme()
	_build_main()
	_build_selection()
	_build_hud()
	_build_result()
	_build_cinematic()
	_build_pause()
	_build_settings()
	_build_controls()
	_build_announcement()
	_hide_screens()
	_layout()

func _create_theme() -> void:
	var heading := SystemFont.new()
	heading.font_names = PackedStringArray(["Impact", "Avenir Next Condensed", "Arial Narrow", "sans-serif"])
	heading.font_weight = 800
	_display_font = heading
	var body := SystemFont.new()
	body.font_names = PackedStringArray(["Helvetica Neue", "Arial", "sans-serif"])
	_body_font = body
	var ui_theme := Theme.new()
	ui_theme.default_font = _body_font
	ui_theme.default_font_size = 14
	ui_theme.set_color("font_color", "Label", WHITE)
	ui_theme.set_color("font_color", "Button", WHITE)
	ui_theme.set_color("font_hover_color", "Button", ACID)
	ui_theme.set_color("font_focus_color", "Button", ACID)
	ui_theme.set_stylebox("normal", "Button", _box(Color(0.08, 0.09, 0.1, 0.84), Color("353b3e")))
	ui_theme.set_stylebox("hover", "Button", _box(Color("222729"), ACID))
	ui_theme.set_stylebox("focus", "Button", _box(Color.TRANSPARENT, ACID))
	ui_theme.set_stylebox("pressed", "Button", _box(Color("3c4430"), ACID))
	ui_theme.set_stylebox("panel", "PopupMenu", _box(Color("171c1f"), Color("555e55")))
	ui_theme.set_color("font_color", "PopupMenu", WHITE)
	ui_theme.set_stylebox("hover", "PopupMenu", _box(Color("354035"), ACID))
	ui_theme.set_color("font_color", "OptionButton", WHITE)
	ui_theme.set_stylebox("normal", "OptionButton", _box(Color("212729"), Color("424a43")))
	ui_theme.set_stylebox("focus", "OptionButton", _box(Color.TRANSPARENT, ACID))
	ui_theme.set_constant("separation", "VBoxContainer", 9)
	ui_theme.set_constant("separation", "HBoxContainer", 12)
	theme = ui_theme

func _box(fill: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1 if border.a > 0 else 0)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box

func _screen() -> Control:
	var screen := Control.new()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	return screen

func _fade(parent: Control, fade_right: bool = false) -> ColorRect:
	var backing := ColorRect.new()
	backing.color = Color(0.02, 0.027, 0.034, 0.93)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ COLOR.a *= 1.0-smoothstep(0.60,1.0,UV.y); }"
	if fade_right:
		shader.code = "shader_type canvas_item; void fragment(){ COLOR.a *= (1.0-smoothstep(0.74,1.0,UV.x))*(1.0-smoothstep(0.79,1.0,UV.y)); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	backing.material = material
	parent.add_child(backing)
	return backing

func _label(value: String, font_size: int = 14, color: Color = WHITE, display: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_override("font", _display_font if display else _body_font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _heading(value: String, font_size: int = 72, color: Color = WHITE) -> Label:
	var label: Label = _label(value, font_size, color, true)
	label.add_theme_constant_override("line_spacing", -12)
	return label

func _slash(value: String, action: Callable, caption: String = "", primary: bool = false, height: float = 64) -> SlashButton:
	var button := SlashButton.new()
	button.text = value
	button.caption = caption
	button.primary = primary
	button.title_font = _display_font
	button.body_font = _body_font
	button.custom_minimum_size = Vector2(200, height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(action)
	return button

func _button(value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 40
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	return button

func _spacer(parent: Container, height: float) -> void:
	var control := Control.new()
	control.custom_minimum_size.y = height
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(control)

func _build_main() -> void:
	_main = _screen()
	_main_panel = SlashPanel.new()
	_main.add_child(_main_panel)
	_main_content = VBoxContainer.new()
	_main_content.add_theme_constant_override("separation", 9)
	_main.add_child(_main_content)
	_main_content.add_child(_label("R I F T   R I O T     /     N A T I V E", 11, ACID))
	_main_title = _heading("RIFT\n//RIOT", 108)
	_main_title.add_theme_constant_override("line_spacing", -34)
	_main_content.add_child(_main_title)
	_main_content.add_child(_label("FIND YOUR OPENING. MAKE IT COUNT.", 11, MUTED))
	_spacer(_main_content, 10)
	_main_content.add_child(_slash("VERSUS CPU", func() -> void: mode_selected.emit("cpu"), "ONE MATCH. YOU AGAINST THE MACHINE."))
	_main_content.add_child(_slash("LOCAL VERSUS", func() -> void: mode_selected.emit("local"), "TWO PLAYERS. ONE SCREEN."))
	_main_content.add_child(_slash("ARCADE", func() -> void: mode_selected.emit("arcade"), "FIGHT YOUR WAY THROUGH THE CIRCUIT."))
	_spacer(_main_content, 4)
	var utility := HBoxContainer.new()
	_main_content.add_child(utility)
	for item: Array in [["TRAINING", func() -> void: training_requested.emit()], ["FIGHTER COMMAND", func() -> void: command_requested.emit()]]:
		var button: Button = _button(str(item[0]), item[1])
		button.add_theme_font_size_override("font_size", 11)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		utility.add_child(button)
	var system_row := HBoxContainer.new()
	_main_content.add_child(system_row)
	for item: Array in [["SETTINGS", _show_settings], ["QUIT", func() -> void: quit_requested.emit()]]:
		var button: Button = _button(str(item[0]), item[1])
		button.add_theme_font_size_override("font_size", 11)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		system_row.add_child(button)
	var controls_button: Button = _button("HOW TO PLAY    /    KEYBOARD + GAMEPAD", show_controls)
	controls_button.add_theme_font_size_override("font_size", 11)
	controls_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_main_content.add_child(controls_button)
	_main_nameplate = SlashPanel.new()
	_main_nameplate.cut = 24
	_main_nameplate.fill = Color(0.035, 0.045, 0.05, 0.78)
	_main.add_child(_main_nameplate)
	_main_name = VBoxContainer.new()
	_main.add_child(_main_name)
	_main_name.add_child(_label("THE NEXT CONTENDER", 11, ACID))
	_main_name.add_child(_heading("KAI", 66))
	_main_name.add_child(_label("AVATAR C     ·     ALL-ROUNDER", 12, WHITE))
	_main_note_backing = SlashPanel.new()
	_main_note_backing.cut = 12
	_main_note_backing.fill = Color(0.025, 0.035, 0.04, 0.82)
	_main.add_child(_main_note_backing)
	_main_note = _label("10 FIGHTERS AVAILABLE\n02 MORE / COMING SOON", 11, Color("b3babc"))
	_main_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_main.add_child(_main_note)

func _build_selection() -> void:
	_select = _screen()
	_fighter_select = Control.new()
	_fighter_select.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fighter_select.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_select.add_child(_fighter_select)
	_select_left_backing = _fade(_fighter_select, true)
	_select_heading = _heading("CHOOSE YOUR FIGHTER", 54)
	_fighter_select.add_child(_select_heading)
	_select_mode_label = _label("VERSUS CPU", 12, ACID)
	_fighter_select.add_child(_select_mode_label)
	_select_bio = VBoxContainer.new()
	_fighter_select.add_child(_select_bio)
	_bio_role = _label("P1 / SELECT", 12, ACID)
	_select_bio.add_child(_bio_role)
	_bio_name = _heading("KAI", 78)
	_select_bio.add_child(_bio_name)
	_bio_style = _label("RUSH / FIRE", 14, ACID)
	_select_bio.add_child(_bio_style)
	_bio_description = _label("", 14, MUTED)
	_bio_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bio_description.custom_minimum_size.x = 315
	_select_bio.add_child(_bio_description)
	_spacer(_select_bio, 8)
	_bio_moves = _label("", 12, WHITE)
	_bio_moves.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_select_bio.add_child(_bio_moves)
	_select_opponent_backing = SlashPanel.new()
	_select_opponent_backing.cut = 24
	_select_opponent_backing.fill = Color(0.025, 0.035, 0.04, 0.91)
	_fighter_select.add_child(_select_opponent_backing)
	_select_opponent = VBoxContainer.new()
	_fighter_select.add_child(_select_opponent)
	_select_opponent.add_child(_label("THE MATCHUP", 12, RED))
	_matchup_name = _heading("KAI\nVS NEON", 36)
	_select_opponent.add_child(_matchup_name)
	_matchup_description = _label("Choose your opponent next.", 12, MUTED)
	_matchup_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_matchup_description.custom_minimum_size.x = 225
	_select_opponent.add_child(_matchup_description)
	_roster_backing = ColorRect.new()
	_roster_backing.color = Color(0.025, 0.03, 0.035, 0.89)
	_fighter_select.add_child(_roster_backing)
	_roster = GridContainer.new()
	_roster.columns = 6
	_roster.add_theme_constant_override("h_separation", 8)
	_roster.add_theme_constant_override("v_separation", 8)
	_fighter_select.add_child(_roster)
	var atlas: Texture2D = load("res://assets/ui/future_fighters.png") as Texture2D
	var fighters: Array[Dictionary] = FighterCatalog.all()
	var grayscale_shader := Shader.new()
	grayscale_shader.code = "shader_type canvas_item; void fragment(){vec4 c=texture(TEXTURE,UV);float g=dot(c.rgb,vec3(0.299,0.587,0.114));COLOR=vec4(vec3(g)*0.40,c.a);}"
	for index: int in range(12):
		var tile := Button.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
		tile.clip_contents = true
		var available := index < fighters.size()
		tile.disabled = not available
		tile.focus_mode = Control.FOCUS_ALL if available else Control.FOCUS_NONE
		tile.tooltip_text = str(fighters[index].name) + " / " + str(fighters[index].archetype) if available else "Coming soon · Not playable"
		var tile_style: StyleBoxFlat = _box(Color("1c2226"), Color("363b3d"))
		tile_style.set_border_width_all(1)
		for style_name: String in ["normal", "disabled", "hover", "pressed", "focus"]:
			tile.add_theme_stylebox_override(style_name, tile_style)
		_roster.add_child(tile)
		var art := TextureRect.new()
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.offset_left = 3
		art.offset_right = -3
		art.offset_top = 3
		art.offset_bottom = -3
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		if available:
			var id: String = fighters[index].id
			art.texture = load(fighters[index].portrait_path) as Texture2D
			_roster_buttons.append(tile)
			_roster_ids.append(id)
			tile.pressed.connect(_choose_fighter.bind(id))
			tile.focus_entered.connect(_preview_fighter.bind(id))
			tile.mouse_entered.connect(_preview_fighter.bind(id))
		else:
			var region := AtlasTexture.new()
			region.atlas = atlas
			if atlas != null:
				var cell: Vector2 = Vector2(atlas.get_width() / 4.0, atlas.get_height() / 3.0)
				region.region = Rect2(Vector2(index % 4, floori(index / 4.0)) * cell, cell)
			art.texture = region
			var material := ShaderMaterial.new()
			material.shader = grayscale_shader
			art.material = material
		tile.add_child(art)
		var strip := ColorRect.new()
		strip.color = Color(0.035, 0.045, 0.055, 0.92)
		strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		strip.offset_top = -25
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(strip)
		var name_label: Label = _label(str(fighters[index].name).to_upper() if available else "COMING SOON", 12 if available else 11, WHITE if available else Color("929697"))
		name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		strip.add_child(name_label)
		if not available:
			var locked := _label("×", 26, Color("b4b8b9"))
			locked.position = Vector2(10, 4)
			tile.add_child(locked)
	_select_footer = HBoxContainer.new()
	_fighter_select.add_child(_select_footer)
	_select_footer.add_child(_button("← BACK", _selection_back))
	var roster_note := _label("10 / 12 AVAILABLE", 11, MUTED)
	roster_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_select_footer.add_child(roster_note)
	_confirm_button = _slash("CONFIRM KAI", _confirm_fighter, "", true, 46)
	_select_footer.add_child(_confirm_button)
	_build_stage_selection()

func _build_stage_selection() -> void:
	_stage_select = Control.new()
	_stage_select.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_select.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_select.add_child(_stage_select)
	_stage_heading = _heading("PICK YOUR\nBATTLEGROUND.", 68)
	_stage_select.add_child(_stage_heading)
	_stage_note = _label("KAI  VS  KAI    /    CHOOSE A STAGE", 12, ACID)
	_stage_select.add_child(_stage_note)
	_stage_cards = HBoxContainer.new()
	_stage_cards.add_theme_constant_override("separation", 14)
	_stage_select.add_child(_stage_cards)
	_stage_footer = HBoxContainer.new()
	_stage_select.add_child(_stage_footer)
	_stage_footer.add_child(_button("← FIGHTERS", _show_fighter_selection))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_footer.add_child(spacer)
	_stage_footer.add_child(_slash("LET'S FIGHT", func() -> void: fight_requested.emit(), "", true, 48))

func _build_hud() -> void:
	_hud = _screen()
	_hud_backing = _fade(_hud)
	_hud_top = HBoxContainer.new()
	_hud_top.add_theme_constant_override("separation", 24)
	_hud.add_child(_hud_top)
	for index: int in range(2):
		if index == 1:
			var center := VBoxContainer.new()
			center.custom_minimum_size.x = 100
			center.add_theme_constant_override("separation", -7)
			_hud_top.add_child(center)
			_round = _label("ROUND 01", 11, WHITE)
			_round.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			center.add_child(_round)
			_timer = _heading("99", 62, ACID)
			_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			center.add_child(_timer)
		var player := VBoxContainer.new()
		player.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		player.add_theme_constant_override("separation", 6)
		_hud_top.add_child(player)
		var identity := HBoxContainer.new()
		player.add_child(identity)
		var name_label: Label = _heading("KAI", 27)
		_player_names.append(name_label)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		identity.add_child(name_label)
		var side_label := _label("P1" if index == 0 else "CPU", 12, ACID if index == 0 else RED)
		identity.add_child(side_label)
		if index == 1:
			_p2_identity = side_label
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			identity.move_child(side_label, 0)
		_health.append(_meter(player, ACID if index == 0 else RED, 25, index == 1))
		_guard.append(_meter(player, Color("bdc4c4"), 4, index == 1))
		_energy.append(_meter(player, BLUE, 5, index == 1))
		var gauges := _label("GUARD 100  /  ENERGY 000", 10, Color("c2c8c6"))
		if index == 1:
			gauges.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		player.add_child(gauges)
		_gauge_labels.append(gauges)
		var rounds := _label("◇  ◇", 17, ACID if index == 0 else RED)
		if index == 1:
			rounds.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		player.add_child(rounds)
		_win_markers.append(rounds)
		var combo := _heading("", 46, ACID if index == 0 else RED)
		_hud.add_child(combo)
		_combo_labels.append(combo)
		var power := _label("", 12, ACID if index == 0 else RED)
		_hud.add_child(power)
		_power_labels.append(power)
	_hud_mode = _label("VERSUS CPU", 11, WHITE)
	_hud.add_child(_hud_mode)
	_hud_pause = _button("Ⅱ  PAUSE  /  ESC", func() -> void: pause_requested.emit())
	_hud_pause.add_theme_font_size_override("font_size", 11)
	_hud.add_child(_hud_pause)

func _meter(parent: VBoxContainer, color: Color, height: float, reversed: bool) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = height
	bar.show_percentage = false
	bar.max_value = 100
	bar.value = 100
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN if reversed else ProgressBar.FILL_BEGIN_TO_END
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.04, 0.05, 0.06, 0.94)
	background.border_color = Color("383d3c")
	background.set_border_width_all(1)
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar

func _build_result() -> void:
	_result = _screen()
	_result_panel = SlashPanel.new()
	_result.add_child(_result_panel)
	_result_content = VBoxContainer.new()
	_result_content.add_theme_constant_override("separation", 18)
	_result.add_child(_result_content)
	_result_content.add_child(_label("RIFT RIOT  /  MATCH RESULT", 12, ACID))
	_result_title = _heading("VICTORY", 88, ACID)
	_result_content.add_child(_result_title)
	_result_caption = _label("PLAYER 1  /  KAI", 18, WHITE)
	_result_content.add_child(_result_caption)
	_spacer(_result_content, 24)
	_result_actions = VBoxContainer.new()
	_result_actions.add_theme_constant_override("separation", 10)
	_result_content.add_child(_result_actions)

func _build_cinematic() -> void:
	_cinematic = _screen()
	var top := ColorRect.new()
	top.color = Color("080a0f")
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 56
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cinematic.add_child(top)
	var brand := _label("RIFT//RIOT   /   LIMIT RELEASE", 15, WHITE, true)
	brand.position = Vector2(30, 17)
	top.add_child(brand)
	var bottom := ColorRect.new()
	bottom.color = Color("080a0f")
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -110
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cinematic.add_child(bottom)
	_cinematic_name = _heading("RIFT BREAKER", 46, ACID)
	_cinematic_name.position = Vector2(32, 18)
	bottom.add_child(_cinematic_name)
	_cinematic_fighter = _label("KAI / SUPER", 15, WHITE)
	_cinematic_fighter.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_cinematic_fighter.offset_left = -290
	_cinematic_fighter.offset_right = -32
	_cinematic_fighter.offset_top = 38
	_cinematic_fighter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom.add_child(_cinematic_fighter)
	_cinematic_rule = ColorRect.new()
	_cinematic_rule.color = ACID
	_cinematic_rule.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_cinematic_rule.offset_bottom = 3
	_cinematic_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_cinematic_rule)

func show_cinematic(profile: Dictionary) -> void:
	_hide_screens()
	_cinematic.show()
	_cinematic_name.text = str(profile.super_name).to_upper()
	_cinematic_name.add_theme_color_override("font_color", profile.color)
	_cinematic_fighter.text = str(profile.name).to_upper() + " / SUPER"
	_cinematic_rule.color = profile.color
	get_viewport().gui_release_focus()

func _modal(title: String, subtitle: String, dimensions: Vector2) -> Dictionary:
	var screen: Control = _screen()
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.02, 0.025, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color("14191c"), Color("49503c")))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -dimensions.x * 0.5
	panel.offset_top = -dimensions.y * 0.5
	panel.offset_right = dimensions.x * 0.5
	panel.offset_bottom = dimensions.y * 0.5
	screen.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	column.add_child(_label(subtitle, 11, ACID))
	column.add_child(_heading(title, 58))
	return {"screen": screen, "content": column}

func _build_pause() -> void:
	var modal: Dictionary = _modal("PAUSED", "TAKE A BREATH. THEN GET BACK IN.", Vector2(500, 580))
	_pause = modal["screen"] as Control
	var column: VBoxContainer = modal["content"] as VBoxContainer
	column.add_child(_slash("RESUME", func() -> void: resume_requested.emit(), "", true, 58))
	column.add_child(_slash("REMATCH", func() -> void: rematch_requested.emit(), "", false, 58))
	column.add_child(_button("FIGHTER COMMAND", func() -> void: command_requested.emit()))
	column.add_child(_button("HOW TO PLAY", show_controls))
	column.add_child(_button("SETTINGS", _show_settings))
	column.add_child(_button("BACK TO MAIN MENU", func() -> void: menu_requested.emit()))
	column.add_child(_label("P1  WASD + J/K/L    ·    P2  ARROWS + 1/2/3\nESC / START  Resume    ·    Controllers supported", 11, MUTED))

func _build_settings() -> void:
	var modal: Dictionary = _modal("SYSTEM", "TUNE YOUR FIGHT", Vector2(540, 585))
	_settings = modal["screen"] as Control
	var column: VBoxContainer = modal["content"] as VBoxContainer
	_music_check = CheckButton.new()
	_music_check.text = "MUSIC"
	_music_check.custom_minimum_size.y = 52
	_music_check.button_pressed = _music_enabled
	_music_check.toggled.connect(func(enabled: bool) -> void: _music_enabled = enabled; music_toggled.emit(enabled))
	column.add_child(_music_check)
	column.add_child(_label("CPU DIFFICULTY", 12, ACID))
	_difficulty_picker = OptionButton.new()
	_difficulty_picker.custom_minimum_size.y = 46
	for difficulty: String in ["EASY", "NORMAL", "HARD", "EXPERT"]:
		_difficulty_picker.add_item(difficulty)
	_difficulty_picker.select(_difficulty)
	_difficulty_picker.item_selected.connect(func(index: int) -> void: _difficulty = index; difficulty_changed.emit(index))
	column.add_child(_difficulty_picker)
	column.add_child(_label("Applies to VERSUS CPU. Arcade always climbs from ROOKIE to EXPERT across nine bouts.", 12, MUTED))
	column.add_child(_slash("CONTROL SETTINGS", func() -> void: control_settings_requested.emit(), "REMAP KEYBOARD OR CONTROLLER", false, 48))
	column.add_child(_label("Environments: Poly Haven CC0\nOriginal synth-metal score", 11, MUTED))
	_spacer(column, 10)
	column.add_child(_slash("DONE", _close_settings, "", true, 50))

func _build_controls() -> void:
	var modal: Dictionary = _modal("HOW TO PLAY", "LEARN THE INPUTS. FIND YOUR RHYTHM.", Vector2(860, 680))
	_controls = modal["screen"] as Control
	var column: VBoxContainer = modal["content"] as VBoxContainer
	column.add_theme_constant_override("separation", 8)
	var table := GridContainer.new()
	table.columns = 4
	table.add_theme_constant_override("h_separation", 30)
	table.add_theme_constant_override("v_separation", 8)
	column.add_child(table)
	var rows: Array[PackedStringArray] = [
		PackedStringArray(["ACTION", "PLAYER 1", "PLAYER 2", "GAMEPAD"]),
		PackedStringArray(["Move / Jump / Crouch", "W A S D", "Arrow keys", "D-pad / Left stick"]),
		PackedStringArray(["Light / Heavy / Low", "J / K / L", "1 / 2 / 3", "A / B / X"]),
		PackedStringArray(["Special I", "U", "5", "Y"]),
		PackedStringArray(["Guard", "I", "0", "LB"]),
		PackedStringArray(["Dodge", "Shift", "4", "RB"]),
		PackedStringArray(["Special II", "O", "6", "RT"]),
		PackedStringArray(["Overdrive / SUPER", "H / P", "7 / 8", "LT / R-stick click"]),
		PackedStringArray(["Pause", "Escape", "Escape", "Start"]),
	]
	for row_index: int in range(rows.size()):
		for value: String in rows[row_index]:
			var cell: Label = _label(value, 12 if row_index > 0 else 11, WHITE if row_index > 0 else ACID)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			table.add_child(cell)
	_spacer(column, 12)
	var tips := _label("J is light. K is heavy. U and O are your character's unique specials.\nEarn POWER by fighting. At 100, land P's opening hit for a cinematic SUPER.\nH spends 50 power on overdrive. Open SYSTEM → CONTROL SETTINGS to remap. F11 fullscreen. F3 hitboxes / frame data.", 13, MUTED)
	column.add_child(tips)
	column.add_child(_label("Ten fighters, ten styles. Choose both fighters in versus.\nArcade challenges the other nine fighters with rising difficulty.", 12, MUTED))
	_spacer(column, 5)
	column.add_child(_slash("GOT IT", _close_controls, "", true, 48))

func _build_announcement() -> void:
	_announcement = _screen()
	_announcement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var band := ColorRect.new()
	band.color = Color(0.025, 0.03, 0.035, 0.78)
	band.anchor_right = 1.0
	band.anchor_top = 0.5
	band.anchor_bottom = 0.5
	band.offset_top = -107
	band.offset_bottom = 107
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_announcement.add_child(band)
	var column := VBoxContainer.new()
	column.anchor_right = 1.0
	column.anchor_top = 0.5
	column.anchor_bottom = 0.5
	column.offset_top = -92
	column.offset_bottom = 92
	column.add_theme_constant_override("separation", -2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_announcement.add_child(column)
	_announcement_title = _heading("FIGHT", 108, ACID)
	_announcement_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_announcement_title)
	_announcement_subtitle = _label("", 16, WHITE)
	_announcement_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_announcement_subtitle)

func _layout() -> void:
	if not _built or _main_content == null:
		return
	var w: float = maxf(size.x, 1100)
	var h: float = maxf(size.y, 720)
	var edge: float = maxf(38, w * 0.035)
	_main_panel.size = Vector2(w * 0.47, h)
	_main_content.position = Vector2(edge, maxf(28, h * 0.052))
	_main_content.size = Vector2(w * 0.345, 0)
	_main_title.add_theme_font_size_override("font_size", int(clampf(h * 0.128, 89, 115)))
	_main_name.position = Vector2(w * 0.71, h * 0.75)
	_main_nameplate.position = _main_name.position - Vector2(20, 15)
	_main_nameplate.size = Vector2(minf(w * 0.28, 382), 153)
	_main_note.position = Vector2(w - 340, 42)
	_main_note.size.x = 290
	_main_note_backing.position = _main_note.position - Vector2(15, 11)
	_main_note_backing.size = Vector2(324, 54)
	_select_left_backing.size = Vector2(maxf(620, w * 0.46), 490)
	_select_heading.position = Vector2(edge, 34)
	_select_heading.add_theme_font_size_override("font_size", int(clampf(w * 0.038, 42, 58)))
	_select_mode_label.position = Vector2(edge + 3, 100)
	_select_bio.position = Vector2(edge, 154)
	_select_bio.size.x = 330
	_bio_name.add_theme_font_size_override("font_size", 78 if h >= 820 else 60)
	_select_opponent.position = Vector2(w - edge - 254, 172)
	_select_opponent_backing.position = _select_opponent.position - Vector2(22, 18)
	_select_opponent_backing.size = Vector2(302, 256)
	var roster_height: float = clampf(h * 0.24, 174, 214)
	_roster_backing.position = Vector2(0, h - roster_height - 94)
	_roster_backing.size = Vector2(w, roster_height + 94)
	_roster.position = Vector2(edge, h - roster_height - 78)
	_roster.size = Vector2(w - edge * 2, roster_height)
	for tile: Node in _roster.get_children():
		(tile as Control).custom_minimum_size = Vector2((w - edge * 2 - 40) / 6, (roster_height - 8) / 2)
	_select_footer.position = Vector2(edge, h - 62)
	_select_footer.size = Vector2(w - edge * 2, 46)
	_stage_heading.position = Vector2(edge, 56)
	_stage_note.position = Vector2(edge + 2, 218)
	_stage_cards.position = Vector2(edge, h - 230)
	_stage_cards.size = Vector2(w - edge * 2, 130)
	_stage_footer.position = Vector2(edge, h - 74)
	_stage_footer.size = Vector2(w - edge * 2, 48)
	_hud_top.position = Vector2(edge, 28)
	_hud_top.size = Vector2(w - edge * 2, 130)
	_hud_backing.size = Vector2(w, 222)
	_combo_labels[0].position = Vector2(edge, 185)
	_combo_labels[1].position = Vector2(w - edge - 225, 185)
	_combo_labels[1].size.x = 225
	_combo_labels[1].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_power_labels[0].position = Vector2(edge, h - 76)
	_power_labels[1].position = Vector2(w - edge - 235, h - 76)
	_power_labels[1].size.x = 235
	_power_labels[1].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud_mode.position = Vector2(edge, h - 37)
	_hud_pause.position = Vector2(w - edge - 168, h - 54)
	_hud_pause.size = Vector2(168, 36)
	_result_panel.size = Vector2(w * 0.49, h)
	_result_content.position = Vector2(edge, h * 0.19)
	_result_content.size = Vector2(w * 0.40, 0)
	_result_title.add_theme_font_size_override("font_size", int(clampf(w * 0.065, 70, 98)))

func _hide_screens() -> void:
	for screen: Control in [_main, _select, _hud, _result, _pause, _settings, _controls, _announcement, _cinematic]:
		screen.hide()

func _focus_first(parent: Node) -> void:
	call_deferred("_apply_focus", weakref(parent))

func _apply_focus(reference: WeakRef) -> void:
	var parent: Node = reference.get_ref() as Node
	if parent == null or not parent.is_inside_tree():
		return
	var button: BaseButton = _first_focusable(parent)
	if button != null:
		button.grab_focus()

func _first_focusable(parent: Node) -> BaseButton:
	for child: Node in parent.get_children():
		if child is BaseButton:
			var button: BaseButton = child as BaseButton
			if not button.disabled and button.is_visible_in_tree():
				return button
		if child.get_child_count() > 0:
			var nested: BaseButton = _first_focusable(child)
			if nested != null:
				return nested
	return null

func show_main() -> void:
	_ensure_built()
	_hide_screens()
	_main.show()
	var fighter: Dictionary = FighterCatalog.get_fighter(_fighter_ids[0])
	(_main_name.get_child(1) as Label).text = str(fighter.name).to_upper()
	(_main_name.get_child(2) as Label).text = str(fighter.archetype).to_upper()
	_layout()
	_focus_first(_main_content)

func show_select(mode: String, stage_names: PackedStringArray) -> void:
	_ensure_built()
	_mode = mode
	_selection_slot = 0
	_stage_names = stage_names
	_stage_index = clampi(_stage_index, 0, maxi(stage_names.size() - 1, 0))
	_select_mode_label.text = _mode_name(mode)
	_hide_screens()
	_select.show()
	_rebuild_stages()
	_show_fighter_selection()
	_layout()

func _confirm_fighter() -> void:
	fighter_confirmed.emit()
	if _selection_slot == 0 and _mode != "arcade":
		_selection_slot = 1
		_show_fighter_selection()
	else:
		_show_stage_selection()

func _choose_fighter(id: String) -> void:
	_preview_fighter(id)
	_confirm_fighter()

func _preview_fighter(id: String) -> void:
	if not _fighter_select.visible or not _select.visible: return
	var changed: bool = _fighter_ids[_selection_slot] != id
	_fighter_ids[_selection_slot] = id
	_refresh_selection_info()
	if changed: fighter_changed.emit(id, _selection_slot)

func _refresh_selection_info() -> void:
	var id: String = _fighter_ids[_selection_slot]
	var fighter: Dictionary = FighterCatalog.get_fighter(id)
	_bio_role.text = "PLAYER 1 / CHOOSE" if _selection_slot == 0 else "PLAYER 2 / CHOOSE" if _mode == "local" else "CPU / CHOOSE OPPONENT"
	_bio_name.text = str(fighter.name).to_upper()
	_bio_name.add_theme_color_override("font_color", fighter.color)
	_bio_style.text = str(fighter.archetype).to_upper()
	_bio_description.text = str(fighter.description)
	var moves: Array[MoveData] = FighterCatalog.moves(id)
	_bio_moves.text = "SPECIAL // %s\nSUPER // %s" % [moves[5].display_name.to_upper(), str(fighter.super_name).to_upper()]
	_matchup_name.text = "%s\nVS %s" % [str(FighterCatalog.get_fighter(_fighter_ids[0]).name).to_upper(), "THE ROSTER" if _mode == "arcade" else str(FighterCatalog.get_fighter(_fighter_ids[1]).name).to_upper()]
	_matchup_description.text = "Nine opponents. Rising difficulty.\nYour power meter builds through combat." if _mode == "arcade" else "Select P1, then choose an opponent.\nBuild 100 power to unleash a cinematic super."
	_confirm_button.text = "CONFIRM " + str(fighter.name).to_upper()
	_confirm_button.queue_redraw()
	for i in range(_roster_buttons.size()):
		var selected: bool = _roster_ids[i] == id
		var border := _box(Color("1c2226"), fighter.color if selected else Color("363b3d"))
		border.set_border_width_all(3 if selected else 1)
		for state_name in ["normal", "focus", "hover", "pressed"]:
			_roster_buttons[i].add_theme_stylebox_override(state_name, border)

func set_fighters(ids: Array[String]) -> void:
	for i in range(mini(2, ids.size())):
		_fighter_ids[i] = str(FighterCatalog.get_fighter(ids[i]).id)
	if _built:
		for i in range(_player_names.size()):
			_player_names[i].text = str(FighterCatalog.get_fighter(_fighter_ids[i]).name).to_upper()

func get_fighters() -> Array[String]:
	return _fighter_ids.duplicate()

func _focus_roster() -> void:
	var index := _roster_ids.find(_fighter_ids[_selection_slot])
	if index >= 0: _roster_buttons[index].call_deferred("grab_focus")

func _selection_back() -> void:
	if _selection_slot > 0:
		_selection_slot = 0
		_show_fighter_selection()
	else: menu_requested.emit()

func _show_fighter_selection() -> void:
	_fighter_select.show()
	_stage_select.hide()
	selection_step_changed.emit("fighter")
	_refresh_selection_info()
	fighter_changed.emit(_fighter_ids[_selection_slot], _selection_slot)
	_focus_roster()

func _show_stage_selection() -> void:
	_fighter_select.hide()
	_stage_select.show()
	_stage_note.text = "%s VS %s / CHOOSE A STAGE" % [str(FighterCatalog.get_fighter(_fighter_ids[0]).name).to_upper(), "THE CIRCUIT" if _mode == "arcade" else str(FighterCatalog.get_fighter(_fighter_ids[1]).name).to_upper()]
	selection_step_changed.emit("stage")
	stage_selected.emit(_stage_index)
	_focus_first(_stage_cards)

func show_stages() -> void:
	_ensure_built()
	_show_stage_selection()

func _rebuild_stages() -> void:
	for child: Node in _stage_cards.get_children():
		_stage_cards.remove_child(child)
		child.queue_free()
	_stage_buttons.clear()
	for index: int in range(_stage_names.size()):
		var button: SlashButton = _slash(_stage_names[index].to_upper(), _choose_stage.bind(index), "STAGE %02d  /  AVAILABLE" % (index + 1), false, 112)
		button.title_size = 27
		button.toggle_mode = true
		button.button_pressed = index == _stage_index
		_stage_cards.add_child(button)
		_stage_buttons.append(button)

func _choose_stage(index: int) -> void:
	_stage_index = index
	for i: int in range(_stage_buttons.size()):
		_stage_buttons[i].set_pressed_no_signal(i == index)
		_stage_buttons[i].queue_redraw()
	stage_selected.emit(index)

func set_stage(index: int) -> void:
	_stage_index = clampi(index, 0, maxi(_stage_names.size() - 1, 0))
	for i: int in range(_stage_buttons.size()):
		_stage_buttons[i].set_pressed_no_signal(i == _stage_index)
		_stage_buttons[i].queue_redraw()

func show_hud(mode: String) -> void:
	_ensure_built()
	_mode = mode
	_hide_screens()
	_hud.show()
	set_fighters(_fighter_ids)
	_p2_identity.text = "P2" if mode == "local" else "CPU"
	_hud_mode.text = _mode_name(mode)
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()

func update_hud(fighters: Array[Dictionary], wins: Array[int], remaining_frames: int, round_number: int, arcade_index: int) -> void:
	_ensure_built()
	for index: int in range(mini(2, fighters.size())):
		_health[index].value = float(fighters[index].get("hp", 100))
		_guard[index].value = float(fighters[index].get("guard", 100))
		_energy[index].value = float(fighters[index].get("energy", 0))
		_gauge_labels[index].text = "GUARD %03d  /  %s" % [int(_guard[index].value), "SUPER READY · P" if index == 0 and _energy[index].value >= 100 else "SUPER READY · 8" if _energy[index].value >= 100 else "POWER %03d" % int(_energy[index].value)]
		_gauge_labels[index].add_theme_color_override("font_color", ACID if _energy[index].value >= 100 else MUTED)
		var power_frames: int = int(fighters[index].get("power_frames", 0))
		_power_labels[index].text = "OVERDRIVE  /  %.1f s" % (power_frames / 60.0) if power_frames > 0 else ""
		var won: int = wins[index] if index < wins.size() else 0
		_win_markers[index].text = ("◆" if won >= 1 else "◇") + "  " + ("◆" if won >= 2 else "◇")
		var combo: int = int(fighters[index].get("combo", 0))
		_combo_labels[index].text = "%d HIT" % combo if combo > 1 else ""
	_timer.text = "%02d" % maxi(0, ceili(float(remaining_frames) / 60.0))
	_timer.add_theme_color_override("font_color", RED if remaining_frames <= 10 * 60 else ACID)
	_round.text = "ROUND %02d" % round_number
	_hud_mode.text = "ARCADE / BOUT %02d OF 09 / %s" % [arcade_index + 1, _arcade_tier(arcade_index)] if _mode == "arcade" else _mode_name(_mode)


func _arcade_tier(arcade_index: int) -> String:
	return ["ROOKIE", "ROOKIE", "CHALLENGER", "CHALLENGER", "VETERAN", "VETERAN", "EXPERT", "EXPERT", "EXPERT"][clampi(arcade_index, 0, 8)]

func show_announcement(text: String, subtitle: String = "") -> void:
	_ensure_built()
	if _announcement_tween != null and _announcement_tween.is_valid():
		_announcement_tween.kill()
	if text.is_empty():
		_announcement.hide()
		return
	_announcement_title.text = text.to_upper()
	_announcement_subtitle.text = subtitle.to_upper()
	_announcement.show()
	_announcement.modulate.a = 1.0
	_announcement_tween = create_tween()
	_announcement_tween.tween_interval(1.2)
	_announcement_tween.tween_property(_announcement, "modulate:a", 0.0, 0.2)
	_announcement_tween.tween_callback(_announcement.hide)

func show_result(winner: int, mode: String, arcade_index: int, complete: bool = false) -> void:
	_ensure_built()
	_mode = mode
	_hide_screens()
	_result.show()
	_result_title.text = "VICTORY" if winner == 0 else "DEFEAT"
	_result_title.add_theme_color_override("font_color", ACID if winner == 0 else RED)
	var winner_name: String = str(FighterCatalog.get_fighter(_fighter_ids[maxi(0, winner)]).name).to_upper()
	_result_caption.text = "PLAYER %d / %s WINS" % [winner + 1, winner_name]
	if mode == "local":
		_result_title.text = "P%d WINS" % (winner + 1)
	elif mode == "arcade":
		_result_caption.text = "BOUT %02d / %s" % [arcade_index + 1, "CIRCUIT COMPLETE" if complete and winner == 0 else winner_name + " ADVANCES" if winner == 0 else "THE CIRCUIT ENDS HERE"]
		if complete and winner == 0:
			_result_title.text = "ARCADE\nCOMPLETE"
	for child: Node in _result_actions.get_children():
		_result_actions.remove_child(child)
		child.queue_free()
	if mode == "arcade" and winner == 0 and not complete:
		_result_actions.add_child(_slash("NEXT FIGHT", func() -> void: next_requested.emit(), "", true))
	_result_actions.add_child(_slash("REMATCH", func() -> void: rematch_requested.emit(), "", mode != "arcade" or winner != 0 or complete))
	_result_actions.add_child(_slash("MAIN MENU", func() -> void: menu_requested.emit()))
	_layout()
	_focus_first(_result_actions)

func show_pause() -> void:
	_ensure_built()
	_pause.show()
	_focus_first(_pause)

func hide_pause() -> void:
	_ensure_built()
	_pause.hide()
	_settings.hide()
	_controls.hide()
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()

func handle_back() -> bool:
	## Lets the parent route Escape / controller cancel through the current UI layer.
	if _controls != null and _controls.visible:
		_close_controls()
		return true
	if _settings != null and _settings.visible:
		_close_settings()
		return true
	if _select != null and _select.visible and _stage_select.visible:
		_show_fighter_selection()
		return true
	if _select != null and _select.visible and _fighter_select.visible and _selection_slot > 0:
		_selection_back()
		return true
	return false

func set_music(enabled: bool) -> void:
	_music_enabled = enabled
	if _music_check != null:
		_music_check.set_pressed_no_signal(enabled)

func set_difficulty(index: int) -> void:
	_difficulty = clampi(index, 0, 3)
	if _difficulty_picker != null:
		_difficulty_picker.select(_difficulty)

func _show_settings() -> void:
	_modal_return = _pause if _pause.visible else _main
	_settings.show()
	_focus_first(_settings)

func _close_settings() -> void:
	_settings.hide()
	if _modal_return != null:
		_focus_first(_modal_return)

func show_controls() -> void:
	_ensure_built()
	_modal_return = _pause if _pause.visible else _main
	_controls.show()
	_focus_first(_controls)

func _close_controls() -> void:
	_controls.hide()
	if _modal_return != null:
		_focus_first(_modal_return)

func _mode_name(mode: String) -> String:
	match mode:
		"local": return "LOCAL VERSUS"
		"arcade": return "ARCADE CIRCUIT"
		_: return "VERSUS CPU"
