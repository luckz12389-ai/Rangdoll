extends CanvasLayer
## Mobile controls: floating joystick (left 40%), look-drag (right side), action buttons.

signal jump_pressed
signal sprint_toggled(on: bool)
signal camera_pressed
signal spawn_npc_pressed
signal noise_pressed
signal knockout_pressed
signal pause_pressed

const JOY_RADIUS := 130.0
var move_vec := Vector2.ZERO
var _look := Vector2.ZERO
var _joy_id := -1
var _look_id := -1
var _joy_origin := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _pad: Control

func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.set_default_font_size(24)
	root.theme = th
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pad = Control.new()
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.draw.connect(_draw_joy)
	root.add_child(_pad)
	_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# bottom-right cluster (no overlaps): sizes/offsets in pixels from the screen edge
	_btn(root, GameSettings.t("jump"), 60, 60, 150).pressed.connect(jump_pressed.emit)
	var run := _btn(root, GameSettings.t("run"), 240, 60, 110)
	run.toggle_mode = true
	run.toggled.connect(func(on: bool): sprint_toggled.emit(on))
	_btn(root, "NPC+", 60, 240, 110).pressed.connect(spawn_npc_pressed.emit)
	_btn(root, GameSettings.t("noise"), 240, 200, 110).pressed.connect(noise_pressed.emit)
	_btn(root, "KO", 60, 370, 110).pressed.connect(knockout_pressed.emit)
	# top-right
	_btn(root, "II", 40, 40, 90, true).pressed.connect(pause_pressed.emit)
	_btn(root, GameSettings.t("cam"), 150, 40, 90, true).pressed.connect(camera_pressed.emit)

func _btn(root: Control, text: String, from_right: float, from_edge: float, size: float, top := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 0.0 if top else 1.0
	b.anchor_bottom = b.anchor_top
	b.offset_right = -from_right
	b.offset_left = -from_right - size
	if top:
		b.offset_top = from_edge
		b.offset_bottom = from_edge + size
	else:
		b.offset_bottom = -from_edge
		b.offset_top = -from_edge - size
	root.add_child(b)
	return b

func consume_look() -> Vector2:
	var l := _look
	_look = Vector2.ZERO
	return l

func _unhandled_input(e: InputEvent) -> void:
	var w := get_viewport().get_visible_rect().size.x
	if e is InputEventScreenTouch:
		if e.pressed:
			if e.position.x < w * 0.4 and _joy_id == -1:
				_joy_id = e.index
				_joy_origin = e.position
				_joy_pos = e.position
				_pad.queue_redraw()
			elif e.position.x >= w * 0.4 and _look_id == -1:
				_look_id = e.index
		else:
			if e.index == _joy_id:
				_joy_id = -1
				move_vec = Vector2.ZERO
				_pad.queue_redraw()
			elif e.index == _look_id:
				_look_id = -1
	elif e is InputEventScreenDrag:
		if e.index == _joy_id:
			var d: Vector2 = (e.position - _joy_origin).limit_length(JOY_RADIUS)
			_joy_pos = _joy_origin + d
			move_vec = d / JOY_RADIUS
			_pad.queue_redraw()
		elif e.index == _look_id:
			_look += e.relative

func _draw_joy() -> void:
	if _joy_id == -1:
		return
	_pad.draw_circle(_joy_origin, JOY_RADIUS, Color(1, 1, 1, 0.12))
	_pad.draw_circle(_joy_pos, 50.0, Color(1, 1, 1, 0.35))
