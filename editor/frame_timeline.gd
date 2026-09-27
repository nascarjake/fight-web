extends Control
## Zero-based 60 Hz move timeline. One cell represents one simulation frame.

signal scrubbed(frame: int)

const STARTUP_COLOR := Color("dfbd66")
const ACTIVE_COLOR := Color("f07768")
const RECOVERY_COLOR := Color("7186a2")
const INVULN_COLOR := Color("77d9d0")
const ACCENT_COLOR := Color("d6ed68")

var move: MoveData
var playhead: int = 0
var _dragging: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(0, 94)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	tooltip_text = "Drag to inspect an exact frame. Arrow keys step one frame. Frame 0 is the first frame; simulation runs at 60 Hz."

func set_move(value: MoveData) -> void:
	move = value
	playhead = clampi(playhead, 0, _total() - 1)
	queue_redraw()

func set_playhead(frame: int) -> void:
	playhead = clampi(frame, 0, _total() - 1)
	queue_redraw()

func _total() -> int:
	return maxi(move.total_frames(), 1) if move != null else 1

func _track() -> Rect2:
	return Rect2(2, 14, maxf(size.x - 4, 1), 30)

func _draw() -> void:
	var track: Rect2 = _track()
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(0, 8, size.x, 42), Color("111519"))
	if move == null:
		return
	var total: int = _total()
	var unit: float = track.size.x / float(total)
	var lengths: Array[int] = [move.startup, move.active, move.recovery]
	var colors: Array[Color] = [STARTUP_COLOR, ACTIVE_COLOR, RECOVERY_COLOR]
	var offset: int = 0
	for index: int in range(lengths.size()):
		var segment: Rect2 = Rect2(track.position.x + offset * unit, track.position.y, lengths[index] * unit, track.size.y)
		draw_rect(segment, colors[index])
		if segment.size.x > 25:
			draw_string(font, Vector2(segment.position.x, 34), str(lengths[index]), HORIZONTAL_ALIGNMENT_CENTER, segment.size.x, 12, Color("172026"))
		offset += lengths[index]
	if total <= 100:
		for frame: int in range(1, total):
			var cell_x: float = track.position.x + frame * unit
			draw_line(Vector2(cell_x, 14), Vector2(cell_x, 44), Color(0.06, 0.09, 0.1, 0.23), 1)
	if move.invuln_start >= 0 and move.invuln_end >= move.invuln_start:
		_draw_window(move.invuln_start, move.invuln_end, 48, INVULN_COLOR, unit, total)
	if move.cancel_start >= 0 and move.cancel_end >= move.cancel_start:
		_draw_window(move.cancel_start, move.cancel_end, 55, ACCENT_COLOR, unit, total)
	var tick_step: int = maxi(1, ceili(float(total) / 6.0))
	for tick: int in range(0, total, tick_step):
		var tick_x: float = track.position.x + tick * unit
		draw_line(Vector2(tick_x, 64), Vector2(tick_x, 68), Color("53606b"), 1)
		if tick_x < size.x - 42:
			draw_string(font, Vector2(tick_x, 82), str(tick), HORIZONTAL_ALIGNMENT_LEFT, 40, 10, Color("8b969f"))
	var last_text: String = str(total - 1)
	draw_string(font, Vector2(size.x - 30, 82), last_text, HORIZONTAL_ALIGNMENT_RIGHT, 28, 10, Color("8b969f"))
	var head_x: float = track.position.x + (float(playhead) + 0.5) * unit
	draw_line(Vector2(head_x, 6), Vector2(head_x, 63), Color("f0f4e9"), 2)
	draw_colored_polygon(PackedVector2Array([Vector2(head_x - 4, 1), Vector2(head_x + 4, 1), Vector2(head_x, 7)]), Color("f0f4e9"))
	if has_focus():
		draw_rect(Rect2(0, 0, size.x, size.y), Color("d6ed68"), false, 1)

func _draw_window(first: int, last: int, y: float, color: Color, unit: float, total: int) -> void:
	var start: int = clampi(first, 0, total)
	var end: int = clampi(last + 1, 0, total)
	if end > start:
		draw_rect(Rect2(2 + start * unit, y, (end - start) * unit, 4), color)

func _scrub_at(x: float) -> void:
	var track: Rect2 = _track()
	playhead = clampi(floori((x - track.position.x) / track.size.x * _total()), 0, _total() - 1)
	queue_redraw()
	scrubbed.emit(playhead)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mouse_event.pressed
			if _dragging:
				grab_focus()
				_scrub_at(mouse_event.position.x)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_scrub_at(motion.position.x)
		accept_event()
	elif event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.keycode in [KEY_LEFT, KEY_RIGHT]:
			set_playhead(playhead + (1 if key.keycode == KEY_RIGHT else -1))
			scrubbed.emit(playhead)
			accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()
